'use client';

import { useEffect, useState } from 'react';
import {
  Pencil,
  Trash2,
  Power,
  Layers,
  FileText,
  ListChecks,
  Sparkles,
  Info,
  CheckCircle2,
  XCircle,
  AlertCircle,
  ArrowRight,
  Folder,
  Hash,
  Tag,
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import CategoryIcon from './CategoryIcon';
import ServiceIcon from './ServiceIcon';
import { serviceIconPresets } from '@/lib/service-icons.mjs';

type Category = {
  id: string;
  slug: string;
  name: string;
  description: string;
  active: boolean;
  displayOrder: number;
  iconKey: string | null;
  iconUrl: string | null;
};

type Service = Category & {
  popular: boolean;
  category: Category;
  shortDescription: string;
  suggestedPriceMin: number;
  suggestedPriceMax: number;
  estimatedDurationMinutes: number | null;
  currency: string;
  iconKey: string | null;
  iconUrl: string | null;
};

type QuantityField = {
  key: string;
  label: string;
  minimum: number;
};

interface CategoryDetailModalProps {
  category: Category;
  services: Service[];
  onClose: () => void;
  onEdit: () => void;
  onToggleActive: () => Promise<void> | void;
  onDelete: () => void;
  busy?: boolean;
}

export default function CategoryDetailModal({
  category,
  services,
  onClose,
  onEdit,
  onToggleActive,
  onDelete,
  busy = false,
}: CategoryDetailModalProps) {
  const [quantityFields, setQuantityFields] = useState<QuantityField[]>([]);
  const [loadingFields, setLoadingFields] = useState(true);

  // Fetch quantity fields specifically for this category
  useEffect(() => {
    const controller = new AbortController();
    setLoadingFields(true);
    fetch(`/api/admin/catalogue/service-categories/${category.id}/quantity-fields`, {
      cache: 'no-store',
      signal: controller.signal,
    })
      .then(async res => {
        if (!res.ok) return;
        const json = await res.json();
        if (Array.isArray(json.data)) setQuantityFields(json.data);
      })
      .catch(() => {})
      .finally(() => {
        if (!controller.signal.aborted) setLoadingFields(false);
      });

    return () => controller.abort();
  }, [category.id]);

  const associatedServices = services.filter(s => s.category?.id === category.id);
  const activeServicesCount = associatedServices.filter(s => s.active).length;

  const preset = serviceIconPresets.find(p => p.key === category.iconKey);
  const iconSourceLabel = category.iconUrl
    ? 'Ảnh tải lên riêng'
    : preset
    ? `Icon mẫu: ${preset.label}`
    : 'Tự động theo slug';

  return (
    <CataloguePopup
      title={category.name}
      eyebrow="QUẢN LÝ DANH MỤC & BIỂU MẪU ĐẶT DỊCH VỤ"
      busy={busy}
      wide={true}
      onClose={onClose}
    >
      <div className="catalogue-detail-container">
        {/* 1. HERO HEADER */}
        <div className="catalogue-detail-hero">
          <div className="catalogue-detail-hero-avatar">
            <CategoryIcon
              iconKey={category.iconKey}
              iconUrl={category.iconUrl}
              slug={category.slug}
              size={64}
            />
          </div>

          <div className="catalogue-detail-hero-content">
            <div className="catalogue-detail-badges">
              <span className={`catalogue-status-pill ${category.active ? 'active' : 'inactive'}`}>
                {category.active ? <CheckCircle2 size={12} /> : <XCircle size={12} />}
                {category.active ? 'Đang hoạt động' : 'Tạm ẩn trên App'}
              </span>

              <span className="catalogue-badge-pill code-badge">
                <Tag size={12} />
                slug: {category.slug}
              </span>

              <span className="catalogue-badge-pill category-badge">
                <Hash size={12} />
                Thứ tự #{category.displayOrder}
              </span>

              <span className="catalogue-badge-pill popular-badge">
                <Layers size={12} />
                {associatedServices.length} dịch vụ trực thuộc
              </span>
            </div>

            <h3 className="catalogue-detail-hero-title">{category.name}</h3>

            <p className="catalogue-detail-hero-sub">
              ID: <code className="catalogue-code-tag">{category.id}</code>
            </p>
          </div>

          <div className="catalogue-detail-hero-quick-action">
            <button
              type="button"
              className="btn btn-primary catalogue-hero-edit-btn"
              disabled={busy}
              onClick={onEdit}
            >
              <Pencil size={14} />
              Chỉnh sửa thông tin
            </button>
          </div>
        </div>

        {/* 2. STATS & GENERAL INFO */}
        <section className="catalogue-detail-section">
          <div className="catalogue-detail-section-header">
            <h4>
              <Info size={16} />
              Thông tin chung & Thống kê
            </h4>
          </div>

          <div className="catalogue-detail-card">
            <div className="catalogue-detail-tiles">
              <div className="catalogue-detail-tile">
                <span className="catalogue-detail-tile-label">MÃ ĐƯỜNG DẪN (SLUG)</span>
                <strong className="catalogue-detail-tile-value mono">{category.slug}</strong>
              </div>

              <div className="catalogue-detail-tile">
                <span className="catalogue-detail-tile-label">THỨ TỰ HIỂN THỊ</span>
                <strong className="catalogue-detail-tile-value">#{category.displayOrder}</strong>
              </div>

              <div className="catalogue-detail-tile">
                <span className="catalogue-detail-tile-label">DỊCH VỤ TRỰC THUỘC</span>
                <strong className="catalogue-detail-tile-value">
                  {associatedServices.length} ({activeServicesCount} đang bật)
                </strong>
              </div>

              <div className="catalogue-detail-tile">
                <span className="catalogue-detail-tile-label">NGUỒN BIỂU TƯỢNG (ICON)</span>
                <strong className="catalogue-detail-tile-value">{iconSourceLabel}</strong>
              </div>
            </div>

            <div className="catalogue-detail-desc-block">
              <span className="catalogue-detail-desc-title">Mô tả danh mục</span>
              {category.description ? (
                <p className="catalogue-detail-desc-text">{category.description}</p>
              ) : (
                <p className="catalogue-detail-empty-text">Chưa có mô tả chi tiết cho danh mục này.</p>
              )}
            </div>
          </div>
        </section>

        {/* 3. CATEGORY & BOOKING FORMS / QUANTITY FIELDS */}
        <section className="catalogue-detail-section">
          <div className="catalogue-detail-section-header">
            <h4>
              <ListChecks size={16} />
              Trường số lượng & Form đặt dịch vụ dùng chung
              <span className="catalogue-count-pill">{quantityFields.length} trường</span>
            </h4>
          </div>

          <div className="catalogue-detail-card">
            <div className="catalogue-inherited-box">
              <Sparkles size={16} color="#059669" />
              <div>
                <strong>Quy tắc kế thừa biểu mẫu (Booking Fields)</strong>
                <p>
                  Mọi dịch vụ được thêm vào danh mục <strong>{category.name}</strong> sẽ tự động kế thừa các trường số lượng này trong form đặt dịch vụ. Khách hàng sử dụng các trường này để nhập diện tích, số lượng phòng hoặc khối lượng công việc, đồng thời là biến số để hệ thống tính giá dịch vụ.
                </p>
              </div>
            </div>

            {loadingFields ? (
              <div className="catalogue-detail-empty-box">
                <Info size={16} />
                <span>Đang tải thông tin trường số lượng…</span>
              </div>
            ) : quantityFields.length > 0 ? (
              <div className="catalogue-custom-fields-list">
                {quantityFields.map((field, index) => (
                  <div key={field.key || index} className="catalogue-field-item-card">
                    <div className="catalogue-field-idx">{index + 1}</div>
                    <div className="catalogue-field-item-content">
                      <div className="catalogue-field-item-header">
                        <span className="catalogue-field-item-label">{field.label || field.key}</span>
                        <div className="catalogue-field-item-tags">
                          <span className="catalogue-field-tag type-number">
                            Số nguyên dương (Number)
                          </span>
                          <span className="catalogue-field-tag required">Kế thừa tự động</span>
                        </div>
                      </div>
                      <div className="catalogue-field-item-meta">
                        <span>Mã trường: <code>{field.key}</code></span>
                        <span>•</span>
                        <span>Giá trị tối thiểu: <strong>{field.minimum ?? 1}</strong></span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="catalogue-detail-empty-box">
                <Info size={16} />
                <span>Danh mục này chưa cấu hình trường số lượng dùng chung nào. Nhấn <strong>Chỉnh sửa</strong> để thêm trường.</span>
              </div>
            )}
          </div>
        </section>

        {/* 4. ASSOCIATED SERVICES */}
        <section className="catalogue-detail-section">
          <div className="catalogue-detail-section-header">
            <h4>
              <Folder size={16} />
              Dịch vụ trực thuộc danh mục
              <span className="catalogue-count-pill">{associatedServices.length} dịch vụ</span>
            </h4>
          </div>

          <div className="catalogue-detail-card">
            {associatedServices.length > 0 ? (
              <div className="catalogue-detail-services-grid">
                {associatedServices.map(svc => (
                  <div key={svc.id} className="catalogue-detail-svc-card">
                    <div className="catalogue-detail-svc-icon">
                      <ServiceIcon
                        iconKey={svc.iconKey}
                        iconUrl={svc.iconUrl}
                        slug={svc.slug}
                        size={28}
                      />
                    </div>
                    <div className="catalogue-detail-svc-info">
                      <div className="catalogue-detail-svc-name">
                        <b>{svc.name}</b>
                        {svc.popular && <span className="catalogue-popular-star">★ Phổ biến</span>}
                      </div>
                      <div className="catalogue-detail-svc-meta">
                        <span>slug: {svc.slug}</span>
                        <span>•</span>
                        <span>{svc.estimatedDurationMinutes ? `${svc.estimatedDurationMinutes} phút` : '60 phút'}</span>
                      </div>
                    </div>
                    <div className="catalogue-detail-svc-status">
                      <span className={`catalogue-status ${svc.active ? 'active' : 'inactive'}`}>
                        {svc.active ? 'Hoạt động' : 'Tạm ẩn'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="catalogue-detail-empty-box">
                <Info size={16} />
                <span>Chưa có dịch vụ nào thuộc danh mục này. Bạn có thể sang mục <strong>Dịch vụ</strong> để tạo dịch vụ mới.</span>
              </div>
            )}
          </div>
        </section>

        {/* 5. FOOTER ACTIONS */}
        <div className="catalogue-detail-footer-bar">
          <button
            type="button"
            className="btn btn-outline"
            disabled={busy}
            onClick={onClose}
          >
            Đóng
          </button>

          <button
            type="button"
            className="btn btn-outline catalogue-btn-danger"
            disabled={busy || associatedServices.length > 0}
            title={associatedServices.length > 0 ? 'Chỉ xóa được danh mục không còn dịch vụ trực thuộc' : 'Xóa danh mục'}
            onClick={onDelete}
          >
            <Trash2 size={15} />
            {associatedServices.length > 0 ? `Không thể xóa (${associatedServices.length} dịch vụ)` : 'Xóa danh mục'}
          </button>

          <button
            type="button"
            className="btn btn-outline"
            disabled={busy}
            onClick={onToggleActive}
          >
            <Power size={15} />
            {category.active ? 'Tạm ẩn danh mục' : 'Bật hiển thị danh mục'}
          </button>

          <button
            type="button"
            className="btn btn-primary catalogue-detail-edit-main-btn"
            disabled={busy}
            onClick={onEdit}
          >
            <Pencil size={15} />
            Chỉnh sửa toàn bộ thông tin
          </button>
        </div>
      </div>
    </CataloguePopup>
  );
}

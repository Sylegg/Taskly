'use client';

import { useEffect, useState } from 'react';
import {
  Pencil,
  Trash2,
  Power,
  Star,
  Clock,
  Tag,
  Folder,
  FileText,
  Coins,
  ListChecks,
  Sparkles,
  Info,
  CheckCircle2,
  XCircle,
  HelpCircle,
  AlertCircle,
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
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

type PriceRule = {
  mode: string;
  baseAmount: number;
  unitAmount: number;
  platformFeeAmount: number;
  platformFeePercent?: number | null;
  enabled: boolean;
  quoteTtlMinutes?: number;
  quantityField?: string;
};

type BookingSchema = {
  serviceSlugs: string[];
  fields: { key: string; label: string; type: string; required?: boolean }[];
};

type BookingField = {
  key: string;
  label: string;
  type: string;
  required: boolean;
  options: string[];
};

interface ServiceDetailModalProps {
  service: Service;
  priceRule: PriceRule | null | undefined;
  bookingSchema?: BookingSchema;
  onClose: () => void;
  onEdit: () => void;
  onTogglePopular: () => Promise<void> | void;
  onToggleActive: () => Promise<void> | void;
  onDelete: () => void;
  busy?: boolean;
}

export default function ServiceDetailModal({
  service,
  priceRule,
  bookingSchema,
  onClose,
  onEdit,
  onTogglePopular,
  onToggleActive,
  onDelete,
  busy = false,
}: ServiceDetailModalProps) {
  const [customFields, setCustomFields] = useState<BookingField[]>([]);
  const [loadingFields, setLoadingFields] = useState(true);
  const [currentPrice, setCurrentPrice] = useState<PriceRule | null | undefined>(priceRule);
  const [loadingPrice, setLoadingPrice] = useState(priceRule === undefined);

  // Fetch custom booking fields
  useEffect(() => {
    const controller = new AbortController();
    setLoadingFields(true);
    fetch(`/api/admin/catalogue/services/${service.id}/booking-fields`, {
      cache: 'no-store',
      signal: controller.signal,
    })
      .then(async res => {
        if (!res.ok) throw new Error('Không tải được yêu cầu');
        const json = await res.json();
        if (Array.isArray(json.data)) {
          setCustomFields(json.data);
        }
      })
      .catch(() => {})
      .finally(() => {
        if (!controller.signal.aborted) setLoadingFields(false);
      });
    return () => controller.abort();
  }, [service.id]);

  // Fetch pricing if not loaded yet
  useEffect(() => {
    if (priceRule !== undefined) {
      setCurrentPrice(priceRule);
      setLoadingPrice(false);
      return;
    }
    const controller = new AbortController();
    setLoadingPrice(true);
    fetch(`/api/admin/catalogue/services/${service.id}/pricing`, {
      cache: 'no-store',
      signal: controller.signal,
    })
      .then(async res => {
        if (!res.ok) throw new Error('Không tải được giá');
        const json = await res.json();
        setCurrentPrice(json.data);
      })
      .catch(() => {
        setCurrentPrice(null);
      })
      .finally(() => {
        if (!controller.signal.aborted) setLoadingPrice(false);
      });
    return () => controller.abort();
  }, [service.id, priceRule]);

  // Filter inherited category quantity fields
  const schemaFields = bookingSchema?.fields || [];
  const inheritedFields = schemaFields.filter(
    sf => !customFields.some(cf => cf.key === sf.key)
  );

  const presetLabel =
    serviceIconPresets.find(p => p.key === service.iconKey)?.label ||
    'Tự động theo mã dịch vụ';

  return (
    <CataloguePopup
      title={service.name}
      wide={true}
      eyebrow="CHI TIẾT DỊCH VỤ"
      busy={busy}
      onClose={onClose}
    >
      <div className="catalogue-detail-container">
        {/* 1. HERO HEADER CARD */}
        <div className="catalogue-detail-hero">
          <div className="catalogue-detail-hero-left">
            <div className="catalogue-detail-icon-box">
              <ServiceIcon
                iconKey={service.iconKey}
                iconUrl={service.iconUrl}
                slug={service.slug}
                size={48}
              />
            </div>
            <div className="catalogue-detail-hero-info">
              <div className="catalogue-detail-hero-badges">
                <span
                  className={
                    'catalogue-status-pill ' +
                    (service.active ? 'active' : 'inactive')
                  }
                >
                  <span className="catalogue-status-dot" />
                  {service.active ? 'Đang hoạt động' : 'Tạm ẩn trên app'}
                </span>

                <button
                  type="button"
                  className={
                    'catalogue-popular-pill ' +
                    (service.popular ? 'active' : '')
                  }
                  disabled={busy}
                  onClick={onTogglePopular}
                  title="Nhấp để đổi trạng thái phổ biến"
                >
                  <Star
                    size={13}
                    fill={service.popular ? 'currentColor' : 'none'}
                  />
                  <span>
                    {service.popular ? 'Dịch vụ phổ biến' : 'Chưa bật phổ biến'}
                  </span>
                </button>

                <span className="catalogue-category-pill">
                  <Folder size={13} />
                  {service.category.name}
                </span>

                <span className="catalogue-slug-pill">
                  <Tag size={13} />
                  <code>{service.slug}</code>
                </span>
              </div>
              <h2 className="catalogue-detail-hero-title">{service.name}</h2>
              <p className="catalogue-detail-hero-subtitle">
                {service.iconUrl
                  ? 'Icon: Ảnh tải lên riêng'
                  : `Icon ứng dụng: ${presetLabel}`}
              </p>
            </div>
          </div>

          <div className="catalogue-detail-hero-quick-action">
            <button
              type="button"
              className="btn btn-primary catalogue-detail-edit-hero-btn"
              disabled={busy}
              onClick={onEdit}
            >
              <Pencil size={15} />
              Chỉnh sửa dịch vụ
            </button>
          </div>
        </div>

        {/* 2. THÔNG TIN CƠ BẢN */}
        <section className="catalogue-detail-card">
          <div className="catalogue-detail-card-header">
            <div className="catalogue-detail-card-title">
              <Info size={18} className="catalogue-detail-icon-accent" />
              <h3>Thông tin chung</h3>
            </div>
          </div>

          <div className="catalogue-detail-tiles">
            <div className="catalogue-detail-tile">
              <span className="catalogue-detail-tile-label">Mã đường dẫn (Slug)</span>
              <strong className="catalogue-detail-tile-value catalogue-code-text">
                {service.slug}
              </strong>
            </div>

            <div className="catalogue-detail-tile">
              <span className="catalogue-detail-tile-label">Nhóm dịch vụ</span>
              <strong className="catalogue-detail-tile-value">
                {service.category.name}
                {!service.category.active && (
                  <span className="catalogue-tile-sub-warn">
                    {' '}(Nhóm đang ẩn)
                  </span>
                )}
              </strong>
            </div>

            <div className="catalogue-detail-tile">
              <span className="catalogue-detail-tile-label">Thời gian dự kiến</span>
              <strong className="catalogue-detail-tile-value">
                <Clock size={14} style={{ display: 'inline', marginRight: 4, verticalAlign: -1 }} />
                {service.estimatedDurationMinutes
                  ? `${service.estimatedDurationMinutes} phút (${(
                      service.estimatedDurationMinutes / 60
                    )
                      .toFixed(1)
                      .replace('.0', '')} giờ)`
                  : 'Chưa thiết lập'}
              </strong>
            </div>

            <div className="catalogue-detail-tile">
              <span className="catalogue-detail-tile-label">Biểu tượng (Icon)</span>
              <strong className="catalogue-detail-tile-value">
                {service.iconUrl ? 'Ảnh riêng' : presetLabel}
              </strong>
            </div>
          </div>

          {service.shortDescription && (
            <div className="catalogue-detail-desc-box">
              <span className="catalogue-detail-desc-label">Mô tả ngắn:</span>
              <p className="catalogue-detail-desc-text">
                {service.shortDescription}
              </p>
            </div>
          )}

          <div className="catalogue-detail-desc-box full">
            <span className="catalogue-detail-desc-label">Mô tả chi tiết:</span>
            <p className="catalogue-detail-desc-text long">
              {service.description || 'Chưa có mô tả chi tiết cho dịch vụ này.'}
            </p>
          </div>
        </section>

        {/* 3. BIỂU MẪU ĐẶT DỊCH VỤ (BOOKING FORM - READ ONLY) */}
        <section className="catalogue-detail-card">
          <div className="catalogue-detail-card-header">
            <div className="catalogue-detail-card-title">
              <ListChecks size={18} className="catalogue-detail-icon-accent" />
              <h3>Biểu mẫu thông tin đặt dịch vụ</h3>
            </div>
            <span className="catalogue-detail-badge-count">
              {inheritedFields.length + customFields.length} trường
            </span>
          </div>
          <p className="catalogue-detail-card-intro">
            Các trường thông tin khách hàng cần cung cấp khi tiến hành đặt dịch vụ này trên ứng dụng.
          </p>

          {/* Trường kế thừa */}
          <div className="catalogue-detail-inherited-block">
            <div className="catalogue-detail-block-heading">
              <Sparkles size={14} color="#059669" />
              <strong>Trường kế thừa từ danh mục ({service.category.name})</strong>
            </div>
            {inheritedFields.length > 0 ? (
              <div className="catalogue-detail-pills-row">
                {inheritedFields.map(field => (
                  <div key={field.key} className="catalogue-field-chip inherited">
                    <span className="catalogue-field-chip-name">{field.label}</span>
                    <span className="catalogue-field-chip-type">
                      {field.type === 'number'
                        ? 'Số lượng'
                        : field.type === 'choice'
                        ? 'Lựa chọn'
                        : 'Văn bản'}
                    </span>
                    <span className="catalogue-field-chip-req">Bắt buộc</span>
                  </div>
                ))}
              </div>
            ) : (
              <p className="catalogue-detail-empty-text">
                Không có trường kế thừa từ danh mục.
              </p>
            )}
            <small className="catalogue-detail-block-help">
              Các trường này được thiết lập tại nhóm danh mục và tự động xuất hiện trên tất cả dịch vụ thuộc nhóm.
            </small>
          </div>

          {/* Yêu cầu riêng của dịch vụ */}
          <div className="catalogue-detail-custom-fields-block">
            <div className="catalogue-detail-block-heading">
              <FileText size={14} color="#0d9488" />
              <strong>Yêu cầu riêng của dịch vụ này</strong>
            </div>
            {loadingFields ? (
              <p className="catalogue-detail-empty-text">Đang tải biểu mẫu…</p>
            ) : customFields.length > 0 ? (
              <div className="catalogue-detail-custom-fields-list">
                {customFields.map((field, idx) => (
                  <div key={field.key || idx} className="catalogue-custom-field-item">
                    <span className="catalogue-field-idx">#{idx + 1}</span>
                    <div className="catalogue-field-item-content">
                      <strong className="catalogue-field-item-label">
                        {field.label}
                      </strong>
                      <span className="catalogue-field-item-meta">
                        Kiểu nhập:{' '}
                        <b>
                          {field.type === 'text'
                            ? 'Văn bản'
                            : field.type === 'number'
                            ? 'Số lượng'
                            : 'Lựa chọn'}
                        </b>
                        {' · '}
                        {field.required ? 'Bắt buộc' : 'Tùy chọn'}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="catalogue-detail-empty-box">
                <HelpCircle size={18} color="#94a3b8" />
                <span>Dịch vụ này chưa thiết lập yêu cầu riêng bổ sung.</span>
              </div>
            )}
          </div>
        </section>

        {/* 4. THIẾT LẬP BẢNG GIÁ & PHÍ NỀN TẢNG (PRICING - READ ONLY) */}
        <section className="catalogue-detail-card">
          <div className="catalogue-detail-card-header">
            <div className="catalogue-detail-card-title">
              <Coins size={18} className="catalogue-detail-icon-accent" />
              <h3>Bảng giá & Phí sàn</h3>
            </div>
            {currentPrice && (
              <span
                className={
                  'catalogue-status-pill ' +
                  (currentPrice.enabled ? 'active' : 'inactive')
                }
              >
                <span className="catalogue-status-dot" />
                {currentPrice.enabled ? 'Đã bật báo giá' : 'Chưa bật báo giá'}
              </span>
            )}
          </div>

          {loadingPrice ? (
            <p className="catalogue-detail-empty-text">Đang tải bảng giá…</p>
          ) : currentPrice ? (
            <div className="catalogue-detail-pricing-content">
              <div className="catalogue-detail-tiles">
                <div className="catalogue-detail-tile highlight">
                  <span className="catalogue-detail-tile-label">Phương thức tính giá</span>
                  <strong className="catalogue-detail-tile-value">
                    {currentPrice.mode === 'FIXED'
                      ? 'Giá cố định'
                      : currentPrice.mode === 'HOURLY'
                      ? 'Theo giờ'
                      : `Theo số lượng (${currentPrice.quantityField || 'mặc định'})`}
                  </strong>
                </div>

                <div className="catalogue-detail-tile highlight">
                  <span className="catalogue-detail-tile-label">
                    {currentPrice.mode === 'FIXED' ? 'Giá dịch vụ' : 'Giá cơ bản'}
                  </span>
                  <strong className="catalogue-detail-tile-value price-strong">
                    {Number(currentPrice.baseAmount).toLocaleString('vi-VN')} đ
                  </strong>
                </div>

                {currentPrice.mode !== 'FIXED' && (
                  <div className="catalogue-detail-tile highlight">
                    <span className="catalogue-detail-tile-label">
                      {currentPrice.mode === 'HOURLY'
                        ? 'Đơn giá mỗi giờ'
                        : 'Đơn giá mỗi đơn vị'}
                    </span>
                    <strong className="catalogue-detail-tile-value price-strong">
                      {Number(currentPrice.unitAmount).toLocaleString('vi-VN')} đ
                      {currentPrice.mode === 'HOURLY' ? '/giờ' : '/đơn vị'}
                    </strong>
                  </div>
                )}

                <div className="catalogue-detail-tile">
                  <span className="catalogue-detail-tile-label">Phí sàn</span>
                  <strong className="catalogue-detail-tile-value">
                    {currentPrice.platformFeePercent != null
                      ? `${currentPrice.platformFeePercent}%`
                      : `${Number(currentPrice.platformFeeAmount || 0).toLocaleString('vi-VN')} đ`}
                  </strong>
                </div>

                <div className="catalogue-detail-tile">
                  <span className="catalogue-detail-tile-label">Thời hạn báo giá</span>
                  <strong className="catalogue-detail-tile-value">
                    {currentPrice.quoteTtlMinutes || 15} phút
                  </strong>
                </div>
              </div>

              {/* Hộp công thức tính giá trực quan */}
              <div className="catalogue-detail-formula-box">
                <span className="catalogue-detail-formula-label">Công thức tính giá khách hàng:</span>
                <p className="catalogue-detail-formula-text">
                  {currentPrice.mode === 'FIXED'
                    ? `Customer thanh toán = ${Number(currentPrice.baseAmount).toLocaleString('vi-VN')} đ.`
                    : currentPrice.mode === 'HOURLY'
                    ? `Customer thanh toán = ${Number(currentPrice.baseAmount).toLocaleString('vi-VN')} đ (cơ bản) + ${Number(currentPrice.unitAmount).toLocaleString('vi-VN')} đ × Số giờ.`
                    : `Customer thanh toán = ${Number(currentPrice.baseAmount).toLocaleString('vi-VN')} đ (cơ bản) + ${Number(currentPrice.unitAmount).toLocaleString('vi-VN')} đ × ${currentPrice.quantityField || 'Số lượng'}.`}
                </p>
              </div>
            </div>
          ) : (
            <div className="catalogue-detail-warn-banner">
              <AlertCircle size={18} color="#d97706" />
              <div>
                <strong>Dịch vụ chưa thiết lập bảng giá</strong>
                <p>Khách hàng chưa thể nhận báo giá hoặc đặt dịch vụ này trên ứng dụng người dùng.</p>
              </div>
            </div>
          )}
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
            disabled={busy}
            onClick={onDelete}
          >
            <Trash2 size={15} />
            Xóa dịch vụ
          </button>

          <button
            type="button"
            className="btn btn-outline"
            disabled={busy}
            onClick={onToggleActive}
          >
            <Power size={15} />
            {service.active ? 'Tạm ẩn dịch vụ' : 'Bật hiển thị dịch vụ'}
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

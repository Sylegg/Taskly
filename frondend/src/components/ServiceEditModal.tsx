'use client';

import { useEffect, useRef, useState } from 'react';
import {
  FileText,
  Sparkles,
  ListChecks,
  Coins,
  Upload,
  Trash2,
  Plus,
  AlertCircle,
  HelpCircle,
  Folder,
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import ServiceIcon from './ServiceIcon';
import { serviceIconPresets, validateServiceIconFile } from '@/lib/service-icons.mjs';
import { pricingDraft, pricingPayload } from '@/lib/service-pricing.mjs';

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

interface ServiceEditModalProps {
  service: Service | null;
  categories: Category[];
  bookingSchemas: BookingSchema[] | null;
  initialPrice: PriceRule | null | undefined;
  onClose: () => void;
  onSaved: (savedService: Service) => void;
  busy?: boolean;
}

const slugify = (name: string) =>
  name
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');

export default function ServiceEditModal({
  service,
  categories,
  bookingSchemas,
  initialPrice,
  onClose,
  onSaved,
  busy = false,
}: ServiceEditModalProps) {
  const isEditing = Boolean(service);
  const [activeTab, setActiveTab] = useState<'basic' | 'icon' | 'fields' | 'pricing'>('basic');

  // Basic info draft
  const [draft, setDraft] = useState({
    name: service?.name || '',
    slug: service?.slug || '',
    categoryId: service?.category?.id || categories[0]?.id || '',
    shortDescription: service?.shortDescription || '',
    description: service?.description || '',
    estimatedDurationMinutes: service?.estimatedDurationMinutes ?? 60,
    popular: service?.popular ?? false,
    iconKey: service?.iconKey || '',
    iconUrl: service?.iconUrl || null,
    iconDataUrl: null as string | null,
    displayOrder: service?.displayOrder ?? 0,
  });

  // Icon upload state
  const [iconReading, setIconReading] = useState(false);
  const [iconError, setIconError] = useState('');
  const iconInputRef = useRef<HTMLInputElement | null>(null);

  // Custom booking fields
  const [customFields, setCustomFields] = useState<BookingField[]>([]);
  const [fieldsLoading, setFieldsLoading] = useState(isEditing);

  // Pricing setup
  const [pricingState, setPricingState] = useState(() => pricingDraft(initialPrice ?? null));
  const [pricingLoaded, setPricingLoaded] = useState(false);

  // Submission state
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  // Fetch existing custom booking fields and pricing if editing
  useEffect(() => {
    if (!service) return;
    const controller = new AbortController();

    // Fetch custom booking fields
    setFieldsLoading(true);
    fetch(`/api/admin/catalogue/services/${service.id}/booking-fields`, {
      cache: 'no-store',
      signal: controller.signal,
    })
      .then(async res => {
        if (!res.ok) return;
        const json = await res.json();
        if (Array.isArray(json.data)) setCustomFields(json.data);
      })
      .catch(() => {})
      .finally(() => {
        if (!controller.signal.aborted) setFieldsLoading(false);
      });

    // Fetch pricing if initialPrice was not passed
    if (initialPrice === undefined) {
      fetch(`/api/admin/catalogue/services/${service.id}/pricing`, {
        cache: 'no-store',
        signal: controller.signal,
      })
        .then(async res => {
          if (!res.ok) return;
          const json = await res.json();
          setPricingState(pricingDraft(json.data));
          setPricingLoaded(true);
        })
        .catch(() => {
          setPricingLoaded(true);
        });
    } else {
      setPricingLoaded(true);
    }

    return () => controller.abort();
  }, [service, initialPrice]);

  // Derived quantity fields from schema
  const currentCategory = categories.find(c => c.id === draft.categoryId);
  const schema = bookingSchemas?.find(s => s.serviceSlugs.includes(draft.slug));
  const schemaFields = schema?.fields || [];
  const inheritedFields = schemaFields.filter(
    sf => !customFields.some(cf => cf.key === sf.key)
  );

  const availableQuantityFields = [
    ...schemaFields.filter(f => f.type === 'number'),
    ...customFields
      .filter(f => f.type === 'number')
      .map(f => ({ key: f.key, label: f.label, type: 'number' })),
  ].filter(
    (field, idx, self) => self.findIndex(f => f.key === field.key) === idx
  );

  // Icon handlers
  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;
    setIconError('');
    const validationError = validateServiceIconFile(file);
    if (validationError) {
      setIconError(validationError);
      return;
    }
    const reader = new FileReader();
    setIconReading(true);
    reader.onload = () => {
      const result = reader.result;
      if (typeof result !== 'string' || !/^data:image\/(png|jpeg);base64,/.test(result)) {
        setIconError('Ảnh không hợp lệ. Vui lòng chọn PNG hoặc JPG.');
      } else {
        setDraft(prev => ({ ...prev, iconDataUrl: result, iconUrl: null }));
      }
      setIconReading(false);
    };
    reader.onerror = () => {
      setIconReading(false);
      setIconError('Không thể đọc file ảnh.');
    };
    reader.readAsDataURL(file);
  }

  function chooseIconPreset(key: string) {
    setIconError('');
    setDraft(prev => ({ ...prev, iconKey: key, iconUrl: null, iconDataUrl: '' }));
  }

  function removeCustomIcon() {
    setIconError('');
    setDraft(prev => ({ ...prev, iconUrl: null, iconDataUrl: '' }));
    if (iconInputRef.current) iconInputRef.current.value = '';
  }

  // Booking fields handlers
  function addCustomField() {
    if (customFields.length >= 10) return;
    const newKey = 'field_' + crypto.randomUUID().replaceAll('-', '').slice(0, 8);
    setCustomFields(prev => [
      ...prev,
      { key: newKey, label: '', type: 'text', required: true, options: [] },
    ]);
  }

  function updateCustomField(index: number, updates: Partial<BookingField>) {
    setCustomFields(prev =>
      prev.map((f, i) => (i === index ? { ...f, ...updates } : f))
    );
  }

  function removeCustomField(index: number) {
    setCustomFields(prev => prev.filter((_, i) => i !== index));
  }

  // Pricing handlers
  function updatePricing(key: keyof typeof pricingState, value: unknown) {
    setPricingState(prev => ({ ...prev, [key]: value }));
  }

  function changePricingMode(mode: string) {
    setPricingState(prev => ({
      ...prev,
      mode,
      quantityField:
        mode === 'FIELD'
          ? prev.quantityField || availableQuantityFields[0]?.key || ''
          : '',
    }));
  }

  // Save all changes
  async function handleSaveAll(e: React.FormEvent) {
    e.preventDefault();
    if (saving || iconReading) return;
    setError('');

    // Validation
    if (!draft.name.trim()) {
      setActiveTab('basic');
      setError('Vui lòng nhập tên dịch vụ.');
      return;
    }
    if (!draft.categoryId) {
      setActiveTab('basic');
      setError('Vui lòng chọn nhóm dịch vụ.');
      return;
    }
    if (!draft.shortDescription.trim()) {
      setActiveTab('basic');
      setError('Vui lòng nhập mô tả ngắn.');
      return;
    }

    // Validate custom fields
    for (const f of customFields) {
      if (!f.label.trim()) {
        setActiveTab('fields');
        setError('Tất cả các trường yêu cầu riêng cần có tên hiển thị.');
        return;
      }
    }

    // Validate pricing if FIELD mode
    if (isEditing && pricingState.mode === 'FIELD' && !pricingState.quantityField) {
      setActiveTab('pricing');
      setError('Vui lòng chọn trường số lượng khi tính giá theo số lượng.');
      return;
    }

    setSaving(true);
    try {
      // 1. Save base service info
      const serviceBody = {
        categoryId: draft.categoryId,
        slug: draft.slug || slugify(draft.name),
        name: draft.name.trim(),
        shortDescription: draft.shortDescription.trim(),
        description: draft.description,
        suggestedPriceMin: 0,
        suggestedPriceMax: 0,
        currency: 'VND',
        estimatedDurationMinutes: draft.estimatedDurationMinutes,
        displayOrder: draft.displayOrder,
        iconKey: draft.iconKey,
        iconDataUrl: draft.iconDataUrl,
      };

      const serviceRes = await fetch(
        '/api/admin/catalogue/services' + (isEditing ? '/' + service!.id : ''),
        {
          method: isEditing ? 'PATCH' : 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(serviceBody),
        }
      );
      const serviceJson = await serviceRes.json();
      if (!serviceRes.ok) {
        throw new Error(serviceJson.error || 'Không thể lưu thông tin dịch vụ.');
      }
      const savedService: Service = serviceJson.data;

      // 2. Save popular status if changed
      if (isEditing && draft.popular !== service!.popular) {
        await fetch(`/api/admin/catalogue/services/${savedService.id}/popular`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ popular: draft.popular }),
        });
        savedService.popular = draft.popular;
      }

      // 3. Save custom booking fields
      if (isEditing || savedService.id) {
        const fieldsRes = await fetch(
          `/api/admin/catalogue/services/${savedService.id}/booking-fields`,
          {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(customFields),
          }
        );
        const fieldsJson = await fieldsRes.json();
        if (!fieldsRes.ok) {
          throw new Error(fieldsJson.error || 'Không thể lưu các trường yêu cầu.');
        }

        // 4. Save pricing
        const pricingBody = pricingPayload(
          pricingState,
          availableQuantityFields
        );
        const priceRes = await fetch(
          `/api/admin/catalogue/services/${savedService.id}/pricing`,
          {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(pricingBody),
          }
        );
        const priceJson = await priceRes.json();
        if (!priceRes.ok) {
          throw new Error(priceJson.error || 'Không thể lưu bảng giá.');
        }
      }

      onSaved(savedService);
    } catch (cause) {
      setError((cause as Error).message);
    } finally {
      setSaving(false);
    }
  }

  const quantityLabel =
    availableQuantityFields.find(f => f.key === pricingState.quantityField)?.label ||
    'Số lượng';

  return (
    <CataloguePopup
      title={isEditing ? `Chỉnh sửa: ${service!.name}` : 'Tạo dịch vụ mới'}
      wide={true}
      eyebrow="QUẢN LÝ DỊCH VỤ"
      busy={saving || busy}
      onClose={onClose}
    >
      <form className="catalogue-edit-form" onSubmit={handleSaveAll}>
        {error && (
          <div role="alert" className="api-error catalogue-edit-error">
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        {/* TAB NAVIGATION BAR */}
        <nav className="catalogue-edit-tabs">
          <button
            type="button"
            className={
              'catalogue-edit-tab-btn ' + (activeTab === 'basic' ? 'active' : '')
            }
            onClick={() => setActiveTab('basic')}
          >
            <FileText size={16} />
            <span>1. Thông tin chung</span>
          </button>

          <button
            type="button"
            className={
              'catalogue-edit-tab-btn ' + (activeTab === 'icon' ? 'active' : '')
            }
            onClick={() => setActiveTab('icon')}
          >
            <Sparkles size={16} />
            <span>2. Biểu tượng (Icon)</span>
          </button>

          <button
            type="button"
            className={
              'catalogue-edit-tab-btn ' + (activeTab === 'fields' ? 'active' : '')
            }
            onClick={() => setActiveTab('fields')}
          >
            <ListChecks size={16} />
            <span>3. Form đặt dịch vụ</span>
            {customFields.length > 0 && (
              <span className="catalogue-tab-counter">{customFields.length}</span>
            )}
          </button>

          <button
            type="button"
            className={
              'catalogue-edit-tab-btn ' + (activeTab === 'pricing' ? 'active' : '')
            }
            onClick={() => setActiveTab('pricing')}
          >
            <Coins size={16} />
            <span>4. Thiết lập giá</span>
            {pricingState.enabled && (
              <span className="catalogue-tab-dot active" title="Báo giá đang bật" />
            )}
          </button>
        </nav>

        {/* TAB 1: THÔNG TIN CƠ BẢN */}
        {activeTab === 'basic' && (
          <div className="catalogue-tab-panel">
            <div className="catalogue-form-row two-cols">
              <label>
                Tên dịch vụ <span className="req">*</span>
                <input
                  required
                  maxLength={160}
                  placeholder="Ví dụ: Tổng vệ sinh nhà ở"
                  value={draft.name}
                  onChange={e =>
                    setDraft(prev => ({
                      ...prev,
                      name: e.target.value,
                      slug: isEditing ? prev.slug : slugify(e.target.value),
                    }))
                  }
                />
              </label>

              <label>
                Mã đường dẫn (Slug) <span className="req">*</span>
                <input
                  required
                  maxLength={160}
                  placeholder="deep-cleaning"
                  value={draft.slug}
                  onChange={e =>
                    setDraft(prev => ({ ...prev, slug: slugify(e.target.value) }))
                  }
                />
              </label>
            </div>

            <div className="catalogue-form-row two-cols">
              <label>
                Nhóm dịch vụ (Danh mục) <span className="req">*</span>
                <select
                  required
                  value={draft.categoryId}
                  onChange={e =>
                    setDraft(prev => ({ ...prev, categoryId: e.target.value }))
                  }
                >
                  <option value="">-- Chọn nhóm dịch vụ --</option>
                  {categories.map(c => (
                    <option key={c.id} value={c.id}>
                      {c.name} {c.active ? '' : '(đang tạm ẩn)'}
                    </option>
                  ))}
                </select>
              </label>

              <label>
                Thời gian dự kiến (phút)
                <input
                  type="number"
                  min={15}
                  max={1440}
                  placeholder="60"
                  value={draft.estimatedDurationMinutes ?? ''}
                  onChange={e =>
                    setDraft(prev => ({
                      ...prev,
                      estimatedDurationMinutes: e.target.value
                        ? Number(e.target.value)
                        : null,
                    }))
                  }
                />
              </label>
            </div>

            <div className="catalogue-checkbox-row">
              <label className="catalogue-toggle-label">
                <input
                  type="checkbox"
                  checked={draft.popular}
                  onChange={e =>
                    setDraft(prev => ({ ...prev, popular: e.target.checked }))
                  }
                />
                <span className="catalogue-toggle-title">
                  ★ Đánh dấu là Dịch vụ phổ biến (hiển thị ưu tiên ở trang chủ)
                </span>
              </label>
            </div>

            <label>
              Mô tả ngắn <span className="req">*</span>
              <input
                required
                maxLength={500}
                placeholder="Tóm tắt ngắn hiển thị trên danh sách thẻ và tìm kiếm"
                value={draft.shortDescription}
                onChange={e =>
                  setDraft(prev => ({ ...prev, shortDescription: e.target.value }))
                }
              />
              <small>Tối đa 500 ký tự. Hiển thị ở thẻ dịch vụ trên app khách hàng.</small>
            </label>

            <label>
              Mô tả chi tiết dịch vụ
              <textarea
                maxLength={4000}
                rows={5}
                placeholder="Mô tả các hạng mục công việc chi tiết, phạm vi thực hiện, quy trình..."
                value={draft.description}
                onChange={e =>
                  setDraft(prev => ({ ...prev, description: e.target.value }))
                }
              />
              <small>Tối đa 4000 ký tự.</small>
            </label>
          </div>
        )}

        {/* TAB 2: BIỂU TƯỢNG (ICON) */}
        {activeTab === 'icon' && (
          <div className="catalogue-tab-panel">
            <div className="catalogue-icon-tab-hero">
              <div className="catalogue-icon-tab-preview">
                <ServiceIcon
                  iconKey={draft.iconKey}
                  iconUrl={draft.iconDataUrl || draft.iconUrl}
                  slug={draft.slug}
                  size={64}
                />
              </div>
              <div className="catalogue-icon-tab-info">
                <strong>Xem trước biểu tượng hiển thị</strong>
                <p>
                  {draft.iconDataUrl || draft.iconUrl
                    ? 'Đang dùng: Ảnh riêng tải lên'
                    : draft.iconKey
                    ? `Đang dùng icon mẫu: ${
                        serviceIconPresets.find(p => p.key === draft.iconKey)?.label ||
                        draft.iconKey
                      }`
                    : 'Tự động chọn theo mã dịch vụ (slug)'}
                </p>
                {(draft.iconDataUrl || draft.iconUrl) && (
                  <button
                    type="button"
                    className="catalogue-remove-image-btn"
                    onClick={removeCustomIcon}
                  >
                    <Trash2 size={13} />
                    Gỡ ảnh riêng & dùng icon hệ thống
                  </button>
                )}
              </div>
            </div>

            {/* Upload file */}
            <div className="catalogue-icon-upload-card">
              <h4>Tải lên ảnh icon riêng</h4>
              <p>Hỗ trợ định dạng PNG hoặc JPG, kích thước tối đa 1 MB. Ảnh vuông hiển thị đẹp nhất.</p>
              <div className="catalogue-upload-actions">
                <label className="catalogue-upload-button-styled">
                  <Upload size={16} />
                  <span>{iconReading ? 'Đang đọc ảnh…' : 'Chọn ảnh từ thiết bị'}</span>
                  <input
                    ref={iconInputRef}
                    type="file"
                    accept="image/png,image/jpeg"
                    className="catalogue-file-input-hidden"
                    onChange={handleFileSelect}
                  />
                </label>
              </div>
              {iconError && <p className="catalogue-icon-error">{iconError}</p>}
            </div>

            {/* Chọn preset icon */}
            <div className="catalogue-icon-preset-section">
              <h4>Hoặc chọn biểu tượng có sẵn trong hệ thống</h4>
              <div className="catalogue-icon-preset-grid">
                {serviceIconPresets.map(preset => {
                  const isSelected =
                    draft.iconKey === preset.key &&
                    !draft.iconDataUrl &&
                    !draft.iconUrl;
                  return (
                    <button
                      key={preset.key}
                      type="button"
                      className={
                        'catalogue-preset-card ' + (isSelected ? 'selected' : '')
                      }
                      onClick={() => chooseIconPreset(preset.key)}
                    >
                      <ServiceIcon iconKey={preset.key} size={28} />
                      <span>{preset.label}</span>
                    </button>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: FORM ĐẶT DỊCH VỤ */}
        {activeTab === 'fields' && (
          <div className="catalogue-tab-panel">
            {/* Trường kế thừa */}
            <div className="catalogue-detail-inherited-block">
              <div className="catalogue-detail-block-heading">
                <Folder size={15} color="#059669" />
                <strong>
                  Trường kế thừa từ danh mục ({currentCategory?.name || 'Nhóm'})
                </strong>
              </div>
              {inheritedFields.length > 0 ? (
                <div className="catalogue-detail-pills-row">
                  {inheritedFields.map(f => (
                    <div key={f.key} className="catalogue-field-chip inherited">
                      <span>{f.label}</span>
                      <small>
                        {f.type === 'number'
                          ? 'Số lượng'
                          : f.type === 'choice'
                          ? 'Lựa chọn'
                          : 'Văn bản'}
                      </small>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="catalogue-detail-empty-text">
                  Danh mục này không có trường số lượng nào.
                </p>
              )}
              <small className="catalogue-detail-block-help">
                Chỉnh sửa các trường kế thừa trong phần Quản lý Danh mục.
              </small>
            </div>

            {/* Quản lý trường riêng */}
            <div className="catalogue-custom-fields-editor">
              <div className="catalogue-custom-fields-editor-header">
                <div>
                  <h4>Yêu cầu riêng của dịch vụ này</h4>
                  <p>
                    Thêm các câu hỏi hoặc thông tin chi tiết mà khách hàng cần cung cấp riêng cho dịch vụ này.
                  </p>
                </div>
                <button
                  type="button"
                  className="btn btn-outline"
                  disabled={customFields.length >= 10}
                  onClick={addCustomField}
                >
                  <Plus size={15} />
                  Thêm trường yêu cầu
                </button>
              </div>

              {fieldsLoading ? (
                <p>Đang tải danh sách yêu cầu…</p>
              ) : customFields.length === 0 ? (
                <div className="catalogue-empty-fields-box">
                  <HelpCircle size={22} color="#94a3b8" />
                  <p>Chưa có yêu cầu riêng nào.</p>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={addCustomField}
                  >
                    <Plus size={14} /> Thêm yêu cầu đầu tiên
                  </button>
                </div>
              ) : (
                <div className="catalogue-fields-edit-list">
                  {customFields.map((field, index) => (
                    <div key={field.key} className="catalogue-field-edit-card">
                      <div className="catalogue-field-edit-header">
                        <span className="catalogue-field-edit-badge">
                          Trường #{index + 1}
                        </span>
                        <button
                          type="button"
                          className="catalogue-delete-icon-btn"
                          title="Xóa trường này"
                          onClick={() => removeCustomField(index)}
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>

                      <div className="catalogue-form-row two-cols">
                        <label>
                          Tên yêu cầu / Nhãn <span className="req">*</span>
                          <input
                            required
                            maxLength={120}
                            placeholder="Ví dụ: Vệ sinh cửa kính"
                            value={field.label}
                            onChange={e =>
                              updateCustomField(index, { label: e.target.value })
                            }
                          />
                        </label>

                        <label>
                          Kiểu dữ liệu nhập
                          <select
                            value={field.type}
                            onChange={e =>
                              updateCustomField(index, {
                                type: e.target.value,
                                options: [],
                              })
                            }
                          >
                            <option value="text">Văn bản (Text)</option>
                            <option value="number">Số lượng (Number)</option>
                            <option value="choice">Lựa chọn (Choice)</option>
                          </select>
                        </label>
                      </div>

                      <div className="catalogue-checkbox-row inline">
                        <label className="catalogue-toggle-label">
                          <input
                            type="checkbox"
                            checked={field.required}
                            onChange={e =>
                              updateCustomField(index, {
                                required: e.target.checked,
                              })
                            }
                          />
                          <span>Bắt buộc khách hàng phải điền</span>
                        </label>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* TAB 4: THIẾT LẬP GIÁ */}
        {activeTab === 'pricing' && (
          <div className="catalogue-tab-panel">
            <div className="catalogue-pricing-tab-intro">
              <h4>Cấu hình giá & Phí dịch vụ</h4>
              <p>
                Bảng giá này được hệ thống sử dụng để tự động tính tiền khi khách hàng đặt dịch vụ trên ứng dụng.
              </p>
            </div>

            <div className="catalogue-form-row two-cols">
              <label>
                Phương thức tính giá
                <select
                  value={pricingState.mode}
                  onChange={e => changePricingMode(e.target.value)}
                >
                  <option value="FIXED">Giá cố định trọn gói</option>
                  <option value="HOURLY">Theo thời gian (giờ)</option>
                  <option value="FIELD">Theo số lượng (từ biểu mẫu)</option>
                </select>
              </label>

              {pricingState.mode === 'FIELD' && (
                <label>
                  Trường số lượng dùng tính giá <span className="req">*</span>
                  <select
                    required
                    value={pricingState.quantityField}
                    onChange={e => updatePricing('quantityField', e.target.value)}
                  >
                    <option value="">-- Chọn trường số lượng --</option>
                    {availableQuantityFields.map(f => (
                      <option key={f.key} value={f.key}>
                        {f.label}
                      </option>
                    ))}
                  </select>
                </label>
              )}
            </div>

            <div className="catalogue-form-row three-cols">
              <label>
                {pricingState.mode === 'FIXED' ? 'Giá dịch vụ (đ)' : 'Giá cơ bản (đ)'}
                <input
                  required
                  type="text"
                  inputMode="numeric"
                  placeholder="100000"
                  value={pricingState.baseAmount}
                  onChange={e => {
                    const clean = e.target.value.replace(/[.,\s₫đ]/g, '');
                    if (/^\d*$/.test(clean)) updatePricing('baseAmount', clean);
                  }}
                />
              </label>

              {pricingState.mode !== 'FIXED' && (
                <label>
                  {pricingState.mode === 'HOURLY'
                    ? 'Đơn giá mỗi giờ (đ)'
                    : 'Đơn giá mỗi đơn vị (đ)'}
                  <input
                    required
                    type="number"
                    min={0}
                    max={1000000000}
                    placeholder="50000"
                    value={pricingState.unitAmount}
                    onChange={e => updatePricing('unitAmount', e.target.value)}
                  />
                </label>
              )}

              <label>
                Phí sàn (%)
                <input
                  required
                  type="number"
                  min={0}
                  max={100}
                  step={0.01}
                  placeholder="10"
                  value={pricingState.platformFeePercent}
                  onChange={e =>
                    updatePricing('platformFeePercent', e.target.value)
                  }
                />
              </label>

              <label>
                Thời hạn báo giá (phút)
                <input
                  required
                  type="number"
                  min={1}
                  max={60}
                  placeholder="15"
                  value={pricingState.quoteTtlMinutes}
                  onChange={e =>
                    updatePricing('quoteTtlMinutes', e.target.value)
                  }
                />
              </label>
            </div>

            {/* Preview công thức */}
            <div className="catalogue-detail-formula-box">
              <span className="catalogue-detail-formula-label">
                Phí sàn trừ vào tiền Partner. Thực nhận = Tiền dịch vụ - Phí sàn.
              </span>
              <p className="catalogue-detail-formula-text">
                {pricingState.mode === 'FIXED'
                  ? `Customer thanh toán = Giá dịch vụ (${Number(pricingState.baseAmount || 0).toLocaleString('vi-VN')} đ).`
                  : `Customer thanh toán = Giá cơ bản (${Number(pricingState.baseAmount || 0).toLocaleString('vi-VN')} đ) + Đơn giá (${Number(pricingState.unitAmount || 0).toLocaleString('vi-VN')} đ) × ${pricingState.mode === 'HOURLY' ? 'Số giờ' : quantityLabel}.`}
              </p>
            </div>

            {/* Checkbox kích hoạt báo giá */}
            <div className="catalogue-checkbox-row">
              <label className="catalogue-toggle-label">
                <input
                  type="checkbox"
                  checked={pricingState.enabled}
                  onChange={e => updatePricing('enabled', e.target.checked)}
                />
                <span className="catalogue-toggle-title">
                  Bật báo giá cho dịch vụ (cho phép khách hàng đặt dịch vụ này trên app)
                </span>
              </label>
            </div>
          </div>
        )}

        {/* FOOTER ACTIONS */}
        <div className="catalogue-edit-footer">
          <button
            type="button"
            className="btn btn-outline"
            disabled={saving}
            onClick={onClose}
          >
            Hủy
          </button>

          <div className="catalogue-edit-footer-nav">
            {activeTab !== 'basic' && (
              <button
                type="button"
                className="btn btn-outline"
                disabled={saving}
                onClick={() => {
                  if (activeTab === 'pricing') setActiveTab('fields');
                  else if (activeTab === 'fields') setActiveTab('icon');
                  else if (activeTab === 'icon') setActiveTab('basic');
                }}
              >
                ← Bước trước
              </button>
            )}

            {activeTab !== 'pricing' && (
              <button
                type="button"
                className="btn btn-outline"
                disabled={saving}
                onClick={() => {
                  if (activeTab === 'basic') setActiveTab('icon');
                  else if (activeTab === 'icon') setActiveTab('fields');
                  else if (activeTab === 'fields') setActiveTab('pricing');
                }}
              >
                Bước tiếp →
              </button>
            )}

            <button
              type="submit"
              className="btn btn-primary catalogue-btn-save-all"
              disabled={saving || iconReading}
            >
              {saving ? 'Đang lưu thay đổi…' : 'Lưu toàn bộ thay đổi'}
            </button>
          </div>
        </div>
      </form>
    </CataloguePopup>
  );
}

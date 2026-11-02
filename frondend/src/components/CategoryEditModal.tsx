'use client';

import { useEffect, useRef, useState } from 'react';
import {
  FileText,
  Sparkles,
  ListChecks,
  Upload,
  Trash2,
  Plus,
  AlertCircle,
  HelpCircle,
  Layers,
  ArrowRight,
  ArrowLeft,
  Check,
  Eye,
} from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import CategoryIcon from './CategoryIcon';
import { serviceIconPresets, validateServiceIconFile } from '@/lib/service-icons.mjs';

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

type QuantityField = {
  key: string;
  label: string;
  minimum: number;
};

interface CategoryEditModalProps {
  category: Category | null;
  initialDisplayOrder?: number;
  onClose: () => void;
  onSaved: (savedCategory: Category) => void;
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

export default function CategoryEditModal({
  category,
  initialDisplayOrder = 0,
  onClose,
  onSaved,
  busy = false,
}: CategoryEditModalProps) {
  const isEditing = Boolean(category);
  const [activeTab, setActiveTab] = useState<'basic' | 'icon' | 'fields'>('basic');

  // Tab 1: Basic info draft
  const [draft, setDraft] = useState({
    name: category?.name || '',
    slug: category?.slug || '',
    description: category?.description || '',
    displayOrder: category?.displayOrder ?? initialDisplayOrder,
    iconKey: category?.iconKey || '',
    iconUrl: category?.iconUrl || null,
    iconDataUrl: null as string | null,
  });

  // Tab 2: Icon upload state
  const [iconReading, setIconReading] = useState(false);
  const [iconError, setIconError] = useState('');
  const iconInputRef = useRef<HTMLInputElement | null>(null);

  // Tab 3: Quantity fields
  const [quantityFields, setQuantityFields] = useState<QuantityField[]>([]);
  const [fieldsLoading, setFieldsLoading] = useState(isEditing);

  // Submission state
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');

  // Fetch existing quantity fields if editing, or set initial default fields if creating new
  useEffect(() => {
    if (!category) {
      setQuantityFields([
        { key: 'quantity', label: 'Diện tích / Khối lượng', minimum: 1 },
      ]);
      setFieldsLoading(false);
      return;
    }

    const controller = new AbortController();
    setFieldsLoading(true);

    fetch(`/api/admin/catalogue/service-categories/${category.id}/quantity-fields`, {
      cache: 'no-store',
      signal: controller.signal,
    })
      .then(async res => {
        if (!res.ok) return;
        const json = await res.json();
        if (Array.isArray(json.data) && json.data.length > 0) {
          setQuantityFields(json.data);
        } else {
          setQuantityFields([
            { key: 'quantity', label: 'Số lượng', minimum: 1 },
          ]);
        }
      })
      .catch(() => {})
      .finally(() => {
        if (!controller.signal.aborted) setFieldsLoading(false);
      });

    return () => controller.abort();
  }, [category]);

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
      setIconError('Không thể đọc file ảnh. Vui lòng thử lại.');
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

  // Quantity fields handlers
  function addQuantityField() {
    if (quantityFields.length >= 10) return;
    const newKey = 'quantity_' + crypto.randomUUID().replaceAll('-', '').slice(0, 8);
    setQuantityFields(prev => [
      ...prev,
      { key: newKey, label: '', minimum: 1 },
    ]);
  }

  function updateQuantityField(index: number, updates: Partial<QuantityField>) {
    setQuantityFields(prev =>
      prev.map((f, i) => (i === index ? { ...f, ...updates } : f))
    );
  }

  function removeQuantityField(index: number) {
    setQuantityFields(prev => prev.filter((_, i) => i !== index));
  }

  // Save all changes
  async function handleSaveAll(e: React.FormEvent) {
    e.preventDefault();
    if (saving || iconReading) return;
    setError('');

    // Basic Validation
    if (!draft.name.trim()) {
      setActiveTab('basic');
      setError('Vui lòng nhập tên danh mục.');
      return;
    }

    const cleanSlug = draft.slug.trim() || slugify(draft.name);
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(cleanSlug)) {
      setActiveTab('basic');
      setError('Mã slug chỉ được chứa chữ thường (a-z), số (0-9) và dấu gạch nối (-). Ví dụ: don-dep-nha');
      return;
    }

    // Quantity fields validation
    const keysSeen = new Set<string>();
    for (let i = 0; i < quantityFields.length; i++) {
      const qf = quantityFields[i];
      if (!qf.label.trim()) {
        setActiveTab('fields');
        setError(`Vui lòng nhập tên hiển thị cho trường số lượng #${i + 1}.`);
        return;
      }
      if (!qf.key.trim() || !/^[a-zA-Z][a-zA-Z0-9_]{0,79}$/.test(qf.key)) {
        setActiveTab('fields');
        setError(`Mã trường #${i + 1} ("${qf.key}") không hợp lệ. Phải bắt đầu bằng chữ cái tiếng Anh và chỉ chứa chữ cái, số, dấu gạch dưới.`);
        return;
      }
      if (['floor', 'budget'].includes(qf.key.toLowerCase())) {
        setActiveTab('fields');
        setError(`Mã trường "${qf.key}" là từ khóa dành riêng cho hệ thống, vui lòng chọn mã khác.`);
        return;
      }
      if (keysSeen.has(qf.key)) {
        setActiveTab('fields');
        setError(`Mã trường "${qf.key}" bị trùng lặp. Mỗi trường số lượng phải có mã riêng biệt.`);
        return;
      }
      keysSeen.add(qf.key);
    }

    setSaving(true);
    try {
      const payload = {
        name: draft.name.trim(),
        slug: cleanSlug,
        description: draft.description.trim(),
        displayOrder: Number(draft.displayOrder) || 0,
        iconKey: draft.iconKey || '',
        iconDataUrl: draft.iconDataUrl,
        quantityFields: quantityFields.map(f => ({
          key: f.key.trim(),
          label: f.label.trim(),
          minimum: Math.max(0, Number(f.minimum) || 0),
        })),
      };

      const path = isEditing ? `service-categories/${category!.id}` : 'service-categories';
      const method = isEditing ? 'PATCH' : 'POST';

      const res = await fetch(`/api/admin/catalogue/${path}`, {
        method,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });

      const json = await res.json();
      if (!res.ok) {
        throw new Error(json.error || 'Không thể lưu danh mục.');
      }

      // Also ensure quantity-fields PUT is invoked if editing to update the booking schemas cache
      if (isEditing && category) {
        await fetch(`/api/admin/catalogue/service-categories/${category.id}/quantity-fields`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            fields: payload.quantityFields,
          }),
        }).catch(() => {});
      }

      onSaved(json.data);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <CataloguePopup
      title={isEditing ? `Chỉnh sửa: ${category!.name}` : 'Tạo danh mục mới'}
      eyebrow="QUẢN LÝ DANH MỤC & BIỂU MẪU ĐẶT DỊCH VỤ"
      busy={saving || busy}
      wide={true}
      onClose={onClose}
    >
      <form onSubmit={handleSaveAll} className="catalogue-edit-form">
        {/* TABS NAVIGATION */}
        <div className="catalogue-tabs-nav" role="tablist">
          <button
            type="button"
            role="tab"
            aria-selected={activeTab === 'basic'}
            className={`catalogue-tab-btn ${activeTab === 'basic' ? 'active' : ''}`}
            onClick={() => setActiveTab('basic')}
          >
            <FileText size={16} />
            <span>1. Thông tin chung</span>
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={activeTab === 'icon'}
            className={`catalogue-tab-btn ${activeTab === 'icon' ? 'active' : ''}`}
            onClick={() => setActiveTab('icon')}
          >
            <Sparkles size={16} />
            <span>2. Biểu tượng (Icon)</span>
            {draft.iconDataUrl || draft.iconUrl ? (
              <span className="catalogue-tab-dot custom" title="Ảnh riêng" />
            ) : draft.iconKey ? (
              <span className="catalogue-tab-dot preset" title="Icon mẫu" />
            ) : null}
          </button>

          <button
            type="button"
            role="tab"
            aria-selected={activeTab === 'fields'}
            className={`catalogue-tab-btn ${activeTab === 'fields' ? 'active' : ''}`}
            onClick={() => setActiveTab('fields')}
          >
            <ListChecks size={16} />
            <span>3. Form & Trường số lượng</span>
            <span className="catalogue-tab-badge">{quantityFields.length}</span>
          </button>
        </div>

        {/* ERROR BANNER */}
        {error && (
          <div role="alert" className="catalogue-edit-error">
            <AlertCircle size={16} />
            <span>{error}</span>
          </div>
        )}

        {/* TAB 1: BASIC INFORMATION */}
        {activeTab === 'basic' && (
          <div className="catalogue-tab-content active">
            <div className="catalogue-form-row two-cols">
              <div className="catalogue-form-field">
                <label htmlFor="cat-name">
                  Tên danh mục <span className="required">*</span>
                </label>
                <input
                  id="cat-name"
                  type="text"
                  required
                  maxLength={160}
                  value={draft.name}
                  onChange={e => {
                    const newName = e.target.value;
                    setDraft(prev => ({
                      ...prev,
                      name: newName,
                      slug: isEditing ? prev.slug : slugify(newName),
                    }));
                  }}
                  placeholder="Ví dụ: Dọn dẹp nhà cửa, Sửa chữa điện nước…"
                />
                <small>Tên danh mục xuất hiện trên thanh điều hướng và màn hình chính ứng dụng.</small>
              </div>

              <div className="catalogue-form-field">
                <label htmlFor="cat-slug">
                  Mã đường dẫn (Slug) <span className="required">*</span>
                </label>
                <input
                  id="cat-slug"
                  type="text"
                  required
                  maxLength={80}
                  value={draft.slug}
                  onChange={e => setDraft(prev => ({ ...prev, slug: e.target.value }))}
                  placeholder="don-dep-nha"
                />
                <small>Dùng trong liên kết URL và nhận diện hệ thống (chữ thường, số, dấu gạch ngang).</small>
              </div>
            </div>

            <div className="catalogue-form-row two-cols">
              <div className="catalogue-form-field">
                <label htmlFor="cat-order">Thứ tự hiển thị (Display Order)</label>
                <input
                  id="cat-order"
                  type="number"
                  min={0}
                  max={100000}
                  value={draft.displayOrder}
                  onChange={e =>
                    setDraft(prev => ({ ...prev, displayOrder: parseInt(e.target.value, 10) || 0 }))
                  }
                />
                <small>Số nhỏ hơn sẽ được xếp trước trong danh sách trên ứng dụng.</small>
              </div>

              <div className="catalogue-form-field">
                <label>Trạng thái danh mục</label>
                <div className="catalogue-readonly-info-pill">
                  {category?.active ?? true ? (
                    <span className="catalogue-status-text active">✓ Hoạt động trên ứng dụng</span>
                  ) : (
                    <span className="catalogue-status-text inactive">✕ Đang tạm ẩn</span>
                  )}
                  <small style={{ marginTop: 2, display: 'block' }}>
                    Có thể bật/tắt hiển thị danh mục nhanh tại trang xem chi tiết sau khi lưu.
                  </small>
                </div>
              </div>
            </div>

            <div className="catalogue-form-field">
              <div className="catalogue-field-header-row">
                <label htmlFor="cat-desc">Mô tả danh mục</label>
                <span className="catalogue-char-count">{draft.description.length}/1000</span>
              </div>
              <textarea
                id="cat-desc"
                rows={4}
                maxLength={1000}
                value={draft.description}
                onChange={e => setDraft(prev => ({ ...prev, description: e.target.value }))}
                placeholder="Giới thiệu nhóm dịch vụ này để khách hàng hiểu rõ các gói dịch vụ tiện ích bên trong…"
              />
            </div>
          </div>
        )}

        {/* TAB 2: ICON SELECTION */}
        {activeTab === 'icon' && (
          <div className="catalogue-tab-content active">
            <div className="catalogue-icon-tab-content">
              {/* Live Preview Card */}
              <div className="catalogue-icon-preview-box">
                <div className="catalogue-icon-preview-large">
                  <CategoryIcon
                    iconKey={draft.iconKey}
                    iconUrl={draft.iconUrl}
                    previewUrl={draft.iconDataUrl}
                    slug={draft.slug}
                    size={64}
                  />
                </div>
                <div className="catalogue-icon-preview-info">
                  <h4>{draft.name || 'Tên danh mục'}</h4>
                  <p>
                    {draft.iconDataUrl || draft.iconUrl ? (
                      <span className="catalogue-icon-tag custom">Đang dùng ảnh riêng tải lên</span>
                    ) : draft.iconKey ? (
                      <span className="catalogue-icon-tag preset">
                        Icon mẫu: {serviceIconPresets.find(p => p.key === draft.iconKey)?.label || draft.iconKey}
                      </span>
                    ) : (
                      <span className="catalogue-icon-tag auto">Tự động chọn icon theo slug</span>
                    )}
                  </p>
                  <small>Icon này đại diện cho toàn bộ danh mục trên màn hình trang chủ khách hàng.</small>
                </div>
              </div>

              {/* Upload Section */}
              <div className="catalogue-icon-upload-section">
                <h4>Tải lên biểu tượng riêng</h4>
                <div className="catalogue-upload-actions">
                  <label className="catalogue-upload-button-styled">
                    <Upload size={16} />
                    <span>{iconReading ? 'Đang đọc ảnh…' : 'Chọn ảnh PNG / JPG (tối đa 1MB)'}</span>
                    <input
                      ref={iconInputRef}
                      type="file"
                      accept="image/png,image/jpeg"
                      className="catalogue-file-input-hidden"
                      disabled={iconReading}
                      onChange={handleFileSelect}
                    />
                  </label>

                  {(draft.iconDataUrl || draft.iconUrl) && (
                    <button
                      type="button"
                      className="btn btn-outline catalogue-btn-danger"
                      onClick={removeCustomIcon}
                    >
                      <Trash2 size={14} />
                      Gỡ ảnh riêng (dùng icon mẫu)
                    </button>
                  )}
                </div>

                {iconError && <div className="catalogue-icon-error-msg">{iconError}</div>}
              </div>

              {/* Preset Icons Grid */}
              <div className="catalogue-icon-preset-section">
                <h4>Hoặc chọn từ thư viện icon có sẵn ({serviceIconPresets.length} icons)</h4>
                <div className="catalogue-icon-preset-grid">
                  <button
                    type="button"
                    className={`catalogue-preset-card ${
                      !(draft.iconDataUrl || draft.iconUrl) && !draft.iconKey ? 'selected' : ''
                    }`}
                    onClick={() => chooseIconPreset('')}
                  >
                    <CategoryIcon slug={draft.slug} size={32} />
                    <span>Tự động</span>
                  </button>

                  {serviceIconPresets.map(preset => (
                    <button
                      type="button"
                      key={preset.key}
                      className={`catalogue-preset-card ${
                        !(draft.iconDataUrl || draft.iconUrl) && draft.iconKey === preset.key
                          ? 'selected'
                          : ''
                      }`}
                      onClick={() => chooseIconPreset(preset.key)}
                    >
                      <CategoryIcon iconKey={preset.key} slug={draft.slug} size={32} />
                      <span>{preset.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 3: QUANTITY FIELDS (Category & Booking Forms) */}
        {activeTab === 'fields' && (
          <div className="catalogue-tab-content active">
            <div className="catalogue-inherited-box">
              <Sparkles size={16} color="#059669" />
              <div>
                <strong>Cơ chế Form đặt dịch vụ & Trường số lượng (Category & Booking Forms)</strong>
                <p>
                  Các trường số lượng tại đây được dùng chung cho tất cả các dịch vụ trong danh mục. Khách hàng sẽ nhập số lượng (ví dụ: m², số phòng, số lượng thiết bị...) khi đặt lịch trên App TaskLy. Đây cũng là biến số lượng để tính giá dịch vụ theo công thức.
                </p>
              </div>
            </div>

            <div className="catalogue-custom-fields-editor">
              <div className="catalogue-custom-fields-editor-header">
                <div>
                  <h4>Danh sách trường số lượng của danh mục</h4>
                  <p>Tối đa 10 trường số lượng (mỗi trường bắt buộc có tên hiển thị và mã định danh).</p>
                </div>
                <button
                  type="button"
                  className="btn btn-outline"
                  disabled={quantityFields.length >= 10}
                  onClick={addQuantityField}
                >
                  <Plus size={15} />
                  Thêm trường số lượng
                </button>
              </div>

              {fieldsLoading ? (
                <div className="catalogue-detail-empty-box">
                  <HelpCircle size={16} />
                  <span>Đang tải danh sách trường số lượng…</span>
                </div>
              ) : quantityFields.length === 0 ? (
                <div className="catalogue-empty-fields-box">
                  <p>Chưa có trường số lượng nào được cấu hình cho danh mục này.</p>
                  <button
                    type="button"
                    className="btn btn-outline"
                    onClick={addQuantityField}
                  >
                    <Plus size={15} />
                    Thêm trường số lượng đầu tiên
                  </button>
                </div>
              ) : (
                <div className="catalogue-fields-edit-list">
                  {quantityFields.map((field, index) => (
                    <div key={index} className="catalogue-field-edit-card">
                      <div className="catalogue-field-edit-header">
                        <span className="catalogue-field-edit-badge">
                          Trường số lượng #{index + 1}
                        </span>
                        <button
                          type="button"
                          className="catalogue-delete-icon-btn"
                          title="Xóa trường này"
                          onClick={() => removeQuantityField(index)}
                        >
                          <Trash2 size={15} />
                        </button>
                      </div>

                      <div className="catalogue-form-row three-cols">
                        <div className="catalogue-form-field">
                          <label>
                            Tên hiển thị <span className="required">*</span>
                          </label>
                          <input
                            type="text"
                            required
                            maxLength={120}
                            placeholder="Ví dụ: Diện tích căn hộ (m²), Số máy lạnh…"
                            value={field.label}
                            onChange={e =>
                              updateQuantityField(index, { label: e.target.value })
                            }
                          />
                        </div>

                        <div className="catalogue-form-field">
                          <label>
                            Mã trường (Key) <span className="required">*</span>
                          </label>
                          <input
                            type="text"
                            required
                            maxLength={80}
                            placeholder="quantity_sqm"
                            value={field.key}
                            onChange={e =>
                              updateQuantityField(index, {
                                key: e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, ''),
                              })
                            }
                          />
                        </div>

                        <div className="catalogue-form-field">
                          <label>Giá trị tối thiểu</label>
                          <input
                            type="number"
                            min={0}
                            max={1000000}
                            value={field.minimum}
                            onChange={e =>
                              updateQuantityField(index, {
                                minimum: Math.max(0, parseInt(e.target.value, 10) || 0),
                              })
                            }
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* LIVE FORM SIMULATION */}
              {quantityFields.length > 0 && (
                <div className="catalogue-live-preview-box">
                  <div className="catalogue-live-preview-title">
                    <Eye size={15} />
                    <span>Mô phỏng giao diện chọn số lượng trên App TaskLy (Live Preview):</span>
                  </div>
                  <div className="catalogue-live-preview-content">
                    {quantityFields.map((field, index) => (
                      <div key={index} className="catalogue-live-stepper-item">
                        <span className="catalogue-live-stepper-label">
                          {field.label.trim() || `Trường số lượng #${index + 1}`}
                        </span>
                        <div className="catalogue-live-stepper-controls">
                          <button type="button" className="catalogue-stepper-btn" disabled>-</button>
                          <span className="catalogue-stepper-val">{field.minimum || 1}</span>
                          <button type="button" className="catalogue-stepper-btn" disabled>+</button>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              )}
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
            Hủy bỏ
          </button>

          <div className="catalogue-edit-footer-nav">
            {activeTab !== 'basic' && (
              <button
                type="button"
                className="btn btn-outline"
                disabled={saving}
                onClick={() => {
                  if (activeTab === 'fields') setActiveTab('icon');
                  else if (activeTab === 'icon') setActiveTab('basic');
                }}
              >
                <ArrowLeft size={15} />
                Quay lại
              </button>
            )}

            {activeTab !== 'fields' && (
              <button
                type="button"
                className="btn btn-outline"
                disabled={saving}
                onClick={() => {
                  if (activeTab === 'basic') setActiveTab('icon');
                  else if (activeTab === 'icon') setActiveTab('fields');
                }}
              >
                Tiếp theo
                <ArrowRight size={15} />
              </button>
            )}

            <button
              type="submit"
              className="btn btn-primary catalogue-btn-save-all"
              disabled={saving || iconReading || fieldsLoading}
            >
              <Check size={16} />
              {saving ? 'Đang lưu danh mục…' : 'Lưu toàn bộ thay đổi'}
            </button>
          </div>
        </div>
      </form>
    </CataloguePopup>
  );
}

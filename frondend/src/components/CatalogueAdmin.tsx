'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { Plus, RefreshCw, Pencil, Power, Trash2, Search, Upload, Download, ArrowRight, Star } from 'lucide-react';
import CataloguePopup from './CataloguePopup';
import ServiceIcon from './ServiceIcon';
import CategoryIcon from './CategoryIcon';
import ServiceDetailModal from './ServiceDetailModal';
import ServiceEditModal from './ServiceEditModal';
import CategoryDetailModal from './CategoryDetailModal';
import CategoryEditModal from './CategoryEditModal';
import { serviceIconPresets, validateServiceIconFile } from '@/lib/service-icons.mjs';
import './catalogue-admin.css';

type Category = { id: string; slug: string; name: string; description: string; active: boolean; displayOrder: number; iconKey: string | null; iconUrl: string | null };
type Service = Category & { popular: boolean; category: Category; shortDescription: string; suggestedPriceMin: number; suggestedPriceMax: number; estimatedDurationMinutes: number | null; currency: string; iconKey: string | null; iconUrl: string | null };
type Item = Category | Service;
type PriceRule = { mode: string; baseAmount: number; unitAmount: number; platformFeeAmount: number; platformFeePercent?: number | null; enabled: boolean };
type BookingSchema = { serviceSlugs: string[]; fields: { key: string; label: string; type: string }[] };

async function api(path: string, method = 'GET', body?: unknown) {
  const response = await fetch('/api/admin/catalogue/' + path, { method, cache: 'no-store', headers: { 'Content-Type': 'application/json' }, ...(body ? { body: JSON.stringify(body) } : {}) });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || 'Không thể lưu dữ liệu.');
  return result.data;
}
async function loadBookingSchemas(): Promise<BookingSchema[]> {
  const response = await fetch('/api/public/booking-schemas', { cache: 'no-store' });
  if (!response.ok) throw new Error('Không thể tải biểu mẫu.');
  const result = await response.json();
  if (!Array.isArray(result.data)) throw new Error('Thông tin biểu mẫu không hợp lệ.');
  return result.data.filter((schema: BookingSchema | null) => schema
    && Array.isArray(schema.serviceSlugs) && schema.serviceSlugs.every(slug => typeof slug === 'string')
    && Array.isArray(schema.fields) && schema.fields.every(field => field && typeof field.key === 'string' && typeof field.label === 'string'));
}
function csvCell(value: string) {
  const safe = /^[\s]*[=+\-@]/.test(value) ? "'" + value : value;
  return '"' + safe.replace(/"/g, '""') + '"';
}

export default function CatalogueAdmin({ mode }: { mode: 'categories' | 'services' }) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [services, setServices] = useState<Service[]>([]);
  const [prices, setPrices] = useState<Record<string, PriceRule | null | undefined>>({});
  async function refreshPrice(id: string) {
    try { const rule = await api(`services/${id}/pricing`); setPrices(previous => ({ ...previous, [id]: rule })); }
    catch { setPrices(previous => ({ ...previous, [id]: undefined })); }
  }
  const [bookingSchemas, setBookingSchemas] = useState<BookingSchema[] | null>(null);
  const [loading, setLoading] = useState(true), [saving, setSaving] = useState(false);
  const [error, setError] = useState(''), [message, setMessage] = useState(''), [search, setSearch] = useState('');
  const [editing, setEditing] = useState<Item | null | undefined>(undefined);
  const [deleting, setDeleting] = useState<Item | null>(null);
  const [details, setDetails] = useState<Item | null>(null);
  const [pricingSaving, setPricingSaving] = useState(false);
  const [visibility, setVisibility] = useState('all');
  const isService = mode === 'services', resource = isService ? 'services' : 'service-categories';
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const [[c, s], schemas] = await Promise.all([
        Promise.all([api('service-categories'), api('services')]),
        loadBookingSchemas().catch(() => null),
      ]);
      setCategories(c); setServices(s); setBookingSchemas(schemas);
      const rules = await Promise.all((s as Service[]).map(async service => {
        try { return [service.id, await api(`services/${service.id}/pricing`)] as const; }
        catch { return [service.id, undefined] as const; }
      }));
      setPrices(Object.fromEntries(rules));
    }
    catch (e) { setError((e as Error).message); } finally { setLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);
  useEffect(() => { setEditing(undefined); setDeleting(null); setDetails(null); setVisibility('all'); setSearch(''); setMessage(''); setError(''); }, [mode]);
  function closeEditing() { setEditing(undefined); }
  function open(item: Item | null) {
    setEditing(item); setDetails(null); setError(''); setMessage('');
  }
  async function mutate(work: () => Promise<unknown>, success: string) {
    if (saving) return;
    setSaving(true); setError(''); setMessage('');
    try { await work(); closeEditing(); setDeleting(null); setDetails(null); setMessage(success); await load(); }
    catch (e) { setError((e as Error).message); } finally { setSaving(false); }
  }
  async function togglePopular(service: Service) {
    if (saving || loading || pricingSaving) return;
    setSaving(true); setError('');
    try {
      const updated: Service = await api('services/' + service.id + '/popular', 'PATCH', { popular: !service.popular });
      setServices(previous => previous.map(item => item.id === service.id ? { ...item, popular: updated.popular } : item));
      setDetails(previous => previous?.id === service.id ? { ...previous, popular: updated.popular } : previous);
    } catch (e) { setError((e as Error).message); }
    finally { setSaving(false); }
  }
  const IconComponent = isService ? ServiceIcon : CategoryIcon;
  const items: Item[] = isService ? services : categories;
  const rows = items.filter(item => (item.name + ' ' + item.slug + ' ' + (isService ? (item as Service).category.name : '')).toLowerCase().includes(search.toLowerCase()) && (visibility === 'all' || item.active === (visibility === 'active')));
  function formSummary(slug: string, full = false) {
    if (bookingSchemas === null) return 'Chưa có thông tin';
    const schema = bookingSchemas.find(entry => entry.serviceSlugs.includes(slug));
    if (!schema?.fields.length) return 'Chưa thiết lập';
    const labels = schema.fields.map(entry => entry.label || entry.key);
    return full || labels.length <= 3 ? labels.join(', ') : labels.slice(0, 3).join(', ') + `, +${labels.length - 3} trường`;
  }
  function showDetails(item: Item) { setDetails(item); setError(''); }
  function exportCsv() {
    const headings = isService ? ['Dịch vụ', 'Nhóm', 'Form', 'Trạng thái'] : ['Mã', 'Nhóm dịch vụ', 'Mô tả', 'Hiện'];
    const values = rows.map(item => isService
      ? [item.name, (item as Service).category.name, formSummary(item.slug, true), item.active ? 'Hoạt động' : 'Tạm ẩn']
      : [item.slug, item.name, item.description || '', item.active ? 'Hoạt động' : 'Tạm ẩn']);
    const content = '\uFEFF' + [headings, ...values].map(row => row.map(csvCell).join(',')).join('\r\n');
    const url = URL.createObjectURL(new Blob([content], { type: 'text/csv;charset=utf-8;' }));
    const link = document.createElement('a');
    link.href = url; link.download = isService ? 'taskly-dich-vu.csv' : 'taskly-danh-muc.csv';
    document.body.appendChild(link); link.click(); link.remove();
    window.setTimeout(() => URL.revokeObjectURL(url), 0);
  }
  return <div className="catalogue-admin catalogue-page">
    <div className="catalogue-notice">Dữ liệu được lưu trong cơ sở dữ liệu TaskLy. Nhấp <strong>Xem chi tiết</strong> để xem, chỉnh sửa và quản lý hiển thị trên ứng dụng người dùng.</div>
    <div className="catalogue-page-actions">
      <button className="btn btn-primary" disabled={loading || saving || (isService && !categories.length)} onClick={() => open(null)}><Plus size={17}/> {isService ? 'Dịch vụ' : 'Danh mục'}</button>
      <button className="btn btn-outline" disabled={loading || saving} onClick={() => void load()}><RefreshCw size={16}/> Tải lại</button>
    </div>
    {message && <div role="status" className="notice">{message}</div>}
    {error && editing === undefined && !deleting && !details && <div role="alert" className="api-error">{error}</div>}
    <div className="catalogue-filters">
      <label className="catalogue-search"><Search size={18}/><input aria-label={isService ? 'Tìm kiếm dịch vụ' : 'Tìm kiếm danh mục'} value={search} onChange={e => setSearch(e.target.value)} placeholder={isService ? 'Tìm theo tên, mã hoặc nhóm…' : 'Tìm theo tên hoặc mã…'}/></label>
      <select aria-label="Lọc trạng thái hiển thị" value={visibility} onChange={e => setVisibility(e.target.value)}><option value="all">Tất cả trạng thái</option><option value="active">Hoạt động</option><option value="inactive">Tạm ẩn</option></select>
    </div>
    <div className="panel catalogue-list">
      <div className="catalogue-list-header"><span className="catalogue-record-count">{loading ? 'Đang tải dữ liệu…' : `${rows.length} bản ghi • Click vào một dòng để xem chi tiết`}</span><button className="btn btn-outline catalogue-export-button" disabled={loading || !rows.length} onClick={exportCsv}><Download size={16}/> Xuất CSV</button></div>
      {loading ? <div className="no-data">Đang tải {isService ? 'dịch vụ' : 'danh mục'}…</div> : <div className={'catalogue-table ' + (isService ? 'catalogue-service-table' : 'catalogue-category-table')}>
        <table aria-label={isService ? 'Danh sách dịch vụ' : 'Danh sách danh mục'}>
          <thead><tr>{isService ? <><th className="catalogue-service-column">Dịch vụ</th><th className="catalogue-group-column">Nhóm</th><th className="catalogue-form-column">Form</th><th className="catalogue-price-column">Giá dịch vụ</th><th className="catalogue-fee-column">Phí sàn</th><th className="catalogue-status-column">Trạng thái</th></> : <><th className="catalogue-code-column">Mã</th><th className="catalogue-group-column">Nhóm dịch vụ</th><th className="catalogue-description-column">Mô tả</th><th className="catalogue-status-column">Hiện</th></>}<th className="catalogue-actions-column">Thao tác</th></tr></thead>
          <tbody>{rows.map(item => <tr key={item.id} className="catalogue-row" onClick={() => showDetails(item)}>
            {isService ? <>
              <td><div className="catalogue-name"><span className={isService ? 'catalogue-item-icon' : 'catalogue-category-icon'}><IconComponent iconKey={(item as Service).iconKey} iconUrl={(item as Service).iconUrl} slug={item.slug} size={20}/></span><b>{item.name}<small aria-hidden={!(item as Service).popular}>{(item as Service).popular ? '★ Phổ biến' : '\u00a0'}</small></b></div></td>
              <td>{(item as Service).category.name}</td>
              <td className="catalogue-form-summary" title={formSummary(item.slug, true)}><span className="catalogue-form-text">{formSummary(item.slug)}</span></td>
              <td style={{ whiteSpace: 'nowrap' }}>{prices[item.id] ? <><strong>{Number(prices[item.id]!.mode === 'FIXED' ? prices[item.id]!.baseAmount : prices[item.id]!.unitAmount).toLocaleString('vi-VN')} đ{prices[item.id]!.mode === 'HOURLY' ? '/giờ' : prices[item.id]!.mode === 'FIELD' ? '/đơn vị' : ''}</strong>{prices[item.id]!.mode !== 'FIXED' && <small>Giá cơ bản: {prices[item.id]!.baseAmount.toLocaleString('vi-VN')} đ</small>}{!prices[item.id]!.enabled && <small>Chưa bật báo giá</small>}</> : prices[item.id] === null ? 'Chưa cấu hình' : 'Chưa tải được'}</td>
              <td style={{ whiteSpace: 'nowrap' }}>{prices[item.id] ? (prices[item.id]!.platformFeePercent != null ? `${prices[item.id]!.platformFeePercent}%` : `${prices[item.id]!.platformFeeAmount.toLocaleString('vi-VN')} đ`) : '—'}</td>
            </> : <><td><b className="catalogue-code">{item.slug}</b></td><td><div className="catalogue-name"><span className="catalogue-category-icon"><CategoryIcon iconKey={item.iconKey} iconUrl={item.iconUrl} slug={item.slug} size={22}/></span><b>{item.name}</b></div></td><td>{item.description || 'Chưa có mô tả'}</td></>}
            <td><span className={'catalogue-status ' + (item.active ? 'active' : 'inactive')}>{item.active ? 'Hoạt động' : 'Tạm ẩn'}</span>{isService && !(item as Service).category.active && <small>Nhóm đang tạm ẩn</small>}</td>
            <td><div className="catalogue-row-actions"><button className="catalogue-detail-button" disabled={saving} aria-label={'Xem chi tiết ' + item.name} onClick={event => { event.stopPropagation(); showDetails(item); }}>Xem chi tiết <ArrowRight size={16}/></button>
              {isService && <button type="button" className={'catalogue-popular-button' + ((item as Service).popular ? ' selected' : '')} aria-pressed={(item as Service).popular} aria-label={((item as Service).popular ? 'Tắt phổ biến: ' : 'Bật phổ biến: ') + item.name} disabled={saving || loading || pricingSaving} onClick={event => { event.stopPropagation(); void togglePopular(item as Service); }} title={(item as Service).popular ? 'Tắt phổ biến' : 'Bật phổ biến'}><Star size={15} fill={(item as Service).popular ? 'currentColor' : 'none'} aria-hidden="true"/></button>}
            </div></td>
          </tr>)}</tbody>
        </table>
        {!rows.length && <div className="no-data">{isService && !categories.length ? 'Hãy tạo danh mục trước khi thêm dịch vụ.' : 'Chưa có dữ liệu phù hợp.'}</div>}
      </div>}
      <div className="catalogue-list-footer"><span>Hiển thị {loading ? '…' : `${rows.length}/${items.length}`} dòng</span><span>TaskLy</span></div>
    </div>
    {editing !== undefined && isService && (
      <ServiceEditModal
        service={editing as Service | null}
        categories={categories}
        bookingSchemas={bookingSchemas}
        initialPrice={editing ? prices[editing.id] : null}
        busy={saving}
        onClose={closeEditing}
        onSaved={savedService => {
          closeEditing();
          setMessage(editing ? 'Đã lưu toàn bộ thông tin dịch vụ.' : 'Đã tạo dịch vụ mới.');
          void load();
        }}
      />
    )}
    {editing !== undefined && !isService && (
      <CategoryEditModal
        category={editing as Category | null}
        initialDisplayOrder={categories.length ? Math.max(...categories.map(c => c.displayOrder)) + 1 : 0}
        busy={saving}
        onClose={closeEditing}
        onSaved={savedCat => {
          closeEditing();
          setMessage(editing ? 'Đã lưu toàn bộ thông tin danh mục.' : 'Đã tạo danh mục mới.');
          void load();
        }}
      />
    )}
    {deleting && <CataloguePopup title={'Xóa ' + deleting.name + '?'} compact busy={saving} onClose={() => { setDeleting(null); setError(''); }}><div className="catalogue-dialog"><p>{isService ? 'Dịch vụ sẽ được gỡ khỏi ứng dụng người dùng.' : 'Chỉ xóa được danh mục không còn dịch vụ. Có thể tạm ẩn để ẩn cả nhóm.'}</p>{error && <div role="alert" className="api-error">{error}</div>}<div className="row catalogue-footer"><button className="btn btn-outline" disabled={saving} onClick={() => { setDeleting(null); setError(''); }}>Hủy</button><button className="btn btn-primary" disabled={saving} onClick={() => void mutate(() => api(resource + '/' + deleting.id, 'DELETE'), 'Đã xóa.')}>{saving ? 'Đang xóa…' : 'Xóa'}</button></div></div></CataloguePopup>}
    {details && isService && (
      <ServiceDetailModal
        service={details as Service}
        priceRule={prices[details.id]}
        bookingSchema={bookingSchemas?.find(schema => schema.serviceSlugs.includes(details.slug))}
        busy={saving}
        onClose={() => { setDetails(null); setError(''); }}
        onEdit={() => {
          const s = details as Service;
          open(s);
        }}
        onTogglePopular={() => void togglePopular(details as Service)}
        onToggleActive={() => void mutate(() => api(resource + '/' + details.id + '/' + (details.active ? 'deactivate' : 'activate'), 'POST'), 'Đã cập nhật hiển thị trên ứng dụng người dùng.')}
        onDelete={() => {
          setDeleting(details);
          setDetails(null);
          setError('');
        }}
      />
    )}
    {details && !isService && (
      <CategoryDetailModal
        category={details as Category}
        services={services}
        busy={saving}
        onClose={() => { setDetails(null); setError(''); }}
        onEdit={() => {
          const c = details as Category;
          open(c);
        }}
        onToggleActive={() => void mutate(() => api(resource + '/' + details.id + '/' + (details.active ? 'deactivate' : 'activate'), 'POST'), 'Đã cập nhật hiển thị trên ứng dụng người dùng.')}
        onDelete={() => {
          setDeleting(details);
          setDetails(null);
          setError('');
        }}
      />
    )}
  </div>;
}

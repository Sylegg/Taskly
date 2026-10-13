'use client';

import { useEffect, useState } from 'react';
import { RefreshCw } from 'lucide-react';
import { pricingDraft, pricingPayload } from '@/lib/service-pricing.mjs';
import './service-pricing-editor.css';

type QuantityField = { key: string; label: string };
type Props = { serviceId: string; serviceSlug: string; quantityFields: QuantityField[] | null; onBusyChange?: (busy: boolean) => void; onSaved?: () => void };

export default function ServicePricingEditor({ serviceId, serviceSlug, quantityFields, onBusyChange, onSaved }: Props) {
  const [draft, setDraft] = useState(() => pricingDraft(null));
  const [loading, setLoading] = useState(true), [loaded, setLoaded] = useState(false), [saving, setSaving] = useState(false);
  const [configured, setConfigured] = useState(false), [reload, setReload] = useState(0);
  const [error, setError] = useState(''), [message, setMessage] = useState('');
  const endpoint = '/api/admin/catalogue/services/' + serviceId + '/pricing';

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true); setLoaded(false); setError(''); setMessage('');
    void (async () => {
      try {
        const response = await fetch(endpoint, { cache: 'no-store', signal: controller.signal });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Không thể tải thiết lập giá.');
        const next = pricingDraft(result.data);
        if (controller.signal.aborted) return;
        setDraft(next); setConfigured(result.data !== null); setLoaded(true);
      } catch (cause) {
        if (!controller.signal.aborted) setError((cause as Error).message);
      } finally { if (!controller.signal.aborted) setLoading(false); }
    })();
    return () => controller.abort();
  }, [endpoint, reload, serviceSlug]);

  useEffect(() => { onBusyChange?.(saving); return () => onBusyChange?.(false); }, [saving, onBusyChange]);

  const field = (key: keyof typeof draft, value: string | boolean) => {
    setDraft(previous => ({ ...previous, [key]: value })); setMessage('');
  };
  function changeMode(mode: string) {
    setDraft(previous => ({ ...previous, mode, quantityField: mode === 'FIELD' ? previous.quantityField || quantityFields?.[0]?.key || '' : '' }));
    setMessage(''); setError('');
  }
  async function save(event: React.FormEvent) {
    event.preventDefault();
    if (!loaded || loading || saving) return;
    setError(''); setMessage('');
    let body;
    try { body = pricingPayload(draft, quantityFields); }
    catch (cause) { setError((cause as Error).message); return; }
    setSaving(true);
    try {
      const response = await fetch(endpoint, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Không thể lưu thiết lập giá.');
      setDraft(pricingDraft(body)); setConfigured(true);
      onSaved?.();
      setMessage('Đã lưu giá. Ứng dụng sẽ dùng cấu hình này khi lấy báo giá mới.');
    } catch (cause) { setError((cause as Error).message); }
    finally { setSaving(false); }
  }

  const quantityLabel = quantityFields?.find(field => field.key === draft.quantityField)?.label || 'Số lượng';
  return <section className="service-pricing" aria-label="Thiết lập giá dịch vụ">
    <div className="service-pricing-heading"><div><h3>Thiết lập giá</h3><p>Cấu hình giá dùng khi khách đặt dịch vụ trên ứng dụng.</p></div>
      <button type="button" className="btn btn-outline" disabled={loading || saving} onClick={() => setReload(value => value + 1)}><RefreshCw size={14}/> Tải giá</button></div>
    {loading && <p role="status">Đang tải thiết lập giá…</p>}
    {error && <div role="alert" className="api-error">{error}</div>}
    {message && <div role="status" className="notice">{message}</div>}
    {loaded && !loading && <form onSubmit={save}>
      {configured && draft.platformFeePercent === '' && <p role="alert" className="service-pricing-help">Bảng giá cũ đang dùng phí cố định. Nhập tỷ lệ % và lưu để chuyển sang phí phần trăm.</p>}
      {!configured && <p className="service-pricing-help">Dịch vụ chưa có giá. Nhập giá và bật báo giá để khách có thể đặt dịch vụ.</p>}
      <fieldset disabled={saving}>
        <label>Cách tính giá<select value={draft.mode} onChange={event => changeMode(event.target.value)}>
          <option value="FIXED">Giá cố định</option><option value="HOURLY">Theo giờ</option>
          <option value="FIELD">Theo số lượng</option>
        </select></label>
        {draft.mode === 'FIELD' && <label>Trường số lượng<select required value={draft.quantityField} onChange={event => field('quantityField', event.target.value)}>
          <option value="">Chọn trường số lượng</option>
          {draft.quantityField && !quantityFields?.some(item => item.key === draft.quantityField) && <option value={draft.quantityField} disabled>Trường hiện tại chưa khả dụng</option>}
          {quantityFields?.map(item => <option key={item.key} value={item.key}>{item.label}</option>)}
        </select></label>}
        {draft.mode === 'FIELD' && quantityFields !== null && quantityFields.length === 0 && <p role="alert" className="service-pricing-help">Biểu mẫu dịch vụ này chưa có trường số lượng để tính giá. Cần có trường như số món, số máy hoặc khối lượng trước khi lưu giá theo số lượng.</p>}
        {quantityFields === null && <p className="service-pricing-help">Chưa tải được biểu mẫu để chọn giá theo số lượng. Tải lại danh sách dịch vụ để thử lại.</p>}
        <div className="service-pricing-grid">
          <label>{draft.mode === 'FIXED' ? 'Giá cố định (đ)' : 'Giá cơ bản (đ)'}<input required type="text" inputMode="numeric" pattern="[0-9]+" placeholder="Nhập giá, ví dụ 150000" value={draft.baseAmount} onFocus={event => event.currentTarget.select()} onChange={event => { const value = event.target.value.replace(/[.,\s₫đ]/g, ''); if (/^\d*$/.test(value)) field('baseAmount', value); }}/></label>
          {draft.mode !== 'FIXED' && <label>{draft.mode === 'HOURLY' ? 'Đơn giá mỗi giờ (đ)' : 'Đơn giá mỗi đơn vị (đ)'}<input required type="number" min={0} max={1000000000} step={1} value={draft.unitAmount} onChange={event => field('unitAmount', event.target.value)}/></label>}
          <label>Phí sàn (%)<input required type="number" min={0} max={100} step={0.01} value={draft.platformFeePercent} onChange={event => field('platformFeePercent', event.target.value)}/></label>
          <label>Thời hạn báo giá (phút)<input required type="number" min={1} max={60} step={1} value={draft.quoteTtlMinutes} onChange={event => field('quoteTtlMinutes', event.target.value)}/></label>
        </div>
        <p className="service-pricing-help">Phí sàn trừ vào tiền Partner. Thực nhận = Tiền dịch vụ - Phí sàn.</p><p className="service-pricing-formula">{draft.mode === 'FIXED' ? 'Customer thanh toán = Giá dịch vụ.' : `Customer thanh toán = Giá cơ bản + Đơn giá × ${draft.mode === 'HOURLY' ? 'Số giờ' : quantityLabel}.`}</p>
        <p className="service-pricing-help">Phí phần trăm được tính trên tiền dịch vụ, làm tròn đến đồng. Thời hạn báo giá là thời gian giá còn hiệu lực kể từ lúc lấy báo giá; hết hạn khách cần cập nhật báo giá mới.</p>
        <label className="service-pricing-enabled"><input type="checkbox" checked={draft.enabled} onChange={event => field('enabled', event.target.checked)}/> Bật báo giá cho dịch vụ</label>
        <div className="service-pricing-actions"><button type="submit" className="btn btn-primary" disabled={saving}>{saving ? 'Đang lưu giá…' : 'Lưu giá'}</button></div>
      </fieldset>
    </form>}
  </section>;
}

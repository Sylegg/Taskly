'use client';

import { useState, type FormEvent } from 'react';

export type AdminAddress = {
  id: string;
  label: string;
  address_line: string;
  city: string;
  recipient_name?: string;
  recipient_phone?: string;
  ward?: string;
  district?: string;
  building_type?: string;
  building_description?: string;
  notes?: string;
  latitude?: number;
  longitude?: number;
  is_default: boolean;
};

const fields = [
  ['label', 'Tên địa chỉ', 100, true], ['recipient_name', 'Người nhận', 160],
  ['recipient_phone', 'Số điện thoại người nhận', 10], ['address_line', 'Số nhà và đường', 500, true],
  ['ward', 'Phường / xã', 160], ['district', 'Quận / huyện', 160], ['city', 'Tỉnh / thành phố', 160, true],
  ['building_type', 'Loại nhà', 100], ['building_description', 'Chỉ dẫn vị trí', 500], ['notes', 'Ghi chú', 500],
] as const;
const locationFields = ['address_line', 'ward', 'district', 'city'] as const;
const newAddress: AdminAddress = { id: '', label: '', address_line: '', city: '', is_default: false };

export default function AdminAddressBook({ userId, addresses, onSaved }: {
  userId: string; addresses: AdminAddress[]; onSaved: (addresses: AdminAddress[]) => void;
}) {
  const [editing, setEditing] = useState<AdminAddress | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  async function write(method: 'POST' | 'PATCH' | 'DELETE', id: string, body?: object) {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const path = '/api/admin/customers/' + encodeURIComponent(userId) + '/addresses' + (id ? '/' + encodeURIComponent(id) : '');
      const response = await fetch(path, {
        method,
        ...(body ? { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) } : {}),
      });
      const result = await response.json().catch(() => null);
      if (!response.ok || !Array.isArray(result?.data)) throw Error(result?.error || 'Không thể cập nhật sổ địa chỉ.');
      onSaved(result.data);
      setEditing(null);
      setNotice(method === 'DELETE' ? 'Đã xóa địa chỉ đã lưu.' : 'Đã lưu địa chỉ.');
    } catch (error) { setError((error as Error).message); }
    finally { setBusy(false); }
  }

  function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || !editing) return;
    const values = new FormData(event.currentTarget);
    const value = (key: string) => String(values.get(key) || '').trim();
    const unchangedLocation = editing.id && locationFields.every(key => value(key) === (editing[key] || '').trim());
    void write(editing.id ? 'PATCH' : 'POST', editing.id, {
      label: value('label'), recipientName: value('recipient_name'), recipientPhone: value('recipient_phone'),
      addressLine: value('address_line'), ward: value('ward'), district: value('district'), city: value('city'),
      buildingType: value('building_type'), buildingDescription: value('building_description'), notes: value('notes'),
      defaultAddress: values.has('is_default'),
      latitude: unchangedLocation ? editing.latitude : null, longitude: unchangedLocation ? editing.longitude : null,
    });
  }

  return <div>
    {error && <p role="alert">{error}</p>}
    {notice && <p role="status">{notice}</p>}
    {editing ? <form key={editing.id || 'new-address'} onSubmit={save}>
      <div className="form-grid">
        {fields.map(([key, title, length, required]) => <label key={key} className="field">
          <span>{title}</span>
          <input name={key} defaultValue={editing[key] || ''} maxLength={length} required={required}
            type={key === 'recipient_phone' ? 'tel' : 'text'}
            pattern={key === 'recipient_phone' ? '0[0-9]{9}' : undefined} />
        </label>)}
      </div>
      <p><label><input type="checkbox" name="is_default" defaultChecked={editing.is_default} disabled={editing.is_default} /> Địa chỉ mặc định</label></p>
      <div className="row">
        <button className="btn btn-primary" disabled={busy}>{busy ? 'Đang lưu…' : 'Lưu địa chỉ'}</button>
        <button className="btn btn-outline" type="button" disabled={busy} onClick={() => { setEditing(null); setError(''); }}>Hủy</button>
      </div>
    </form> : <>
      <button className="btn btn-outline" type="button" disabled={busy} onClick={() => { setEditing(newAddress); setError(''); setNotice(''); }}>Thêm địa chỉ</button>
      {addresses.length === 0 && <p>Chưa có địa chỉ đã lưu.</p>}
      <div className="customer-address-grid" style={{ marginTop: 12 }}>
        {addresses.map(address => <article key={address.id} className="customer-address-card">
          <div className="customer-address-card-header">
            <strong>{address.label}</strong>{address.is_default && <span className="badge green">Mặc định</span>}
          </div>
          <p>{[address.address_line, address.ward, address.district, address.city].filter(Boolean).join(', ')}</p>
          {(address.recipient_name || address.recipient_phone) && <p>{[address.recipient_name, address.recipient_phone].filter(Boolean).join(' · ')}</p>}
          {address.building_type && <p>{address.building_type}</p>}
          {address.building_description && <p>{address.building_description}</p>}
          {address.notes && <p>{address.notes}</p>}
          <div className="row">
            <button className="btn btn-outline" type="button" disabled={busy} onClick={() => { setEditing(address); setError(''); setNotice(''); }}>Sửa</button>
            <button className="btn btn-danger" type="button" disabled={busy} onClick={() => {
              if (window.confirm('Xóa địa chỉ này khỏi sổ địa chỉ đã lưu?')) void write('DELETE', address.id);
            }}>Xóa</button>
          </div>
        </article>)}
      </div>
    </>}
  </div>;
}

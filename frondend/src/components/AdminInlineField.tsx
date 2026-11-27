'use client';

import { useState, type FormEvent } from 'react';
import { Edit3 } from 'lucide-react';

export type ProfileField = 'name' | 'phone' | 'email' | 'profile_date' | 'date_of_birth';

export function displayProfileDate(date?: string | null) {
  return date && /^\d{4}-\d{2}-\d{2}$/.test(date) ? date.split('-').reverse().join('/') : '—';
}

export default function AdminInlineField({ field, label, value, onSave }: {
  field: ProfileField;
  label: string;
  value?: string | null;
  onSave: (field: ProfileField, value: string) => Promise<void>;
}) {
  const [draft, setDraft] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const date = field === 'profile_date' || field === 'date_of_birth';

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy || draft === null) return;
    setError('');
    setBusy(true);
    try {
      const next = field === 'email' ? draft.trim().toLowerCase() : draft.trim();
      await onSave(field, next);
      setDraft(null);
    } catch (error) { setError((error as Error).message); }
    finally { setBusy(false); }
  }

  if (draft === null) return <button type="button" className="admin-inline-value" aria-label={`Sửa ${label.toLowerCase()}`}
    onClick={() => setDraft(value || '')}>
    <span>{date ? displayProfileDate(value) : value || 'Chưa cập nhật'}</span><Edit3 size={13} aria-hidden="true" />
  </button>;

  return <form className="admin-inline-form" onSubmit={save}>
    <input aria-label={label} type={date ? 'date' : field === 'phone' ? 'tel' : field === 'email' ? 'email' : 'text'}
      value={draft} onChange={event => setDraft(event.target.value)} autoFocus required={!date}
      minLength={field === 'name' ? 2 : undefined} maxLength={field === 'name' ? 160 : field === 'email' ? 254 : undefined}
      pattern={field === 'phone' ? '0[0-9]{9}' : undefined} disabled={busy} />
    <div className="row">
      <button className="btn btn-primary" type="submit" disabled={busy}>{busy ? 'Đang lưu…' : 'Lưu'}</button>
      <button className="btn btn-outline" type="button" disabled={busy} onClick={() => { setError(''); setDraft(null); }}>Hủy</button>
    </div>
    {error && <small role="alert">{error}</small>}
  </form>;
}

'use client';

import { useState, type FormEvent } from 'react';
import { CheckCircle2 } from 'lucide-react';
import type { Evidence } from './RecruitmentDossier';

const api = '/api/admin/recruitment/kyc/';
const sides = [
  { side: 'FRONT', field: 'front', label: 'Mặt trước' },
  { side: 'BACK', field: 'back', label: 'Mặt sau' },
] as const;

export default function AdminKycActions({ partnerId, identity, documents, canReview, onChanged, photoLinks = false }: {
  partnerId: string;
  identity?: Evidence;
  documents: Evidence[];
  canReview: boolean;
  onChanged: () => Promise<void>;
  photoLinks?: boolean;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({});
  const verificationId = identity?.id;
  const version = identity?.version ?? -1;
  const isNationalId = identity?.document_type === 'NATIONAL_ID';
  const approved = isNationalId && identity?.status === 'APPROVED';
  const pending = isNationalId && ['SUBMITTED', 'UNDER_REVIEW'].includes(String(identity?.status));
  const identityDocs = verificationId ? documents.filter(doc => doc.verification_id === verificationId) : [];
  const photos = sides.map(({ side }) => identityDocs.find(doc => doc.document_side === side));
  const bothClean = isNationalId && photos.every(photo => photo?.scan_status === 'CLEAN');
  const legalName = isNationalId ? String(identity?.legal_name || '') : '';
  const documentNumber = isNationalId ? String(identity?.document_number || '') : '';
  const canApprove = canReview && pending && bothClean && legalName.trim().length >= 2 && /^[0-9]{12}$/.test(documentNumber);
  const newRecord = !identity || ['REJECTED', 'EXPIRED'].includes(String(identity.status));
  const canSubmit = canReview && (newRecord || identity?.status === 'DRAFT' || pending && !canApprove);
  const assistedPath = api + 'assisted/' + partnerId + '/';

  async function write(url: string, body?: FormData) {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      const response = await fetch(url, { method: 'POST', body });
      const result = await response.json().catch(() => null);
      if (!response.ok) throw Error(result?.error || 'Không thể lưu hồ sơ CCCD.');
      setPhotoUrls({});
      await onChanged();
    } catch (error) {
      setError((error as Error).message);
    } finally {
      setBusy(false);
    }
  }

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    if (verificationId) form.set('verificationId', String(verificationId));
    form.set('version', String(version));
    void write(assistedPath + 'submit', form);
  }

  async function getPhotoUrl(document: Evidence) {
    setError('');
    try {
      const response = await fetch(api + `${document.verification_id}/documents/${document.id}/url`, { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok) throw Error(result?.error || 'Không mở được ảnh CCCD.');
      const url = new URL(result.data.url);
      if (!['https:', 'http:'].includes(url.protocol)) throw Error('Liên kết ảnh không hợp lệ.');
      setPhotoUrls(previous => ({ ...previous, [String(document.id)]: url.toString() }));
    } catch (error) {
      setError((error as Error).message);
    }
  }

  return <div className="admin-kyc-actions">
    <div className="admin-kyc-row">
      <span>Giấy tờ CCCD</span>
      <strong>{bothClean ? 'Hai mặt đã qua kiểm tra an toàn' : 'Chưa đủ hai mặt đã kiểm tra'}</strong>
    </div>
    {canSubmit && <form key={`${verificationId}-${version}`} onSubmit={submit}>
      <div className="admin-kyc-sides">
        {sides.map(({ field, label }, index) => {
          const hasPhoto = !newRecord && isNationalId && photos[index]?.scan_status === 'CLEAN';
          return <label className="field" key={field}>
            {hasPhoto ? `${label} · Đã có ảnh` : `Thêm ảnh ${label.toLowerCase()}`}
            <input name={field} type="file" accept="image/jpeg,image/png" required={!hasPhoto} disabled={busy} />
          </label>;
        })}
      </div>
      <small>JPG hoặc PNG, tối đa 4 MB mỗi ảnh.</small>
      <div className="admin-kyc-sides">
        <label className="field">Họ tên trên CCCD
          <input name="legalName" defaultValue={newRecord ? '' : legalName} required minLength={2} maxLength={160} autoComplete="off" disabled={busy} />
        </label>
        <label className="field">Số CCCD
          <input name="documentNumber" defaultValue={newRecord ? '' : documentNumber} required pattern="[0-9]{12}" maxLength={12} inputMode="numeric" autoComplete="off" disabled={busy} />
        </label>
      </div>
      <label className="admin-kyc-consent">
        <input type="checkbox" name="ownerAuthorized" value="true" required disabled={busy} />
        <span>Đã đối chiếu CCCD gốc và được đối tác đồng ý lưu ảnh.</span>
      </label>
      <button className="btn btn-primary" type="submit" disabled={busy}>
        {busy ? 'Đang gửi CCCD…' : 'Xác nhận thêm CCCD'}
      </button>
    </form>}
    {canReview && photoLinks && identityDocs.some(photo => photo.scan_status === 'CLEAN') && (
      <div className="admin-kyc-photo-links">
        {[...sides, { side: 'SELFIE', label: 'Ảnh chân dung' }].map(({ side, label }) => {
          const photo = identityDocs.find(doc => doc.document_side === side && doc.scan_status === 'CLEAN');
          if (!photo) return null;
          const url = photoUrls[String(photo.id)];
          return url
            ? <a key={side} href={url} target="_blank" rel="noopener noreferrer" onClick={() => setPhotoUrls(previous => ({ ...previous, [String(photo.id)]: '' }))}>Mở {label.toLowerCase()}</a>
            : <button key={side} className="btn btn-outline" type="button" onClick={() => void getPhotoUrl(photo)}>Xem {label.toLowerCase()}</button>;
        })}
      </div>
    )}
    <div className="admin-kyc-row">
      <span>Phê duyệt CCCD</span>
      {canApprove ? (
        <button type="button" className="btn admin-kyc-approve" disabled={busy} onClick={() => {
          if (window.confirm('Bạn đã đối chiếu hai mặt CCCD với giấy tờ gốc của đối tác?')) {
            void write(assistedPath + `${verificationId}/approve?version=${version}`);
          }
        }}><CheckCircle2 size={15} aria-hidden="true" /> {busy ? 'Đang phê duyệt…' : 'Phê duyệt CCCD'}</button>
      ) : approved ? (
        <strong className="admin-kyc-approved"><CheckCircle2 size={15} aria-hidden="true" /> Đã phê duyệt</strong>
      ) : <strong>Chưa phê duyệt</strong>}
    </div>
    {error && <p className="admin-kyc-error" role="alert">{error}</p>}
  </div>;
}

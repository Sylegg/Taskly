'use client';

import { useState, type FormEvent } from 'react';
import type { Dossier, Evidence } from './RecruitmentDossier';

const sides = [['FRONT', 'Mặt trước'], ['BACK', 'Mặt sau'], ['SELFIE', 'Ảnh chân dung']] as const;
const reviewStages = new Set(['PRELIMINARY_REVIEW', 'ESCALATED', 'DOCUMENTS_RECEIVED', 'FINAL_REVIEW', 'ACTIVE']);
const officeCheckinStages = new Set(['PRELIMINARY_APPROVED', 'UNIFORM_PENDING', 'DOCUMENT_APPOINTMENT', 'ACTION_REQUIRED', 'DOCUMENTS_RECEIVED', 'FINAL_REVIEW', 'ACTIVE']);

export default function AdminKycActions({ dossier, onChanged, photoLinks = false }: {
  dossier: Dossier;
  onChanged?: () => Promise<void>;
  photoLinks?: boolean;
}) {
  const [sideToAdd, setSideToAdd] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [photoUrls, setPhotoUrls] = useState<Record<string, string>>({});
  const { application, identities, documents, appointments } = dossier;
  const identity = identities[0];
  const identityDocs = documents.filter(doc => doc.verification_id === identity?.id);
  const bothClean = ['FRONT', 'BACK'].every(side => identityDocs.some(doc => doc.document_side === side && doc.scan_status === 'CLEAN'));
  const office = appointments.some(visit => ['CHECKED_IN', 'COMPLETED'].includes(String(visit.status)) && visit.checked_in_at);
  const draft = identity?.status === 'DRAFT' && identity.document_type === 'NATIONAL_ID';
  const prepare = office && (!identity || ['REJECTED', 'EXPIRED'].includes(String(identity.status)) ||
    (identity.status === 'DRAFT' && !identity.document_type));
  const submit = office && draft && bothClean && /^\d{12}$/.test(String(identity.document_number || ''));
  const pending = identity?.document_type === 'NATIONAL_ID' && ['SUBMITTED', 'UNDER_REVIEW'].includes(String(identity.status));
  const reviewStage = application.reviewReady && reviewStages.has(application.status);
  const approve = pending && bothClean && reviewStage;
  const canCheckIn = photoLinks && !office && identity?.status !== 'APPROVED' && application.eligibility.preliminary_approved === true &&
    officeCheckinStages.has(application.status);
  const api = '/api/admin/recruitment/kyc/';

  async function write(url: string, body: Record<string, unknown> | FormData, form?: HTMLFormElement) {
    if (busy) return;
    setBusy(true);
    setError('');
    try {
      const multipart = body instanceof FormData;
      const response = await fetch(url, { method: 'POST', ...(
        multipart ? { body } : { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
      ) });
      const result = await response.json().catch(() => null);
      if (!response.ok) throw Error(result?.error || 'Không thể lưu hồ sơ CCCD.');
      form?.reset();
      setSideToAdd(null);
      await onChanged?.();
    } catch (error) { setError((error as Error).message); }
    finally { setBusy(false); }
  }

  function addPhoto(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = event.currentTarget;
    if (draft && sideToAdd) void write(api + `${identity.id}/documents/${sideToAdd}`, new FormData(form), form);
  }

  function officeWrite(event: FormEvent<HTMLFormElement>, action: 'draft' | 'submit') {
    event.preventDefault();
    const form = event.currentTarget;
    const values = new FormData(form);
    const route = api + `office/${application.id}/`;
    if (action === 'draft' && prepare) {
      void write(route + 'draft', {
        legalName: values.get('legalName'), documentNumber: values.get('documentNumber'), consentRecorded: values.has('consent'),
      }, form);
    } else if (action === 'submit' && submit) {
      void write(route + identity.id + (reviewStage ? '/approve' : '/submit'), { consent: values.has('consent') }, form);
    }
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
    } catch (error) { setError((error as Error).message); }
  }

  return <div className="admin-kyc-actions">
    {canCheckIn && <button type="button" className="btn btn-outline" disabled={busy} onClick={() => {
      if (window.confirm('Xác nhận đối tác đang có mặt tại văn phòng?')) {
        void write(`/api/admin/recruitment/applications/${application.id}/checkin`, {});
      }
    }}>Xác nhận check-in để thêm CCCD</button>}
    {prepare && <form onSubmit={event => officeWrite(event, 'draft')}>
      <strong>Tiếp nhận CCCD tại văn phòng</strong>
      <label className="field">Họ tên trên CCCD<input name="legalName" required minLength={2} maxLength={160} autoComplete="off" /></label>
      <label className="field">Số CCCD<input name="documentNumber" required pattern="[0-9]{12}" maxLength={12} inputMode="numeric" autoComplete="off" /></label>
      <label><input type="checkbox" name="consent" required /> Đối tác có mặt và đồng ý cho ghi nhận thông tin CCCD.</label>
      <button className="btn btn-outline" type="submit" disabled={busy}>Tạo hồ sơ để thêm ảnh CCCD</button>
    </form>}
    {(draft || photoLinks && identityDocs.length > 0) && <div className="admin-kyc-sides">
      {sides.map(([side, label]) => {
        const photo = identityDocs.find(doc => doc.document_side === side);
        if (!draft && !photo) return null;
        const url = photo ? photoUrls[String(photo.id)] : null;
        return <div className="admin-kyc-side" key={side}>
          <strong>{label}</strong>
          {photo ? <span>{photo.scan_status === 'CLEAN' ? 'Đã qua kiểm tra an toàn' : 'Ảnh chưa qua kiểm tra an toàn'}</span>
            : <button className="btn btn-outline" type="button" disabled={busy}
              onClick={() => { setSideToAdd(side); setError(''); }}>Thêm ảnh {label.toLowerCase()}</button>}
          {photoLinks && photo?.scan_status === 'CLEAN' && (url
            ? <a href={url} target="_blank" rel="noopener noreferrer" onClick={() => setPhotoUrls(previous => ({ ...previous, [String(photo.id)]: '' }))}>Mở ảnh {label.toLowerCase()}</a>
            : <button className="btn btn-outline" type="button" onClick={() => void getPhotoUrl(photo)}>Xem ảnh {label.toLowerCase()}</button>)}
        </div>;
      })}
    </div>}
    {draft && sideToAdd && <form key={sideToAdd} onSubmit={addPhoto}>
      <label className="field">{sides.find(([side]) => side === sideToAdd)?.[1]} · JPG hoặc PNG, tối đa 4 MB
        <input name="file" type="file" accept="image/jpeg,image/png" required />
      </label>
      <label><input type="checkbox" name="ownerAuthorized" value="true" required /> Chủ hồ sơ đã đồng ý cho bổ sung ảnh.</label>
      <div className="row">
        <button className="btn btn-primary" type="submit" disabled={busy}>{busy ? 'Đang tải…' : 'Tải ảnh lên'}</button>
        <button className="btn btn-outline" type="button" disabled={busy} onClick={() => setSideToAdd(null)}>Hủy</button>
      </div>
    </form>}
    {submit && <form onSubmit={event => officeWrite(event, 'submit')}>
      <label><input type="checkbox" name="consent" required /> Đã đối chiếu giấy tờ gốc và được đối tác đồng ý gửi hồ sơ.</label>
      <button className={`btn ${reviewStage ? 'btn-primary' : 'btn-outline'}`} type="submit" disabled={busy}>
        {reviewStage ? 'Duyệt KYC' : 'Gửi xét duyệt tại văn phòng'}
      </button>
    </form>}
    {draft && bothClean && !office && <p>Đối tác có thể gửi hồ sơ trên app Partner để Admin duyệt.</p>}
    {!identity && !office && <p>Check-in tại văn phòng hoặc tạo hồ sơ trên app Partner để bắt đầu thêm ảnh CCCD.</p>}
    {pending && bothClean && !reviewStage && <p>Hoàn tất bước tiếp nhận hồ sơ để duyệt KYC.</p>}
    {approve && <button type="button" className="btn btn-primary" disabled={busy} onClick={() => {
      if (window.confirm('Bạn đã đối chiếu hai mặt CCCD và thông tin của chủ hồ sơ?')) {
        void write(api + `${identity.id}/approve`, { reason: 'Đã kiểm tra và xác nhận CCCD hợp lệ.' });
      }
    }}>{busy ? 'Đang xử lý…' : 'Duyệt KYC'}</button>}
    {error && <p role="alert">{error}</p>}
  </div>;
}

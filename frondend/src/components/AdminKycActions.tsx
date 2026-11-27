'use client';

import { useEffect, useState, type FormEvent } from 'react';
import { CheckCircle2, X, ZoomIn } from 'lucide-react';
import type { Evidence } from './RecruitmentDossier';

const api = '/api/admin/recruitment/kyc/';
const sides = [
  { side: 'FRONT', field: 'front', label: 'Mặt trước' },
  { side: 'BACK', field: 'back', label: 'Mặt sau' },
] as const;

type PhotoPreview = { label: string; url: string };

function PhotoThumbnail({ label, url, onOpen, pending = false }: {
  label: string;
  url: string | null;
  onOpen: () => void;
  pending?: boolean;
}) {
  const [failedUrl, setFailedUrl] = useState('');
  return <button className="admin-kyc-thumbnail" type="button" disabled={pending}
    aria-label={`Xem ảnh ${label.toLowerCase()}`} onClick={onOpen}>
    {url && url !== failedUrl
      ? <img src={url} alt={`CCCD ${label.toLowerCase()}`} referrerPolicy="no-referrer" onError={() => setFailedUrl(url)} />
      : <span className="admin-kyc-photo-placeholder">{url === null ? 'Đang tải ảnh…' : 'Không thể hiển thị ảnh'}</span>}
    <span className="admin-kyc-photo-caption"><ZoomIn size={14} aria-hidden="true" /> {pending ? 'Đang mở…' : 'Phóng to'}</span>
  </button>;
}

function PhotoField({ field, label, hasPhoto, busy, onPreview }: {
  field: string;
  label: string;
  hasPhoto: boolean;
  busy: boolean;
  onPreview: (preview: PhotoPreview) => void;
}) {
  const [url, setUrl] = useState('');
  useEffect(() => () => { if (url) URL.revokeObjectURL(url); }, [url]);

  return <div className="admin-kyc-photo-field">
    <label className="field">
      {hasPhoto ? `${label} · Đã có ảnh` : `Thêm ảnh ${label.toLowerCase()}`}
      <input name={field} type="file" accept="image/jpeg,image/png" required={!hasPhoto} disabled={busy}
        onChange={event => {
          const file = event.currentTarget.files?.[0];
          setUrl(file ? URL.createObjectURL(file) : '');
        }} />
    </label>
    {url && <PhotoThumbnail label={label} url={url} onOpen={() => onPreview({ label, url })} />}
  </div>;
}

async function savedPhotoUrl(path: string, signal?: AbortSignal) {
  const response = await fetch(path, { cache: 'no-store', signal });
  const result = await response.json();
  if (!response.ok) throw Error(result?.error || 'Không mở được ảnh CCCD.');
  const url = new URL(result.data.url);
  if (!['https:', 'http:'].includes(url.protocol)) throw Error('Liên kết ảnh không hợp lệ.');
  return url.toString();
}

function SavedPhoto({ document, label, onPreview }: {
  document: Evidence;
  label: string;
  onPreview: (preview: PhotoPreview) => void;
}) {
  const [url, setUrl] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  const path = api + `${document.verification_id}/documents/${document.id}/url`;

  useEffect(() => {
    const request = new AbortController();
    void savedPhotoUrl(path, request.signal).then(setUrl).catch(() => {
      if (!request.signal.aborted) setUrl('');
    });
    return () => request.abort();
  }, [path]);

  async function open() {
    setPending(true);
    setError('');
    try {
      const freshUrl = await savedPhotoUrl(path);
      setUrl(freshUrl);
      onPreview({ label, url: freshUrl });
    } catch (error) {
      setError((error as Error).message);
    } finally {
      setPending(false);
    }
  }

  return <div className="admin-kyc-photo-field">
    <strong>{label}</strong>
    <PhotoThumbnail label={label} url={url} pending={pending} onOpen={() => void open()} />
    {error && <p className="admin-kyc-error" role="alert">{error}</p>}
  </div>;
}

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
  const [preview, setPreview] = useState<PhotoPreview | null>(null);
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
      setPreview(null);
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

  return <div className="admin-kyc-actions">
    <div className="admin-kyc-row">
      <span>Giấy tờ CCCD</span>
      <strong>{bothClean ? 'Hai mặt đã qua kiểm tra an toàn' : 'Chưa đủ hai mặt đã kiểm tra'}</strong>
    </div>
    {canSubmit && <form key={`${verificationId}-${version}`} onSubmit={submit}>
      <div className="admin-kyc-sides">
        {sides.map(({ field, label }, index) => (
          <PhotoField key={field} field={field} label={label} busy={busy} onPreview={setPreview}
            hasPhoto={!newRecord && isNationalId && photos[index]?.scan_status === 'CLEAN'} />
        ))}
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
      <div className="admin-kyc-sides">
        {[...sides, { side: 'SELFIE', label: 'Ảnh chân dung' }].map(({ side, label }) => {
          const photo = identityDocs.find(doc => doc.document_side === side && doc.scan_status === 'CLEAN');
          if (!photo) return null;
          return <SavedPhoto key={`${photo.id}-${photo.created_at}`} document={photo} label={label} onPreview={setPreview} />;
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
    {preview && <dialog className="admin-kyc-dialog" aria-label={`Ảnh CCCD · ${preview.label}`}
      ref={node => { if (node && !node.open) node.showModal(); }}
      onClose={() => setPreview(null)}
      onClick={event => { if (event.target === event.currentTarget) event.currentTarget.close(); }}
      onKeyDown={event => { if (event.key === 'Escape') event.stopPropagation(); }}>
      <div className="admin-kyc-dialog-header">
        <strong>{preview.label}</strong>
        <button className="icon-button" type="button" aria-label="Đóng ảnh" autoFocus
          onClick={event => event.currentTarget.closest('dialog')?.close()}><X size={18} aria-hidden="true" /></button>
      </div>
      <img src={preview.url} alt={`Ảnh CCCD · ${preview.label}`} referrerPolicy="no-referrer" />
    </dialog>}
  </div>;
}

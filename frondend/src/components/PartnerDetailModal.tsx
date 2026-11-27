'use client';

import React, { useEffect, useState, type FormEvent } from 'react';
import {
  X,
  User,
  Phone,
  Mail,
  Calendar,
  CreditCard,
  Building2,
  CheckCircle2,
  XCircle,
  AlertCircle,
  Clock,
  MapPin,
  Briefcase,
  Award,
  ShieldCheck,
  FileText,
  Shirt,
  Copy,
  Check,
  ExternalLink,
  Lock,
  Unlock,
  AlertTriangle,
  RefreshCw,
  Sparkles,
  Edit3,
} from 'lucide-react';
import { getPartnerCriteriaProgress, partnerCriteria } from '@/lib/partner-criteria';
import { partnerStatusLabels } from './PartnerChecks';
import PartnerKycBadge from './PartnerKycBadge';
import './partner-admin.css';
import PartnerProfileEditor from './PartnerProfileEditor';
import AdminAddressBook from './AdminAddressBook';
import AdminInlineField, { displayProfileDate, type ProfileField } from './AdminInlineField';
import AdminKycActions from './AdminKycActions';

type PartnerDetailModalProps = {
  partner: any;
  onClose: () => void;
  onUpdatePartner?: (id: string, body: any) => Promise<void>;
  onAction?: (item: any, action: string) => void;
  onEditPartner?: (partner: any) => void;
  saving?: boolean;
  initialEdit?: boolean;
  onSaved?: () => void;
};

export default function PartnerDetailModal({
  partner,
  onClose,
  onUpdatePartner,
  onAction,
  initialEdit = false,
  onSaved,
  saving,
}: PartnerDetailModalProps) {
  const [editing, setEditing] = useState(initialEdit);
  const [activeTab, setActiveTab] = useState<'overview' | 'criteria' | 'services' | 'identity' | 'timeline'>('overview');
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [copied, setCopied] = useState(false);
  const [uploadingAvatar, setUploadingAvatar] = useState(false);
  const [avatarError, setAvatarError] = useState('');
  const [newAvatar, setNewAvatar] = useState<string | null>(null);
  const [avatarFile, setAvatarFile] = useState<File | null>(null);

  useEffect(() => {
    let active = true;
    setLoading(true);
    setError('');

    fetch('/api/admin/customers/' + encodeURIComponent(partner.id), { cache: 'no-store' })
      .then(async (res) => {
        const j = await res.json();
        if (!res.ok) throw new Error(j.error || 'Không thể tải hồ sơ chi tiết đối tác');
        return j.data;
      })
      .then((d) => {
        if (active) {
          setData(d);
          setLoading(false);
        }
      })
      .catch((e) => {
        if (active) {
          setError(e.message);
          setLoading(false);
        }
      });

    return () => {
      active = false;
    };
  }, [partner.id]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const copyId = () => {
    navigator.clipboard.writeText(partner.id);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  // Resolve checks from partner or dossier
  const partnerChecks: Record<string, boolean> = partner.partner_checks || data?.dossier?.application?.eligibility || {};
  const { passed: passedCriteriaCount, total: totalCriteriaCount, percentage: criteriaPercent } =
    getPartnerCriteriaProgress(partnerChecks);

  const dossier = data?.dossier;
  const bankAccounts = data?.bank || [];
  const profile = data?.profile || partner;
  const latestIdentity = dossier?.identities?.[0];
  const kycStatus = latestIdentity?.status || partner.kyc;
  const kycApproved = kycStatus === 'APPROVED';
  const cleanIdentitySides = ['FRONT', 'BACK'].every(side => dossier?.documents?.some((doc: any) =>
    doc.verification_id === latestIdentity?.id && doc.document_side === side && doc.scan_status === 'CLEAN'));
  const avatar = newAvatar || profile.avatar || partner.avatar;

  async function reloadPartner() {
    const response = await fetch('/api/admin/customers/' + encodeURIComponent(partner.id), { cache: 'no-store' });
    const result = await response.json();
    if (!response.ok) throw Error(result.error || 'Không thể tải lại hồ sơ đối tác.');
    setData(result.data);
    onSaved?.();
  }

  async function saveProfileField(field: ProfileField, value: string) {
    if (!onUpdatePartner) throw Error('Không thể lưu thông tin.');
    await onUpdatePartner(partner.id, { profileField: { field, value } });
    if (field === 'date_of_birth') {
      setData((previous: any) => ({
        ...previous, dossier: { ...previous.dossier, application: { ...previous.dossier.application, dateOfBirth: value || null } },
      }));
    } else {
      setData((previous: any) => ({
        ...previous, profile: { ...previous.profile, [field === 'name' ? 'full_name' : field]: value || null },
      }));
    }
  }

  async function saveAvatar(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!avatarFile || uploadingAvatar) return;
    const form = event.currentTarget;
    const payload = new FormData(form);
    payload.set('file', avatarFile);
    setAvatarError('');
    setUploadingAvatar(true);
    try {
      const response = await fetch('/api/admin/customers/' + encodeURIComponent(partner.id) + '/partner-avatar', {
        method: 'POST', body: payload,
      });
      const result = await response.json().catch(() => null);
      if (!response.ok || typeof result?.data?.avatar !== 'string') {
        throw new Error(result?.error || 'Không thể lưu ảnh đại diện.');
      }
      setNewAvatar(result.data.avatar);
      form.reset();
      setAvatarFile(null);
      onSaved?.();
    } catch (error) { setAvatarError((error as Error).message); }
    finally { setUploadingAvatar(false); }
  }

  const isSuspended = partner.status === 'SUSPENDED';
  const recruitmentStatus = partner.recruitment_status || dossier?.application?.status || 'NOT_REGISTERED';
  const recruitmentLabel = partnerStatusLabels[recruitmentStatus] || recruitmentStatus;

  return (
    <div className="partner-modal-overlay" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="partner-modal-card" role="dialog" aria-modal="true">
        {/* Modal Header */}
        <div className="partner-modal-header">
          <div className="partner-modal-profile">
            <div className="partner-modal-avatar">
              {String(partner.name || 'P').slice(0, 1).toUpperCase()}
              {avatar && <img src={avatar} alt="Ảnh đại diện đối tác" onError={event => { event.currentTarget.hidden = true; }} />}
            </div>
            <div className="partner-modal-name-group">
              <div className="partner-modal-name-row">
                <h2>{profile.full_name || partner.name || 'Đối tác chưa cập nhật tên'}</h2>
                <span className={`partner-badge ${partner.status === 'ACTIVE' ? 'active' : 'suspended'}`}>
                  {partner.status === 'ACTIVE' ? '● Đang hoạt động' : 'Tạm ngưng'}
                </span>
                <span className="partner-badge info">
                  {recruitmentLabel}
                </span>
                {kycStatus && <PartnerKycBadge kyc={kycStatus} prefix="KYC " />}
              </div>
              <div className="partner-modal-id-row">
                <span><Phone size={13} /> {profile.phone || partner.phone || 'Chưa có SĐT'}</span>
                <span>•</span>
                <span><Mail size={13} /> {profile.email || partner.email || 'Chưa có email'}</span>
              </div>
            </div>
          </div>
          <button className="partner-modal-close-btn" onClick={onClose} aria-label="Đóng cửa sổ">
            <X size={20} />
          </button>
        </div>

        {/* Modal Tabs Bar */}
        {!editing && <div className="partner-modal-tabs">
          <button
            className={`partner-tab-btn ${activeTab === 'overview' ? 'active' : ''}`}
            onClick={() => setActiveTab('overview')}
          >
            <User size={15} /> Tổng quan & Ngân hàng
          </button>
          <button
            className={`partner-tab-btn ${activeTab === 'criteria' ? 'active' : ''}`}
            onClick={() => setActiveTab('criteria')}
          >
            <ShieldCheck size={15} /> Tiêu chuẩn đạt chuẩn ({passedCriteriaCount}/{totalCriteriaCount})
          </button>
          <button
            className={`partner-tab-btn ${activeTab === 'services' ? 'active' : ''}`}
            onClick={() => setActiveTab('services')}
          >
            <Briefcase size={15} /> Dịch vụ & Khu vực ({dossier?.services?.length || 0})
          </button>
          <button
            className={`partner-tab-btn ${activeTab === 'identity' ? 'active' : ''}`}
            onClick={() => setActiveTab('identity')}
          >
            <FileText size={15} /> Giấy tờ & Tuyển dụng
          </button>

        </div>}

        {/* Modal Body */}
        <div className="partner-modal-body">
          {editing ? <PartnerProfileEditor id={partner.id} onCancel={() => setEditing(false)} onSaved={(latest) => { setData(latest); setEditing(false); onSaved?.(); }} /> : <>
          {error && (
            <div style={{ padding: '12px 16px', background: '#fef2f2', border: '1px solid #fecaca', borderRadius: 12, color: '#dc2626', fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 }}>
              <AlertCircle size={17} />
              <span>{error}</span>
            </div>
          )}

          {/* TAB 1: OVERVIEW & BANK */}
          {activeTab === 'overview' && (
            <div className="partner-section-grid">
              {/* Account profile card */}
              <div className="partner-card-box">
                <div className="partner-card-header">
                  <h4 className="partner-card-title"><User size={16} color="#2563eb" /> Hồ sơ tài khoản</h4>
                  <span className="partner-badge neutral">TaskLy Account</span>
                </div>
                <div className="partner-spec-list">
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Họ và tên:</span>
                    {data && onUpdatePartner ? <AdminInlineField field="name" label="Họ và tên" value={profile.full_name} onSave={saveProfileField} />
                      : <strong className="partner-spec-value">{profile.full_name || partner.name || 'Chưa cập nhật'}</strong>}
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Số điện thoại:</span>
                    {data && onUpdatePartner ? <AdminInlineField field="phone" label="Số điện thoại" value={profile.phone} onSave={saveProfileField} />
                      : <strong className="partner-spec-value">{profile.phone || partner.phone || 'Chưa cập nhật'}</strong>}
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Email tài khoản:</span>
                    {data && onUpdatePartner ? <AdminInlineField field="email" label="Email" value={profile.email} onSave={saveProfileField} />
                      : <span className="partner-spec-value">{profile.email || partner.email || 'Chưa cập nhật'}</span>}
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Ngày sinh:</span>
                    {dossier && onUpdatePartner ? <AdminInlineField field="date_of_birth" label="Ngày sinh"
                      value={dossier.application.dateOfBirth} onSave={saveProfileField} />
                      : <span className="partner-spec-value">{displayProfileDate(dossier?.application?.dateOfBirth)}</span>}
                  </div>

                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Kinh nghiệm nghề:</span>
                    <span className="partner-spec-value">{dossier?.application?.experience || 'Đã có kinh nghiệm'}</span>
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Ngày tạo tài khoản:</span>
                    <span className="partner-spec-value">{profile?.created_at ? new Date(profile.created_at).toLocaleDateString('vi-VN') : (partner.created || 'Gần đây')}</span>
                  </div>
                  {data && onUpdatePartner && <div className="partner-spec-item">
                    <span className="partner-spec-label">Ngày hồ sơ</span>
                    <AdminInlineField field="profile_date" label="Ngày hồ sơ" value={profile.profile_date} onSave={saveProfileField} />
                  </div>}
                  <form className="partner-avatar-form" onSubmit={saveAvatar}>
                    <strong>Ảnh đại diện</strong>
                    <div className="row" style={{ flexWrap: 'wrap' }}>
                      <label className="btn btn-outline">Chọn ảnh
                        <input className="partner-avatar-file" type="file" accept="image/jpeg,image/png"
                          onChange={event => setAvatarFile(event.target.files?.[0] ?? null)} />
                      </label>
                      <label className="btn btn-outline">Chụp ảnh
                        <input className="partner-avatar-file" type="file" accept="image/*" capture="user"
                          onChange={event => setAvatarFile(event.target.files?.[0] ?? null)} />
                      </label>
                    </div>
                    <small>{avatarFile?.name || 'JPG hoặc PNG, tối đa 4 MB.'}</small>
                    <label><input type="checkbox" name="ownerAuthorized" value="true" required /> Đối tác đồng ý dùng ảnh làm ảnh đại diện.</label>
                    <button className="btn btn-primary" type="submit" disabled={!avatarFile || uploadingAvatar}>
                      {uploadingAvatar ? 'Đang lưu…' : 'Lưu ảnh đại diện'}
                    </button>
                    {avatarError && <span role="alert">{avatarError}</span>}
                  </form>
                </div>
              </div>

              {data && <div className="partner-card-box">
                <div className="partner-card-header">
                  <h4 className="partner-card-title"><MapPin size={16} /> Sổ địa chỉ</h4>
                </div>
                <AdminAddressBook userId={partner.id} addresses={data.addresses || []}
                  onSaved={addresses => setData((previous: any) => ({ ...previous, addresses }))} />
              </div>}

              {/* Bank Account Card */}
              <div className="partner-card-box">
                <div className="partner-card-header">
                  <h4 className="partner-card-title"><CreditCard size={16} color="#059669" /> Tài khoản nhận thu nhập Partner</h4>
                  {bankAccounts.length > 0 && <span className="partner-badge active">Đã liên kết</span>}
                </div>
                {bankAccounts.length === 0 ? (
                  <div style={{ textAlign: 'center', padding: '24px 12px', color: '#94a3b8' }}>
                    <CreditCard size={32} style={{ margin: '0 auto 8px', opacity: 0.5 }} />
                    <p style={{ margin: 0, fontSize: 13 }}>Đối tác chưa liên kết tài khoản ngân hàng.</p>
                  </div>
                ) : (
                  bankAccounts.map((b: any, i: number) => (
                    <div key={i} style={{ background: '#f8fafc', padding: 14, borderRadius: 12, border: '1px solid #e2e8f0', display: 'flex', flexDirection: 'column', gap: 8 }}>
                      <div className="partner-spec-item">
                        <span className="partner-spec-label">Ngân hàng:</span>
                        <strong className="partner-spec-value" style={{ color: '#059669' }}>{b.bank_name || 'Ngân hàng TMCP'}</strong>
                      </div>
                      <div className="partner-spec-item">
                        <span className="partner-spec-label">Tên chủ tài khoản:</span>
                        <strong className="partner-spec-value">{b.account_name || 'CHỦ TÀI KHOẢN'}</strong>
                      </div>
                      <div className="partner-spec-item">
                        <span className="partner-spec-label">Số tài khoản:</span>
                        <strong className="partner-spec-value" style={{ fontFamily: 'monospace', letterSpacing: '0.05em' }}>{b.account_number || '•••• ••••'}</strong>
                      </div>
                      {b.updated_at && (
                        <div className="partner-spec-item">
                          <span className="partner-spec-label">Cập nhật lúc:</span>
                          <span className="partner-spec-value" style={{ fontSize: 11.5, color: '#64748b' }}>{new Date(b.updated_at).toLocaleString('vi-VN')}</span>
                        </div>
                      )}
                    </div>
                  ))
                )}

                {/* Job statistics */}
                <div style={{ borderTop: '1px solid #f1f5f9', paddingTop: 14, marginTop: 4 }}>
                  <h5 style={{ margin: '0 0 10px 0', fontSize: 13, fontWeight: 750, color: '#334155' }}>Hiệu suất công việc</h5>
                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                    <div style={{ background: '#eff6ff', padding: '10px 14px', borderRadius: 10, textAlign: 'center' }}>
                      <span style={{ fontSize: 11.5, color: '#1d4ed8', fontWeight: 600 }}>Việc đã nhận</span>
                      <strong style={{ display: 'block', fontSize: 18, color: '#1e40af', marginTop: 2 }}>{loading ? '…' : data?.performance?.accepted_jobs ?? '—'}</strong>
                    </div>
                    <div style={{ background: '#ecfdf5', padding: '10px 14px', borderRadius: 10, textAlign: 'center' }}>
                      <span style={{ fontSize: 11.5, color: '#047857', fontWeight: 600 }}>Việc hoàn tất</span>
                      <strong style={{ display: 'block', fontSize: 18, color: '#065f46', marginTop: 2 }}>{loading ? '…' : data?.performance?.completed_jobs ?? '—'}</strong>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* TAB 2: CRITERIA STANDARDS */}
          {activeTab === 'criteria' && (
            <div className="partner-criteria-panel">
              <div className="partner-criteria-header-row">
                <div className="partner-criteria-title">
                  <h3>Tiến trình đạt chuẩn TaskLy Partner</h3>
                  <p>Tiến độ theo {totalCriteriaCount} tiêu chí tuyển dụng và thiết lập hoạt động. Xem định danh CCCD ở mục Giấy tờ &amp; Tuyển dụng.</p>
                </div>
                <div style={{ textAlign: 'right' }}>
                  <span style={{ fontSize: 14, fontWeight: 800, color: criteriaPercent === 100 ? '#059669' : '#d97706' }}>
                    {passedCriteriaCount} / {totalCriteriaCount} tiêu chuẩn ({criteriaPercent}%)
                  </span>
                  <div style={{ width: 180, height: 8, background: '#f1f5f9', borderRadius: 6, overflow: 'hidden', marginTop: 4 }}>
                    <div style={{ width: `${criteriaPercent}%`, height: '100%', background: criteriaPercent === 100 ? '#10b981' : '#f59e0b', borderRadius: 6 }} />
                  </div>
                </div>
              </div>

              {partner.review_reason && (
                <div style={{ background: '#fffbeb', border: '1px solid #fde68a', borderRadius: 12, padding: '12px 16px', display: 'flex', alignItems: 'flex-start', gap: 10 }}>
                  <AlertTriangle size={18} color="#d97706" style={{ flexShrink: 0, marginTop: 2 }} />
                  <div>
                    <strong style={{ fontSize: 13, color: '#92400e' }}>Ghi chú của hội đồng thẩm định:</strong>
                    <p style={{ margin: '2px 0 0', fontSize: 12.5, color: '#78350f' }}>{partner.review_reason}</p>
                  </div>
                </div>
              )}

              <div className="partner-criteria-grid">
                {partnerCriteria.map((crit, index) => {
                  const isPassed = !!partnerChecks[crit.key];
                  return (
                    <div key={crit.key} className={`partner-criteria-item ${isPassed ? 'passed' : 'failed'}`}>
                      <div className="partner-criteria-number">{index + 1}</div>
                      {isPassed ? (
                        <CheckCircle2 size={18} color="#16a34a" style={{ flexShrink: 0 }} />
                      ) : (
                        <XCircle size={18} color="#ea580c" style={{ flexShrink: 0 }} />
                      )}
                      <div className="partner-criteria-info">
                        <span className="partner-criteria-label">{crit.label}</span>
                        <span className="partner-criteria-status">
                          {isPassed ? '✓ Đạt chuẩn' : 'Chưa hoàn tất'}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {/* TAB 3: SERVICES & AREAS */}
          {activeTab === 'services' && (
            <div className="partner-section-grid">
              {/* Working Areas */}
              <div className="partner-card-box">
                <div className="partner-card-header">
                  <h4 className="partner-card-title"><MapPin size={16} color="#e11d48" /> Địa bàn hoạt động</h4>
                  <span className="partner-badge info">{dossier?.areas?.length || 0} khu vực</span>
                </div>
                {!dossier?.areas || dossier.areas.length === 0 ? (
                  <p style={{ fontSize: 13, color: '#94a3b8', margin: '14px 0' }}>Chưa thiết lập khu vực hoạt động.</p>
                ) : (
                  <div className="partner-tag-cloud">
                    {dossier.areas.map((a: any, idx: number) => (
                      <span key={idx} className="partner-chip success">
                        <MapPin size={13} />
                        <span>{a.city || a.district || a.ward || 'TP. Hồ Chí Minh'}</span>
                      </span>
                    ))}
                  </div>
                )}


              </div>
            </div>
          )}

          {/* TAB 4: IDENTITY & RECRUITMENT */}
          {activeTab === 'identity' && (
            <div className="partner-section-grid">
              {/* Identity Documents */}
              <div className="partner-card-box">
                <div className="partner-card-header">
                  <h4 className="partner-card-title"><FileText size={16} color="#2563eb" /> Căn cước công dân (CCCD)</h4>
                  <PartnerKycBadge kyc={kycStatus} />
                </div>
                {dossier?.identities && dossier.identities.length > 0 ? (
                  dossier.identities.map((idDoc: any, i: number) => (
                    <div key={i} className="partner-spec-list">
                      <div className="partner-spec-item">
                        <span className="partner-spec-label">Họ tên trên CCCD:</span>
                        <strong className="partner-spec-value">{idDoc.legal_name || idDoc.legalName || profile?.full_name || partner.name}</strong>
                      </div>
                      <div className="partner-spec-item">
                        <span className="partner-spec-label">Số CCCD:</span>
                        <strong className="partner-spec-value" style={{ fontFamily: 'monospace' }}>{idDoc.document_number || idDoc.documentNumber || 'Chưa có số CCCD'}</strong>
                      </div>
                      <div className="partner-spec-item">
                        <span className="partner-spec-label">Loại giấy tờ:</span>
                        <span className="partner-spec-value">Thẻ Căn cước công dân gắn chip</span>
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="partner-spec-list">
                    <div className="partner-spec-item">
                      <span className="partner-spec-label">Họ tên đăng ký:</span>
                      <strong className="partner-spec-value">{partner.name}</strong>
                    </div>

                  </div>
                )}

                <div className="partner-spec-list">
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Giấy tờ CCCD</span>
                    <span className="partner-spec-value">{cleanIdentitySides ? 'Hai mặt đã qua kiểm tra an toàn' : 'Chưa đủ hai mặt đã kiểm tra'}</span>
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Phê duyệt CCCD</span>
                    <span className="partner-spec-value">{kycApproved ? 'Đã phê duyệt' : 'Chưa phê duyệt'}</span>
                  </div>
                </div>
                {dossier && <AdminKycActions key={partner.id} dossier={dossier} onChanged={reloadPartner} photoLinks />}

                {/* Exam result */}
                <div style={{ borderTop: '1px solid #f1f5f9', paddingTop: 14 }}>
                  <h5 style={{ margin: '0 0 10px 0', fontSize: 13, fontWeight: 750, color: '#334155' }}>Kết quả thi tuyển đầu vào</h5>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: '#f8fafc', padding: '10px 14px', borderRadius: 10 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <Award size={18} color="#d97706" />
                      <span style={{ fontSize: 13, fontWeight: 650 }}>Bài thi quy chuẩn TaskLy</span>
                    </div>
                    <span className={`partner-badge ${partnerChecks.exam_passed ? 'active' : 'suspended'}`}>
                      {partnerChecks.exam_passed ? 'ĐẠT (≥ 16/20)' : 'Chưa đạt'}
                    </span>
                  </div>
                </div>
              </div>

              {/* Uniform & Appointment */}
              <div className="partner-card-box">
                <div className="partner-card-header">
                  <h4 className="partner-card-title"><Shirt size={16} color="#059669" /> Đồng phục & Lịch hẹn văn phòng</h4>
                </div>
                <div className="partner-spec-list">
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Đồng phục đối tác:</span>
                    <span className={`partner-badge ${partnerChecks.uniform_resolved ? 'active' : 'pending'}`}>
                      {partnerChecks.uniform_resolved ? 'Đã giải quyết & nhận đồ' : 'Chờ xử lý'}
                    </span>
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Check-in văn phòng:</span>
                    <span className={`partner-badge ${partnerChecks.appointment_checked_in ? 'active' : 'pending'}`}>
                      {partnerChecks.appointment_checked_in ? 'Đã check-in' : 'Chưa check-in'}
                    </span>
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Cam kết hợp tác:</span>
                    <span className={`partner-badge ${partnerChecks.agreements_current ? 'active' : 'pending'}`}>
                      {partnerChecks.agreements_current ? 'Đã ký điện tử' : 'Chưa ký'}
                    </span>
                  </div>
                  <div className="partner-spec-item">
                    <span className="partner-spec-label">Duyệt chính thức:</span>
                    <span className={`partner-badge ${partnerChecks.final_approved ? 'active' : 'pending'}`}>
                      {partnerChecks.final_approved ? 'Đã phê duyệt' : 'Chờ hoàn tất các khâu'}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          )}


          </>}
        </div>

        {/* Modal Footer Actions */}
        <div className="partner-modal-footer">
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            {!editing && (
              <button
                className="btn btn-outline"
                onClick={() => setEditing(true)}
              >
                <Edit3 size={15} /> Chỉnh sửa thông tin
              </button>
            )}
          </div>
          <div className="partner-modal-footer-actions">
            {!editing && partner.recruitment_status === 'ACTIVE' && partner.application_id && onAction && (
              <button
                className="btn btn-outline"
                style={{ color: '#e11d48', borderColor: '#fecdd3' }}
                disabled={saving}
                onClick={() => onAction(partner, 'SUSPEND_TASKER')}
              >
                <AlertTriangle size={15} /> Tạm ngưng kiểm tra
              </button>
            )}

            {!editing && onAction && ['ACTIVE', 'SUSPENDED'].includes(partner.status) && (
              <button
                className={`btn ${isSuspended ? 'btn-primary' : 'btn-danger'}`}
                disabled={saving}
                onClick={() => onAction(partner, 'RESTRICT')}
              >
                {isSuspended ? <Unlock size={15} /> : <Lock size={15} />}
                {isSuspended ? 'Mở khóa tài khoản' : 'Khóa tài khoản'}
              </button>
            )}

            <button className="btn btn-ghost" onClick={onClose}>
              Đóng
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

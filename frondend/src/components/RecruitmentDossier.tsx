'use client';

import { useEffect, useState } from 'react';
import {
  User, Phone, Mail, Calendar, MapPin, Briefcase, Award,
  CheckCircle2, XCircle, Clock, FileText, Shield, GraduationCap,
  Building2, Shirt, History, ChevronRight, Eye, AlertTriangle,
  ExternalLink, ZoomIn, Check, X, Sparkles, MessageSquare
} from 'lucide-react';
import PartnerChecks, { partnerStatusLabels } from './PartnerChecks';

export type Evidence = Record<string, string | number | boolean | null>;

export type DossierApplication = {
  id: string;
  fullName: string;
  status: string;
  version: number;
  updatedAt: string;
  reason: string;
  contactPhone?: string;
  email?: string;
  dateOfBirth?: string;
  experience?: string;
  transport?: string;
  referral?: string;
  firstSubmittedAt?: string;
  editableUntil?: string;
  editable: boolean;
  reviewReady: boolean;
  activatedAt?: string;
  eligibility: Record<string, boolean>;
  requiredChanges: string[];
};

export type Dossier = {
  application: DossierApplication;
  areas: Evidence[];
  services: Evidence[];
  exams: Evidence[];
  lessons: Evidence[];
  agreements: Evidence[];
  identities: Evidence[];
  documents: Evidence[];
  uniforms: Evidence[];
  appointments: Evidence[];
  receipts: Evidence[];
  decisions: Evidence[];
  timeline: Evidence[];
  documentChecklist: Evidence[];
  availability: Evidence[];
  identityHistory: Evidence[];
};

const labels: Record<string, string> = {
  ...partnerStatusLabels,
  COMPLETED: 'Hoàn thành',
  PASSED: 'Đạt',
  FAILED: 'Chưa đạt',
  CLEAN: 'Hợp lệ',
  PENDING: 'Đang chờ',
  PAID: 'Đã thanh toán',
  CANCELLED: 'Đã hủy',
  REFUNDED: 'Đã hoàn tiền',
  RESERVED: 'Đã đặt · Chờ xử lý',
  HANDED_OVER: 'Đã bàn giao',
  WAIVED: 'Miễn thanh toán',
  FRONT: 'Mặt trước',
  BACK: 'Mặt sau',
  SELFIE: 'Ảnh chân dung',
  NATIONAL_ID: 'CCCD',
  PASSPORT: 'Hộ chiếu',
  DEMO: 'Hồ sơ thử nghiệm',
  AT_OFFICE: 'Tiền mặt',
  ONLINE: 'Ngân hàng',
  PARTNER_CONDUCT: 'Tiêu chuẩn tác phong & dịch vụ',
  PARTNER_SAFETY: 'An toàn & Bảo hộ lao động',
  PARTNER_COOPERATION: 'Hợp tác & Quy chế đối tác',
  PARTNER_PRIVACY: 'Bảo mật dữ liệu khách hàng',
  PARTNER_UNIFORM: 'Quy chuẩn sử dụng đồng phục',
  PRELIMINARY: 'Sơ bộ',
  FINAL: 'Chính thức',
  APPROVE_PRELIMINARY: 'Duyệt sơ bộ',
  APPROVE_FINAL: 'Duyệt chính thức & Kích hoạt',
  REQUEST_CHANGES: 'Yêu cầu bổ sung',
  REJECT_WITH_REASON: 'Từ chối hồ sơ',
  ESCALATE: 'Chuyển cấp thẩm quyền',
  SUSPEND: 'Tạm ngưng hoạt động',
  APPLICATION_CREATED: 'Khởi tạo hồ sơ',
  REGISTRATION_DRAFT_SAVED: 'Lưu nháp thông tin',
  REGISTRATION_SUBMITTED: 'Gửi đăng ký',
  PROFILE_SUBMITTED: 'Gửi xét duyệt',
  AGREEMENT_ACCEPTED: 'Ký cam kết',
  DEMO_IDENTITY_SUBMITTED: 'Nộp định danh thử nghiệm',
};

function formatVal(v: Evidence[string], key = ''): string {
  if (v === null || v === undefined || v === '') return '—';
  if (typeof v === 'boolean') return v ? 'Đã hoàn tất' : 'Chưa';
  if (key.endsWith('_at') || key === 'date' || key === 'starts_at' || key === 'ends_at') {
    try {
      return new Date(String(v)).toLocaleString('vi-VN', {
        hour: '2-digit',
        minute: '2-digit',
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
      });
    } catch {
      return String(v);
    }
  }
  return labels[String(v)] || String(v);
}

export default function RecruitmentDossier({
  dossier,
  finalImages,
  canReadIdentity,
  onIdentityApproved,
}: {
  dossier: Dossier;
  finalImages?: Record<string, string> | null;
  canReadIdentity: boolean;
  onIdentityApproved?: () => Promise<void>;
}) {
  const app = dossier.application;
  const [activeTab, setActiveTab] = useState<'identity' | 'academy' | 'office'>('identity');
  const [preview, setPreview] = useState<string>('');
  const [previewTitle, setPreviewTitle] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [loading, setLoading] = useState<boolean>(false);
  const [documentUrls, setDocumentUrls] = useState<Record<string, string>>({});
  const [approving, setApproving] = useState(false);

  useEffect(() => {
    let cancelled = false;
    setDocumentUrls({});
    if (!canReadIdentity) return;
    void Promise.all(dossier.documents.filter(doc => doc.scan_status === 'CLEAN').map(async doc => {
      try {
        const response = await fetch(`/api/admin/recruitment/kyc/${doc.verification_id}/documents/${doc.id}/url`, { cache: 'no-store' });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Không tải được ảnh giấy tờ.');
        const url = new URL(result.data.url);
        if (!['http:', 'https:'].includes(url.protocol)) throw new Error('Liên kết ảnh không hợp lệ.');
        if (!cancelled) setDocumentUrls(previous => ({ ...previous, [String(doc.id)]: url.toString() }));
      } catch (e) {
        if (!cancelled) setError((e as Error).message);
      }
    }));
    return () => { cancelled = true; };
  }, [dossier.documents, canReadIdentity]);

  async function approveIdentity(identity: Evidence) {
    setApproving(true);
    setError('');
    try {
      const response = await fetch(`/api/admin/recruitment/kyc/${identity.id}/approve`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason: 'Đã kiểm tra và xác nhận CCCD hợp lệ.' }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Không xác nhận được CCCD.');
      await onIdentityApproved?.();
    } catch (e) { setError((e as Error).message); }
    finally { setApproving(false); }
  }

  useEffect(() => {
    setPreview('');
    setPreviewTitle('');
    setError('');
  }, [app.id]);

  useEffect(() => {
    if (!preview) return;
    const timer = setTimeout(() => {
      setPreview('');
      setPreviewTitle('');
    }, 240000);
    return () => clearTimeout(timer);
  }, [preview]);

  async function openDocument(document: Evidence, title: string) {
    setLoading(true);
    setError('');
    try {
      const response = await fetch(
        `/api/admin/recruitment/kyc/${document.verification_id}/documents/${document.id}/url`,
        { cache: 'no-store' }
      );
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Không tải được ảnh giấy tờ.');
      const url = new URL(result.data.url);
      if (!['http:', 'https:'].includes(url.protocol)) {
        throw new Error('Liên kết ảnh không an toàn hoặc không hợp lệ.');
      }
      setPreview(url.toString());
      setPreviewTitle(title);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }

  const latestExam = dossier.exams.length > 0 ? dossier.exams[dossier.exams.length - 1] : null;
  let examQuestions: { id: string; text: string; options: string[]; correctOption: number }[] = [];
  let examAnswers: Record<string, number> = {};
  try {
    examQuestions = JSON.parse(String(latestExam?.questions || '[]'));
    examAnswers = JSON.parse(String(latestExam?.answers || '{}'));
  } catch { /* Older attempts may not contain a question snapshot. */ }

  return (
    <div className="dossier-review-layout">
      {/* 1. TOP PIPELINE & ELIGIBILITY STATUS */}
      <aside className="dossier-checks-column" aria-label="Điều kiện đạt chuẩn đối tác">
      <PartnerChecks values={app.eligibility} reason={app.eligibility.preliminary_approved && !['ACTION_REQUIRED', 'REJECTED', 'ESCALATED', 'SUSPENDED'].includes(app.status) ? undefined : app.reason} />
      </aside>
      <div className="dossier-modern-container">

      {app.status === 'ESCALATED' && <div className="dossier-sla-banner in-grace-period"><Clock size={20} /><div><strong>Hồ sơ đang được xem xét thêm</strong><p>{app.reason}</p></div></div>}
      {/* REQUIRED CHANGES WARNING IF ANY */}
      {app.requiredChanges?.length > 0 && (
        <div className="dossier-changes-alert">
          <AlertTriangle size={17} color="#dc2626" />
          <div>
            <strong>Các mục đã yêu cầu ứng viên bổ sung:</strong>
            <div className="changes-tags-list">
              {app.requiredChanges.map((item, idx) => (
                <span key={idx} className="change-tag-chip">
                  {item}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 3. MODERN TAB NAVIGATION */}
      <div className="dossier-tabs-nav">
        <button
          type="button"
          className={`dossier-tab-btn ${activeTab === 'identity' ? 'active' : ''}`}
          onClick={() => setActiveTab('identity')}
        >
          <Shield size={16} />
          <span>Thông tin & Định danh CCCD</span>
        </button>
        <button
          type="button"
          className={`dossier-tab-btn ${activeTab === 'academy' ? 'active' : ''}`}
          onClick={() => setActiveTab('academy')}
        >
          <GraduationCap size={16} />
          <span>Kết quả bài thi đầu vào</span>
          {latestExam && (
            <span
              className={`dossier-tab-pill ${
                latestExam.status === 'PASSED' ? 'green' : 'amber'
              }`}
            >
              {latestExam.score}/20
            </span>
          )}
        </button>
        <button
          type="button"
          className={`dossier-tab-btn ${activeTab === 'office' ? 'active' : ''}`}
          onClick={() => setActiveTab('office')}
        >
          <Building2 size={16} />
          <span>Văn phòng & Đồng phục</span>
          {dossier.uniforms.length > 0 && (
            <span className="dossier-tab-pill blue">
              {dossier.uniforms.length} đơn
            </span>
          )}
        </button>
      </div>

      {/* 4. TAB CONTENTS */}
      <div className="dossier-tab-body">
        {/* ======================================================== */}
        {/* TAB 1: THÔNG TIN CÁ NHÂN & ĐỊNH DANH CCCD */}
        {/* ======================================================== */}
        {activeTab === 'identity' && (
          <div className="dossier-tab-section">
            {/* PERSONAL INFO CARD */}
            <div className="dossier-card">
              <div className="dossier-card-header">
                <div className="dossier-card-title">
                  <User size={18} color="#0b9879" />
                  <h4>Thông tin cá nhân ứng viên</h4>
                </div>
              </div>
              <div className="dossier-grid-cols">
                <div className="dossier-info-field">
                  <span className="field-label">Họ và tên</span>
                  <strong className="field-value">{app.fullName || '—'}</strong>
                </div>
                <div className="dossier-info-field">
                  <span className="field-label">Số điện thoại</span>
                  <strong className="field-value mono">
                    {app.contactPhone || '—'}
                  </strong>
                </div>
                <div className="dossier-info-field">
                  <span className="field-label">Địa chỉ email</span>
                  <span className="field-value">{app.email || '—'}</span>
                </div>
                <div className="dossier-info-field">
                  <span className="field-label">Ngày sinh</span>
                  <span className="field-value">{app.dateOfBirth || '—'}</span>
                </div>
                <div className="dossier-info-field">
                  <span className="field-label">Người giới thiệu</span>
                  <span className="field-value">{app.referral || 'Không có'}</span>
                </div>
              </div>
            </div>

            {/* REGISTERED AREAS */}
            <div>
              <details className="dossier-card dossier-areas-collapse" key={app.id}>
                <summary className="dossier-card-header">
                  <div className="dossier-card-title">
                    <MapPin size={17} color="#0b9879" />
                    <h4>Khu vực hoạt động ({dossier.areas.length})</h4>
                  </div>
                  <ChevronRight size={17} className="dossier-areas-chevron" />
                </summary>
                {dossier.areas.length === 0 ? (
                  <p className="dossier-empty">Chưa đăng ký khu vực nào.</p>
                ) : (
                  <div className="dossier-areas-scroll" tabIndex={0} role="region" aria-label="Danh sách khu vực hoạt động">
                    {dossier.areas.map((a, idx) => (
                      <span key={idx} className="dossier-area-tag">
                        <MapPin size={13} />
                        <strong>{String(a.city)}</strong> · {String(a.name)}
                      </span>
                    ))}
                  </div>
                )}
              </details>

            </div>

            {/* IDENTITY VERIFICATION & CCCD IMAGES */}
            <div className="dossier-card">
              <div className="dossier-card-header">
                <div className="dossier-card-title">
                  <Shield size={18} color="#0b9879" />
                  <h4>Xác minh giấy tờ CCCD & Định danh</h4>
                </div>
              </div>

              {dossier.identities.length === 0 ? (
                <p className="dossier-empty">Chưa có thông tin nộp CCCD.</p>
              ) : (
                <div className="dossier-identities-table-wrap">
                  <table className="dossier-table dossier-identity-table">
                    <thead>
                      <tr>
                        {canReadIdentity ? (
                          <>
                            <th>Họ tên giấy tờ</th>
                            <th>Loại giấy tờ</th>
                            <th>Số định danh</th>
                            <th>Trạng thái</th>
                            <th>Ngày nộp</th>
                            <th>Ghi chú</th>
                          </>
                        ) : (
                          <>
                            <th>Trạng thái</th>
                            <th>Ngày nộp</th>
                            <th>Ngày duyệt</th>
                          </>
                        )}
                      </tr>
                    </thead>
                    <tbody>
                      {dossier.identities.map((id, i) => (
                        <tr key={i}>
                          {canReadIdentity ? (
                            <>
                              <td>
                                <strong>{String(id.legal_name || '—')}</strong>
                              </td>
                              <td>{formatVal(id.document_type)}</td>
                              <td>
                                <span className="mono bold">
                                  {String(id.document_number || '—')}
                                </span>
                              </td>
                              <td>
                                <span
                                  className={`badge ${
                                    id.status === 'APPROVED'
                                      ? 'green'
                                      : id.status === 'SUBMITTED'
                                      ? 'amber'
                                      : 'neutral'
                                  }`}
                                >
                                  {formatVal(id.status)}
                                </span>
                              </td>
                              <td>{formatVal(id.submitted_at, 'date')}</td>
                              <td className="dossier-note-cell"><span className="dossier-note-hover">
                                <button type="button" className="dossier-note-icon" aria-label="Xem ghi chú"><MessageSquare size={16} /></button>
                                <span className="dossier-note-tooltip" role="tooltip">{String(id.decision_reason || 'Chưa có ghi chú')}</span>
                              </span></td>
                            </>
                          ) : (
                            <>
                              <td>
                                <span className="badge amber">
                                  {formatVal(id.status)}
                                </span>
                              </td>
                              <td>{formatVal(id.submitted_at, 'date')}</td>
                              <td>{formatVal(id.reviewed_at, 'date')}</td>
                            </>
                          )}
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              {/* CCCD PHOTO INSPECTION CARDS */}
              {canReadIdentity && dossier.documents.length > 0 && (
                <div className="dossier-doc-inspection">
                  <span className="doc-inspection-title">
                    Ảnh chụp giấy tờ đính kèm ({dossier.documents.length} ảnh):
                  </span>
                  <div className="doc-cards-grid">
                    {[...dossier.documents].sort((a, b) => ['FRONT', 'BACK', 'SELFIE'].indexOf(String(a.document_side)) - ['FRONT', 'BACK', 'SELFIE'].indexOf(String(b.document_side))).map((doc) => {
                      const sideLabel = formatVal(doc.document_side);
                      const isClean = doc.scan_status === 'CLEAN';
                      return (
                        <div key={String(doc.id)} className="doc-photo-card">
                          <div className="doc-photo-info">
                            <div className="doc-side-name">
                              <FileText size={15} color="#0b9879" />
                              <span>{sideLabel}</span>
                            </div>
                            <span
                              className={`doc-scan-badge ${
                                isClean ? 'clean' : 'pending'
                              }`}
                            >
                              {formatVal(doc.scan_status)}
                            </span>
                          </div>
                          <button
                            type="button"
                            className="doc-thumbnail-button"
                            disabled={loading || !isClean}
                            onClick={() => void openDocument(doc, sideLabel)}
                          >
                            {documentUrls[String(doc.id)] ? <img src={documentUrls[String(doc.id)]} alt={sideLabel} referrerPolicy="no-referrer" /> : <span>{isClean ? 'Đang tải ảnh…' : 'Ảnh chưa được kiểm tra an toàn'}</span>}
                            <span className="doc-thumbnail-caption"><ZoomIn size={14} /> Bấm để phóng to</span>
                          </button>
                        </div>
                      );
                    })}
                  </div>
                </div>
              )}

              {/* IMAGE LIGHTBOX PREVIEW */}
              {error && (
                <div className="notice catalogue-notice" role="alert" style={{ marginTop: 12, background: '#fef2f2', borderColor: '#fca5a5', color: '#991b1b' }}>
                  {error}
                </div>
              )}

              {preview && (
                <dialog className="doc-preview-modal-box dossier-image-lightbox" ref={node => { if (node && !node.open) node.showModal(); }} onCancel={() => setPreview('')} onClick={event => { if (event.target === event.currentTarget) setPreview(''); }}>
                  <div className="doc-preview-header">
                    <span>
                      Ảnh giấy tờ: <strong>{previewTitle}</strong>
                    </span>
                    <button
                      type="button"
                      className="btn-icon-action"
                      onClick={() => setPreview('')}
                    >
                      <X size={15} /> Đóng xem ảnh
                    </button>
                  </div>
                  <div className="doc-preview-body">
                    <img
                      src={preview}
                      alt="Ảnh giấy tờ ứng viên"
                      referrerPolicy="no-referrer"
                    />
                  </div>
                </dialog>
              )}
            </div>


          </div>
        )}

        {/* ======================================================== */}
        {/* TAB 2: ĐÀO TẠO ACADEMY & BÀI THI */}
        {/* ======================================================== */}
        {activeTab === 'academy' && (
          <div className="dossier-tab-section">
            {examQuestions.length > 0 && <div className="dossier-card">
              <div className="dossier-exam-questions" tabIndex={0} aria-label="Câu hỏi và câu trả lời bài thi">
                {examQuestions.map((question, index) => {
                  const answer = examAnswers[question.id];
                  return <div className="dossier-exam-question" key={question.id}>
                    <strong>Câu {index + 1}: {question.text}</strong>
                    <span>Đã chọn: {answer === undefined ? 'Chưa trả lời' : question.options[answer]}</span>
                    <span className={answer === question.correctOption ? 'exam-answer-correct' : 'exam-answer-wrong'}>Đáp án đúng: {question.options[question.correctOption]}</span>
                  </div>;
                })}
              </div>
            </div>}
          </div>
        )}

        {/* ======================================================== */}
        {/* TAB 3: VĂN PHÒNG & ĐỒNG PHỤC */}
        {/* ======================================================== */}
        {activeTab === 'office' && (
          <div className="dossier-tab-section">
            {/* OFFICE APPOINTMENTS */}
            <div className="dossier-card">
              <div className="dossier-card-header">
                <div className="dossier-card-title">
                  <Building2 size={18} color="#0b9879" />
                  <h4>Lịch hẹn đối chiếu tại văn phòng</h4>
                </div>
              </div>

              {dossier.appointments.length === 0 ? (
                <p className="dossier-empty">Chưa có lịch hẹn tại văn phòng.</p>
              ) : (
                <table className="dossier-table">
                  <thead>
                    <tr>
                      <th>Văn phòng tiếp nhận</th>
                      <th>Địa chỉ</th>
                      <th>Thời gian hẹn</th>
                      <th>Trạng thái</th>
                      <th>Giờ check-in</th>
                    </tr>
                  </thead>
                  <tbody>
                    {dossier.appointments.map((ap, i) => (
                      <tr key={i}>
                        <td>
                          <strong>{String(ap.name)}</strong>
                        </td>
                        <td>{String(ap.address)}</td>
                        <td>{formatVal(ap.starts_at, 'date')}</td>
                        <td>
                          <span
                            className={`badge ${
                              ap.status === 'CHECKED_IN' ? 'green' : 'amber'
                            }`}
                          >
                            {formatVal(ap.status)}
                          </span>
                        </td>
                        <td>{formatVal(ap.checked_in_at, 'date')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            {/* DOCUMENT RECEIPTS */}
            <div className="dossier-card">
              <div className="dossier-card-header">
                <div className="dossier-card-title">
                  <FileText size={18} color="#0b9879" />
                  <h4>Biên nhận hồ sơ bản chính</h4>
                </div>
              </div>

              {finalImages?.contract && <div style={{ marginBottom: 16 }}><p>Hợp đồng đã ký do Partner gửi</p><img src={finalImages.contract} alt="Hợp đồng đã ký" style={{ width: '100%', maxWidth: 360, height: 240, objectFit: 'contain', cursor: 'zoom-in' }} onClick={() => { setPreview(finalImages.contract); setPreviewTitle('Hợp đồng đã ký'); }} /></div>}
              {dossier.receipts.length === 0 && !finalImages?.contract ? (
                <p className="dossier-empty">Chưa có biên nhận hồ sơ bản chính.</p>
              ) : (
                <>
                  <table className="dossier-table">
                    <thead>
                      <tr>
                        <th>Ngày tiếp nhận</th>
                        <th>Hồ sơ đầy đủ</th>
                        <th>Đã trả bản chính</th>
                        <th>Ghi chú tiếp nhận</th>
                      </tr>
                    </thead>
                    <tbody>
                      {dossier.receipts.map((rc, i) => (
                        <tr key={i}>
                          <td>{formatVal(rc.received_at, 'date')}</td>
                          <td>
                            <span
                              className={`badge ${rc.complete ? 'green' : 'amber'}`}
                            >
                              {rc.complete ? 'Đầy đủ' : 'Chưa đủ'}
                            </span>
                          </td>
                          <td>
                            <span
                              className={`badge ${
                                rc.originals_returned ? 'green' : 'amber'
                              }`}
                            >
                              {rc.originals_returned ? 'Đã trả' : 'Chưa trả'}
                            </span>
                          </td>
                          <td>{String(rc.notes || '—')}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>

                  {dossier.receipts.map((receipt, i) => {
                    let checked: Record<string, boolean> = {};
                    try {
                      checked = JSON.parse(String(receipt.checklist));
                    } catch {
                      /* Legacy */
                    }
                    return (
                      <div key={i} className="receipt-checklist-block">
                        <span className="checklist-block-title">
                          Danh mục giấy tờ đối chiếu:
                        </span>
                        <div className="receipt-items-list">
                          {dossier.documentChecklist.map((item) => (
                            <div
                              key={String(item.id)}
                              className={`receipt-check-item ${
                                checked[String(item.id)] ? 'checked' : ''
                              }`}
                            >
                              {checked[String(item.id)] ? (
                                <CheckCircle2 size={14} color="#059669" />
                              ) : (
                                <XCircle size={14} color="#94a3b8" />
                              )}
                              <span>{formatVal(item.label)}</span>
                            </div>
                          ))}
                        </div>
                      </div>
                    );
                  })}
                </>
              )}
            </div>

            {/* UNIFORMS */}
            <div className="dossier-card"><div className="dossier-card-header"><div className="dossier-card-title"><h4>Ảnh chân dung Partner</h4></div></div>{finalImages?.portrait ? <img src={finalImages.portrait} alt="Ảnh chân dung Partner" style={{ width: 160, height: 200, objectFit: 'cover', borderRadius: 12, cursor: 'zoom-in' }} onClick={() => { setPreview(finalImages.portrait); setPreviewTitle('Ảnh chân dung Partner'); }} /> : <p className="dossier-empty">Partner chưa gửi ảnh chân dung chặng 4.</p>}</div>
            <div className="dossier-card">
              <div className="dossier-card-header">
                <div className="dossier-card-title">
                  <Shirt size={18} color="#0b9879" />
                  <h4>Đồng phục & Thanh toán</h4>
                </div>
              </div>

              {dossier.uniforms.length === 0 ? (
                <p className="dossier-empty">Chưa có đơn đặt đồng phục.</p>
              ) : (
                <table className="dossier-table">
                  <thead>
                    <tr>
                      <th>Gói đồng phục</th>
                      <th>Kích cỡ (Size)</th>
                      <th>Giá tiền</th>
                      <th>Phương thức</th>
                      <th>Thanh toán</th>
                      <th>Trạng thái đơn</th>
                      <th>Bàn giao lúc</th>
                    </tr>
                  </thead>
                  <tbody>
                    {dossier.uniforms.map((u, i) => (
                      <tr key={i}>
                        <td>
                          <strong>{String(u.name)}</strong>
                        </td>
                        <td>
                          <span className="dossier-size-chip">
                            {String(u.size)}
                          </span>
                        </td>
                        <td>
                          <strong style={{ color: '#0b9879' }}>
                            {Number(u.price || 0).toLocaleString('vi-VN')} đ
                          </strong>
                        </td>
                        <td>{formatVal(u.payment_method)}</td>
                        <td>
                          <span
                            className={`badge ${
                              ['CANCELLED', 'REFUNDED'].includes(String(u.status)) ? 'neutral' : u.payment_status === 'PAID' ? 'green' : 'amber'
                            }`}
                          >
                            {u.status === 'CANCELLED' ? 'Không cần thanh toán' : u.status === 'REFUNDED' ? 'Đã hoàn tiền' : formatVal(u.payment_status)}
                          </span>
                        </td>
                        <td>
                          <span className="badge neutral">
                            {formatVal(u.status)}
                          </span>
                        </td>
                        <td>{formatVal(u.handed_over_at, 'date')}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
          </div>
        )}

        {/* ======================================================== */}
        {/* TAB 4: KÍCH HOẠT & LỊCH SỬ DUYỆT */}
        {/* ======================================================== */}

      </div>
    </div>
    </div>
  );
}

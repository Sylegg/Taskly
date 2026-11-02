import { CheckCircle2, Circle, AlertCircle } from 'lucide-react';

export const partnerStatusLabels: Record<string, string> = {
  NOT_REGISTERED: 'Chưa đăng ký hồ sơ',
  NOT_SUBMITTED: 'Chưa nộp định danh',
  REGISTERED: 'Đã đăng ký',
  WAITLISTED: 'Danh sách chờ',
  EXAM_REQUIRED: 'Chờ làm bài thi',
  EXAM_IN_PROGRESS: 'Đang làm bài thi',
  EXAM_FAILED: 'Bài thi chưa đạt',
  TRAINING_REQUIRED: 'Chờ đào tạo',
  AGREEMENT_REQUIRED: 'Chờ ký cam kết',
  PROFILE_INCOMPLETE: 'Chưa hoàn tất hồ sơ',
  PRELIMINARY_REVIEW: 'Chờ duyệt sơ bộ',
  PRELIMINARY_APPROVED: 'Đã duyệt sơ bộ',
  UNIFORM_PENDING: 'Chờ đồng phục',
  DOCUMENT_APPOINTMENT: 'Chờ lịch nộp hồ sơ',
  DOCUMENTS_RECEIVED: 'Đã nhận hồ sơ',
  FINAL_REVIEW: 'Chờ duyệt cuối',
  ACTION_REQUIRED: 'Cần bổ sung hồ sơ',
  ESCALATED: 'Đang xem xét thêm',
  APPROVED: 'Đã phê duyệt',
  ACTIVE: 'Đã kích hoạt',
  SUSPENDED: 'Tạm ngưng hoạt động',
  REJECTED: 'Bị từ chối',
  DRAFT: 'Chưa gửi',
  PENDING_REVIEW: 'Chờ xét duyệt',
  SUBMITTED: 'Đã nộp',
  UNDER_REVIEW: 'Đang kiểm tra',
  EXPIRED: 'Đã hết hạn',
};

export const checks: Record<string, string> = {
  profile_complete: 'Hồ sơ cá nhân',
  agreements_current: 'Cam kết đối tác',
  exam_passed: 'Bài thi đầu vào (≥16/20)',
  identity_complete: 'Giấy tờ CCCD hợp lệ',
  preliminary_approved: 'Duyệt sơ bộ',
  appointment_checked_in: 'Check-in văn phòng',
  uniform_resolved: 'Đồng phục & thanh toán',
  final_approved: 'Duyệt chính thức',
};

export default function PartnerChecks({
  values,
  reason,
}: {
  values?: Record<string, boolean>;
  reason?: string;
}) {
  const entries = Object.entries(checks);
  const doneCount = entries.filter(([key]) => !!values?.[key]).length;
  const totalCount = entries.length;
  const percentage = Math.round((doneCount / totalCount) * 100);

  return (
    <section className="partner-checks-container">
      <div className="partner-checks-header">
        <div className="checks-title-wrap">
          <span className="checks-eyebrow">TIẾN TRÌNH THẨM ĐỊNH</span>
          <h4 className="checks-title">Điều kiện đạt chuẩn đối tác</h4>
        </div>
        <div className="checks-badge-status">
          <span className="checks-progress-text">
            <strong>{doneCount}</strong>/{totalCount} tiêu chuẩn ({percentage}%)
          </span>
          <div className="checks-mini-progress-bar">
            <div
              className="checks-mini-progress-fill"
              style={{ width: `${percentage}%` }}
            />
          </div>
        </div>
      </div>

      <ol className="partner-check-grid">
        {entries.map(([key, label], index) => {
          const isDone = !!values?.[key];
          return (
            <li
              key={key}
              className={`partner-check-pill ${isDone ? 'done' : 'pending'}`}
            >
              <span className="check-step-number">{index + 1}</span>
              {isDone ? (
                <CheckCircle2 size={16} className="check-icon done" />
              ) : (
                <Circle size={16} className="check-icon pending" />
              )}
              <div className="check-content">
                <span className="check-label">{label}</span>
                <span className="check-status-sub">
                  {isDone ? 'Đã đạt' : 'Chưa đạt'}
                </span>
              </div>
            </li>
          );
        })}
      </ol>

      {reason && (
        <div className="partner-check-notice">
          <AlertCircle size={16} color="#d97706" />
          <div>
            <strong>Ghi chú xét duyệt:</strong> <span>{reason}</span>
          </div>
        </div>
      )}
    </section>
  );
}

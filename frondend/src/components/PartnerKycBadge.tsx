import { partnerStatusLabels } from './PartnerChecks';

export default function PartnerKycBadge({ kyc, prefix = '' }: { kyc?: string; prefix?: string }) {
  const status = kyc || 'NOT_SUBMITTED';
  const pending = status === 'SUBMITTED' || status === 'UNDER_REVIEW';
  const tone = status === 'APPROVED' ? 'active' : pending ? 'pending' : 'neutral';
  const label = status === 'APPROVED' ? '✓ Đã duyệt' : status === 'SUBMITTED' ? 'Chờ duyệt' :
    status === 'NOT_SUBMITTED' ? 'Chưa nộp' : partnerStatusLabels[status] || status;

  return <span className={`partner-badge ${tone}`}>{prefix}{label}</span>;
}

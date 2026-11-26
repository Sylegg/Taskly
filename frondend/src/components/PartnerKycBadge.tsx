import { partnerStatusLabels } from './PartnerChecks';

type PartnerIdentity = {
  id: string;
  kyc?: string;
  demo_exe201?: boolean;
};

// The EXE201 approval applies only to the two seeded Tasker accounts.
const exe201SampleTaskers = new Set([
  '8901e5f4-3521-061c-0a29-f34e8300c042',
  '27017642-d8ee-52b5-1af0-50250e95a26d',
]);

export function hasSimulatedKycApproval(partner: PartnerIdentity) {
  return partner.demo_exe201 === true && partner.kyc === 'NOT_SUBMITTED' && exe201SampleTaskers.has(partner.id);
}

export default function PartnerKycBadge({ partner, prefix = '' }: { partner: PartnerIdentity; prefix?: string }) {
  if (hasSimulatedKycApproval(partner)) {
    return <span className="partner-badge active" title="Hồ sơ định danh chính thức chưa nộp">
      {prefix}✓ Đã duyệt (mô phỏng)
    </span>;
  }

  const status = partner.kyc || 'NOT_SUBMITTED';
  const pending = status === 'SUBMITTED' || status === 'UNDER_REVIEW';
  const tone = status === 'APPROVED' ? 'active' : pending ? 'pending' : 'neutral';
  const label = status === 'APPROVED' ? '✓ Đã duyệt' : status === 'SUBMITTED' ? 'Chờ duyệt' :
    status === 'NOT_SUBMITTED' ? 'Chưa nộp' : partnerStatusLabels[status] || status;

  return <span className={`partner-badge ${tone}`}>{prefix}{label}</span>;
}

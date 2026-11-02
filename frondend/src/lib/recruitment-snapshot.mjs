// Explicit demo backup contract shared with Partner. Never production KYC authority.
const statuses = new Set('registered examRequired examInProgress examFailed examPassed trainingRequired agreementRequired profileIncomplete preliminaryReview actionRequired preliminaryApproved uniformPending documentAppointment documentsReceived finalReview approved active rejected suspended waitlisted cancelledByApplicant expired escalated'.split(' '));
const roles = new Set('applicant superAdmin recruitmentStaff trainingManager kycStaff receptionStaff financeStaff operationsManager'.split(' '));
const eligibilityKeys = 'registrationComplete recruiting examPassed trainingComplete agreementsCurrent profileComplete preliminaryApproved uniformResolved appointmentCheckedIn documentsValid finalApproved skillsConfigured areasConfigured availabilityConfigured'.split(' ');
const appKeys = 'id userId createdAt updatedAt status version eligibility documentsReceivedAt activatedAt requiredChanges reason'.split(' ');
const auditKeys = 'actorId role applicationId before after reason at requestId'.split(' ');
const object = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const exact = (value, keys) => object(value) && Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
const text = value => typeof value === 'string' && value.trim().length > 0;
const date = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value) && Number.isFinite(Date.parse(value));
const ready = e => ['preliminaryApproved','uniformResolved','appointmentCheckedIn','documentsValid','agreementsCurrent','finalApproved','skillsConfigured','areasConfigured','availabilityConfigured'].every(key => e[key] === true);
const invalid = () => { throw new Error('Snapshot tuyển dụng demo không hợp lệ.'); };

export function parseRecruitmentSnapshot(source) {
  if (typeof source !== 'string' || source.length > 2000000) invalid();
  let value;
  try { value = JSON.parse(source); } catch { invalid(); }
  if (!exact(value, ['schema','version','mode','applications','audit','requests']) || value.schema !== 'taskly.partner-recruitment' || value.version !== 1 || value.mode !== 'DEMO_METADATA_ONLY' || !Array.isArray(value.applications) || !Array.isArray(value.audit) || !object(value.requests)) invalid();
  const ids = new Set(), users = new Set();
  for (const a of value.applications) {
    if (!exact(a, appKeys) || !text(a.id) || !text(a.userId) || ids.has(a.id) || users.has(a.userId) || !statuses.has(a.status) || !Number.isSafeInteger(a.version) || a.version < 0 || !date(a.createdAt) || !date(a.updatedAt) || [a.documentsReceivedAt,a.activatedAt].some(d => d !== null && !date(d)) || typeof a.reason !== 'string' || !Array.isArray(a.requiredChanges) || a.requiredChanges.some(s => typeof s !== 'string') || !exact(a.eligibility, eligibilityKeys) || Object.values(a.eligibility).some(b => typeof b !== 'boolean') || (a.status === 'active' && !ready(a.eligibility))) invalid();
    ids.add(a.id); users.add(a.userId);
  }
  for (const log of value.audit) {
    if (!exact(log, auditKeys) || !text(log.actorId) || !text(log.requestId) || !ids.has(log.applicationId) || !roles.has(log.role) || !statuses.has(log.before) || !statuses.has(log.after) || !date(log.at) || typeof log.reason !== 'string') invalid();
  }
  if (Object.values(value.requests).some(s => typeof s !== 'string')) invalid();
  return value;
}

export function importRecruitmentDemo(source, current, actor) {
  if (!text(actor?.id) || actor?.role !== 'superAdmin') throw new Error('Chỉ quản trị viên được nhập snapshot demo.');
  const next = parseRecruitmentSnapshot(source);
  if (current) {
    const prior = parseRecruitmentSnapshot(JSON.stringify(current));
    for (const app of prior.applications) {
      const replacement = next.applications.find(a => a.id === app.id);
      if (!replacement || replacement.version < app.version || replacement.userId !== app.userId) throw new Error('Snapshot thiếu hồ sơ hoặc cũ hơn dữ liệu hiện tại.');
    }
  }
  return next;
}

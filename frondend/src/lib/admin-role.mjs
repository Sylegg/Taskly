export function isAdmin(user) {
  return user?.status === 'ACTIVE' && Array.isArray(user.roles) &&
    user.roles.some(role => role === 'ADMIN' || role === 'SUPER_ADMIN');
}
export function isRecruitmentStaff(user) {
  return user?.status === 'ACTIVE' && Array.isArray(user.roles) &&
    user.roles.some(role => ['RECRUITMENT_STAFF','TRAINING_MANAGER','KYC_STAFF','RECEPTION_STAFF','FINANCE_STAFF','OPERATIONS_MANAGER'].includes(role));
}

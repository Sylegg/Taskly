const amountLimit = 1_000_000_000;

export function pricingPayload(draft, quantityFields) {
  if (!['FIXED', 'HOURLY', 'FIELD'].includes(draft.mode)) throw new Error('Chọn cách tính giá hợp lệ.');
  const amount = (value, label) => {
    if (String(value).trim() === '' || !/^\d+$/.test(String(value))) throw new Error(label + ' phải là số nguyên không âm.');
    const result = Number(value);
    if (!Number.isSafeInteger(result) || result > amountLimit) throw new Error(label + ' tối đa 1.000.000.000 đ.');
    return result;
  };
  const baseAmount = amount(draft.baseAmount, 'Giá cơ bản');
  const unitAmount = draft.mode === 'FIXED' ? 0 : amount(draft.unitAmount, 'Đơn giá');
  const platformFeePercent = draft.platformFeePercent == null || draft.platformFeePercent === '' ? null : Number(draft.platformFeePercent);
  if (platformFeePercent !== null && (!Number.isFinite(platformFeePercent) || platformFeePercent < 0 || platformFeePercent > 100 || !/^\d+(\.\d{1,2})?$/.test(String(draft.platformFeePercent)))) throw new Error('Phí sàn từ 0 đến 100%, tối đa 2 chữ số thập phân.');
  const platformFeeAmount = platformFeePercent === null ? amount(draft.platformFeeAmount, 'Phí sàn') : 0;
  const quoteTtlMinutes = amount(draft.quoteTtlMinutes, 'Thời hạn báo giá');
  if (quoteTtlMinutes < 1 || quoteTtlMinutes > 60) throw new Error('Thời hạn báo giá từ 1 đến 60 phút.');
  const quantityField = draft.mode === 'FIELD' ? draft.quantityField : null;
  if (draft.mode === 'FIELD' && !quantityFields?.some(field => field.key === quantityField)) {
    throw new Error('Chọn trường số lượng hợp lệ từ biểu mẫu dịch vụ.');
  }
  const enabled = draft.enabled === true;
  if (enabled && baseAmount + unitAmount + platformFeeAmount === 0) throw new Error('Cần nhập giá trước khi bật báo giá.');
  return { mode: draft.mode, quantityField, baseAmount, unitAmount, platformFeeAmount, quoteTtlMinutes, enabled, ...(platformFeePercent === null ? {} : {platformFeePercent}) };
}

export function pricingDraft(rule) {
  if (rule === null) return { mode: 'FIXED', quantityField: '', baseAmount: '0', unitAmount: '0', platformFeeAmount: '0', platformFeePercent: '10', quoteTtlMinutes: '15', enabled: false };
  if (!rule || !['FIXED', 'HOURLY', 'FIELD'].includes(rule.mode)
    || typeof rule.enabled !== 'boolean'
    || !['baseAmount', 'unitAmount', 'platformFeeAmount'].every(key => Number.isSafeInteger(rule[key]) && rule[key] >= 0 && rule[key] <= amountLimit)
    || !Number.isInteger(rule.quoteTtlMinutes) || rule.quoteTtlMinutes < 1 || rule.quoteTtlMinutes > 60
    || (rule.mode === 'FIELD' && (typeof rule.quantityField !== 'string' || !rule.quantityField))) {
    throw new Error('Thông tin giá từ máy chủ không hợp lệ. Vui lòng tải lại.');
  }
  return { mode: rule.mode, quantityField: rule.quantityField || '', baseAmount: String(rule.baseAmount), unitAmount: String(rule.unitAmount), platformFeeAmount: String(rule.platformFeeAmount), platformFeePercent: rule.platformFeePercent == null ? '' : String(rule.platformFeePercent), quoteTtlMinutes: String(rule.quoteTtlMinutes), enabled: rule.enabled };
}

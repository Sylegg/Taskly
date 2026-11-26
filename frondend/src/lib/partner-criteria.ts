export const partnerCriteria = [
  { key: 'profile_complete', label: 'Hồ sơ cá nhân', desc: 'Đầy đủ họ tên, SĐT, ngày sinh và phương tiện' },
  { key: 'exam_passed', label: 'Bài thi đầu vào', desc: 'Đạt điểm chuẩn bài thi lý thuyết quy trình' },
  { key: 'training_complete', label: 'Đào tạo', desc: 'Đã hoàn thành nội dung đào tạo đối tác' },
  { key: 'agreements_current', label: 'Cam kết đối tác', desc: 'Đã ký thỏa thuận hợp tác và quy tắc ứng xử' },
  { key: 'preliminary_approved', label: 'Duyệt sơ bộ hồ sơ', desc: 'Đội ngũ tuyển dụng đã thông qua vòng sơ khảo' },
  { key: 'appointment_checked_in', label: 'Check-in văn phòng', desc: 'Có mặt tại văn phòng để đối soát hồ sơ gốc' },
  { key: 'documents_valid', label: 'Đối chiếu hồ sơ giấy tờ', desc: 'Bản gốc đối chiếu trùng khớp bản scan' },
  { key: 'uniform_resolved', label: 'Đồng phục và trang bị', desc: 'Đã xử lý yêu cầu đồng phục TaskLy' },
  { key: 'skills_configured', label: 'Kỹ năng dịch vụ', desc: 'Đã thiết lập các dịch vụ nhận việc' },
  { key: 'areas_configured', label: 'Khu vực hoạt động', desc: 'Đã thiết lập địa bàn phục vụ' },
  { key: 'availability_configured', label: 'Lịch làm việc', desc: 'Đã thiết lập thời gian có thể nhận việc' },
  { key: 'final_approved', label: 'Duyệt chính thức', desc: 'Đã có quyết định phê duyệt vận hành' },
] as const;

export function getPartnerCriteriaProgress(values?: Record<string, boolean> | null) {
  const passed = partnerCriteria.filter(({ key }) => values?.[key] === true).length;
  const total = partnerCriteria.length;
  return { passed, total, percentage: Math.round((passed / total) * 100) };
}

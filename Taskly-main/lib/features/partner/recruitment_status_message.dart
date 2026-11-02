(String, String) recruitmentStatusMessage(Map<String, dynamic> app) {
  final status = app['status'];
  final flags = app['eligibility'] as Map? ?? {};
  if (status == 'ACTIVE') return ('Tài khoản đã được kích hoạt', 'Admin đã kích hoạt tài khoản. Bạn có thể sử dụng ứng dụng và cập nhật lịch rảnh khi sẵn sàng nhận việc.');
  if (['ACTION_REQUIRED', 'REJECTED', 'ESCALATED', 'SUSPENDED'].contains(status)) {
    final titles = {'ACTION_REQUIRED': 'Hồ sơ cần bổ sung', 'REJECTED': 'Hồ sơ đã bị từ chối', 'ESCALATED': 'Hồ sơ đang được xem xét thêm', 'SUSPENDED': 'Tài khoản đang tạm ngưng'};
    return (titles[status]!, app['reason']?.toString() ?? '');
  }
  if (status == 'APPROVED') return ('Bổ sung ảnh chặng 4', 'Gửi ảnh chân dung và ảnh hợp đồng đã ký để admin kiểm duyệt trước khi kích hoạt tài khoản.');
  if ( ['DOCUMENTS_RECEIVED', 'FINAL_REVIEW'].contains(status) || flags['appointment_checked_in'] == true) return ('Chờ admin duyệt chính thức và kích hoạt', 'Bạn đã hoàn tất check-in tại văn phòng. Admin sẽ xác nhận các thủ tục và kích hoạt tài khoản. Bạn không cần thao tác ở chặng 4.');
  if (flags['preliminary_approved'] == true) {
    if (flags['uniform_ordered'] != true) return ('Hồ sơ đã được duyệt sơ bộ', 'Tiếp tục chặng 3: chọn gói đồng phục và xác nhận đặt đơn.');
    if (flags['office_visit_confirmed'] != true) return ('Đã đặt đồng phục', 'Vui lòng xem địa chỉ văn phòng và tick xác nhận sẽ đến để hoàn tất chặng 3.');
    return ('Đã xác nhận đến văn phòng', 'Mang CCCD gốc đến địa chỉ đã xem để đối chiếu và nhận đồng phục. Nhân viên sẽ xác nhận check-in khi bạn đến.');
  }
  return ('Hồ sơ đang chờ xét duyệt', 'Kết quả sẽ được thông báo khi admin xử lý hồ sơ.');
}

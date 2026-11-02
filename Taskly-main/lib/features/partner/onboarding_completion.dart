/// Completion comes from persisted requirements, never from status ordering.
Set<String> savedIdentitySides(Map<String, dynamic>? identity) =>
    (identity?['documents'] as List? ?? [])
        .where(
          (doc) =>
              doc['scanStatus'] == 'CLEAN' &&
              ['FRONT', 'BACK', 'SELFIE'].contains(doc['side']),
        )
        .map<String>((doc) => doc['side'].toString())
        .toSet();

Map<int, List<String>> onboardingMissing(
  Map<String, dynamic> application, {
  Map<String, dynamic>? identity,
}) {
  final flags = application['eligibility'] as Map? ?? {};
  final missing = <int, List<String>>{
    for (var step = 1; step <= 8; step++) step: [],
  };
  void require(int step, String key, String message) {
    if (flags[key] != true) missing[step]!.add(message);
  }

  require(
    1,
    'registration_submitted',
    'Chưa hoàn tất đăng ký. Vui lòng hoàn thành màn thứ 3 và bấm Gửi đăng ký.',
  );
  require(
    1,
    'registration_complete',
    'Thông tin cá nhân và hồ sơ chưa hoàn tất. Vui lòng kiểm tra và bổ sung hồ sơ.',
  );
  if (identity == null) {
    require(1, 'identity_complete', 'Chưa lưu đủ số CCCD và ảnh định danh.');
  } else {
    if (!RegExp(r'^\d{12}$')
        .hasMatch((identity['documentNumber'] ?? '').toString())) {
      missing[1]!.add('Chưa lưu số CCCD hợp lệ.');
    }
    final sides = savedIdentitySides(identity);
    const labels = {
      'FRONT': 'CCCD mặt trước',
      'BACK': 'CCCD mặt sau',
      'SELFIE': 'ảnh chân dung',
    };
    final absent = labels.entries
        .where((entry) => !sides.contains(entry.key))
        .map((entry) => entry.value)
        .toList();
    if (absent.isNotEmpty) {
      missing[1]!.add(
        'Đã lưu ${sides.length}/3 ảnh. Cần bổ sung: ${absent.join(', ')}.',
      );
    }
    if (application['eligibility']?['identity_complete'] != true &&
        missing[1]!.isEmpty) {
      missing[1]!.add(
        'Thông tin định danh chưa hợp lệ. Vui lòng kiểm tra hồ sơ.',
      );
    }
  }
  if ((application['fullName'] ?? '').toString().trim().isEmpty) {
    missing[1]!.add('Thiếu họ và tên.');
  }
  if ((application['contactPhone'] ?? '').toString().trim().isEmpty) {
    missing[1]!.add('Thiếu số điện thoại.');
  }
  if ((application['areaIds'] as List? ?? []).isEmpty) {
    missing[1]!.add('Chưa chọn khu vực làm việc.');
  }
  if ((application['serviceIds'] as List? ?? []).isEmpty) {
    missing[1]!.add('Chưa chọn dịch vụ đăng ký.');
  }
  for (final change in application['requiredChanges'] as List? ?? []) {
    if (change.toString().trim().isNotEmpty) missing[1]!.add(change.toString());
  }
  require(2, 'agreements_current', 'Chưa ký đủ cam kết đang có hiệu lực.');
  require(4, 'exam_passed', 'Chưa có kết quả bài thi đạt yêu cầu.');
  require(5, 'preliminary_approved', 'Hồ sơ chưa được phê duyệt sơ bộ.');
  require(
    6,
    'office_visit_confirmed',
    'Chưa xem địa chỉ và xác nhận sẽ đến văn phòng.',
  );

  require(7, 'uniform_ordered', 'Chưa xác nhận đặt đồng phục.');
  require(8, 'final_approved', application['status'] == 'APPROVED'
      ? 'Cần bổ sung ảnh chân dung và ảnh hợp đồng đã ký.'
      : 'Chờ admin kiểm duyệt và phê duyệt chính thức.');



  if (application['status'] != 'ACTIVE' && application['status'] != 'APPROVED') {
    missing[8]!.add('Đang chờ admin kích hoạt tài khoản.');
  }
  return missing;
}

const onboardingStageSteps = <List<int>>[
  [4],
  [1, 2],
  [5, 7, 6],
  [8],
];
bool canOpenOnboardingStage(int stage, Map<int, List<String>> missing) {
  if (stage < 1 || stage > 4) return false;
  return onboardingStageSteps
      .take(stage - 1)
      .expand((steps) => steps)
      .every((step) => missing[step]?.isEmpty == true);
}

int firstIncompleteOnboardingStage(Map<int, List<String>> missing) {
  for (var index = 0; index < onboardingStageSteps.length; index++) {
    if (onboardingStageSteps[index].any(
      (step) => missing[step]?.isEmpty != true,
    )) {
      return index + 1;
    }
  }
  return 4;
}

import 'package:flutter_test/flutter_test.dart';

import '../lib/features/partner/onboarding_completion.dart';

void main() {
  test('identity warnings count saved clean sides and name missing photos', () {
    final identity = <String, dynamic>{
      'documentNumber': '001095012345',
      'documents': [
        {'side': 'FRONT', 'scanStatus': 'CLEAN'},
        {'side': 'FRONT', 'scanStatus': 'CLEAN'},
        {'side': 'BACK', 'scanStatus': 'CLEAN'},
        {'side': 'SELFIE', 'scanStatus': 'PENDING'},
      ],
    };
    expect(savedIdentitySides(identity), {'FRONT', 'BACK'});
    final missing = onboardingMissing({
      'fullName': 'Partner',
      'contactPhone': '0909876902',
      'areaIds': ['area'],
      'serviceIds': ['service'],
      'eligibility': {
        'registration_complete': true,
        'registration_submitted': true,
        'identity_complete': false,
      },
    }, identity: identity);
    expect(missing[1], ['Đã lưu 2/3 ảnh. Cần bổ sung: ảnh chân dung.']);
  });
  test('stages unlock only when all preceding stages are green', () {
    final missing = {
      for (var step = 1; step <= 8; step++) step: <String>['Required'],
    };
    expect(canOpenOnboardingStage(1, missing), isTrue);
    expect(canOpenOnboardingStage(2, missing), isFalse);
    missing[4] = [];
    expect(canOpenOnboardingStage(2, missing), isTrue);
    missing[1] = [];
    expect(canOpenOnboardingStage(3, missing), isFalse);
    missing[2] = [];
    expect(canOpenOnboardingStage(3, missing), isTrue);
    expect(canOpenOnboardingStage(4, missing), isFalse);
    missing[5] = [];
    missing[6] = [];
    missing[7] = [];
    expect(canOpenOnboardingStage(4, missing), isTrue);
    missing[2] = ['Updated agreement'];
    expect(canOpenOnboardingStage(4, missing), isFalse);
    expect(firstIncompleteOnboardingStage(missing), 2);
  });

  test('advanced status does not complete missing requirements', () {
    final missing = onboardingMissing({'status': 'ACTIVE'});
    expect(
      missing.entries
          .where((entry) => entry.key != 3)
          .every((entry) => entry.value.isNotEmpty),
      isTrue,
    );
  });
  test('completion requires persisted evidence for each step', () {
    final app = <String, dynamic>{
      'status': 'ACTIVE',
      'fullName': 'Partner',
      'contactPhone': '0901234567',
      'areaIds': ['area'],
      'serviceIds': ['service'],
      'documentsReceivedAt': '2026-10-10',
      'eligibility': {
        for (final key in [
          'registration_complete',
          'registration_submitted',
          'identity_complete',
          'agreements_current',
          'training_complete',
          'exam_passed',
          'preliminary_approved',
          'appointment_checked_in',
          'uniform_resolved',
          'final_approved',
          'skills_configured',
          'areas_configured',
          'availability_configured',
        ])
          key: true,
      },
    };
    expect(
      onboardingMissing(app).values.every((items) => items.isEmpty),
      isTrue,
    );
    (app['eligibility'] as Map)['registration_submitted'] = false;
    expect(
      onboardingMissing(app)[1],
      contains(
        'Chưa hoàn tất đăng ký. Vui lòng hoàn thành màn thứ 3 và bấm Gửi đăng ký.',
      ),
    );
    (app['eligibility'] as Map)['registration_submitted'] = true;
    (app['eligibility'] as Map)['agreements_current'] = false;
    app['requiredChanges'] = ['Replace unclear image'];
    final missing = onboardingMissing(app);
    expect(missing[1], contains('Replace unclear image'));
    expect(missing[2], isNotEmpty);
    expect(missing[3], isEmpty);
  });
}

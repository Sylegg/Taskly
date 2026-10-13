import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_shell.dart';

void main() {
  for (final scenario in [(320.0, 0), (375.0, 0), (430.0, 0), (375.0, 1)]) {
    final (width, failAt) = scenario;
    testWidgets(
      'new authenticated applicant at $width saves each step before advancing; failure=$failAt',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final seen = <String>[];
        var draftWrites = 0;
        final session =
            Session(
                api: Api(
                  base: 'http://test/api/v1',
                  client: MockClient((request) async {
                    seen.add(request.url.path);
                    if (request.method == 'PUT') {
                      final body = jsonDecode(request.body);
                      expect(body['version'], draftWrites);
                      expect(body['fullName'], 'Ứng viên thử nghiệm');
                      expect(body['contactPhone'], '0901234567');
                      expect(body['dateOfBirth'], '1995-01-01');
                      expect(body['areaIds'], isEmpty);
                      draftWrites++;
                      if (failAt == draftWrites) {
                        return http.Response(
                          jsonEncode({
                            'success': false,
                            'error': {
                              'code': 'DRAFT_FAILED',
                              'message': 'Không lưu được bản nháp',
                            },
                          }),
                          400,
                          headers: {'content-type': 'application/json'},
                        );
                      }
                    }
                    expect(
                      request.headers['Authorization'],
                      'Bearer test-token',
                    );
                    final Object data = switch (request.url.path) {
                      '/api/v1/partner/onboarding' => {
                        'id': 'fictional',
                        'status': 'REGISTERED',
                        'fullName': 'Ứng viên thử nghiệm',
                        'contactPhone': '0901234567',
                        'dateOfBirth': '1995-01-01',
                        'email': 'fictional@test.example',
                        'areaIds': [],
                        'serviceIds': [],
                        'version': request.method == 'PUT' ? draftWrites : 0,
                      },
                      '/api/v1/partner/recruitment-areas' => [],
                      '/api/v1/partner/notifications' => [],
                      '/api/v1/public/services' => {'services': []},
                      _ => throw StateError('Unexpected ${request.url.path}'),
                    };
                    return http.Response(
                      jsonEncode({'success': true, 'data': data}),
                      200,
                      headers: {'content-type': 'application/json'},
                    );
                  }),
                ),
              )
              ..access = 'test-token'
              ..expires = DateTime.now().add(const Duration(hours: 1));
        await tester.pumpWidget(
          MaterialApp(home: RecruitmentShell(session: session)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        expect(find.text('Nhận việc'), findsNothing);
        expect(find.text('Đăng ký trở thành Tasker'), findsOneWidget);
        expect(seen, contains('/api/v1/partner/onboarding'));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Hoàn thiện đăng ký'));
        await tester.tap(find.text('Hoàn thiện đăng ký'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tiếp tục'));
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(draftWrites, 1);
        if (failAt == 1) {
          expect(
            find.textContaining('Không lưu được bản nháp'),
            findsOneWidget,
          );
          expect(find.text('Họ và tên'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
          session.dispose();
          return;
        }
        await tester.ensureVisible(find.text('Tiếp tục'));
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
        expect(draftWrites, 1);
        expect(
          find.text('Vui lòng tick chọn ít nhất 1 khu vực làm việc.'),
          findsOneWidget,
        );
        expect(find.text('Gửi đăng ký'), findsNothing);
        expect(seen.where((path) => path.endsWith('/submit')), isEmpty);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
        session.dispose();
      },
    );
  }

  testWidgets(
    'tapping a partner journey step opens rich step detail bottom sheet with full info',
    (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  final Object data = switch (request.url.path) {
                    '/api/v1/partner/onboarding' => {
                      'id': 'fictional',
                      'status': 'REGISTERED',
                      'fullName': 'Nguyễn Văn Test',
                      'contactPhone': '0901234567',
                      'dateOfBirth': '1995-01-01',
                      'identityCardNumber': '012345678901',
                      'email': 'test@example.com',
                      'areaIds': [],
                      'serviceIds': [],
                      'eligibility': {'exam_passed': true},
                      'version': 0,
                    },
                    '/api/v1/partner/recruitment-areas' => [],
                    '/api/v1/partner/notifications' => [],
                    '/api/v1/public/services' => {'services': []},
                    _ => throw StateError('Unexpected ${request.url.path}'),
                  };
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                    headers: {'content-type': 'application/json'},
                  );
                }),
              ),
            )
            ..access = 'test-token'
            ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(home: RecruitmentShell(session: session)),
      );
      await tester.pumpAndSettle();

      // Drag ListView to bring timeline onto screen
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Tap on Chặng 2 pill to show its content
      await tester.tap(find.text('Chặng 2'));
      await tester.pumpAndSettle();

      final step1Finder = find.text('Bước 1: Thông tin cá nhân & Hồ sơ');
      await tester.ensureVisible(step1Finder);
      expect(step1Finder, findsOneWidget);

      // Tap on step 1 to view details
      await tester.tap(step1Finder);
      await tester.pumpAndSettle();

      // Expect bottom sheet with full details to show
      expect(find.text('Đầu việc & Tiêu chuẩn cần hoàn thành'), findsOneWidget);
      expect(find.text('Thông tin hồ sơ liên quan của bạn'), findsOneWidget);
      expect(find.text('Nguyễn Văn Test'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      expect(find.text('012345678901'), findsOneWidget);
      expect(find.text('Đóng'), findsOneWidget);

      // Tap 'Đóng' to dismiss
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Đầu việc & Tiêu chuẩn cần hoàn thành'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      session.dispose();
    },
  );

  testWidgets(
    'shows 24-hour review notice banner when agreements are done',
    (tester) async {
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  final Object data = switch (request.url.path) {
                    '/api/v1/partner/onboarding' => {
                      'id': 'fictional',
                      'status': 'REGISTERED',
                      'fullName': 'Minh vu',
                      'contactPhone': '0901234567',
                      'dateOfBirth': '1995-01-01',
                      'identityCardNumber': '012345678901',
                      'email': 'minhvu@example.com',
                      'areaIds': ['area-1'],
                      'serviceIds': ['srv-1'],
                      'eligibility': {
                        'exam_passed': true,
                        'registration_submitted': true,
                        'registration_complete': true,
                        'identity_complete': true,
                        'agreements_current': true,
                      },
                      'version': 1,
                    },
                    '/api/v1/partner/recruitment-areas' => [],
                    '/api/v1/partner/notifications' => [],
                    '/api/v1/public/services' => {'services': []},
                    _ => throw StateError('Unexpected ${request.url.path}'),
                  };
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                    headers: {'content-type': 'application/json'},
                  );
                }),
              ),
            )
            ..access = 'test-token'
            ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(home: RecruitmentShell(session: session)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Trong khoảng 24 giờ, đơn hồ sơ của bạn sẽ được quản lý xét duyệt'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Thông báo xét duyệt hồ sơ'), findsOneWidget);
      expect(find.text('Xem lại cam kết'), findsOneWidget);

      // Drag to bring timeline into view
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Verify that before approval: only Chặng 1 and Chặng 2 are rendered, not 3 and 4
      expect(find.text('Chặng 1'), findsOneWidget);
      expect(find.text('Chặng 2'), findsOneWidget);
      expect(find.text('Chặng 3'), findsNothing);
      expect(find.text('Chặng 4'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      session.dispose();
    },
  );

  testWidgets(
    'shows only Chặng 3 and Chặng 4 replacing 1 and 2 after admin preliminary approval',
    (tester) async {
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  final Object data = switch (request.url.path) {
                    '/api/v1/partner/onboarding' => {
                      'id': 'fictional',
                      'status': 'PRELIMINARY_APPROVED',
                      'fullName': 'Minh vu',
                      'contactPhone': '0901234567',
                      'dateOfBirth': '1995-01-01',
                      'identityCardNumber': '012345678901',
                      'email': 'minhvu@example.com',
                      'areaIds': ['area-1'],
                      'serviceIds': ['srv-1'],
                      'eligibility': {
                        'exam_passed': true,
                        'registration_submitted': true,
                        'registration_complete': true,
                        'identity_complete': true,
                        'agreements_current': true,
                        'preliminary_approved': true,
                      },
                      'version': 2,
                    },
                    '/api/v1/partner/recruitment-areas' => [],
                    '/api/v1/partner/notifications' => [],
                    '/api/v1/public/services' => {'services': []},
                    _ => throw StateError('Unexpected ${request.url.path}'),
                  };
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                    headers: {'content-type': 'application/json'},
                  );
                }),
              ),
            )
            ..access = 'test-token'
            ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(home: RecruitmentShell(session: session)),
      );
      await tester.pumpAndSettle();

      // Dismiss decision dialog if presented
      if (find.text('Đã hiểu').evaluate().isNotEmpty) {
        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
      }

      // Drag to bring timeline into view
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();

      // Verify only Chặng 3 and Chặng 4 are visible in the 2 boxes, replacing Chặng 1 & 2
      expect(find.text('Chặng 3'), findsOneWidget);
      expect(find.text('Chặng 4'), findsOneWidget);
      expect(find.text('Chặng 1'), findsNothing);
      expect(find.text('Chặng 2'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      session.dispose();
    },
  );

  testWidgets(
    'tapping notifications bell displays notices and clears unread badge',
    (tester) async {
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  final Object data = switch (request.url.path) {
                    '/api/v1/partner/onboarding' => {
                      'id': 'fictional',
                      'status': 'PRELIMINARY_REVIEW',
                      'fullName': 'Minh vu',
                      'contactPhone': '0901234567',
                      'dateOfBirth': '1995-01-01',
                      'identityCardNumber': '012345678901',
                      'email': 'minhvu@example.com',
                      'areaIds': ['area-1'],
                      'serviceIds': ['srv-1'],
                      'eligibility': {
                        'exam_passed': true,
                        'registration_submitted': true,
                        'registration_complete': true,
                        'identity_complete': true,
                        'agreements_current': true,
                      },
                      'version': 1,
                    },
                    '/api/v1/partner/recruitment-areas' => [],
                    '/api/v1/partner/notifications' => [
                      {
                        'id': 'notice-1',
                        'channel': 'IN_APP',
                        'title': 'Hồ sơ đã được gửi',
                        'message': 'Đơn của bạn đang được xét duyệt.',
                        'created_at': '2026-10-11T20:00:00Z',
                      }
                    ],
                    '/api/v1/public/services' => {'services': []},
                    _ => throw StateError('Unexpected ${request.url.path}'),
                  };
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                    headers: {'content-type': 'application/json'},
                  );
                }),
              ),
            )
            ..access = 'test-token'
            ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(home: RecruitmentShell(session: session)),
      );
      await tester.pumpAndSettle();

      // Dismiss dialog if any
      if (find.text('Đã hiểu').evaluate().isNotEmpty) {
        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
      }

      // Bell badge shows '1' unread notice
      expect(find.text('1'), findsWidgets);

      // Tap the bell button to open notifications modal
      await tester.tap(find.byTooltip('Thông báo'));
      await tester.pumpAndSettle();

      // Notifications modal shows the title
      expect(find.text('Hồ sơ đã được gửi'), findsOneWidget);

      // Dismiss modal by tapping outside or close icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Badge count '1' is now cleared
      final badge = tester.widget<Badge>(find.byType(Badge).first);
      expect(badge.isLabelVisible, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
      session.dispose();
    },
  );
}


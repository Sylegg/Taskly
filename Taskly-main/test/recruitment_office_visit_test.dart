import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_office_visit.dart';

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('RecruitmentOfficeVisit at width $width renders fallback hub card when offices is empty and confirms visit', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requests = <String>[];
      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/v1/partner/offices' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/onboarding' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'eligibility': {
                      'office_visit_confirmed': false,
                    },
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/office-visit-confirmation' && request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'status': 'CONFIRMED'},
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          }),
        ),
      );
      session.access = 'test-token';
      session.expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentOfficeVisit(session: session),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and cards
      expect(find.text('Địa chỉ văn phòng & Tiếp nhận'), findsOneWidget);
      expect(find.text('Văn phòng Tiếp nhận Đối tác'), findsOneWidget);
      expect(find.text('Hành trang cần chuẩn bị mang theo'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Văn phòng TaskLy Partner Hub Trung Tâm'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Văn phòng TaskLy Partner Hub Trung Tâm'), findsOneWidget);

      // Check checkbox
      final checkboxFinder = find.byType(Checkbox);
      await tester.scrollUntilVisible(
        checkboxFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(checkboxFinder, findsOneWidget);
      expect((tester.widget(checkboxFinder) as Checkbox).value, isFalse);

      // Tap checkbox to check it
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      expect((tester.widget(checkboxFinder) as Checkbox).value, isTrue);

      // Submit confirmation
      final submitButton = find.widgetWithText(ElevatedButton, 'Xác nhận sẽ đến văn phòng');
      await tester.scrollUntilVisible(
        submitButton,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verified confirmed state
      expect(find.textContaining('Bạn đã xác nhận sẽ đến văn phòng'), findsOneWidget);
      expect(requests.contains('POST /api/v1/partner/office-visit-confirmation'), isTrue);
    });

    testWidgets('RecruitmentOfficeVisit at width $width renders dynamic offices when non-empty', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            if (request.url.path == '/api/v1/partner/offices' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'name': 'Chi nhánh TaskLy Quận 1',
                      'address': 'Số 45 Lê Duẩn, Bến Nghé, Quận 1, TP. Hồ Chí Minh',
                    },
                    {
                      'name': 'Chi nhánh TaskLy Cầu Giấy',
                      'address': 'Số 99 Duy Tân, Cầu Giấy, Hà Nội',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/onboarding' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'eligibility': {
                      'office_visit_confirmed': true,
                    },
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response('Not Found', 404);
          }),
        ),
      );
      session.access = 'test-token';
      session.expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentOfficeVisit(session: session),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Chi nhánh TaskLy Quận 1'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Chi nhánh TaskLy Quận 1'), findsOneWidget);
      expect(find.text('Chi nhánh TaskLy Cầu Giấy'), findsOneWidget);
      expect(find.text('2 địa điểm'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.textContaining('Bạn đã xác nhận sẽ đến văn phòng'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Bạn đã xác nhận sẽ đến văn phòng'), findsOneWidget);
    });
  }
}

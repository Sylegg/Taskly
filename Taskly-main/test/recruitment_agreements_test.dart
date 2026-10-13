import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_agreements.dart';

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets(
      'RecruitmentAgreements at width $width provides single reading, scroll down, tick once, and confirm',
      (tester) async {
        final requestedUrls = <String>[];
        final session = Session(
          api: Api(
            base: 'http://test/api/v1',
            client: MockClient((request) async {
              requestedUrls.add('${request.method} ${request.url.path}');
              if (request.url.path == '/api/v1/partner/agreements' &&
                  request.method == 'GET') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': [
                      {
                        'id': 'agr_code_of_conduct',
                        'documentType': 'Quy tắc ứng xử và tiêu chuẩn dịch vụ',
                        'version': 'v2.0',
                        'contentUrl': 'https://taskly.vn/terms/conduct',
                        'accepted': false,
                      },
                      {
                        'id': 'agr_safety_asset',
                        'documentType':
                            'Chính sách an toàn & bảo vệ tài sản khách hàng',
                        'version': 'v1.8',
                        'contentUrl': 'https://taskly.vn/terms/safety',
                        'accepted': false,
                      },
                    ],
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }

              if (request.url.path == '/api/v1/partner/agreements/accept-all' &&
                  request.method == 'POST') {
                return http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {'status': 'PROFILE_INCOMPLETE'},
                  }),
                  200,
                  headers: {'content-type': 'application/json'},
                );
              }

              return http.Response(
                jsonEncode({'success': true, 'data': {}}),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        );
        session.access = 'test-token';
        session.expires = DateTime.now().add(const Duration(hours: 1));

        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: RecruitmentAgreements(session: session),
          ),
        );
        await tester.pumpAndSettle();

        // Verify header and document structure
        expect(find.text('Cam kết đối tác TaskLy'), findsOneWidget);
        expect(
          find.text('BẢN CAM KẾT VÀ QUY CHẾ HOẠT ĐỘNG ĐỐI TÁC'),
          findsOneWidget,
        );
        expect(
          find.text('Quy tắc ứng xử và tiêu chuẩn dịch vụ (v2.0)'),
          findsOneWidget,
        );

        // Scroll to bottom so the confirmation box is fully visible
        await tester.scrollUntilVisible(
          find.text('Xác nhận và Ký cam kết'),
          300,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();

        // Verify there is only exactly 1 Checkbox at the bottom (tick 1 lần duy nhất)
        expect(find.byType(Checkbox), findsOneWidget);

        // Verify the single checkbox text
        expect(
          find.text(
            'Tôi đã đọc kỹ, hiểu rõ và đồng ý với tất cả 05 cam kết tiêu chuẩn đối tác nêu trên.',
          ),
          findsOneWidget,
        );

        // Check the single checkbox
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Verify button is enabled and tap to confirm
        await tester.tap(find.text('Xác nhận và Ký cam kết'));
        await tester.pumpAndSettle();

        // Verify batch accept was requested
        expect(
          requestedUrls.contains('POST /api/v1/partner/agreements/accept-all') ||
              requestedUrls.contains(
                'POST /api/v1/partner/agreements/agr_code_of_conduct/accept',
              ),
          isTrue,
        );
      },
    );
  }

  testWidgets('RecruitmentAgreements displays already accepted state',
      (tester) async {
    final session = Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/partner/agreements') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'agr_code_of_conduct',
                    'documentType': 'Quy tắc ứng xử và tiêu chuẩn dịch vụ',
                    'version': 'v2.0',
                    'contentUrl': 'https://taskly.vn/terms/conduct',
                    'accepted': true,
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'data': {}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    session.access = 'test-token';
    session.expires = DateTime.now().add(const Duration(hours: 1));

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentAgreements(session: session),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cam kết đối tác đã có hiệu lực'), findsOneWidget);
    expect(find.text('Đã ký kết'), findsOneWidget);
  });
}

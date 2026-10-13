import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_uniform.dart';

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('RecruitmentUniform at width $width renders packages, sizes, and orders', (tester) async {
      final requests = <String>[];
      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/v1/partner/uniforms' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'id': 'uniform_standard',
                      'name': 'Gói đồng phục TaskLy Tiêu chuẩn',
                      'price': '0',
                      'description': 'Bao gồm 02 áo polo, 01 nón bảo hiểm, 01 túi đồ nghề.',
                      'policy': 'Cấp phát tại văn phòng.',
                      'sizes': {'M': 50, 'L': 50, 'XL': 35},
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/uniform-orders' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'id': 'ord-1234',
                      'size': 'L',
                      'price': '0',
                      'payment_status': 'PAID',
                      'status': 'RESERVED',
                      'payment_method': 'AT_OFFICE',
                    },
                  ],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/uniform-orders' && request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'id': 'ord-new', 'status': 'RESERVED'},
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

      await tester.pumpWidget(MaterialApp(home: RecruitmentUniform(session: session)));
      await tester.pumpAndSettle();

      // Check header and packages
      expect(find.text('Đồng phục & Trang bị'), findsOneWidget);
      expect(find.text('Đồng phục chính hãng TaskLy'), findsOneWidget);
      expect(find.text('Gói đồng phục TaskLy Tiêu chuẩn • 0 đ'), findsOneWidget);

      // Scroll to size L chip
      await tester.scrollUntilVisible(
        find.text('L'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Check size chips
      expect(find.text('L'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('XL'), findsOneWidget);

      // Select size L
      await tester.tap(find.text('L'));
      await tester.pumpAndSettle();

      // Scroll to submit button if needed
      await tester.scrollUntilVisible(
        find.text('Xác nhận đặt đồng phục'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap order
      await tester.tap(find.text('Xác nhận đặt đồng phục'));
      await tester.pumpAndSettle();

      expect(requests.contains('POST /api/v1/partner/uniform-orders'), isTrue);
    });
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/customer_view.dart';

void main() {
  testWidgets(
    'top up validates amount and retries using the same request without claiming funds are credited',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <Map<String, dynamic>>[];
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            if (request.method == 'POST') {
              requests.add(jsonDecode(request.body) as Map<String, dynamic>);
              if (requests.length == 1) {
                return http.Response(
                  jsonEncode({
                    'success': false,
                    'error': {'code': 'NETWORK', 'message': 'Mất kết nối'},
                  }),
                  503,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'status': 'PENDING'},
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'balance': 25000,
                  'requestId': '12345678-1234-1234-1234-123456789012',
                  'config': {
                    'minDeposit': 50000,
                    'maxDeposit': 50000000,
                    'bankName': 'Bank',
                    'bankAccount': '123456789',
                    'accountOwner': 'Taskly',
                    'qrPrefix': 'TASKLY NAP',
                  },
                  'transactions': [
                    {
                      'amount': 100000,
                      'status': 'COMPLETED',
                      'created_at': '2026-10-13',
                      'reference_code': 'OLD',
                    },
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'test';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CustomerTopUpDialog(session: session)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Số dư: 25000 đ'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '100');
      final submit = find.widgetWithText(FilledButton, 'Tôi đã chuyển khoản');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(
        find.text('Nhập số tiền từ 50000 đến 50000000 đ.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '100000');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      expect(find.text('Mất kết nối'), findsOneWidget);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      expect(requests[1]['amount'], 100000);
      expect(
        find.text('Đã gửi yêu cầu nạp tiền, đang chờ xác nhận.'),
        findsOneWidget,
      );
      expect(find.text('Số dư: 25000 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

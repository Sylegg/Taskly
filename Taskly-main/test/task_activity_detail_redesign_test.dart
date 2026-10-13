import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_activity.dart';

void main() {
  testWidgets(
    'TaskActivityDetail formats dates accurately and displays modern card layout',
    (tester) async {
      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            final data = {
              'task': {
                'id': '604efaa7-1111-2222-3333-444455556666',
                'serviceName': 'Kiểm tra sự cố máy lạnh, Tổng vệ sinh nhà ở',
                'status': 'POSTED',
                'address': '123 Nguyen Trai',
                'scheduledAt': '2026-10-13T08:30:00Z',
                'taskerId': null,
                'taskerName': null,
                'budgetAmount': 350000,
                'platformFee': 35000,
                'partnerNetAmount': 315000,
              },
              'events': [
                {
                  'status': 'POSTED',
                  'at': '2026-10-13T01:34:06.494995Z',
                  'reason': 'Đã xác nhận giá; đã thanh toán ngân hàng giả lập',
                },
              ],
              'messages': [],
              'payment': {
                'method': 'MOCK_BANK',
                'status': 'PAID',
                'amount': 350000,
                'cancel_after': DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
                'match_deadline': DateTime.now().toUtc().add(const Duration(hours: 1)).toIso8601String(),
              },
            };
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      )
        ..access = 'test-token'
        ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: TaskActivityDetail(
            session: session,
            id: '604efaa7-1111-2222-3333-444455556666',
            partner: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Title and Header Card
      expect(find.text('Hoạt động công việc'), findsOneWidget);
      expect(find.text('#604EFAA7'), findsOneWidget);
      expect(find.text('Kiểm tra sự cố máy lạnh, Tổng vệ sinh nhà ở'), findsOneWidget);
      expect(find.text('Đã đặt dịch vụ'), findsWidgets);
      expect(find.text('350.000 đ'), findsWidgets);

      // 2. Address & Clean Scheduled Time
      expect(find.text('Địa chỉ thực hiện'), findsOneWidget);
      expect(find.text('123 Nguyen Trai'), findsOneWidget);
      expect(find.text('Thời gian hẹn làm việc'), findsOneWidget);

      // 3. Payment & Formatted Vietnamese cancellation terms (NO raw ms/us timestamps!)
      expect(find.text('Chuyển khoản / Ngân hàng'), findsOneWidget);
      expect(find.text('Đã thanh toán ngân hàng giả lập.'), findsOneWidget);
      expect(find.textContaining('.484'), findsNothing); // Raw ms eliminated!
      expect(find.textContaining('Thời gian khóa hủy đơn'), findsOneWidget);
      expect(find.textContaining('Có thể hủy từ'), findsOneWidget);

      // 4. Stepper & Formatted timeline event
      expect(find.text('Tiến trình công việc'), findsOneWidget);
      expect(find.text('Đã xác nhận giá; đã thanh toán ngân hàng giả lập'), findsOneWidget);

      // 5. Friendly Tasker search empty state
      expect(find.text('Hệ thống đang kết nối Tasker'), findsOneWidget);
      expect(find.text('Chat sẽ xuất hiện khi công việc đã có Tasker.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'TaskActivityDetail handles cancellation flow when unlocked',
    (tester) async {
      var cancelRequested = false;
      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/cancel')) {
              cancelRequested = true;
              return http.Response(
                jsonEncode({'success': true, 'data': {}}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            final data = {
              'task': {
                'id': '604efaa7-1111-2222-3333-444455556666',
                'serviceName': 'Tổng vệ sinh nhà ở',
                'status': 'POSTED',
                'address': '456 Le Loi',
                'taskerId': null,
                'taskerName': null,
                'budgetAmount': 200000,
              },
              'events': [],
              'messages': [],
              'payment': {
                'method': 'MOCK_BANK',
                'status': 'PAID',
                'amount': 200000,
                // cancel_after is in the past -> cancellation is unlocked!
                'cancel_after': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
                'match_deadline': DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
              },
            };
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      )
        ..access = 'test-token'
        ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: TaskActivityDetail(
            session: session,
            id: '604efaa7-1111-2222-3333-444455556666',
            partner: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Button is enabled and says "Hủy đơn và hoàn tiền đã thanh toán"
      expect(find.text('Hủy đơn và hoàn tiền đã thanh toán'), findsOneWidget);
      await tester.ensureVisible(find.text('Hủy đơn và hoàn tiền đã thanh toán'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy đơn và hoàn tiền đã thanh toán'));
      await tester.pumpAndSettle();

      // Confirmation dialog pops up
      expect(find.text('Xác nhận hủy đơn?'), findsOneWidget);
      expect(find.text('Xác nhận hủy'), findsOneWidget);

      await tester.tap(find.text('Xác nhận hủy'));
      await tester.pumpAndSettle();
      expect(cancelRequested, isTrue);

      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );

  testWidgets(
    'TaskBookingServicesCard renders modern multi-service layout with tap-to-scroll navigation',
    (tester) async {
      final booking = {
        'duration': 3,
        'subtotal': 312000,
        'platformFee': 0,
        'total': 312000,
        'notes': 'Gọi trước khi đến 15 phút',
        'services': [
          {
            'serviceName': 'Kiểm tra sự cố máy lạnh',
            'mode': 'UNIT',
            'quantity': 1,
            'quantityLabel': 'Số lượng',
            'subtotal': 200000,
            'total': 200000,
            'fields': [
              {'label': 'Hạng mục hoặc thiết bị', 'value': 1},
              {'label': 'Mức độ khẩn cấp', 'value': 'Bình thường'},
              {'label': 'Số máy lạnh', 'value': 1},
            ],
            'description': 'Tổng vệ sinh nhà ở: 2',
          },
          {
            'serviceName': 'Tổng vệ sinh nhà ở',
            'mode': 'UNIT',
            'quantity': 1,
            'quantityLabel': 'Diện tích',
            'subtotal': 112000,
            'total': 112000,
            'fields': [
              {'label': 'Diện tích (m²)', 'value': 1},
              {'label': 'Vệ sinh cửa kính', 'value': 21},
              {'label': 'giờ', 'value': 1},
            ],
            'description': '',
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaskBookingServicesCard(booking: booking),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('Chi tiết dịch vụ'), findsOneWidget);
      expect(find.text('2 dịch vụ'), findsOneWidget);
      expect(find.text('3 giờ'), findsOneWidget);

      // Quick-nav chips checks (Bấm sẽ scroll)
      expect(find.text('Chạm dịch vụ để cuộn nhanh đến:'), findsOneWidget);
      expect(find.text('Kiểm tra sự cố máy lạnh'), findsWidgets);
      expect(find.text('Tổng vệ sinh nhà ở'), findsWidgets);

      // Service 1 specifications
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Hạng mục hoặc thiết bị'), findsOneWidget);
      expect(find.text('Mức độ khẩn cấp'), findsOneWidget);
      expect(find.text('Bình thường'), findsOneWidget);
      expect(find.text('200.000 đ'), findsWidgets);
      expect(find.textContaining('Tổng vệ sinh nhà ở: 2'), findsOneWidget);

      // Service 2 specifications
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Vệ sinh cửa kính'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);
      expect(find.text('112.000 đ'), findsWidgets);

      // Total bill summary
      expect(find.text('Tổng giá dịch vụ'), findsOneWidget);
      expect(find.text('Tổng thanh toán'), findsOneWidget);
      expect(find.text('312.000 đ'), findsWidgets);
      expect(find.textContaining('Gọi trước khi đến 15 phút'), findsOneWidget);

      // Tap on service 2 chip to scroll
      final chip2 = find.text('2').first;
      await tester.tap(chip2);
      await tester.pumpAndSettle();

      // Tap next service button
      expect(find.text('Dịch vụ tiếp theo'), findsOneWidget);
      await tester.tap(find.text('Dịch vụ tiếp theo'));
      await tester.pumpAndSettle();

      // Let highlight timer elapse
      await tester.pump(const Duration(seconds: 2));
    },
  );
}



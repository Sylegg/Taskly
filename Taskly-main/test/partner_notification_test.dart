import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_notifications.dart';

void main() {
  testWidgets('PartnerNotificationView renders notifications, filters, and marks read',
      (tester) async {
    final notificationsList = [
      {
        'id': 'notif-1',
        'channel': 'IN_APP',
        'status': 'DELIVERED',
        'title': 'Nhận việc: Dọn dẹp nhà #TASK101',
        'message': 'Bạn đã được phân công thực hiện công việc Dọn dẹp nhà.',
        'created_at': DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'read_at': null,
        'task_id': 'task-101',
      },
      {
        'id': 'notif-2',
        'channel': 'IN_APP',
        'status': 'DELIVERED',
        'title': 'Chào mừng bạn đến với TaskLy Partner!',
        'message': 'Chúc mừng bạn đã gia nhập mạng lưới đối tác TaskLy.',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'read_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'task_id': null,
      },
    ];

    bool readAllCalled = false;

    final session = Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/partner/notifications') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': notificationsList,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/partner/notifications/read-all') {
            readAllCalled = true;
            for (final n in notificationsList) {
              n['read_at'] = DateTime.now().toIso8601String();
            }
            return http.Response(
              jsonEncode({'success': true, 'data': {'updated': true}}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{"success":false}', 404);
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartnerNotificationView(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Notifications
    expect(find.text('Thông báo'), findsWidgets);
    expect(find.text('Nhận việc: Dọn dẹp nhà #TASK101'), findsOneWidget);
    expect(find.text('Chào mừng bạn đến với TaskLy Partner!'), findsOneWidget);

    // Filter tabs
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Chưa đọc (1)'), findsOneWidget);

    // Switch to 'Chưa đọc'
    await tester.tap(find.text('Chưa đọc (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Nhận việc: Dọn dẹp nhà #TASK101'), findsOneWidget);
    expect(find.text('Chào mừng bạn đến với TaskLy Partner!'), findsNothing);

    // Tap "Đã đọc tất cả"
    await tester.tap(find.byTooltip('Đã đọc tất cả'));
    await tester.pumpAndSettle();
    expect(readAllCalled, isTrue);

    // Switch back to 'Tất cả'
    await tester.tap(find.text('Tất cả (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng bạn đến với TaskLy Partner!'), findsOneWidget);
  });
}

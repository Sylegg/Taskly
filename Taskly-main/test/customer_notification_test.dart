import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/customer_notifications.dart';
import 'package:taskly_mobile/data/mock/mock_customer_repository.dart';

void main() {
  testWidgets('CustomerNotificationView renders and handles user interactions', (tester) async {
    final repo = MockCustomerRepository(latency: Duration.zero);
    final c = CustomerController(repo, demoControls: repo, demoMode: true);
    await c.refresh();

    // Seed test notifications
    repo.store.notifications = [
      AppNotification(
        'notif-1',
        'Đối tác đã nhận đơn',
        'task-101',
        DateTime.now().subtract(const Duration(minutes: 5)),
        read: false,
      ),
      AppNotification(
        'notif-2',
        'Chào mừng đến với TaskLy!',
        '',
        DateTime.now().subtract(const Duration(hours: 2)),
        read: true,
      ),
    ];
    await c.refresh();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomerNotificationView(controller: c),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and notifications
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Đối tác đã nhận đơn'), findsOneWidget);
    expect(find.text('Chào mừng đến với TaskLy!'), findsOneWidget);

    // Verify filter tabs: 'Tất cả (2)' and 'Chưa đọc (1)'
    expect(find.text('Tất cả (2)'), findsOneWidget);
    expect(find.text('Chưa đọc (1)'), findsOneWidget);

    // Filter to unread only
    await tester.tap(find.text('Chưa đọc (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Đối tác đã nhận đơn'), findsOneWidget);
    expect(find.text('Chào mừng đến với TaskLy!'), findsNothing);

    // Tap "Đã đọc tất cả"
    await tester.tap(find.byTooltip('Đã đọc tất cả'));
    await tester.pumpAndSettle();
    expect(c.data!.notifications.every((n) => n.read), isTrue);

    // Filter back to all
    await tester.tap(find.text('Tất cả (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Chào mừng đến với TaskLy!'), findsOneWidget);
  });
}

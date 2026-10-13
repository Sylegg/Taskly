import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/app/tasker_controller.dart';
import 'package:taskly_mobile/features/customer_view.dart';
import 'package:taskly_mobile/features/tasker_view.dart';
import 'package:taskly_mobile/main.dart';

void main() {
  testWidgets('Backend identity opens home and logout calls the real session', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      TaskLyApp(
        user: const {
          'id': 'backend-user',
          'fullName': 'Nguyen Test',
          'email': 'test@example.com',
          'phone': '0901234567',
        },
        onLogout: () async {
          loggedOut = true;
        },
      ),
    );
    await tester.pumpAndSettle();
    final view = tester.widget<CustomerView>(find.byType(CustomerView));
    expect(view.controller.route.page, PageId.home);
    expect(view.controller.data!.profile.email, 'test@example.com');
    expect(view.onOpenTasker, isNull);
    view.controller.root(PageId.profile);
    await tester.pumpAndSettle();
    expect(find.text('Nguyen Test'), findsWidgets);
    final logout = find.widgetWithText(OutlinedButton, 'Đăng xuất');
    await tester.scrollUntilVisible(
      logout,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(loggedOut, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Partner opens Tasker home with its own backend identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      TaskLyApp(
        isPartner: true,
        user: const {
          'fullName': 'Partner Test',
          'email': 'partner@example.com',
          'phone': '0901234567',
        },
        onLogout: () async {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CustomerView), findsNothing);
    final view = tester.widget<TaskerView>(find.byType(TaskerView));
    expect(view.controller.route.page, TaskerPage.home);
    expect(view.controller.data!.profile.profile.email, 'partner@example.com');
    expect(view.onSwitchCustomer, isNull);
    expect(view.onLogout, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

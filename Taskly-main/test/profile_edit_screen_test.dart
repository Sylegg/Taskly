import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/data/mock/mock_customer_repository.dart';
import 'package:taskly_mobile/main.dart';

void main() {
  testWidgets(
    'Thông tin của bạn: allows editing phone number and keeps email read-only',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MockCustomerRepository(latency: Duration.zero);
      repo.store.authenticated = true;
      final c = CustomerController(repo, demoControls: repo, demoMode: true);
      addTearDown(c.dispose);

      await tester.pumpWidget(TaskLyApp(controller: c));
      await tester.pumpAndSettle();

      // Open profile edit screen properly
      c.editProfile();
      await tester.pumpAndSettle();

      // Verify heading is displayed
      expect(find.text('Thông tin của bạn'), findsOneWidget);

      // Verify email field is read-only
      final emailFieldFinder = find.byWidgetPredicate(
        (w) => w is TextFormField && w.key == const ValueKey('Email (Gmail)'),
      );
      expect(emailFieldFinder, findsOneWidget);
      final emailTextField = tester.widget<TextField>(
        find.descendant(of: emailFieldFinder, matching: find.byType(TextField)),
      );
      expect(emailTextField.readOnly, isTrue);

      // Verify lock icon and helper text for Email
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(
        find.textContaining('Email dùng để đăng nhập và nhận OTP, không thể chỉnh sửa.'),
        findsOneWidget,
      );

      // Verify phone field is editable
      final phoneFieldFinder = find.byWidgetPredicate(
        (w) => w is TextFormField && w.key == const ValueKey('Số điện thoại'),
      );
      expect(phoneFieldFinder, findsOneWidget);
      final phoneTextField = tester.widget<TextField>(
        find.descendant(of: phoneFieldFinder, matching: find.byType(TextField)),
      );
      expect(phoneTextField.readOnly, isFalse);

      // Edit phone number
      await tester.enterText(phoneFieldFinder, '0988776655');
      await tester.pumpAndSettle();

      // Save profile
      await tester.tap(find.text('Lưu thông tin'));
      await tester.pumpAndSettle();

      // Check that updated phone is persisted in repository snapshot
      final snapshot = await repo.load();
      expect(snapshot.profile.phone, '0988776655');
    },
  );
}

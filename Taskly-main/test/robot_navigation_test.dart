import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/features/home/home_components.dart';

void main() {
  testWidgets('Customer menu exposes exactly four working destinations', (
    tester,
  ) async {
    int? destination;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: TaskLyBottomNav(
            selected: 0,
            onSelected: (value) => destination = value,
          ),
        ),
      ),
    );
    expect(find.text('Dịch vụ'), findsOneWidget);
    expect(find.text('Cộng đồng'), findsOneWidget);
    expect(find.text('Hoạt động'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-nav-2')), findsNothing);
    for (final index in [0, 1, 3, 4]) {
      await tester.tap(find.byKey(ValueKey('customer-nav-$index')));
      expect(destination, index);
    }
  });
}

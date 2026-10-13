import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/features/task_activity.dart';
void main() {
  for (final partner in [true, false]) {
    testWidgets('Booking amount for partner=$partner', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TaskBookingServicesCard(
        partner: partner, partnerNetAmount: 100800,
        booking: {'subtotal': 112000, 'platformFee': 11200, 'total': 112000, 'services': [
          {'serviceName': 'Vệ sinh', 'total': 112000, 'fields': []},
        ]},
      )))));
      expect(find.text(partner ? 'Tiền thực nhận' : 'Tổng thanh toán'), findsOneWidget);
      if (partner) {
        expect(find.text('Tổng giá dịch vụ'), findsNothing);
        expect(find.text('Phí dịch vụ'), findsNothing);
        expect(find.text('100.800 đ'), findsWidgets);
        expect(find.text('112.000 đ'), findsNothing);
      } else {
        expect(find.text('112.000 đ'), findsWidgets);
      }
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/features/customer_view.dart';
import 'package:taskly_mobile/domain/models.dart';
void main() {
  testWidgets('failed address update keeps entered fields and shows the server error', (tester) async {
    Address? submitted;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CustomerAddressDialog(
      address: const Address('id', 'Home', '123 Street', 'Ring bell', city: 'HCM', buildingType: 'Nhà riêng', buildingDescription: 'Floor 5', contactName: 'Customer', contactPhone: '0901234567'),
      isApi: true,
      onSave: (a) async { submitted = a; return false; },
      saveError: () => 'Không thể lưu địa chỉ',
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cập nhật'));
    await tester.pumpAndSettle();
    expect(submitted!.buildingDescription, 'Floor 5');
    expect(submitted!.note, 'Ring bell');
    expect(submitted!.contactPhone, '0901234567');
    expect(find.text('Không thể lưu địa chỉ'), findsOneWidget);
    expect(find.text('Sửa thông tin địa chỉ'), findsOneWidget);
    expect(find.text('123 Street'), findsOneWidget);
  });
}

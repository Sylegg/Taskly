import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_benefits.dart';
import 'package:taskly_mobile/features/partner/recruitment_shell.dart';

void main() {
  testWidgets('Partner income screen renders rich income dashboard, tiers, and service rates', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/partner/benefits')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'name': 'Thưởng mùa hè sôi động',
                'description': 'Tặng 500.000đ khi hoàn thành trên 30 đơn/tuần trong tháng 6-8',
                'eligible': true,
                'content_url': 'https://taskly.vn/policies/summer',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final session = Session(
      api: Api(client: client, base: 'http://localhost/api/v1'),
    )
      ..access = 'valid-token'
      ..expires = DateTime.now().add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerIncome(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Hero Card & Wallet balance
    expect(find.text('THU NHẬP ĐỐI TÁC TASKLY'), findsOneWidget);
    expect(find.text('Thu nhập & Quyền lợi tài chính 💰'), findsOneWidget);
    expect(find.text('SỐ DƯ VÍ KHẢ DỤNG'), findsOneWidget);
    expect(find.text('1.850.000đ'), findsOneWidget);
    expect(find.text('15 - 28 Triệu'), findsOneWidget);
    expect(find.text('Thực nhận 85% - 88%'), findsOneWidget);

    // Verify Deposit & Withdraw buttons
    expect(find.text('Nạp tiền'), findsOneWidget);
    expect(find.text('Rút tiền'), findsOneWidget);

    // Verify Daily Multi-Order Milestone Bonuses
    expect(find.text('Thưởng mốc đơn mỗi ngày'), findsOneWidget);
    expect(find.text('Cộng ví sau 24h'), findsOneWidget);
    expect(find.text('3 đơn / ngày'), findsOneWidget);
    expect(find.text('5 đơn / ngày'), findsOneWidget);
    expect(find.text('8 đơn / ngày'), findsOneWidget);
    expect(find.text('10+ đơn / ngày'), findsOneWidget);
    expect(find.text('+260.000đ'), findsOneWidget);

    // Verify Wallet policies
    expect(find.text('Rút tiền 24/7 tức thì'), findsOneWidget);
    expect(find.text('100% Tiền Tip'), findsOneWidget);

    // Test tapping Nạp tiền opens modal bottom sheet
    await tester.tap(find.text('Nạp tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Nạp tiền vào ví'), findsOneWidget);
    expect(find.text('Xác nhận nạp 200.000đ'), findsOneWidget);
    await tester.tap(find.text('Xác nhận nạp 200.000đ'));
    await tester.pumpAndSettle();
    expect(find.text('2.050.000đ'), findsOneWidget);

    // Test tapping Rút tiền opens modal bottom sheet
    await tester.tap(find.text('Rút tiền'));
    await tester.pumpAndSettle();
    expect(find.text('Rút tiền về ngân hàng'), findsOneWidget);
    expect(find.text('Xác nhận rút 500.000đ'), findsOneWidget);
    await tester.tap(find.text('Xác nhận rút 500.000đ'));
    await tester.pumpAndSettle();
    expect(find.text('1.550.000đ'), findsOneWidget);
  });

  testWidgets('RecruitmentShell bottom bar has Thu nhập tab with wallet icon', (tester) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'id': 'app-1',
            'fullName': 'Trần Văn B',
            'status': 'ACTIVE',
            'phone': '0912345678',
            'city': 'TP. Hồ Chí Minh',
            'agreementsAccepted': true,
            'depositConfirmed': true,
            'trainingPassed': true,
            'identityVerified': true,
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final session = Session(
      api: Api(client: client, base: 'http://localhost/api/v1'),
    )
      ..access = 'valid-token'
      ..expires = DateTime.now().add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentShell(session: session, onLogout: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Tab label exists in bottom bar
    expect(find.text('Thu nhập'), findsWidgets);
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsWidgets);

    // Tap on Thu nhập tab
    await tester.tap(find.text('Thu nhập').last);
    await tester.pumpAndSettle();

    // Verify header title switches to Thu nhập and displays screen
    expect(find.text('THU NHẬP ĐỐI TÁC TASKLY'), findsOneWidget);
  });
}

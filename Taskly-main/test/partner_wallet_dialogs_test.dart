import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_benefits.dart';

void main() {
  testWidgets('Redesigned Deposit Bottom Sheet displays rich bank card, quick chips, and deposits successfully', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    int currentBalance = 300000;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/partner/wallet') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'balance': currentBalance,
              'config': {
                'bankName': 'Vietcombank',
                'bankAccount': '0988889999',
                'accountOwner': 'CONG TY CO PHAN TASKLY VIET NAM',
                'qrPrefix': 'TASKLY NAP',
                'minDeposit': 50000,
                'maxDeposit': 20000000,
                'minWithdraw': 50000,
                'maxWithdrawDaily': 20000000,
                'withdrawFeePercent': 0.0,
              },
              'transactions': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/partner/wallet/deposit') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        currentBalance += (body['amount'] as num).toInt();
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': body['requestId'],
              'status': 'COMPLETED',
            },
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
      ..user = {'id': '604efaa7-b612-47f4-addb-5cc4c69fd4d6'}
      ..expires = DateTime.now().add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerBenefits(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial balance
    expect(find.text('300.000đ'), findsOneWidget);
    expect(find.text('Nạp tiền'), findsOneWidget);

    // Tap Nạp tiền to open redesigned deposit bottom sheet
    await tester.tap(find.text('Nạp tiền'));
    await tester.pumpAndSettle();

    // Verify redesigned header
    expect(find.text('Nạp tiền vào ví'), findsOneWidget);
    expect(find.text('Chuyển khoản theo thông tin ngân hàng bên dưới'), findsOneWidget);

    // Verify official bank card details
    expect(find.text('Vietcombank'), findsOneWidget);
    expect(find.text('Tài khoản chính thức'), findsOneWidget);
    expect(find.text('0988889999'), findsOneWidget);
    expect(find.text('CONG TY CO PHAN TASKLY VIET NAM'), findsOneWidget);
    expect(find.text('TASKLY NAP 604efaa7-b612-47f4-addb-5cc4c69fd4d6'), findsOneWidget);
    expect(find.text('Sao chép'), findsNWidgets(2));

    // Verify quick preset chips
    expect(find.text('+100.000đ'), findsOneWidget);
    expect(find.text('+200.000đ'), findsOneWidget);
    expect(find.text('+500.000đ'), findsOneWidget);

    // Tap quick chip +500.000đ
    await tester.tap(find.text('+500.000đ'));
    await tester.pumpAndSettle();

    // Verify submit button
    expect(find.text('Xác nhận nạp tiền'), findsOneWidget);
    await tester.tap(find.text('Xác nhận nạp tiền'));
    await tester.pumpAndSettle();

    // Verify new balance updated to 800.000đ
    expect(find.text('800.000đ'), findsOneWidget);
  });

  testWidgets('Redesigned Withdraw Bottom Sheet displays bank info, limits, real-time fee, and withdraws successfully', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    int currentBalance = 300000;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/partner/bank-account') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'bankName': 'Techcombank',
              'accountNumber': '1903657849',
              'accountName': 'NGUYEN VAN A',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/partner/wallet') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'balance': currentBalance,
              'config': {
                'bankName': 'Vietcombank',
                'bankAccount': '0988889999',
                'accountOwner': 'CONG TY CO PHAN TASKLY VIET NAM',
                'qrPrefix': 'TASKLY NAP',
                'minDeposit': 50000,
                'maxDeposit': 20000000,
                'minWithdraw': 50000,
                'maxWithdrawDaily': 20000000,
                'withdrawFeePercent': 0.0,
              },
              'transactions': [],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/partner/wallet/withdraw') && request.method == 'POST') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        currentBalance -= (body['amount'] as num).toInt();
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'id': body['requestId'],
              'status': 'PENDING',
            },
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
      ..user = {'id': '604efaa7-b612-47f4-addb-5cc4c69fd4d6'}
      ..expires = DateTime.now().add(const Duration(days: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerBenefits(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial balance
    expect(find.text('300.000đ'), findsOneWidget);
    expect(find.text('Rút tiền'), findsOneWidget);

    // Tap Rút tiền to open redesigned withdraw bottom sheet
    await tester.tap(find.text('Rút tiền'));
    await tester.pumpAndSettle();

    // Verify header in bottom sheet
    expect(find.text('Rút tiền về ngân hàng'), findsWidgets);
    expect(find.text('Chuyển về tài khoản ngân hàng chính chủ của đối tác'), findsOneWidget);

    // Verify available balance & limit card
    expect(find.text('SỐ DƯ VÍ KHẢ DỤNG'), findsOneWidget);
    expect(find.text('Sẵn sàng rút'), findsOneWidget);
    expect(find.text('Hạn mức: 20.000.000đ/ngày'), findsOneWidget);
    expect(find.text('Phí: Miễn phí'), findsOneWidget);

    // Verify partner beneficiary bank card
    expect(find.text('Techcombank'), findsOneWidget);
    expect(find.text('Đã liên kết'), findsOneWidget);
    expect(find.text('1903657849'), findsOneWidget);
    expect(find.text('NGUYEN VAN A'), findsOneWidget);

    // Verify "Rút tất cả" action button
    expect(find.text('Rút tất cả'), findsOneWidget);
    await tester.tap(find.text('Rút tất cả'));
    await tester.pumpAndSettle();

    // Verify real-time calculation breakdown
    expect(find.text('Số tiền yêu cầu rút:'), findsOneWidget);
    expect(find.text('Phí rút tiền (0.0%):'), findsOneWidget);
    expect(find.text('Tiền nhận:'), findsOneWidget);
    expect(find.text('300.000đ'), findsWidgets);

    // Verify notice
    expect(
      find.text('Yêu cầu sẽ được gửi để xét duyệt. Giao dịch hoàn tất khi quản trị viên xác nhận đã chuyển tiền.'),
      findsOneWidget,
    );

    // Verify submit button
    expect(find.text('Gửi yêu cầu rút tiền'), findsOneWidget);
    await tester.tap(find.text('Gửi yêu cầu rút tiền'));
    await tester.pumpAndSettle();

    // Verify updated balance to 0đ
    expect(find.text('0đ'), findsOneWidget);
  });
}

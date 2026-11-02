import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_jobs.dart';
import 'package:taskly_mobile/features/partner/partner_payment_confirmation.dart';

class _Server {
  bool received = false, fail = false;
  String method = 'CASH', payment = 'AWAITING_CASH';
  int requests = 0;
  Map<String, dynamic> get task => {
    'id': 'task-1',
    'status': received && method == 'CASH' ? 'PAID' : 'COMPLETED',
    'serviceName': 'Đơn chờ nhận tiền',
    'taskerId': 'partner',
    'customerName': 'Khách hàng',
    'partnerNetAmount': 80000,
    'paymentMethod': method,
    'paymentStatus': payment,
    'cashAmountDue': method == 'CASH' && payment == 'AWAITING_CASH' ? 60000 : 0,
    'partnerPaymentConfirmedAt': received ? '2026-10-20T10:00:00Z' : null,
  };
  late final session =
      Session(
          api: Api(
            base: 'http://test/api/v1',
            client: MockClient((request) async {
              dynamic data = [];
              final path = request.url.path;
              if (path.endsWith('/payment-received')) {
                requests++;
                if (fail)
                  return http.Response(
                    jsonEncode({
                      'success': false,
                      'error': {
                        'code': 'OFFLINE',
                        'message': 'Chưa gửi được xác nhận nhận tiền',
                      },
                    }),
                    503,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                received = true;
                payment = 'PAID';
                data = null;
              } else if (path.endsWith('/task-activity')) {
                data = [task];
              } else if (path.endsWith('/partner/wallet')) {
                data = {'serviceIncome': 80000, 'balance': 300000};
              } else if (path.endsWith('/partner/work-areas')) {
                data = {'areaIds': [], 'areas': []};
              } else if (path.endsWith('/live-sync')) {
                data = {'revision': received ? 2 : 1};
              }
              return http.Response(
                jsonEncode({'success': true, 'data': data}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        )
        ..access = 'fixture'
        ..expires = DateTime.now().add(const Duration(hours: 1));
}

Future<void> open(
  WidgetTester tester,
  _Server server, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    server.session.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: PartnerJobs(session: server.session),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> active(WidgetTester tester) async {
  await tester.ensureVisible(find.byIcon(Icons.pending_actions_rounded));
  await tester.tap(find.byIcon(Icons.pending_actions_rounded));
  await tester.pumpAndSettle();
}

Future<void> history(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Đã xong').last);
  await tester.tap(find.text('Đã xong').last);
  await tester.pumpAndSettle();
}

Future<void> confirm(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Xác nhận đã nhận tiền'));
  await tester.tap(find.text('Xác nhận đã nhận tiền'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Đã nhận tiền'));
  await tester.pumpAndSettle();
}

void main() {
  test('history requires partner receipt independently of customer approval and payment', () {
    for (final status in ['COMPLETED', 'PAID']) {
      final task = {'status': status, 'customerConfirmedAt': 'confirmed'};
      expect(needsPartnerPaymentConfirmation(task), isTrue);
      expect(isPartnerHistoryTask(task), isFalse);
      task['partnerPaymentConfirmedAt'] = 'received';
      expect(isPartnerHistoryTask(task), isTrue);
    }
  });
  for (final method in ['CASH', 'BANK', 'BALANCE']) {
    testWidgets(
      '$method job stays active until explicit receipt confirmation',
      (tester) async {
        final server = _Server();
        if (method != 'CASH') {
          server.method = method == 'BANK' ? 'BANK' : 'CASH';
          server.payment = 'PAID';
        }
        await open(tester, server, width: method == 'CASH' ? 320 : 390);
        await history(tester);
        expect(find.text('Đơn chờ nhận tiền'), findsNothing);
        await active(tester);
        expect(find.text('Đơn chờ nhận tiền'), findsOneWidget);
        expect(find.text('Xác nhận đã nhận tiền'), findsOneWidget);
        await confirm(tester);
        expect(server.requests, 1);
        expect(find.text('Đơn chờ nhận tiền'), findsNothing);
        await history(tester);
        expect(find.text('Đơn chờ nhận tiền'), findsOneWidget);
        final err = tester.takeException();
        print('STEP 5 ERR: $err');
        expect(err, isNull);
      },
    );
  }
  testWidgets('failure keeps receipt task active and permits retry', (
    tester,
  ) async {
    final server = _Server()..fail = true;
    await open(tester, server);
    await active(tester);
    await confirm(tester);
    expect(server.received, isFalse);
    expect(find.text('Chưa gửi được xác nhận nhận tiền'), findsOneWidget);
    expect(find.text('Đơn chờ nhận tiền'), findsOneWidget);
    server.fail = false;
    await confirm(tester);
    expect(server.received, isTrue);
  });
  testWidgets('declining receipt confirmation sends no request', (
    tester,
  ) async {
    final server = _Server();
    await open(tester, server);
    await active(tester);
    await tester.ensureVisible(find.text('Xác nhận đã nhận tiền'));
    await tester.tap(find.text('Xác nhận đã nhận tiền'));
    await tester.pumpAndSettle();
    expect(find.textContaining('60.000 đ'), findsWidgets);
    await tester.tap(find.text('Chưa nhận'));
    await tester.pumpAndSettle();
    expect(server.requests, 0);
    expect(find.text('Đơn chờ nhận tiền'), findsOneWidget);
  });
}

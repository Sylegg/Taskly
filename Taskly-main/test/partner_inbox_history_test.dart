import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_inbox.dart';

class InboxSession extends Session {
  final updates = StreamController<void>.broadcast();
  String activeStatus = 'ACCEPTED';
  bool received = false;
  int receipts = 0;
  @override
  Stream<void> get liveChanges => updates.stream;
  @override
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (method == 'POST' && path.endsWith('/payment-received')) {
      received = true;
      receipts++;
      activeStatus = 'PAID';
      return null;
    }
    return [
      for (final entry in {
        'Đang làm': activeStatus,
        'Đã hoàn tất': 'COMPLETED',
        'Đơn thanh toán': 'PAID',
        'Đơn hủy': 'CANCELLED',
        'Đơn hoàn tiền': 'REFUNDED',
        'Đơn hết hạn': 'EXPIRED',
      }.entries)
        {
          'id': entry.key,
          'serviceName': entry.key,
          'status': entry.value,
          'customerName': 'Khách',
          'partnerNetAmount': 90000,
          'scheduledAt': '2026-10-14T07:00:00Z',
          'taskerId': 'partner',
          'paymentMethod': 'CASH',
          'paymentStatus': received ? 'PAID' : 'AWAITING_CASH',
          'cashAmountDue': 100000,
          'partnerPaymentConfirmedAt': entry.key != 'Đang làm' || received
              ? '2026-10-20T09:00:00Z'
              : null,
        },
    ];
  }
}

void main() {
  testWidgets(
    'Partner Activity keeps completed job visible until receipt and then moves it to history',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final session = InboxSession();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                actions: [
                  TextButton(
                    onPressed: () => openPartnerJobHistory(context, session),
                    child: const Text('Lịch sử'),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                child: PartnerInbox(session: session),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Đang làm'), findsOneWidget);
      expect(find.text('Đơn hủy'), findsNothing);
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử nhận việc'), findsOneWidget);
      expect(find.text('Đang làm'), findsNothing);
      for (final label in [
        'Đã hoàn tất',
        'Đơn thanh toán',
        'Đơn hủy',
        'Đơn hoàn tiền',
        'Đơn hết hạn',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.pageBack();
      await tester.pumpAndSettle();
      session.activeStatus = 'COMPLETED';
      session.updates.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Đang làm'), findsOneWidget);
      expect(find.byTooltip('Xác nhận đã nhận tiền'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('partner-payment-action')))
            .height,
        lessThan(120),
      );
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Đang làm'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Xác nhận đã nhận tiền'));
      await tester.tap(find.byTooltip('Xác nhận đã nhận tiền'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Đã nhận tiền'));
      await tester.pumpAndSettle();
      expect(session.receipts, 1);
      expect(find.text('Bạn chưa có công việc đang xử lý.'), findsOneWidget);
      await tester.tap(find.text('Lịch sử'));
      await tester.pumpAndSettle();
      expect(find.text('Đang làm'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await session.updates.close();
      session.dispose();
    },
  );
}

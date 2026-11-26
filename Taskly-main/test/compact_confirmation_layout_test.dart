import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/completion_review.dart';
import 'package:taskly_mobile/features/partner/partner_payment_confirmation.dart';

void main() {
  testWidgets('icon-only actions stay compact and retain accessible labels', (
    tester,
  ) async {
    final session = Session();
    int opened = 0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CompletionAttention(iconOnly: true, onPressed: () => opened++),
                PartnerPaymentConfirmation(
                  iconOnly: true,
                  session: session,
                  task: const {
                    'id': 'task',
                    'paymentMethod': 'CASH',
                    'paymentStatus': 'AWAITING_CASH',
                    'cashAmountDue': 30000,
                  },
                  onConfirmed: () async {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final key in [
      'customer-completion-action',
      'partner-payment-action',
    ]) {
      expect(tester.getSize(find.byKey(ValueKey(key))), const Size(36, 36));
    }
    await tester.tap(find.byTooltip('Xem ảnh & xác nhận'));
    expect(opened, 1);
    await tester.tap(find.byTooltip('Xác nhận đã nhận tiền'));
    await tester.pumpAndSettle();
    expect(find.textContaining('30.000 đ'), findsOneWidget);
    await tester.tap(find.text('Chưa nhận'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  for (final width in [280.0, 390.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        'compact confirmation actions fit $width at text scale $scale',
        (tester) async {
          final session = Session();
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox());
            session.dispose();
          });
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width,
                    child: MediaQuery(
                      data: MediaQueryData(
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CompletionAttention(onPressed: () {}),
                          PartnerPaymentConfirmation(
                            session: session,
                            task: const {
                              'id': 'task-1',
                              'paymentMethod': 'CASH',
                              'paymentStatus': 'AWAITING_CASH',
                              'cashAmountDue': 1234567,
                            },
                            onConfirmed: () async {},
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .getSize(
                  find.byKey(const ValueKey('customer-completion-action')),
                )
                .height,
            lessThan(scale == 1 ? 100 : 150),
          );
          expect(
            tester
                .getSize(find.byKey(const ValueKey('partner-payment-action')))
                .height,
            lessThan(scale == 1 ? 120 : 180),
          );
          expect(find.text('Xem ảnh & xác nhận'), findsOneWidget);
          expect(find.text('Xác nhận đã nhận tiền'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

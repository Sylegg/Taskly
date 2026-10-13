import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_inbox.dart';

class InboxSession extends Session {
  final updates = StreamController<void>.broadcast();
  String activeStatus = 'ACCEPTED';
  @override Stream<void> get liveChanges => updates.stream;
  @override Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    return [
      for (final entry in {'Đang làm': activeStatus, 'Đã hoàn tất': 'COMPLETED',
        'Đơn thanh toán': 'PAID', 'Đơn hủy': 'CANCELLED', 'Đơn hoàn tiền': 'REFUNDED',
        'Đơn hết hạn': 'EXPIRED'}.entries)
        {'id': entry.key, 'serviceName': entry.key, 'status': entry.value,
          'customerName': 'Khách', 'partnerNetAmount': 90000,
          'scheduledAt': '2026-10-14T07:00:00Z', 'taskerId': 'partner'},
    ];
  }
}
void main() {
  testWidgets('inbox separates ended jobs and moves newly ended job into history', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = InboxSession();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      appBar: AppBar(actions: [TextButton(
        onPressed: () => openPartnerJobHistory(context, session), child: const Text('Lịch sử'))]),
      body: SingleChildScrollView(child: PartnerInbox(session: session)),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Đang làm'), findsOneWidget);
    expect(find.text('Đơn hủy'), findsNothing);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử nhận việc'), findsOneWidget);
    expect(find.text('Đang làm'), findsNothing);
    for(final label in ['Đã hoàn tất','Đơn thanh toán','Đơn hủy','Đơn hoàn tiền','Đơn hết hạn']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    session.activeStatus = 'COMPLETED';
    session.updates.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có công việc đang xử lý.'), findsOneWidget);
    await tester.tap(find.text('Lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Đang làm'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await session.updates.close();
    session.dispose();
  });
}

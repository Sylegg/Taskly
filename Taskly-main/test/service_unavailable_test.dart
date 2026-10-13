import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_activity.dart';

class PreviewSession extends Session {
  final updates = StreamController<void>.broadcast();
  bool unavailable = false;
  @override Stream<void> get liveChanges => updates.stream;
  @override Future<dynamic> request(String path, {String method = 'GET', Map<String, dynamic>? body}) async {
    if (unavailable) throw ApiFailure('TASK_NOT_AVAILABLE', 'Unavailable', 404);
    if (method == 'POST') return null;
    return {
      'task': {'id': 'test', 'serviceName': 'Dọn nhà', 'status': 'POSTED',
        'budgetAmount': 100000, 'platformFee': 10000, 'partnerNetAmount': 90000},
      'events': [], 'messages': [], 'payment': {}, 'booking': {},
      'addressDetails': {}, 'earlyStart': {},
    };
  }
}
void main() {
  testWidgets('cancellation while viewing shows one centered dialog and returns to jobs', (tester) async {
    final session = PreviewSession();
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TaskActivityDetail(session: session, id: 'test', partner: true, preview: true))),
        child: const Text('Danh sách dịch vụ')),
    ))));
    await tester.tap(find.text('Danh sách dịch vụ'));
    await tester.pumpAndSettle();
    session.unavailable = true;
    session.updates.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Dịch vụ không còn nữa'), findsOneWidget);
    expect(find.text('Vui lòng tìm dịch vụ khác.'), findsOneWidget);
    session.updates.add(null);
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Tìm dịch vụ khác'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách dịch vụ'), findsOneWidget);
    expect(find.byType(TaskActivityDetail), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await session.updates.close();
    session.dispose();
  });
}

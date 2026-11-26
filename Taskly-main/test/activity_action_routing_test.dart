import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_activity.dart';
import 'package:taskly_mobile/features/task_chat.dart';
import 'package:taskly_mobile/features/completion_review.dart';

class _ActionSession extends Session {
  final paths = <String>[];
  final writes = <String>[];
  String? address = '123 Nguyễn Trãi';
  String? scheduledAt = '2026-10-20T09:00:00Z';
  @override
  Stream<void> get liveChanges => const Stream.empty();
  Map<String, dynamic> get task => {
    'id': 'task-routing',
    'serviceName': 'Dọn nhà kiểm thử',
    'status': 'COMPLETED',
    'customerName': 'Khách',
    'taskerName': 'Đối tác',
    'taskerId': 'partner',
    'scheduledAt': scheduledAt,
    'budgetAmount': 70000,
    'partnerNetAmount': 63000,
    'paymentMethod': 'CASH',
    'paymentStatus': 'AWAITING_CASH',
    'cashAmountDue': 70000,
    'address': address,
    'customerConfirmedAt': null,
    'partnerPaymentConfirmedAt': null,
  };
  @override
  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    paths.add(path);
    if (method != 'GET') {
      writes.add(path);
      return null;
    }
    if (path.contains('start-eligibility')) return <String, dynamic>{};
    if (path.startsWith('/task-activity/task-routing'))
      return {
        'task': task,
        'messages': [],
        'events': [],
        'payment': {},
        'booking': {},
        'addressDetails': {},
      };
    return [task];
  }
}

Future<void> open(
  WidgetTester tester,
  _ActionSession session,
  bool partner, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    session.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaskActivityList(
            session: session,
            partner: partner,
            showHeading: false,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

void main() {
  for (final partner in [false, true]) {
    final role = partner ? 'partner' : 'customer';
    testWidgets(
      '$role activity shows schedule, full address and correct amount',
      (tester) async {
        final session = _ActionSession()
          ..address =
              '123 Nguyễn Trãi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh';
        await open(tester, session, partner, width: 320);
        expect(find.text(session.address!), findsOneWidget);
        expect(find.textContaining('Lịch hẹn:'), findsOneWidget);
        expect(find.textContaining('20/10/2026'), findsOneWidget);
        expect(find.text(partner ? '63.000 đ' : '70.000 đ'), findsOneWidget);
        expect(find.text('Thực nhận'), findsNothing);
        expect(
          tester.widget<Text>(find.text(session.address!)).overflow,
          isNot(TextOverflow.ellipsis),
        );
        expect(find.byTooltip('Xem chi tiết'), findsOneWidget);
        expect(find.byTooltip('Nhắn tin'), findsOneWidget);
        expect(session.writes, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('$role activity explains missing address and schedule', (
      tester,
    ) async {
      final session = _ActionSession()
        ..address = '  '
        ..scheduledAt = null;
      await open(tester, session, partner);
      expect(find.text('Chưa có địa chỉ thực hiện'), findsOneWidget);
      expect(find.text('Lịch hẹn chưa được cập nhật'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$role card body does not navigate or confirm', (tester) async {
      final session = _ActionSession();
      await open(tester, session, partner);
      await tester.tap(find.text('Dọn nhà kiểm thử'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskActivityDetail), findsNothing);
      expect(find.byType(TaskChatScreen), findsNothing);
      expect(find.byType(CompletionReviewScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(session.writes, isEmpty);
      expect(session.paths.where((p) => p.contains('/task-routing')), isEmpty);
    });
    testWidgets('$role eye opens job details without opening confirmation', (
      tester,
    ) async {
      final session = _ActionSession();
      await open(tester, session, partner, width: 320);
      final eye = tester.getCenter(find.byTooltip('Xem chi tiết'));
      final chat = tester.getCenter(find.byTooltip('Nhắn tin'));
      expect((eye.dy - chat.dy).abs(), lessThan(1));
      expect(eye.dx, lessThan(chat.dx));
      await tester.tap(find.byTooltip('Xem chi tiết'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskActivityDetail), findsOneWidget);
      final detail = tester.widget<TaskActivityDetail>(
        find.byType(TaskActivityDetail),
      );
      expect(detail.partner, partner);
      expect(detail.id, 'task-routing');
      expect(find.byType(TaskChatScreen), findsNothing);
      expect(find.byType(CompletionReviewScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('123 Nguyễn Trãi').hitTestable(), findsOneWidget);
      expect(session.writes, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$role message icon only opens chat for this job', (
      tester,
    ) async {
      final session = _ActionSession();
      await open(tester, session, partner);
      await tester.tap(find.byTooltip('Nhắn tin'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskChatScreen), findsOneWidget);
      final chat = tester.widget<TaskChatScreen>(find.byType(TaskChatScreen));
      expect(chat.partner, partner);
      expect(chat.taskId, 'task-routing');
      expect(find.byType(TaskActivityDetail), findsNothing);
      expect(find.byType(CompletionReviewScreen), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(session.writes, isEmpty);
    });
    testWidgets('$role confirmation icon only opens its own flow', (
      tester,
    ) async {
      final session = _ActionSession();
      await open(tester, session, partner);
      await tester.tap(
        find.byTooltip(
          partner ? 'Xác nhận đã nhận tiền' : 'Xem ảnh & xác nhận',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TaskActivityDetail), findsNothing);
      expect(find.byType(TaskChatScreen), findsNothing);
      if (partner) {
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(CompletionReviewScreen), findsNothing);
      } else {
        expect(find.byType(CompletionReviewScreen), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
      }
      expect(session.writes, isEmpty);
    });
  }
}


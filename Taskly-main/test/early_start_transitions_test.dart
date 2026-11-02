import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_activity.dart';

class _BookingServer {
  final base = DateTime.utc(2030, 1, 1, 10);
  late DateTime now = base;
  late DateTime expiry = base.add(const Duration(seconds: 2));
  late DateTime scheduled = base.add(const Duration(seconds: 3));
  String taskStatus = 'ARRIVED';
  String requestStatus = 'PENDING';
  bool expireDuringDecision = false;
  final decisions = <Map<String, dynamic>>[];
  late final session =
      Session(
          api: Api(
            base: 'http://test/api/v1',
            client: MockClient((request) async {
              dynamic data = {'revision': 0};
              if (request.url.path.endsWith('/decision')) {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                decisions.add(body);
                if (expireDuringDecision) {
                  now = expiry;
                  requestStatus = 'EXPIRED';
                  return http.Response(
                    jsonEncode({
                      'success': false,
                      'error': {
                        'code': 'EARLY_START_REQUEST_EXPIRED',
                        'message': 'Đề nghị đã hết hạn',
                      },
                    }),
                    409,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                requestStatus = body['action'] == 'APPROVE'
                    ? 'APPROVED'
                    : 'REJECTED';
                data = {'status': requestStatus};
              } else if (request.url.path.endsWith('/start-eligibility')) {
                data = {
                  'serverNow': now.toIso8601String(),
                  'scheduledStartAt': scheduled.toIso8601String(),
                  'allowedStartAt': scheduled.toIso8601String(),
                  'taskStatus': taskStatus,
                  'checkedInAt': base
                      .subtract(const Duration(minutes: 1))
                      .toIso8601String(),
                  'actualStartedAt': taskStatus == 'IN_PROGRESS'
                      ? now.toIso8601String()
                      : null,
                  'canStart':
                      taskStatus == 'ARRIVED' && !now.isBefore(scheduled),
                  'canRequestEarlyStart': now.isBefore(scheduled),
                  // Intentionally stale request: the app must also check server time and job state.
                  'activeRequest': {
                    'id': 'request-1',
                    'status': requestStatus,
                    'requestedStartAt': base.toIso8601String(),
                    'proposedEndAt': base
                        .add(const Duration(hours: 2))
                        .toIso8601String(),
                    'expiresAt': expiry.toIso8601String(),
                  },
                };
              } else if (request.url.path.contains('/task-activity/task-1')) {
                data = {
                  'task': {
                    'id': 'task-1',
                    'serviceName': 'Ủi quần áo',
                    'status': 'TASKER_ON_THE_WAY',
                    'taskerId': 'partner-1',
                    'taskerName': 'Minh vu',
                    'scheduledAt': scheduled.toIso8601String(),
                    'budgetAmount': 27000,
                  },
                  'events': [],
                  'messages': [],
                };
              }
              return http.Response(
                jsonEncode({'success': true, 'data': data}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
          ),
        )
        ..access = 'test'
        ..expires = DateTime.now().add(const Duration(hours: 1));
}

Future<void> _open(
  WidgetTester tester,
  _BookingServer server, {
  bool partner = false,
}) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    server.session.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      home: TaskActivityDetail(
        session: server.session,
        id: 'task-1',
        partner: partner,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'customer hides pending actions at expiry using server clock without manual refresh',
    (tester) async {
      final server = _BookingServer();
      await _open(tester, server);
      expect(find.text('Đồng ý bắt đầu sớm'), findsOneWidget);
      server.now = server.expiry;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Đồng ý bắt đầu sớm'), findsNothing);
      expect(find.text('Giữ nguyên giờ đặt'), findsNothing);
      expect(server.decisions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'already expired request never appears after opening an old booking',
    (tester) async {
      final server = _BookingServer();
      server.now = server.scheduled.add(const Duration(days: 7));
      await _open(tester, server);
      expect(find.text('Partner đề nghị bắt đầu sớm'), findsNothing);
      expect(find.textContaining('Đã đến giờ làm việc'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'partner replaces pending approval with Start when scheduled time arrives',
    (tester) async {
      final server = _BookingServer();
      await _open(tester, server, partner: true);
      expect(find.textContaining('Đang chờ khách duyệt'), findsOneWidget);
      expect(find.text('Bắt đầu công việc'), findsNothing);
      server.now = server.scheduled;
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đang chờ khách duyệt'), findsNothing);
      final start = find.widgetWithText(FilledButton, 'Bắt đầu công việc');
      expect(start, findsOneWidget);
      expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
      expect(server.decisions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'customer automatically follows actual job state from latest eligibility snapshot',
    (tester) async {
      final server = _BookingServer();
      await _open(tester, server);
      server.taskStatus = 'IN_PROGRESS';
      server.now = server.base.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Partner đề nghị bắt đầu sớm'), findsNothing);
      expect(find.textContaining('Bắt đầu thực tế lúc'), findsOneWidget);
      expect(find.text('Đang thực hiện'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  for (final action in ['APPROVE', 'REJECT']) {
    testWidgets('customer sends valid action $action', (tester) async {
      final server = _BookingServer();
      await _open(tester, server);
      final label = action == 'APPROVE'
          ? 'Đồng ý bắt đầu sớm'
          : 'Giữ nguyên giờ đặt';
      final button = find.text(label);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(server.decisions.single, {'action': action});
      expect(find.text('Partner đề nghị bắt đầu sớm'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'expiry race refreshes booking without keeping stale buttons or showing invalid data',
    (tester) async {
      final server = _BookingServer()..expireDuringDecision = true;
      await _open(tester, server);
      final button = find.text('Đồng ý bắt đầu sớm');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Partner đề nghị bắt đầu sớm'), findsNothing);
      expect(find.text('Hoạt động công việc'), findsOneWidget);
      expect(
        find.textContaining('Lịch làm việc đã được cập nhật'),
        findsOneWidget,
      );
      expect(find.text('Dữ liệu chưa hợp lệ.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

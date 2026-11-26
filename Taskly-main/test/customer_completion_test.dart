import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/completion_review.dart';
import 'package:taskly_mobile/features/task_activity.dart';

const image =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

class _Server {
  bool confirmed = false;
  bool fail = false;
  int confirmations = 0;
  Map<String, dynamic> get pending => {
    'id': 'pending',
    'serviceName': 'Đơn cần xác nhận',
    'status': 'PAID',
    'taskerId': 'partner',
    'taskerName': 'Minh',
    'budgetAmount': 27000,
    'customerConfirmedAt': confirmed ? '2026-10-20T09:00:00Z' : null,
  };
  late final session =
      Session(
          api: Api(
            base: 'http://test/api/v1',
            client: MockClient((request) async {
              dynamic data = {'revision': confirmed ? 2 : 1};
              if (request.url.path.endsWith('/confirm-completion')) {
                confirmations++;
                if (fail)
                  return http.Response(
                    jsonEncode({
                      'success': false,
                      'error': {
                        'code': 'OFFLINE',
                        'message': 'Chưa gửi được xác nhận',
                      },
                    }),
                    503,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                confirmed = true;
                data = {'confirmed': true};
              } else if (request.url.path.endsWith('/task-activity')) {
                data = [
                  {
                    'id': 'active',
                    'status': 'ACCEPTED',
                    'serviceName': 'Đơn đang làm',
                    'taskerId': 'partner',
                  },
                  pending,
                ];
              } else if (request.url.path.endsWith('/pending')) {
                data = {
                  'task': pending,
                  'events': [],
                  'messages': [
                    for (int i = 0; i < 2; i++)
                      {
                        'id': '$i',
                        'mine': false,
                        'text': 'Ảnh xác nhận khu vực đã hoàn thành theo yêu cầu khách hàng',
                        'imageData': image,
                      },
                    {
                      'id': 'checkin',
                      'mine': false,
                      'text': 'Ảnh check-in',
                      'imageData': image,
                    },
                  ],
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

Future<void> openList(
  WidgetTester tester,
  _Server server, {
  bool history = false,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
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
          child: TaskActivityList(
            session: server.session,
            showHeading: false,
            filter: (task) => history
                ? isCustomerHistoryTask(task)
                : !isCustomerHistoryTask(task),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> reviewAll(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Xem ảnh & xác nhận'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
  expect(find.text('Xác nhận hoàn thành'), findsWidgets);
  expect(
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
        )
        .onPressed,
    isNull,
  );
  await tester.tap(find.text('Ảnh tiếp'));
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpAndSettle();
  expect(find.textContaining('Đã xem 2/2'), findsOneWidget);
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pump();
}

void main() {
  test('completed and cash-paid work stays active until customer confirms', () {
    for (final status in ['COMPLETED', 'PAID']) {
      expect(isCustomerHistoryTask({'status': status}), isFalse);
      expect(
        isCustomerHistoryTask({
          'status': status,
          'customerConfirmedAt': '2026-10-20',
        }),
        isTrue,
      );
    }
    expect(isCustomerHistoryTask({'status': 'CANCELLED'}), isTrue);
  });
  testWidgets(
    'pending review is highlighted first and is absent from history',
    (tester) async {
      final server = _Server();
      await openList(tester, server);
      expect(
        tester.getTopLeft(find.text('Đơn cần xác nhận')).dy,
        lessThan(tester.getTopLeft(find.text('Đơn đang làm')).dy),
      );
      expect(find.byTooltip('Xem ảnh & xác nhận'), findsOneWidget);
      expect(find.byTooltip('Nhắn tin'), findsNWidgets(2));
      expect(find.text('Chat'), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('customer-completion-action')))
            .height,
        lessThan(85),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unconfirmed paid work does not appear in history', (
    tester,
  ) async {
    final server = _Server();
    await openList(tester, server, history: true);
    expect(find.text('Đơn cần xác nhận'), findsNothing);
  });
  testWidgets(
    'view both completion photos then confirm moves work out of active list',
    (tester) async {
      final server = _Server();
      await openList(tester, server);
      await reviewAll(tester);
      expect(find.textContaining('Đã xem 2/2'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'),
      );
      await tester.pumpAndSettle();
      expect(server.confirmations, 1);
      expect(find.text('Đơn cần xác nhận'), findsNothing);
      expect(isCustomerHistoryTask(server.pending), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed confirmation retains review and allows retry', (
    tester,
  ) async {
    final server = _Server()..fail = true;
    await openList(tester, server);
    await reviewAll(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'));
    await tester.pumpAndSettle();
    expect(server.confirmed, isFalse);
    expect(find.text('Chưa gửi được xác nhận'), findsOneWidget);
    server.fail = false;
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận hoàn thành'));
    await tester.pumpAndSettle();
    expect(server.confirmed, isTrue);
  });
}

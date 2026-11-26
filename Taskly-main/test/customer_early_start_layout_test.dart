import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_activity.dart';

void main() {
  for (final scenario in [
    (320.0, 1.0),
    (360.0, 1.0),
    (360.0, 1.4),
    (430.0, 1.0),
  ]) {
    testWidgets(
      'customer early start fits ${scenario.$1}px at ${scenario.$2} text scale',
      (tester) async {
        tester.view.physicalSize = Size(scenario.$1, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final start = DateTime(
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          23,
          50,
        );
        final end = start.add(const Duration(hours: 2));
        final scheduled = start.add(const Duration(minutes: 15));
        String formatted(DateTime dt) =>
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}, ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        String? decision;
        final session =
            Session(
                api: Api(
                  base: 'http://test/api/v1',
                  client: MockClient((request) async {
                    dynamic data = {'revision': 0};
                    if (request.url.path.endsWith('/decision')) {
                      decision =
                          (jsonDecode(request.body) as Map)['action'] as String;
                      data = {};
                    } else if (request.url.path.endsWith(
                      '/start-eligibility',
                    )) {
                      data = {
                        'activeRequest': decision == null
                            ? {
                                'id': 'request-1',
                                'status': 'PENDING',
                                'requestedStartAt': start.toIso8601String(),
                                'proposedEndAt': end.toIso8601String(),
                                'expiresAt': start
                                    .subtract(const Duration(minutes: 30))
                                    .toIso8601String(),
                                'reason': 'Đối tác đã đến và khách hàng có thể bắt đầu sớm hơn lịch hẹn.',
                              }
                            : null,
                      };
                    } else if (request.url.path.endsWith(
                      '/task-activity/task-1',
                    )) {
                      data = {
                        'task': {
                          'id': 'task-1',
                          'serviceName': 'Dọn dẹp nhà',
                          'status': 'ACCEPTED',
                          'taskerId': 'partner-1',
                          'taskerName': 'Minh vu',
                          'scheduledAt': scheduled.toIso8601String(),
                          'originalScheduledStartAt': scheduled
                              .toIso8601String(),
                          'budgetAmount': 200000,
                          'address': 'Địa chỉ thực hiện',
                        },
                        'events': [],
                        'messages': [],
                      };
                    }
                    return http.Response(
                      jsonEncode({'success': true, 'data': data}),
                      200,
                      headers: {
                        'content-type': 'application/json; charset=utf-8',
                      },
                    );
                  }),
                ),
              )
              ..access = 'test-token'
              ..expires = DateTime.now().add(const Duration(hours: 1));
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scenario.$2)),
              child: child!,
            ),
            home: TaskActivityDetail(
              session: session,
              id: 'task-1',
              partner: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Partner đề nghị bắt đầu sớm'), findsOneWidget);
        expect(
          find.text('${formatted(start)}\nđến ${formatted(end)}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        final approve = find.widgetWithText(FilledButton, 'Đồng ý bắt đầu sớm');
        await tester.ensureVisible(approve);
        await tester.pumpAndSettle();
        await tester.tap(approve);
        await tester.pumpAndSettle();
        expect(decision, 'APPROVE');
        expect(find.text('Partner đề nghị bắt đầu sớm'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/task_activity.dart';
import 'package:taskly_mobile/features/partner/partner_account.dart';
import 'package:taskly_mobile/features/partner/partner_jobs.dart';

void main() {
  testWidgets(
    'Partner task progress uses shared task history and actual status API',
    (tester) async {
      var status = 'ACCEPTED';
      var writes = 0;
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  Object data;
                  if (request.url.path.endsWith('/status')) {
                    final body = jsonDecode(request.body);
                    expect(body['expectedStatus'], 'ACCEPTED');
                    expect(body['status'], 'TASKER_ON_THE_WAY');
                    expect(body['requestId'], isNotEmpty);
                    status = body['status'];
                    writes++;
                    data = {'status': status};
                  } else {
                    expect(request.url.path, '/api/v1/task-activity/task-demo');
                    data = {
                      'task': {
                        'serviceName': 'Dịch vụ DEMO',
                        'status': status,
                        'address': 'Địa chỉ DEMO',
                        'taskerId': 'fictional',
                        'taskerName': 'DEMO',
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
            ..access = 'fixture'
            ..expires = DateTime.now().add(const Duration(hours: 1));
      await tester.pumpWidget(
        MaterialApp(
          home: TaskActivityDetail(
            session: session,
            id: 'task-demo',
            partner: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu di chuyển'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(find.text('Tôi đã đến'), findsOneWidget);
      expect(find.text('Chat với khách hàng'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
  testWidgets('Partner account saves validated profile through existing API', (
    tester,
  ) async {
    var writes = 0;
    var profile = {
      'fullName': 'Tên DEMO',
      'phone': '',
      'email': 'fictional@example.test',
      'language': 'vi',
    };
    final session =
        Session(
            api: Api(
              base: 'http://test/api/v1',
              client: MockClient((request) async {
                if (request.method == 'PATCH') {
                  expect(request.url.path, '/api/v1/users/me/profile');
                  final body = jsonDecode(request.body);
                  expect(body['fullName'], 'Tên cập nhật DEMO');
                  writes++;
                  profile = {...profile, ...Map<String, String>.from(body)};
                }
                return http.Response(
                  jsonEncode({'success': true, 'data': profile}),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            ),
          )
          ..access = 'fixture'
          ..expires = DateTime.now().add(const Duration(hours: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PartnerAccount(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editBtn = find.byTooltip('Chỉnh sửa thông tin tài khoản');
    if (editBtn.evaluate().isNotEmpty) {
      await tester.tap(editBtn);
      await tester.pumpAndSettle();
    }
    await tester.enterText(
      find.byType(TextFormField).first,
      'Tên cập nhật DEMO',
    );
    await tester.ensureVisible(find.text('Lưu thông tin tài khoản'));
    await tester.tap(find.text('Lưu thông tin tài khoản'));
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Đã lưu thông tin tài khoản.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });
  testWidgets('Partner jobs accept through API and open persisted activity', (
    tester,
  ) async {
    var accepts = 0;
    final session =
        Session(
            api: Api(
              base: 'http://test/api/v1',
              client: MockClient((request) async {
                Object data;
                final path = request.url.path;
                if (path.endsWith('/accept')) {
                  expect(request.method, 'POST');
                  accepts++;
                  data = {'id': 'job-real', 'status': 'ACCEPTED'};
                } else if (path.endsWith('/partner/jobs')) {
                  data = [
                    {
                      'id': 'job-real',
                      'title': 'Việc phù hợp từ API',
                      'city_snapshot': 'Hà Nội',
                      'budget_amount': 100000,
                      'scheduled_at': '2030-01-01T08:00:00Z',
                      'estimated_duration_minutes': 60,
                    },
                  ];
                } else if (path.endsWith('/task-activity')) {
                  expect(request.url.queryParameters['partner'], 'true');
                  data = [];
                } else if (path.endsWith('/task-activity/job-real')) {
                  data = {
                    'task': {
                      'serviceName': 'Dọn nhà',
                      'status': 'ACCEPTED',
                      'address': 'Địa chỉ thử nghiệm',
                      'taskerId': 'partner',
                      'taskerName': 'Partner',
                    },
                    'events': [
                      {
                        'status': 'ACCEPTED',
                        'at': '2030-01-01T08:00:00Z',
                        'reason': '',
                      },
                    ],
                    'messages': [],
                  };
                } else {
                  throw StateError('Unexpected route: $path');
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
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PartnerJobs(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Việc phù hợp từ API'), findsOneWidget);
    await tester.ensureVisible(find.text('Nhận việc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhận việc'));
    await tester.pumpAndSettle();
    expect(accepts, 1);
    expect(find.text('Bắt đầu di chuyển'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    session.dispose();
  });

  for (final width in [320.0, 360.0, 375.0]) {
    testWidgets(
      'Partner jobs renders without overflow on screen width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final session =
            Session(
                api: Api(
                  base: 'http://test/api/v1',
                  client: MockClient((request) async {
                    Object data;
                    final path = request.url.path;
                    if (path.endsWith('/partner/jobs')) {
                      data = [];
                    } else if (path.endsWith('/task-activity')) {
                      data = [];
                    } else {
                      throw StateError('Unexpected route: $path');
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

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PartnerJobs(session: session)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Mở thêm lịch rảnh'), findsNothing);
        expect(find.byTooltip('Cập nhật lịch rảnh'), findsNothing);
        expect(find.text('Thử quét lại'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to Tab 1 (Đang làm)
        await tester.tap(find.text('Đang làm').last);
        await tester.pumpAndSettle();
        expect(find.text('Bạn chưa có công việc nào đang thực hiện'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Switch to Tab 2 (Đã xong)
        await tester.tap(find.text('Đã xong').last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }
}


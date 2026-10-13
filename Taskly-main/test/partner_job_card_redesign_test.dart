import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_jobs.dart';

void main() {
  testWidgets('Partner job card renders beautifully without raw timestamps or unformatted currency', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var previewJobCalled = false;

    final session = Session(
      api: Api(
        base: 'http://localhost/api/v1',
        client: MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/partner/jobs')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'job-sample-101',
                    'title': 'Tổng vệ sinh nhà ở',
                    'description': 'Dọn dẹp căn hộ 2 phòng ngủ, lau chùi sàn và kính ban công.',
                    'city_snapshot': 'TP. Hồ Chí Minh',
                    'budget_amount': 112000,
                    'partner_net_amount': 100800,
                    'scheduled_at': '2026-10-14T02:32:58.847Z',
                    'estimated_duration_minutes': 120,
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (path.contains('/task-activity/job-sample-101')) {
            previewJobCalled = true;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'task': {
                    'serviceName': 'Tổng vệ sinh nhà ở',
                    'status': 'POSTED',
                    'address': 'TP. Hồ Chí Minh',
                  },
                  'events': [],
                  'messages': [],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (path.endsWith('/partner/work-areas')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'areaIds': ['area-1'],
                  'areas': [
                    {
                      'id': 'area-1',
                      'city': 'TP. Hồ Chí Minh',
                      'recruiting': true,
                    }
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (path.endsWith('/partner/bank-account')) {
            return http.Response(
              jsonEncode({'success': true, 'data': {'accountNumber': '123456789'}}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (path.endsWith('/partner/status')) {
            return http.Response(
              jsonEncode({'success': true, 'data': {'isOnline': true}}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
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
          body: PartnerJobs(session: session),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify title and description
    expect(find.text('Tổng vệ sinh nhà ở'), findsOneWidget);
    expect(
      find.text('Dọn dẹp căn hộ 2 phòng ngủ, lau chùi sàn và kính ban công.'),
      findsOneWidget,
    );

    // 2. Verify category tag & schedule badge
    expect(find.text('Dịch vụ TaskLy'), findsOneWidget);

    // 3. Verify location and properly formatted budget
    expect(find.text('TP. Hồ Chí Minh'), findsOneWidget);
    expect(find.text('Giá đơn: 112.000 đ'), findsOneWidget);

    // 4. Verify clean duration formatting
    expect(find.text('120 phút (2 giờ)'), findsOneWidget);

    // 5. Verify raw unformatted millisecond timestamp is NOT shown
    expect(find.textContaining('02:32:58.847'), findsNothing);

    // 6. Verify partner net income is displayed prominently with formatting
    expect(find.text('Thu nhập nhận được'), findsOneWidget);
    expect(find.text('Thực nhận: 100.800 đ'), findsOneWidget);

    // 7. Verify action button
    final detailsBtn = find.text('Xem chi tiết');
    expect(detailsBtn, findsOneWidget);

    // 8. Tapping "Xem chi tiết" opens preview
    await tester.tap(detailsBtn);
    await tester.pumpAndSettle();
    expect(previewJobCalled, isTrue);
  });

  for (final width in [320.0, 360.0, 375.0]) {
    testWidgets('Partner job card renders without overflow on width $width', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            final path = request.url.path;
            if (path.endsWith('/partner/jobs')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'id': 'job-sample-$width',
                      'title': 'Tổng vệ sinh nhà ở căn hộ chung cư cao cấp',
                      'description': 'Dọn dẹp căn hộ 3 phòng ngủ đầy đủ tiện nghi.',
                      'city_snapshot': 'TP. Hồ Chí Minh',
                      'budget_amount': 250000,
                      'partner_net_amount': 225000,
                      'scheduled_at': '2026-10-14T02:32:58.847Z',
                      'estimated_duration_minutes': 180,
                    }
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            } else if (path.endsWith('/partner/work-areas')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'areaIds': ['area-1'],
                    'areas': [
                      {
                        'id': 'area-1',
                        'city': 'TP. Hồ Chí Minh',
                        'recruiting': true,
                      }
                    ],
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
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
            body: SingleChildScrollView(
              child: PartnerJobs(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tổng vệ sinh nhà ở căn hộ chung cư cao cấp'), findsOneWidget);
      expect(find.text('Xem chi tiết'), findsOneWidget);
      expect(find.text('Thu nhập nhận được'), findsOneWidget);
      expect(find.text('Thực nhận: 225.000 đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_jobs.dart';

void main() {
  for (final width in [320.0, 360.0, 375.0, 390.0, 414.0]) {
    testWidgets('Active job card buttons stay on single line without wrapping on width $width', (tester) async {
      tester.view.physicalSize = Size(width, 844);
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
                jsonEncode({'success': true, 'data': []}),
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
                      {'id': 'area-1', 'city': 'TP. Hồ Chí Minh', 'recruiting': true}
                    ],
                  },
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            } else if (path.endsWith('/partner/status')) {
              return http.Response(
                jsonEncode({'success': true, 'data': {'isOnline': true}}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            } else if (path.contains('/task-activity')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'id': 'task-active-1',
                      'title': 'Dọn dẹp nhà theo giờ',
                      'status': 'ACCEPTED',
                      'serviceName': 'Dọn dẹp nhà theo giờ',
                      'address': 'Landmark 81, Bình Thạnh',
                      'scheduled_at': '2026-10-14T08:00:00.000Z',
                      'estimated_duration_minutes': 120,
                      'partner_net_amount': 250000,
                    },
                    {
                      'id': 'task-active-2',
                      'title': 'Sửa điều hòa',
                      'status': 'TASKER_ON_THE_WAY',
                      'serviceName': 'Sửa điều hòa',
                      'address': 'Quận 1, TP. Hồ Chí Minh',
                      'scheduled_at': '2026-10-14T11:00:00.000Z',
                      'estimated_duration_minutes': 60,
                      'partner_net_amount': 300000,
                    },
                  ],
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

      // Switch to Tab 1: "Đang làm"
      final dangLamTab = find.byIcon(Icons.pending_actions_rounded);
      expect(dangLamTab, findsOneWidget);
      await tester.tap(dangLamTab);
      await tester.pumpAndSettle();

      // Verify buttons are rendered
      final detailButtons = find.text('Chi tiết');
      expect(detailButtons, findsNWidgets(2));

      final action1 = find.text('Bắt đầu di chuyển');
      expect(action1, findsOneWidget);

      final action2 = find.text('Đã đến nơi');
      expect(action2, findsOneWidget);

      // Verify that "Chi tiết" and "Bắt đầu di chuyển" on card 1 are on the SAME line (approx same dy)
      final detail1Center = tester.getCenter(detailButtons.at(0));
      final action1Center = tester.getCenter(action1);
      expect((detail1Center.dy - action1Center.dy).abs(), lessThan(5.0),
          reason: 'Buttons on card 1 must be on the same horizontal row, not wrapped!');

      // Verify that "Chi tiết" and "Đã đến nơi" on card 2 are on the SAME line
      final detail2Center = tester.getCenter(detailButtons.at(1));
      final action2Center = tester.getCenter(action2);
      expect((detail2Center.dy - action2Center.dy).abs(), lessThan(5.0),
          reason: 'Buttons on card 2 must be on the same horizontal row, not wrapped!');

      // Ensure no overflow exception was thrown
      expect(tester.takeException(), isNull);
    });
  }
}

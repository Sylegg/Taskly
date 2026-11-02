import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_jobs.dart';

void main() {
  testWidgets('Partner jobs displays date filters, status tags and schedule timeline buffer', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final todayIso = DateTime(now.year, now.month, now.day, 10, 0).toUtc().toIso8601String();
    final todayConflictIso = DateTime(now.year, now.month, now.day, 12, 30).toUtc().toIso8601String();
    final tomorrowIso = DateTime(now.year, now.month, now.day, 9, 0).add(const Duration(days: 1)).toUtc().toIso8601String();

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
                    'id': 'job-eligible-today',
                    'title': 'Vệ sinh máy lạnh hôm nay',
                    'description': 'Bảo dưỡng 1 máy lạnh',
                    'city_snapshot': 'TP. Hồ Chí Minh',
                    'budget_amount': 200000,
                    'partner_net_amount': 180000,
                    'scheduled_at': todayIso,
                    'estimated_duration_minutes': 60,
                    'eligible': true,
                    'statusTag': 'ELIGIBLE',
                    'statusTagLabel': 'Có thể nhận',
                  },
                  {
                    'id': 'job-buffer-short',
                    'title': 'Sửa ống nước thiếu buffer',
                    'description': 'Xung đột đệm 60 phút',
                    'city_snapshot': 'TP. Hồ Chí Minh',
                    'budget_amount': 150000,
                    'partner_net_amount': 135000,
                    'scheduled_at': todayConflictIso,
                    'estimated_duration_minutes': 60,
                    'eligible': false,
                    'reasonCode': 'BUFFER_TOO_SHORT',
                    'reasonMessage': 'Bạn đang có việc đến 12:00. Cần tối thiểu 60 phút dự phòng, nên chỉ có thể nhận việc bắt đầu từ 13:00.',
                    'statusTag': 'BUFFER_TOO_SHORT',
                    'statusTagLabel': 'Thiếu buffer',
                    'earliestEligibleStartAt': DateTime(now.year, now.month, now.day, 13, 0).toUtc().toIso8601String(),
                  },
                  {
                    'id': 'job-tomorrow',
                    'title': 'Dọn dẹp ngày mai',
                    'description': 'Nhận trước ngày mai',
                    'city_snapshot': 'TP. Hồ Chí Minh',
                    'budget_amount': 300000,
                    'partner_net_amount': 270000,
                    'scheduled_at': tomorrowIso,
                    'estimated_duration_minutes': 120,
                    'eligible': true,
                    'statusTag': 'ELIGIBLE',
                    'statusTagLabel': 'Có thể nhận',
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          } else if (path.endsWith('/partner/my-schedule')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'job-scheduled-1',
                    'title': 'Việc đã nhận sáng nay',
                    'status': 'ACCEPTED',
                    'scheduled_at': DateTime(now.year, now.month, now.day, 10, 0).toUtc().toIso8601String(),
                    'scheduled_end_at': DateTime(now.year, now.month, now.day, 12, 0).toUtc().toIso8601String(),
                    'buffer_minutes': 60,
                    'buffer_end_at': DateTime(now.year, now.month, now.day, 13, 0).toUtc().toIso8601String(),
                    'tightGapWithNextJob': true,
                    'nextJobStartAt': DateTime(now.year, now.month, now.day, 13, 0).toUtc().toIso8601String(),
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
                    {'id': 'area-1', 'city': 'TP. Hồ Chí Minh', 'recruiting': true}
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

    // 1. Verify Date Filter Pills render
    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Hôm nay'), findsOneWidget);
    expect(find.text('Ngày mai'), findsOneWidget);
    expect(find.text('7 ngày tới'), findsOneWidget);

    // 2. Verify Status Tag Chips render on job cards
    expect(find.text('Có thể nhận'), findsNWidgets(2));
    expect(find.text('Thiếu buffer'), findsOneWidget);

    // 3. Verify Explanatory buffer warning on ineligible card
    expect(
      find.text('Bạn đang có việc đến 12:00. Cần tối thiểu 60 phút dự phòng, nên chỉ có thể nhận việc bắt đầu từ 13:00.'),
      findsOneWidget,
    );

    // 4. Verify clicking "Chưa thể nhận" button opens explanation modal
    final disabledBtn = find.text('Chưa thể nhận');
    expect(disabledBtn, findsOneWidget);
    await tester.ensureVisible(disabledBtn);
    await tester.tap(disabledBtn);
    await tester.pumpAndSettle();

    expect(find.text('Không thể nhận việc'), findsOneWidget);
    expect(find.text('Xem việc khác'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('Xem việc khác'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể nhận việc'), findsNothing);

    // 5. Switch to "Ngày mai" filter: should only show tomorrow job
    final tomorrowTab = find.text('Ngày mai');
    await tester.ensureVisible(tomorrowTab);
    await tester.tap(tomorrowTab);
    await tester.pumpAndSettle();
    expect(find.text('Dọn dẹp ngày mai'), findsOneWidget);
    expect(find.text('Vệ sinh máy lạnh hôm nay'), findsNothing);

    // 6. Tap "Lịch của tôi" button: switches to timeline view
    final scheduleBtn = find.text('Lịch của tôi');
    await tester.ensureVisible(scheduleBtn);
    await tester.tap(scheduleBtn);
    await tester.pumpAndSettle();

    // Verify timeline view renders buffer block and tight gap warning
    expect(find.text('Lịch làm việc đã nhận & Buffer đệm'), findsOneWidget);
    expect(find.text('Việc đã nhận sáng nay'), findsOneWidget);
    expect(find.textContaining('Buffer nghỉ & di chuyển: 60 phút'), findsOneWidget);
    expect(find.textContaining('Cảnh báo: Ca tiếp theo bắt đầu lúc'), findsOneWidget);

    // Close timeline
    final closeBtn = find.text('Đóng lịch');
    await tester.ensureVisible(closeBtn);
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();
    expect(find.text('Lịch làm việc đã nhận & Buffer đệm'), findsNothing);
  });
}

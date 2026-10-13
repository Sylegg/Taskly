import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_jobs.dart';

void main() {
  testWidgets('Partner status toggle button displays and toggles between online and offline', (tester) async {
    final session = Session(
      api: Api(
        base: 'http://localhost/api/v1',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerJobs(
              session: session,
              application: const {
                'fullName': 'Nguyễn Văn A',
              },
            ),
          ),
        ),
      ),
    );

    // Initial state should be TRỰC TUYẾN
    expect(find.text('TRỰC TUYẾN'), findsOneWidget);

    // Tap to switch to TẠM NGHỈ
    await tester.tap(find.text('TRỰC TUYẾN'));
    await tester.pumpAndSettle();

    expect(find.text('TẠM NGHỈ'), findsOneWidget);
    expect(find.text('Bạn đang ở chế độ Tạm nghỉ'), findsOneWidget);

    // Tap again to switch back to TRỰC TUYẾN
    await tester.tap(find.text('TẠM NGHỈ'));
    await tester.pumpAndSettle();

    expect(find.text('TRỰC TUYẾN'), findsOneWidget);
  });

  testWidgets('Partner status toggle button does not overflow on small screens (320x640)', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = Session(
      api: Api(
        base: 'http://localhost/api/v1',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerJobs(
              session: session,
              application: const {
                'fullName': 'Nguyễn Văn Rất Dài Của Đối Tác TaskLy',
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('TRỰC TUYẾN'), findsOneWidget);

    // Toggle on small screen
    await tester.tap(find.text('TRỰC TUYẾN'));
    await tester.pumpAndSettle();

    expect(find.text('TẠM NGHỈ'), findsOneWidget);
  });

  testWidgets('Partner tabs 1 and 2 display redesigned modern empty state cards and navigate back', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final session = Session(
      api: Api(
        base: 'http://localhost/api/v1',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 1));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerJobs(
              session: session,
              application: const {
                'fullName': 'Nguyễn Văn A',
              },
            ),
          ),
        ),
      ),
    );

    // --- TAB 1 (Đang làm) ---
    await tester.tap(find.text('Đang làm').last);
    await tester.pumpAndSettle();

    expect(find.text('Công việc đang thực hiện'), findsOneWidget);
    expect(find.text('Bạn chưa có công việc nào đang thực hiện'), findsOneWidget);
    expect(find.text('Sẵn sàng thực hiện nhiệm vụ mới'), findsOneWidget);
    expect(find.text('Xem danh sách việc mới'), findsOneWidget);

    // Tap CTA button in Tab 1 to return to Tab 0
    await tester.ensureVisible(find.text('Xem danh sách việc mới'));
    await tester.tap(find.text('Xem danh sách việc mới'));
    await tester.pumpAndSettle();
    expect(find.text('Công việc phù hợp'), findsOneWidget);

    // --- TAB 2 (Đã xong) ---
    await tester.tap(find.text('Đã xong').last);
    await tester.pumpAndSettle();

    expect(find.text('Lịch sử công việc'), findsOneWidget);
    expect(find.text('Chưa có công việc đã hoàn thành'), findsOneWidget);
    expect(find.text('Lịch sử & doanh thu đã thanh toán'), findsOneWidget);
    expect(find.text('Khám phá việc mới ngay'), findsOneWidget);
    // Duplicate customer heading and ugly raw text should NOT be present
    expect(find.text('Công việc của bạn'), findsNothing);
    expect(find.text('Chưa có công việc đã đặt.'), findsNothing);

    // Tap CTA button in Tab 2 to return to Tab 0
    await tester.ensureVisible(find.text('Khám phá việc mới ngay'));
    await tester.tap(find.text('Khám phá việc mới ngay'));
    await tester.pumpAndSettle();
    expect(find.text('Công việc phù hợp'), findsOneWidget);
  });
}

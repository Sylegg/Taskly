import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_account.dart';
import 'package:taskly_mobile/features/partner/partner_help_center.dart';

void main() {
  Session createMockSession() {
    return Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/users/me')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'fullName': 'Minh Vũ',
                  'email': 'minhvuplo09@gmail.com',
                  'phone': '0909876902',
                  'role': 'TASKER',
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'data': {}}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 2));
  }

  testWidgets('PartnerHelpCenter displays all 4 tabs and functionalities', (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = createMockSession();

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerHelpCenter(session: session),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Overview Tab
    expect(find.text('Trung tâm hỗ trợ Đối tác'), findsOneWidget);
    expect(find.text('HOTLINE KHẨN CẤP 24/7'), findsOneWidget);
    expect(find.textContaining('1900 8868'), findsWidgets);
    expect(find.text('Kênh hỗ trợ nhanh'), findsOneWidget);
    expect(find.text('Báo sự cố'), findsOneWidget);
    expect(find.text('Gửi ticket'), findsOneWidget);
    expect(find.text('Hỏi đáp (FAQ)'), findsOneWidget);
    expect(find.text('TaskLy Hub'), findsOneWidget);
    expect(find.text('Chính sách bảo vệ Đối tác TaskLy Care'), findsOneWidget);

    // 2. Switch to Incident Tab (Tab 1)
    await tester.tap(find.text('🚨 Báo sự cố ca làm'));
    await tester.pumpAndSettle();

    expect(find.text('Khách không có nhà / Không mở cửa'), findsOneWidget);
    expect(find.text('Khách yêu cầu việc nguy hiểm / quá tải'), findsOneWidget);
    expect(find.text('Địa chỉ khách hàng sai lệch quá xa (> 5km)'), findsOneWidget);
    expect(find.text('Khách không chịu thanh toán tiền mặt'), findsOneWidget);
    expect(find.text('Sự cố tai nạn hoặc quấy rối / đe dọa'), findsOneWidget);

    // 3. Switch to Ticket Tab (Tab 2)
    await tester.tap(find.text('📝 Gửi Ticket CSKH'));
    await tester.pumpAndSettle();

    expect(find.text('Tạo phiếu yêu cầu mới'), findsOneWidget);
    expect(find.text('Lịch sử yêu cầu hỗ trợ của bạn'), findsOneWidget);
    expect(find.text('TK-8921'), findsOneWidget);

    // Fill and submit ticket
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ví dụ: Cần đối soát lại tiền tip khách chuyển qua app'),
      'Kiểm tra lại số dư ví Tasker',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mô tả rõ ràng vấn đề để chuyên viên xử lý nhanh nhất...'),
      'Tôi vừa hoàn thành đơn lúc 11:00 nhưng ví chưa hiển thị tiền cộng.',
    );
    await tester.tap(find.text('Gửi phiếu yêu cầu hỗ trợ'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();

    // Verify newly added ticket in history
    expect(find.text('Kiểm tra lại số dư ví Tasker'), findsOneWidget);
    expect(find.text('Chờ tiếp nhận'), findsOneWidget);

    // 4. Switch to FAQ Tab (Tab 3)
    await tester.tap(find.text('❓ Hỏi đáp (FAQ)'));
    await tester.pumpAndSettle();

    expect(find.text('Khi nào tiền công việc được cộng vào ví Tasker?'), findsOneWidget);
    expect(find.text('Phí nền tảng TaskLy là bao nhiêu và tính thế nào?'), findsOneWidget);

    // Test FAQ category filter chip
    await tester.tap(find.text('Đồng phục'));
    await tester.pumpAndSettle();
    expect(find.text('Quy định đồng phục TaskLy khi nhận việc?'), findsOneWidget);
    expect(find.text('Khi nào tiền công việc được cộng vào ví Tasker?'), findsNothing);

    // Test FAQ Search
    await tester.enterText(find.byType(TextField).first, 'tiền');
    await tester.pumpAndSettle();
    expect(find.text('Tất cả'), findsOneWidget);
    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tiền'), findsWidgets);
  });

  testWidgets('PartnerAccount has Help Center items and Academy item', (tester) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = createMockSession();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartnerAccount(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify sections and items
    expect(find.text('Hồ sơ & hoạt động'), findsOneWidget);
    expect(find.text('Cam kết & bảo vệ dữ liệu'), findsOneWidget);
    expect(find.text('Lịch hẹn văn phòng TaskLy Hub'), findsOneWidget);
    expect(find.text('Hợp đồng & Hồ sơ đối tác'), findsOneWidget);

    // Verify Dedicated Uniform Shop Section
    expect(find.text('Đồng phục & Trang thiết bị'), findsOneWidget);
    expect(find.text('Cửa hàng Đồng phục & Trang bị'), findsOneWidget);

    // Verify Support Section
    expect(find.text('Trung tâm hỗ trợ & Trợ giúp'), findsOneWidget);
    expect(find.text('Trung tâm hỗ trợ Đối tác (Help Center)'), findsOneWidget);
    expect(find.text('Báo cáo sự cố khi làm việc'), findsOneWidget);
    expect(find.text('Gửi phiếu yêu cầu hỗ trợ (Ticket)'), findsOneWidget);
    expect(find.text('Quy chuẩn dịch vụ & Cẩm nang 5 sao'), findsOneWidget);

    // Verify Buttons
    expect(find.text('Đổi mật khẩu'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    // Test tap Help Center tile opens PartnerHelpCenter
    await tester.tap(find.text('Trung tâm hỗ trợ Đối tác (Help Center)'));
    await tester.pumpAndSettle();

    expect(find.byType(PartnerHelpCenter), findsOneWidget);
  });
}

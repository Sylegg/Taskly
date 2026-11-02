import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_final_documents.dart';

void main() {
  const samplePng =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4WQAAAAASUVORK5CYII=';

  testWidgets('approved documents can only be viewed even from default account entry', (tester) async {
    final session = Session(api: Api(base: 'http://test/api/v1', client: MockClient((request) async {
      expect(request.method, 'GET');
      return http.Response(jsonEncode({'success': true, 'data': [{'portrait': samplePng, 'contract': samplePng, 'read_only': true, 'approved': true}]}), 200, headers: {'content-type': 'application/json'});
    })))..access = 'test-token'..expires = DateTime.now().add(const Duration(hours: 1));
    await tester.pumpWidget(MaterialApp(home: RecruitmentFinalDocuments(session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Đã duyệt chính thức · Hồ sơ chỉ được xem'), findsOneWidget);
    expect(find.text('Chọn ảnh chân dung'), findsNothing);
    expect(find.text('Chọn ảnh hợp đồng đã ký'), findsNothing);
    expect(find.text('Xóa ảnh'), findsNothing);
    expect(find.text('Gửi admin kiểm duyệt'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(Image), findsNWidgets(2));
  });

  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('RecruitmentFinalDocuments at width $width renders guidelines, documents and submits', (tester) async {
      tester.view.physicalSize = Size(width, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final requestedUrls = <String>[];
      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            requestedUrls.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/v1/partner/final-documents' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/final-documents' && request.method == 'POST') {
              final body = jsonDecode(request.body);
              expect(body['portrait'], samplePng);
              expect(body['contract'], samplePng);
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'id': 'app-123',
                    'status': 'FINAL_REVIEW',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(jsonEncode({'success': false}), 404);
          }),
        ),
      )
        ..access = 'test-token'
        ..expires = DateTime.now().add(const Duration(hours: 1));

      await tester.pumpWidget(
        MaterialApp(
          home: RecruitmentFinalDocuments(
            session: session,
            initialPortrait: samplePng,
            initialContract: samplePng,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header and Badges
      expect(find.text('CHẶNG 4/4'), findsOneWidget);
      expect(find.text('• Hồ sơ & Hợp đồng'), findsOneWidget);

      // Verify Mandatory Rules (User's explicit requirement: Office setting & uniform)
      expect(find.text('QUY ĐỊNH ẢNH CHÂN DUNG BẮT BUỘC'), findsOneWidget);
      expect(find.textContaining('Bắt buộc chụp tại Văn phòng TaskLy'), findsOneWidget);
      expect(find.textContaining('Bắt buộc mặc Áo đồng phục TaskLy'), findsOneWidget);

      // Verify Document Upload Cards
      expect(find.text('1. Ảnh chân dung tại văn phòng'), findsOneWidget);
      expect(find.text('2. Hợp đồng đối tác TaskLy'), findsOneWidget);
      expect(find.text('Chọn ảnh chân dung'), findsOneWidget);
      expect(find.text('Chọn ảnh hợp đồng đã ký'), findsOneWidget);

      // Verify Commitment Checkbox
      expect(find.textContaining('Tôi cam kết ảnh chân dung được chụp trực tiếp tại Văn phòng đại diện TaskLy'), findsOneWidget);

      // Verify Submit Button is enabled in bottom sheet
      final submitFinder = find.widgetWithText(FilledButton, 'Gửi admin kiểm duyệt');
      expect(submitFinder, findsOneWidget);

      // Tap submit button
      await tester.tap(submitFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      // Ensure POST request was dispatched
      expect(requestedUrls, contains('POST /api/v1/partner/final-documents'));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('RecruitmentFinalDocuments shows empty state and requires checklist before submit', (tester) async {
    final session = Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 1));

    tester.view.physicalSize = const Size(375, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentFinalDocuments(session: session),
      ),
    );
    await tester.pumpAndSettle();

    // Verify empty state placeholders
    expect(find.text('Tải ảnh chân dung chụp tại Văn phòng TaskLy'), findsOneWidget);
    expect(find.text('Tải ảnh Hợp đồng đã ký tên'), findsOneWidget);

    // Verify submit button is disabled when empty
    final submitButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Gửi admin kiểm duyệt'));
    expect(submitButton.onPressed, isNull);
  });
}

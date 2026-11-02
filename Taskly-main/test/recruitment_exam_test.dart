import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_exam.dart';

void main() {
  for (final width in [320.0, 375.0, 430.0]) {
    testWidgets('RecruitmentExam at width $width renders intro and active exam flow', (tester) async {
      final requests = <String>[];
      final session = Session(
        api: Api(
          base: 'http://test/api/v1',
          client: MockClient((request) async {
            requests.add('${request.method} ${request.url.path}');
            if (request.url.path == '/api/v1/partner/exam' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'exam_minutes': 15,
                    'pass_mark': 16,
                    'remaining_attempts': 3,
                    'review_topics': ['An toàn', 'Quy tắc ứng xử'],
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/exam/results' && request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path == '/api/v1/partner/exam/attempts' && request.method == 'POST') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'id': 'attempt-1',
                    'status': 'IN_PROGRESS',
                    'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
                    'answers': {},
                    'questions': [
                      {
                        'id': 'q1',
                        'text': 'Đối tác cần đến trước giờ hẹn bao lâu?',
                        'options': ['5 phút', '10 phút', '30 phút', 'Không cần đến trước'],
                      },
                      {
                        'id': 'q2',
                        'text': 'Trang phục chuẩn khi đi làm là gì?',
                        'options': ['Áo polo TaskLy', 'Đồ tự do', 'Đồ ngủ', 'Áo khoác gió'],
                      },
                    ],
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            if (request.url.path.contains('/answers') && request.method == 'PUT') {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'id': 'attempt-1',
                    'status': 'IN_PROGRESS',
                    'expiresAt': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
                    'answers': {'q1': 1},
                    'questions': [
                      {
                        'id': 'q1',
                        'text': 'Đối tác cần đến trước giờ hẹn bao lâu?',
                        'options': ['5 phút', '10 phút', '30 phút', 'Không cần đến trước'],
                      },
                      {
                        'id': 'q2',
                        'text': 'Trang phục chuẩn khi đi làm là gì?',
                        'options': ['Áo polo TaskLy', 'Đồ tự do', 'Đồ ngủ', 'Áo khoác gió'],
                      },
                    ],
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              jsonEncode({'success': true, 'data': {}}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      session.access = 'test-token';
      session.expires = DateTime.now().add(const Duration(hours: 1));

      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: RecruitmentExam(session: session)));
      await tester.pumpAndSettle();

      // Check Intro view
      expect(find.text('Bài thi đầu vào'), findsOneWidget);
      expect(find.text('20 câu • 4 lựa chọn mỗi câu'), findsOneWidget);
      expect(find.text('Bắt đầu / thi lại'), findsOneWidget);

      // Tap start exam
      await tester.tap(find.text('Bắt đầu / thi lại'));
      await tester.pumpAndSettle();

      // In running exam view
      expect(find.text('Đang làm bài thi'), findsOneWidget);
      expect(find.text('Câu 1: Đối tác cần đến trước giờ hẹn bao lâu?'), findsOneWidget);
      expect(find.text('10 phút'), findsOneWidget);

      // Choose answer
      await tester.tap(find.text('10 phút'));
      await tester.pumpAndSettle();

      // Tap Next question
      await tester.tap(find.text('Tiếp'));
      await tester.pumpAndSettle();

      expect(find.text('Câu 2: Trang phục chuẩn khi đi làm là gì?'), findsOneWidget);

      // Verify submit button is visible
      expect(find.text('Nộp bài'), findsOneWidget);
    });
  }
}

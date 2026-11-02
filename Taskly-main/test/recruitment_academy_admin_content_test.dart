import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/recruitment_academy.dart';

void main() {
  for (final scenario in ['empty', 'published', 'error']) {
    testWidgets('Academy $scenario shows Admin content and seconds', (
      tester,
    ) async {
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  expect(request.url.path, '/api/v1/partner/training/courses');
                  final data = scenario == 'published'
                      ? [
                          {
                            'lesson': {
                              'id': 'lesson',
                              'title': 'Video của Admin',
                              'durationSeconds': 125,
                              'demo': false,
                            },
                            'status': 'AVAILABLE',
                            'watchedSeconds': 50,
                          },
                        ]
                      : [];
                  return http.Response(
                    jsonEncode(
                      scenario == 'error'
                          ? {
                              'success': false,
                              'error': {
                                'code': 'OFFLINE',
                                'message': 'Không kết nối được',
                              },
                            }
                          : {'success': true, 'data': data},
                    ),
                    scenario == 'error' ? 503 : 200,
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
        MaterialApp(home: RecruitmentAcademy(session: session)),
      );
      await tester.pumpAndSettle();
      if (scenario == 'published') {
        expect(find.text('Video của Admin'), findsOneWidget);
        expect(find.textContaining('Thời lượng: 125 giây'), findsOneWidget);
        expect(find.textContaining('Đã xem: 50/125 giây'), findsOneWidget);
      } else if (scenario == 'empty') {
        expect(find.textContaining('Admin chưa đăng video'), findsOneWidget);
      } else {
        expect(find.textContaining('Không kết nối được'), findsOneWidget);
        expect(find.text('Thử tải lại'), findsOneWidget);
      }
      expect(find.textContaining('Bài 1: Quy trình giao nhận'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    });
  }
}

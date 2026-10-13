import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/features/customer_community.dart';

void main() {
  testWidgets(
    'community tabs use published metadata and likes are saved through API',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool liked = false;
      int reactionCalls = 0;
      final session =
          Session(
              api: Api(
                base: 'http://test/api/v1',
                client: MockClient((request) async {
                  dynamic data = [];
                  if (request.url.path.endsWith('/public/services')) {
                    data = {'services': []};
                  }
                  if (request.url.path.endsWith('/public/articles')) {
                    data = [
                      {
                        'id': 'story',
                        'title': 'Câu chuyện từ Admin',
                        'summary': 'Chia sẻ kinh nghiệm',
                        'content': 'Nội dung đầy đủ',
                        'imageUrl': '/api/v1/public/article-images/test.png',
                        'createdAt': '2026-10-09T10:00:00Z',
                        'authorName': 'TaskLy',
                        'hashtag': 'ChuyenNha',
                        'groupName': 'Chuyện nhà',
                        'featured': true,
                      },
                    ];
                  }
                  if (request.url.path.endsWith('/reaction')) {
                    reactionCalls++;
                    liked = jsonDecode(request.body)['selected'];
                  }
                  if (request.url.path.endsWith('/engagement') ||
                      request.url.path.endsWith('/reaction')) {
                    data = {
                      'likes': liked ? 1 : 0,
                      'comments': 0,
                      'reposts': 0,
                      'liked': liked,
                      'reposted': false,
                    };
                  }
                  return http.Response(
                    jsonEncode({'success': true, 'data': data}),
                    200,
                    headers: {'content-type': 'application/json'},
                  );
                }),
              ),
            )
            ..access = 'test-token'
            ..expires = DateTime.now().add(const Duration(hours: 1));
      final repository = ApiCustomerRepository(session);
      final controller = CustomerController(repository);
      controller.data = repository.store.snapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: controller,
            builder: (context, _) => CustomerCommunity(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Câu chuyện từ Admin'), findsOneWidget);
      expect(find.text('#ChuyenNha'), findsOneWidget);
      await tester.tap(find.text('Video ngắn'));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có video ngắn nào.'), findsOneWidget);
      expect(find.text('Câu chuyện từ Admin'), findsNothing);
      await tester.tap(find.text('Bảng tin'));
      await tester.pumpAndSettle();
      expect(find.text('Nhóm chung'), findsNothing);
      expect(find.text('Chia sẻ cảm nghĩ của bạn'), findsNothing);
      expect(find.byTooltip('Tài khoản'), findsNothing);
      expect(find.byTooltip('Tìm kiếm bài viết'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Thông báo'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.favorite_border_rounded));
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();
      expect(reactionCalls, 1);
      expect(liked, isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      session.dispose();
    },
  );
}

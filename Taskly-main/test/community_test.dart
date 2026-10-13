import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/community_screens.dart';

void main() {
  testWidgets(
    'community opens the selected real article and displays full content',
    (tester) async {
      final a = CommunityArticle(
        id: 'real-id',
        title: 'Chuyện nhà',
        summary: 'Giới thiệu',
        content: 'Đoạn một\n\nĐoạn hai',
        imageUrl: 'https://taskly.example/image.png',
        createdAt: DateTime(2026, 10, 9),
      );
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityFeed(
                articles: [a],
                onArticle: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('community-article-real-id')));
      expect(selected, 'real-id');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommunityArticleView(article: a),
            ),
          ),
        ),
      );
      expect(find.text(a.content), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

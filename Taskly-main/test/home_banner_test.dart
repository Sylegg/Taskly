import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/home/home_components.dart';

void main() {
  test('banner repository resolves backend image URLs', () async {
    final session = Session(
      api: Api(
        base: 'http://localhost:8080/api/v1',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/public/banners');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 'one',
                  'title': 'Ảnh admin',
                  'imageUrl': '/api/v1/public/banner-images/one/hash.png',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    session.access = 'access';
    session.expires = DateTime.now().add(const Duration(hours: 1));
    final repository = ApiCustomerRepository(session);
    await repository.loadBanners();
    expect(
      repository.store.snapshot().banners.single.imageUrl,
      'http://localhost:8080/api/v1/public/banner-images/one/hash.png',
    );
  });
  testWidgets('banners hide when empty and swipe through admin images', (
    tester,
  ) async {
    Widget host(List<HomeBanner> banners) => MaterialApp(
      home: Scaffold(
        body: SizedBox(width: 360, child: HomePromoSection(banners: banners)),
      ),
    );
    await tester.pumpWidget(host([]));
    expect(find.byType(PageView), findsNothing);
    await tester.pumpWidget(
      host(const [
        HomeBanner(
          id: 'one',
          title: 'Banner 1',
          imageUrl: 'https://example.test/one.png',
        ),
        HomeBanner(
          id: 'two',
          title: 'Banner 2',
          imageUrl: 'https://example.test/two.png',
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('home-banner-one')),
    );
    expect(image.fit, BoxFit.contain);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('home-banner-two')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

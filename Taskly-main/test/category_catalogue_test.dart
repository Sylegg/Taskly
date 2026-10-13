import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/data/mock/mock_customer_repository.dart';
import 'package:taskly_mobile/data/mock/mock_data_store.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/customer_view.dart';
import 'package:taskly_mobile/features/home/home_components.dart';
import 'package:taskly_mobile/shared/category_symbol.dart';

void main() {
  test(
    'catalogue uses category icons and preserves service membership',
    () async {
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient(
            (request) async => http.Response(
              jsonEncode({
                'success': true,
                'data':
                    (request.url.path.endsWith('/banners') ||
                        request.url.path.endsWith('/articles'))
                    ? []
                    : {
                        'categories': [
                          {
                            'id': 'cat',
                            'name': 'Danh mục',
                            'slug': 'cat',
                            'iconKey': 'pets',
                            'iconUrl':
                                '/api/v1/public/category-icons/cat/hash.png',
                          },
                        ],
                        'services': [
                          {
                            'id': 'svc',
                            'name': 'Dịch vụ',
                            'slug': 'svc',
                            'iconKey': 'repair',
                            'category': {'id': 'cat'},
                            'currency': 'VND',
                            'suggestedPriceMin': 1,
                          },
                        ],
                      },
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final data = await ApiCustomerRepository(session).refreshCatalogue();
      expect(data.categories.single.iconKey, 'pets');
      expect(data.services.single.categoryId, 'cat');
      expect(
        data.categories.single.iconUrl,
        contains('/public/category-icons/'),
      );
    },
  );
  testWidgets('category arc has dedicated badges and opens category ids', (
    tester,
  ) async {
    String? selected;
    var allOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: ArcServiceCarousel(
              categories: const [
                ServiceCategory(
                  id: 'cat',
                  name: 'Danh mục thật',
                  slug: 'cat',
                  iconKey: 'pets',
                ),
              ],
              onService: (id) => selected = id,
              onAllServices: () => allOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CategoryBadge), findsWidgets);
    expect(find.byType(CategorySymbol), findsWidgets);
    await tester.tap(find.text('Danh mục thật').hitTestable().first);
    expect(selected, 'cat');
    await tester.tap(find.byKey(const ValueKey('home-all-categories')));
    expect(allOpened, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('catalogue shows all services in their own category sections', (
    tester,
  ) async {
    final store = MockDataStore()..authenticated = true;
    store.categories = const [
      ServiceCategory(id: 'cat', name: 'Danh mục thật', slug: 'cat'),
      ServiceCategory(id: 'other', name: 'Nhóm khác', slug: 'other'),
    ];
    store.catalogueOverride = const [
      Service(
        'inside',
        'Dịch vụ trong nhóm',
        '',
        'pets',
        1,
        '',
        [],
        categoryId: 'cat',
      ),
      Service(
        'outside',
        'Dịch vụ khác',
        '',
        'repair',
        1,
        '',
        [],
        categoryId: 'other',
      ),
    ];
    final controller = CustomerController(MockCustomerRepository(store: store))
      ..data = store.snapshot()
      ..categoryFilter = 'cat'
      ..root(PageId.services);
    await tester.pumpWidget(
      MaterialApp(home: CustomerView(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dịch vụ trong nhóm'), findsOneWidget);
    expect(find.byKey(const ValueKey('category-section-cat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('category-section-other')),
      findsOneWidget,
    );
    expect(find.text('Dịch vụ khác'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    store.dispose();
  });
}

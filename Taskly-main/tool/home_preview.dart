import 'package:flutter/material.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/core/theme.dart';
import 'package:taskly_mobile/data/mock/mock_customer_repository.dart';
import 'package:taskly_mobile/data/mock/mock_data_store.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/home/customer_home.dart';

/// Explicit design fixtures; never used by the signed-in production entry.
MockDataStore homeFixture(String scenario) {
  final store = MockDataStore();
  store.categories = const [
    ServiceCategory(
      id: 'cat-cleaning',
      name: 'Dọn dẹp nhà cửa',
      slug: 'cleaning',
      iconKey: 'cleaning',
    ),
    ServiceCategory(
      id: 'cat-repair',
      name: 'Sửa chữa',
      slug: 'repair',
      iconKey: 'repair',
    ),
    ServiceCategory(
      id: 'cat-moving',
      name: 'Chuyển nhà',
      slug: 'moving',
      iconKey: 'moving',
    ),
    ServiceCategory(
      id: 'cat-pets',
      name: 'Thú cưng',
      slug: 'pets',
      iconKey: 'pets',
    ),
    ServiceCategory(
      id: 'cat-shopping',
      name: 'Mua sắm',
      slug: 'shopping',
      iconKey: 'shopping',
    ),
  ];

  store.authenticated = true;
  store.profile = const Profile(
    'Nguyễn Minh',
    '0901234567',
    'minh@example.test',
    '',
  );
  store.addresses = const [
    Address('home', 'Nhà', 'Thủ Đức', '', isDefault: true),
    Address('office', 'Văn phòng', 'Bình Thạnh', ''),
  ];
  if (scenario == 'new') {
    store.tasks = [];
    store.conversations = [];
    store.notifications = [];
  } else if (scenario == 'no-active') {
    store.tasks = store.tasks
        .where((t) => t.status == TaskStatus.paid)
        .toList();
    store.notifications = [];
  }
  return store;
}

HomeExtras previewExtras(String scenario) => HomeExtras(
  offline: scenario == 'offline',
  loading: scenario == 'loading',
  favoritePartnerIds: scenario == 'new'
      ? const []
      : const ['minh-anh', 'tuan-kiet'],
  rewardPoints: scenario == 'new' ? null : 240,
  serviceRatings: const {
    'cleaning': 4.9,
    'moving': 4.8,
    'assembly': 4.9,
    'shopping': 4.8,
  },
);

void main() {
  const scenario = String.fromEnvironment(
    'HOME_PREVIEW',
    defaultValue: 'returning',
  );
  final store = homeFixture(scenario);
  final controller = CustomerController(MockCustomerRepository(store: store))
    ..data = store.snapshot()
    ..root(PageId.home);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: TaskLyCustomerHome(
        controller: controller,
        extras: previewExtras(scenario),
      ),
    ),
  );
}

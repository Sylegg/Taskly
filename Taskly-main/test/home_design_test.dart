import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/core/theme.dart';
import 'package:taskly_mobile/data/mock/mock_customer_repository.dart';
import 'package:taskly_mobile/features/home/customer_home.dart';
import 'package:taskly_mobile/features/home/home_components.dart';

import '../tool/home_preview.dart';

const capture = bool.fromEnvironment('HOME_CAPTURE');
final boundaryKey = GlobalKey();

ThemeData previewTheme() {
  final base = AppTheme.light;
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'HomePreview',
      fontFamilyFallback: const ['HomeEmoji', 'HomeSymbols'],
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style!.copyWith(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'HomePreview',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style!.copyWith(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'HomePreview',
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

Future<void> saveFrame(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/home-design/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (capture) {
      await (FontLoader('HomeSymbols')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/seguisym.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader('HomeEmoji')..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/seguiemj.ttf').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      final regular = File('C:/Windows/Fonts/segoeui.ttf');
      final bold = File('C:/Windows/Fonts/segoeuib.ttf');
      if (regular.existsSync()) {
        await (FontLoader('HomePreview')..addFont(
              Future.value(ByteData.sublistView(regular.readAsBytesSync())),
            ))
            .load();
        await (FontLoader('HomePreviewBold')..addFont(
              Future.value(ByteData.sublistView(bold.readAsBytesSync())),
            ))
            .load();
      }
    }
  });
  for (final size in [
    const Size(360, 800),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final scenario in [
      'returning',
      'new',
      'no-active',
      'loading',
      'offline',
      'error',
    ]) {
      testWidgets(
        '$scenario fits ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final store = homeFixture(scenario);
          final c = CustomerController(MockCustomerRepository(store: store))
            ..data = store.snapshot()
            ..root(PageId.home);
          if (scenario == 'error') c.error = 'Network failure';
          final theme = capture ? previewTheme() : AppTheme.light;
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                home: TaskLyCustomerHome(
                  controller: c,
                  extras: previewExtras(scenario),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(TaskLyBottomNav), findsOneWidget);
          if (scenario == 'loading') {
            expect(find.byType(HomeSkeleton), findsOneWidget);
            expect(find.byType(CircularProgressIndicator), findsNothing);
          } else {
            if (scenario == 'error') {
              expect(find.text('Không thể tải dữ liệu'), findsOneWidget);
              expect(find.text('Network failure'), findsOneWidget);
              await tester.scrollUntilVisible(
                find.byKey(const ValueKey('home-category-cat-cleaning')),
                100,
                scrollable: find.byType(Scrollable).first,
              );
            }
            expect(find.byType(CategoryBadge), findsWidgets);
            if (scenario == 'offline') {
              expect(find.text('Bạn đang ngoại tuyến'), findsOneWidget);
            }
          }
          if (capture) {
            await saveFrame(
              tester,
              '$scenario-${size.width.toInt()}x${size.height.toInt()}',
            );
          }
          if (scenario != 'loading') {
            final scroll = tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position;
            // Walk the whole screen to lay out every conditional component.
            for (
              double offset = 450;
              offset < scroll.maxScrollExtent;
              offset += 450
            ) {
              scroll.jumpTo(offset);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              if (capture && size.width == 390) {
                await saveFrame(tester, '$scenario-scroll-${offset.toInt()}');
              }
            }
            scroll.jumpTo(scroll.maxScrollExtent);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (scenario == 'new' || scenario == 'no-active') {
              expect(find.byType(ActiveTaskCard), findsNothing);
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
          c.dispose();
          store.dispose();
        },
      );
    }
  }

  testWidgets('Export individual reusable components', (tester) async {
    if (!capture) return;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = homeFixture('returning');
    final data = store.snapshot();
    final active = data.tasks.first;
    final done = data.tasks.last;
    void noop() {}
    final components = <String, (Size, Widget)>{
      'component-header': (
        const Size(390, 440),
        TaskLyHomeHeader(
          name: 'Minh',
          address: 'Nhà · Thủ Đức',
          unread: true,
          onNotifications: noop,
          onAddress: noop,
          onSearch: (_) {},
          onBook: noop,
        ),
      ),
      'component-service-category': (
        const Size(160, 150),
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ServiceIcon(index: 0),
            SizedBox(height: 10),
            Text('Dọn nhà'),
          ],
        ),
      ),
      'component-service-grid': (
        const Size(390, 290),
        ServiceGrid(onService: (_) {}),
      ),
      'component-active-task': (
        const Size(390, 360),
        ActiveTaskCard(
          task: active,
          service: data.service(active.draft.serviceId),
          partner: data.tasker(active.taskerId!),
          onDetails: noop,
          onTrack: noop,
          onMessage: noop,
          eta: 'Dự kiến đến 09:20',
        ),
      ),
      'component-book-again': (
        const Size(390, 160),
        BookAgainCard(
          task: done,
          service: data.service(done.draft.serviceId),
          partner: data.tasker(done.taskerId!),
          onBook: noop,
        ),
      ),
      'component-favorite-partner': (
        const Size(210, 280),
        FavoritePartnerCard(
          partner: data.taskers.first,
          skill: 'Dọn nhà',
          onBook: noop,
        ),
      ),
      'component-assistant': (
        const Size(390, 250),
        TaskLyAssistantCard(
          name: 'Minh',
          service: 'Dọn nhà',
          onBook: noop,
          onDismiss: noop,
        ),
      ),
      'component-rewards': (
        const Size(390, 240),
        RewardsProgressCard(points: 240, target: 300, onTap: noop),
      ),
      'component-recommended-service': (
        const Size(218, 300),
        RecommendedServiceCard(
          service: data.services.first,
          onTap: noop,
          rating: 4.9,
        ),
      ),
      'component-upcoming-task': (
        const Size(390, 180),
        UpcomingTaskCard(
          task: active,
          service: data.services.first,
          onTap: noop,
        ),
      ),
      'component-bottom-navigation': (
        const Size(390, 150),
        TaskLyBottomNav(selected: 0, onSelected: (_) {}),
      ),
    };
    for (final entry in components.entries) {
      tester.view.physicalSize = entry.value.$1;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: previewTheme(),
            home: Scaffold(
              backgroundColor: HomeColors.background,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: entry.value.$2,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await saveFrame(tester, entry.key);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    store.dispose();
  });

  testWidgets('Home respects safe areas and enlarged text on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    final store = homeFixture('new');
    final c = CustomerController(MockCustomerRepository(store: store))
      ..data = store.snapshot();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: TaskLyCustomerHome(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    store.dispose();
  });

  testWidgets(
    'Search, address selection, assistant dismissal and repeat booking work',
    (tester) async {
      final store = homeFixture('returning');
      final c = CustomerController(MockCustomerRepository(store: store))
        ..data = store.snapshot()
        ..root(PageId.home);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: TaskLyCustomerHome(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(AddressSelector));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Văn phòng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Văn phòng · Bình Thạnh'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Dọn');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(c.route.page, PageId.services);
      expect(c.search, 'Dọn');
      c.root(PageId.home);
      await tester.scrollUntilVisible(
        find.byType(TaskLyAssistantCard),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.byType(TaskLyAssistantCard), findsNothing);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt dịch vụ ngay'));
      await tester.pumpAndSettle();
      expect(c.route.page, PageId.create);
      expect(c.draft!.address.id, 'office');
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      store.dispose();
    },
  );
}

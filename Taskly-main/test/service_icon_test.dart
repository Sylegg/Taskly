import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/core/theme.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/home/home_components.dart';
import 'package:taskly_mobile/shared/service_symbol.dart';

const uploadedIcon =
    'https://taskly.example/api/v1/public/service-icons/1/hash.png';

Service service({String iconKey = 'pets', String iconUrl = ''}) => Service(
  'database-id-1',
  'Dịch vụ của tôi',
  '',
  iconKey,
  100000,
  '',
  [],
  slug: 'home-cleaning',
  iconUrl: iconUrl,
);

Widget host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: 360, child: Center(child: child)),
    ),
  ),
);

Finder preset(String key) => find.byWidgetPredicate(
  (widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == 'assets/service-icons/$key.png',
);
void main() {
  testWidgets(
    'popular section shows only configured services and opens real ids',
    (tester) async {
      String? selected;
      const featured = Service(
        'featured-id',
        'Dọn nhà',
        '',
        'pets',
        1,
        '',
        [],
        popular: true,
      );
      await tester.pumpWidget(
        host(
          PopularServicesCard(
            services: [service(), featured],
            onService: (id) => selected = id,
          ),
        ),
      );
      expect(find.text('Phổ biến'), findsOneWidget);
      expect(find.text('Dọn nhà'), findsOneWidget);
      expect(find.text('Dịch vụ của tôi'), findsNothing);
      expect(preset('pets'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('popular-service-featured-id')),
      );
      expect(selected, 'featured-id');
      await tester.pumpWidget(
        host(PopularServicesCard(services: [service()], onService: (_) {})),
      );
      expect(find.text('Phổ biến'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home carousel honors admin preset over the service name', (
    tester,
  ) async {
    String? selected;
    const configured = Service(
      'real-api-id',
      'Vệ sinh máy lạnh',
      '',
      'pets',
      100000,
      '',
      [],
      slug: 'air-conditioning',
    );
    await tester.pumpWidget(
      host(
        ArcServiceCarousel(
          services: const [configured],
          onService: (id) => selected = id,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(preset('pets'), findsWidgets);
    expect(preset('aircon'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('home-service-0')).hitTestable().first,
    );
    expect(selected, 'real-api-id');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty API catalogue does not show demo carousel services', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(ArcServiceCarousel(services: const [], onService: (_) {})),
    );
    expect(find.text('Chưa có dịch vụ đang hoạt động.'), findsOneWidget);
    expect(find.byType(ServiceSymbol), findsNothing);
    expect(find.textContaining('sofa'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carousel keeps distinct database services with the same name', (
    tester,
  ) async {
    const services = [
      Service('id-first', 'Dịch vụ', '', 'pets', 1, '', [], slug: 'pets'),
      Service('id-second', 'Dịch vụ', '', 'wifi', 1, '', [], slug: 'wifi'),
    ];
    await tester.pumpWidget(
      host(ArcServiceCarousel(services: services, onService: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(preset('pets'), findsWidgets);
    expect(preset('wifi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'larger carousel remains usable on narrow screens with enlarged text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(1.6),
              ),
              child: SizedBox(
                width: 320,
                child: ArcServiceCarousel(
                  services: [service()],
                  onService: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'catalogue retains administrator preset and resolves images on API host',
    () {
      final session = Session(
        api: Api(base: 'https://192.168.1.28:8443/api/v1/'),
      );
      final repository = ApiCustomerRepository(session);
      addTearDown(() {
        repository.store.dispose();
        session.api.client.close();
        session.dispose();
      });
      repository.updateCatalogue({
        'services': [
          {
            'id': '1',
            'slug': 'home-cleaning',
            'iconKey': 'pets',
            'popular': true,
            'iconUrl': '/api/v1/public/service-icons/1/hash.png',
            'name': 'Dọn nhà',
            'suggestedPriceMin': 100000,
            'currency': 'VND',
          },
          for (final iconKey in [null, '   '])
            {
              'id': 'fallback-$iconKey',
              'slug': 'sofa-cleaning',
              'iconKey': iconKey,
              'name': 'Vệ sinh sofa',
              'suggestedPriceMin': 120000,
              'currency': 'VND',
            },
        ],
      });
      final services = repository.store.snapshot().services;
      expect(services.first.iconKey, 'pets');
      expect(services.first.popular, isTrue);
      expect(services.first.slug, 'home-cleaning');
      expect(
        services.first.iconUrl,
        'https://192.168.1.28:8443/api/v1/public/service-icons/1/hash.png',
      );
      for (final fallback in services.skip(1)) {
        expect(fallback.iconKey, 'sofa-cleaning');
        expect(fallback.iconUrl, isEmpty);
        expect(fallback.popular, isFalse);
      }
    },
  );

  test(
    'public image resolution supports production URLs and Android emulator',
    () {
      final configured = Api(base: 'https://api.taskly.example/api/v1');
      addTearDown(configured.client.close);
      expect(configured.publicAssetUrl(uploadedIcon), uploadedIcon);
      expect(configured.publicAssetUrl(null), isEmpty);
      expect(configured.publicAssetUrl('data:image/png;base64,abc'), isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final emulator = Api();
      addTearDown(emulator.client.close);
      expect(
        emulator.publicAssetUrl('/api/v1/public/service-icons/1/hash.png'),
        'http://10.0.2.2:8080/api/v1/public/service-icons/1/hash.png',
      );
    },
  );

  test(
    'every configured preset resolves and legacy service aliases remain valid',
    () {
      for (final preset in [
        'cleaning',
        'sparkles',
        'sofa',
        'bed',
        'aircon',
        'repair',
        'laundry',
        'kitchen',
        'assembly',
        'moving',
        'packing',
        'shopping',
        'pets',
        'computer',
        'wifi',
        'iron',
      ]) {
        expect(
          serviceIcon(preset),
          isNot(Icons.grid_view_rounded),
          reason: preset,
        );
      }
      expect(serviceIcon('grid'), Icons.grid_view_rounded);
      expect(serviceIcon('sofa-cleaning'), serviceIcon('sofa'));
      expect(serviceIcon('mattress-cleaning'), serviceIcon('bed'));
      expect(serviceIcon('wifi-setup'), serviceIcon('wifi'));
    },
  );

  testWidgets(
    'popular services honor preset before slug and keep real service id',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        host(
          ServiceGrid(services: [service()], onService: (id) => selected = id),
        ),
      );
      expect(preset('pets'), findsOneWidget);
      expect(preset('cleaning'), findsNothing);
      await tester.tap(find.text('Dịch vụ của tôi'));
      expect(selected, 'database-id-1');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy service without a preset keeps its slug icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ServiceGrid(
          services: [service(iconKey: '')],
          onService: (_) {},
        ),
      ),
    );
    expect(preset('cleaning'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'uploaded transparent PNG replaces preset after loading without resizing',
    (tester) async {
      final client = _ImageClient(200);
      debugNetworkImageHttpClientProvider = () => client;
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      final symbol = find.byType(ServiceSymbol);
      late Size originalSize;
      await tester.runAsync(() async {
        await tester.pumpWidget(
          host(
            ServiceGrid(
              services: [service(iconUrl: uploadedIcon)],
              onService: (_) {},
            ),
          ),
        );
        originalSize = tester.getSize(symbol);
        final image = tester
            .widgetList<Image>(find.byType(Image))
            .firstWhere((image) => image.image is NetworkImage);
        expect((image.image as NetworkImage).url, uploadedIcon);
        expect(image.fit, BoxFit.contain);
        expect(image.color, isNull);
        expect(preset('pets'), findsOneWidget);
        final loaded = Completer<void>();
        final stream = image.image.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (_, _) => loaded.complete(),
          onError: (error, _) => loaded.completeError(error),
        );
        stream.addListener(listener);
        await loaded.future.timeout(const Duration(seconds: 5));
        stream.removeListener(listener);
      });
      await tester.pumpAndSettle();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(preset('pets'), findsNothing);
      expect(tester.getSize(symbol), originalSize);
      expect(client.requested, Uri.parse(uploadedIcon));
      expect(tester.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
    },
  );

  testWidgets(
    'failed uploaded image falls back to configured preset at same size',
    (tester) async {
      debugNetworkImageHttpClientProvider = () => _ImageClient(404);
      addTearDown(() => debugNetworkImageHttpClientProvider = null);
      await tester.pumpWidget(
        host(
          ServiceSymbol.forService(
            service(iconUrl: '$uploadedIcon?missing'),
            size: 54,
          ),
        ),
      );
      final symbol = find.byType(ServiceSymbol);
      expect(tester.getSize(symbol), const Size(54, 54));
      await tester.pumpAndSettle();
      expect(preset('pets'), findsOneWidget);
      expect(tester.getSize(symbol), const Size(54, 54));
      expect(tester.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
    },
  );
}

class _ImageClient extends Fake implements HttpClient {
  _ImageClient(this.status);
  final int status;
  Uri? requested;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requested = url;
    return _ImageRequest(status);
  }
}

class _ImageRequest extends Fake implements HttpClientRequest {
  _ImageRequest(this.status);
  final int status;
  @override
  Future<HttpClientResponse> close() async => _ImageResponse(status);
}

class _ImageResponse extends Stream<List<int>> implements HttpClientResponse {
  _ImageResponse(this.statusCode);
  @override
  final int statusCode;
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

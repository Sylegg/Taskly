import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/features/partner/partner_uniform_shop.dart';
import 'package:taskly_mobile/features/partner/recruitment_uniform.dart';

void main() {
  testWidgets('PartnerUniformShop displays packages and items, filters properly', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final uniforms = [
      {
        'id': 'pack-1',
        'name': 'Gói đồng phục TaskLy Tiêu chuẩn',
        'price': '0',
        'description': 'Bao gồm 02 áo polo, 01 nón bảo hiểm, 01 túi đồ nghề.',
        'policy': 'Cấp phát tại văn phòng.\n[TYPE:PACKAGE]',
        'active': true,
        'sizes': {'M': 50, 'L': 50, 'XL': 35},
      },
      {
        'id': 'item-1',
        'name': 'Áo polo TaskLy cao cấp (Món lẻ)',
        'price': '150000',
        'description': 'Áo thun cotton thoáng khí in logo TaskLy.',
        'policy': 'Đổi trả trong 3 ngày.\n[TYPE:ITEM]',
        'active': true,
        'sizes': {'S': 20, 'M': 30, 'L': 25, 'XL': 10},
      },
    ];

    final session = Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/partner/uniforms' && request.method == 'GET') {
            return http.Response(
              jsonEncode({'success': true, 'data': uniforms}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/partner/uniform-orders' && request.method == 'GET') {
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerUniformShop(session: session),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both items show on 'Tất cả' tab
    expect(find.text('Gói đồng phục TaskLy Tiêu chuẩn'), findsOneWidget);
    expect(find.text('Áo polo TaskLy cao cấp (Món lẻ)'), findsOneWidget);
    expect(find.text('📦 GÓI COMBO'), findsOneWidget);
    expect(find.text('👕 ĐỒ LẺ'), findsOneWidget);

    // Tap on '👕 Đồ lẻ & Phụ kiện' tab
    final itemTab = find.textContaining('Đồ lẻ & Phụ kiện');
    expect(itemTab, findsOneWidget);
    await tester.tap(itemTab);
    await tester.pumpAndSettle();

    // Now only the individual item is visible
    expect(find.text('Áo polo TaskLy cao cấp (Món lẻ)'), findsOneWidget);
    expect(find.text('Gói đồng phục TaskLy Tiêu chuẩn'), findsNothing);

    // Tap on '📦 Gói đồng phục' tab
    final packageTab = find.textContaining('Gói đồng phục');
    expect(packageTab, findsOneWidget);
    await tester.tap(packageTab);
    await tester.pumpAndSettle();

    // Now only the combo package is visible
    expect(find.text('Gói đồng phục TaskLy Tiêu chuẩn'), findsOneWidget);
    expect(find.text('Áo polo TaskLy cao cấp (Món lẻ)'), findsNothing);
  });

  testWidgets('RecruitmentUniform (Onboarding Stage 4) filters out individual items and only displays packages', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final uniforms = [
      {
        'id': 'pack-1',
        'name': 'Gói đồng phục TaskLy Tiêu chuẩn',
        'price': '0',
        'description': 'Bao gồm 02 áo polo, 01 nón bảo hiểm, 01 túi đồ nghề.',
        'policy': 'Cấp phát tại văn phòng.\n[TYPE:PACKAGE]',
        'active': true,
        'sizes': {'M': 50, 'L': 50, 'XL': 35},
      },
      {
        'id': 'item-1',
        'name': 'Áo polo TaskLy cao cấp (Món lẻ)',
        'price': '150000',
        'description': 'Áo thun cotton thoáng khí in logo TaskLy.',
        'policy': 'Đổi trả trong 3 ngày.\n[TYPE:ITEM]',
        'active': true,
        'sizes': {'S': 20, 'M': 30, 'L': 25, 'XL': 10},
      },
    ];

    final session = Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/partner/onboarding') {
            return http.Response(
              jsonEncode({'success': true, 'data': {'status': 'UNIFORM_PENDING'}}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/partner/uniforms') {
            return http.Response(
              jsonEncode({'success': true, 'data': uniforms}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/partner/uniform-orders') {
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: RecruitmentUniform(session: session),
      ),
    );

    await tester.pumpAndSettle();

    // Verify package is displayed
    expect(find.textContaining('Gói đồng phục TaskLy Tiêu chuẩn'), findsOneWidget);

    // Verify item is STRICTLY NOT displayed
    expect(find.textContaining('Áo polo TaskLy cao cấp'), findsNothing);
  });

  testWidgets('PartnerUniformShop cleans [TYPE:ITEM] from policy and zooms image on tap', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const testPngBase64 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    final uniforms = [
      {
        'id': 'item-zoom-1',
        'name': 'Áo thun có hình ảnh phóng to',
        'price': '120000',
        'description': 'Mô tả áo thun',
        'policy': 'Chính sách: có ne [TYPE:ITEM]',
        'imageUrl': testPngBase64,
        'packageType': 'ITEM',
        'active': true,
        'sizes': {'M': 10},
      },
    ];

    final session = Session(
      api: Api(
        base: 'http://test/api/v1',
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/partner/uniforms' && request.method == 'GET') {
            return http.Response(
              jsonEncode({'success': true, 'data': uniforms}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path == '/api/v1/partner/uniform-orders' && request.method == 'GET') {
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
        }),
      ),
    )
      ..access = 'test-token'
      ..expires = DateTime.now().add(const Duration(hours: 2));

    await tester.pumpWidget(
      MaterialApp(
        home: PartnerUniformShop(session: session),
      ),
    );

    await tester.pumpAndSettle();

    // Verify product is listed and zoom icon is present
    expect(find.text('Áo thun có hình ảnh phóng to'), findsOneWidget);
    expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);

    // Tap on image thumbnail to open zoom modal
    await tester.tap(find.byIcon(Icons.zoom_in_rounded));
    await tester.pumpAndSettle();

    // Verify zoom dialog opened with InteractiveViewer and hint
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Chụm 2 ngón tay hoặc vuốt để thu phóng'), findsOneWidget);

    // Close zoom dialog
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Open purchase bottom sheet
    await tester.tap(find.text('Mua đồ lẻ'));
    await tester.pumpAndSettle();

    // Verify [TYPE:ITEM] is NOT shown in policy
    expect(find.textContaining('[TYPE:ITEM]'), findsNothing);
    expect(find.text('Chính sách: có ne'), findsOneWidget);
  });
}


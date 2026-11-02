import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/core/theme.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/domain/booking_draft.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/customer_booking.dart';

void main() {
  final fields = [
    {
      'key': 'area',
      'label': 'Diện tích (m²)',
      'type': 'number',
      'required': true,
      'minimum': 1,
    },
    {
      'key': 'supplies',
      'label': 'Dụng cụ',
      'type': 'choice',
      'required': true,
      'options': ['Nhà đã có', 'Partner mang theo'],
    },
  ];
  test('schema rejects empty, negative, fractional and unknown choices', () {
    final schema = BookingSchema.fromJson({
      'key': 'clean',
      'version': 1,
      'fields': fields,
    });
    for (final value in ['', '-1', '1.5', 'abc']) {
      expect(
        schema.validate({'area': value, 'supplies': 'Nhà đã có'}),
        isNotNull,
      );
    }
    expect(schema.validate({'area': '65', 'supplies': 'invalid'}), isNotNull);
    expect(schema.validate({'area': '65', 'supplies': 'Nhà đã có'}), isNull);
  });
  testWidgets(
    'server draft restores and validates on 360px phone without a save draft button',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? stored = CustomerBookingDraft(
        serviceId: 'service-1',
        schemaKey: 'clean',
        details: {'area': '65', 'supplies': 'Nhà đã có'},
        addressId: 'address-1',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      ).toJson();
      bool failSave = false;
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer access');
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean'],
                  'fields': fields,
                },
              ];
            } else if (request.url.path.endsWith('/booking-quotes')) {
              expect(jsonDecode(request.body)['details']['area'], '75');
              data = {'id': 'quote-1', 'subtotal': 110000, 'platformFee': 5000,
                'total': 110000, 'currency': 'VND',
                'expiresAt': DateTime.now().add(const Duration(minutes: 5)).toUtc().toIso8601String()};
            } else if (request.url.path.endsWith('/booking-draft')) {
              if (request.method == 'PUT') {
                if (failSave) {
                  return http.Response(
                    jsonEncode({
                      'success': false,
                      'error': {
                        'code': 'UNAVAILABLE',
                        'message': 'Không thể lưu lúc này',
                      },
                    }),
                    503,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                stored = Map<String, dynamic>.from(jsonDecode(request.body));
              }
              data = stored;
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service(
          'service-1',
          'Dọn nhà',
          'Nhà cửa',
          'clean',
          100000,
          '',
          [],
          slug: 'clean',
          priceUnit: '',
        ),
      ];
      repo.store.addresses = [
        const Address('address-1', 'Nhà', '123 Nguyễn Huệ', 'Bấm chuông', city: 'HCM', buildingType: 'Nhà riêng', buildingDescription: 'Tầng 1', contactName: 'Customer', contactPhone: '0901234567'),
      ];
      final c = CustomerController(repo)..data = repo.store.snapshot();
      c.draft = TaskDraft(
        serviceId: 'service-1',
        address: repo.store.addresses.first,
        scheduledAt: DateTime.now(),
      );
      c.open(PageId.create);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('65'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '0');
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.textContaining('cần là số nguyên'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '75');
      expect(find.text('Lưu bản nháp'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Lấy báo giá'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lấy báo giá'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('110.000đ').last, -100,
        scrollable: find.byType(Scrollable).first);
      expect(find.text('110.000đ'), findsNWidgets(2));
      expect(find.textContaining('Phí nền tảng'), findsNothing);
      expect(find.textContaining('Báo giá còn hiệu lực'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Customer can select up to 3 services with limit enforcement',
    (tester) async {
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean', 'ac', 'sofa', 'fridge'],
                  'fields': [],
                },
              ];
            } else if (request.url.path.endsWith('/booking-draft')) {
              data = null;
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service(
          's-1',
          'Dọn nhà theo giờ',
          'Quét lau sàn',
          'clean',
          100000,
          '',
          [],
          slug: 'clean',
        ),
        const Service(
          's-2',
          'Vệ sinh sofa tại nhà',
          'Hút bụi sofa',
          'sofa',
          150000,
          '',
          [],
          slug: 'sofa',
        ),
        const Service(
          's-3',
          'Vệ sinh máy lạnh',
          'Vệ sinh lưới lọc',
          'ac',
          200000,
          '',
          [],
          slug: 'ac',
        ),
        const Service(
          's-4',
          'Kiểm tra tủ lạnh',
          'Kiểm tra làm lạnh',
          'fridge',
          120000,
          '',
          [],
          slug: 'fridge',
        ),
      ];
      final c = CustomerController(repo)..data = repo.store.snapshot();
      c.open(PageId.create);

      tester.view.physicalSize = const Size(375, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();

      // Select service 1
      await tester.tap(find.text('Dọn nhà theo giờ'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 1/3 dịch vụ'), findsOneWidget);

      // Select service 2
      await tester.tap(find.text('Vệ sinh sofa tại nhà'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 2/3 dịch vụ'), findsOneWidget);

      // Select service 3
      await tester.tap(find.text('Vệ sinh máy lạnh'));
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 3/3 dịch vụ'), findsOneWidget);
      expect(find.text('Đạt tối đa 3/3'), findsOneWidget);

      // Try selecting 4th service -> blocked, shows snackbar
      await tester.tap(find.text('Kiểm tra tủ lạnh'));
      await tester.pumpAndSettle();
      expect(find.textContaining('chọn tối đa 3 dịch vụ'), findsOneWidget);
      expect(find.text('Đã chọn 3/3 dịch vụ'), findsOneWidget);

      // Deselect service 2 -> now 2/3
      await tester.tap(find.text('Vệ sinh sofa tại nhà').last);
      await tester.pumpAndSettle();
      expect(find.text('Đã chọn 2/3 dịch vụ'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Step 2 renders collapsible accordion boxes for 2+ services and reveals form on tap',
    (tester) async {
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean'],
                  'fields': [
                    {
                      'key': 'area',
                      'label': 'Diện tích (m²)',
                      'type': 'number',
                      'required': true,
                      'minimum': 1,
                      'options': [],
                    },
                  ],
                },
                {
                  'key': 'sofa',
                  'version': 1,
                  'serviceSlugs': ['sofa'],
                  'fields': [
                    {
                      'key': 'items',
                      'label': 'Số bộ sofa',
                      'type': 'number',
                      'required': true,
                      'minimum': 1,
                      'options': [],
                    },
                  ],
                },
              ];
            } else if (request.url.path.endsWith('/booking-draft')) {
              data = null;
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service('s-1', 'Dọn nhà theo giờ', 'Quét lau sàn', 'clean', 100000, '', [], slug: 'clean'),
        const Service('s-2', 'Vệ sinh sofa tại nhà', 'Hút bụi sofa', 'sofa', 150000, '', [], slug: 'sofa'),
      ];
      final c = CustomerController(repo)..data = repo.store.snapshot();
      c.open(PageId.create);

      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Select 2 services
      await tester.tap(find.text('Dọn nhà theo giờ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vệ sinh sofa tại nhà'));
      await tester.pumpAndSettle();

      // Proceed to Step 2
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Step 2 header & boxes are visible
      expect(find.text('Đã chọn 2 dịch vụ'), findsOneWidget);
      expect(find.text('Dọn nhà theo giờ'), findsWidgets);
      expect(find.text('Vệ sinh sofa tại nhà'), findsWidgets);

      // Initially fields are hidden
      expect(find.text('Diện tích (m²)'), findsNothing);
      expect(find.text('Số bộ sofa'), findsNothing);

      // Tap box 1 to expand
      await tester.tap(find.text('Dọn nhà theo giờ').first);
      await tester.pumpAndSettle();

      // Box 1 fields are now visible!
      expect(find.text('Diện tích (m²)'), findsOneWidget);
      expect(find.text('Mô tả bổ sung cho Dọn nhà theo giờ'), findsOneWidget);
      expect(find.text('Số bộ sofa'), findsNothing);

      // Enter value into box 1
      await tester.enterText(find.byType(TextFormField).first, '80');
      await tester.enterText(find.widgetWithText(TextFormField, 'Mô tả bổ sung cho Dọn nhà theo giờ'), 'Dọn kỹ phòng khách');
      await tester.pumpAndSettle();
      expect(find.text('Đã điền'), findsWidgets);

      // Tap box 2 to expand
      await tester.tap(find.text('Vệ sinh sofa tại nhà').first);
      await tester.pumpAndSettle();

      // Box 2 fields are now visible!
      expect(find.text('Số bộ sofa'), findsOneWidget);
      expect(find.text('Mô tả bổ sung cho Vệ sinh sofa tại nhà'), findsOneWidget);

      // Enter description for service 2
      await tester.enterText(find.widgetWithText(TextFormField, 'Mô tả bổ sung cho Vệ sinh sofa tại nhà'), 'Sofa nỉ màu xám');
      await tester.pumpAndSettle();

      // Tap box 1 again to collapse it
      await tester.tap(find.text('Dọn nhà theo giờ').first);
      await tester.pumpAndSettle();
      expect(find.text('Diện tích (m²)'), findsNothing);
      expect(find.text('Mô tả bổ sung cho Dọn nhà theo giờ'), findsNothing);

      // Box 2 is still visible with its own description
      expect(find.text('Số bộ sofa'), findsOneWidget);
      expect(find.text('Mô tả bổ sung cho Vệ sinh sofa tại nhà'), findsOneWidget);
      expect(find.text('Sofa nỉ màu xám'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Step 3 features 24h and 60m digital time picker, quick presets, and deletes estimated duration',
    (tester) async {
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean'],
                  'fields': [],
                },
              ];
            } else if (request.url.path.endsWith('/booking-draft')) {
              data = null;
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service('s-1', 'Dọn nhà theo giờ', 'Quét lau sàn', 'clean', 100000, '', [], slug: 'clean'),
      ];
      repo.store.addresses = [
        const Address('a-1', 'Nhà riêng', '123 Nguyễn Trãi', ''),
      ];
      final c = CustomerController(repo)..data = repo.store.snapshot();
      c.open(PageId.create);

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Select service and proceed
      await tester.tap(find.text('Dọn nhà theo giờ'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Step 2: Form step -> proceed to Step 3 (Lịch hẹn)
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Now on Step 3: Lịch hẹn
      expect(find.text('Lịch hẹn'), findsOneWidget);
      expect(find.text('Ngày thực hiện'), findsOneWidget);
      expect(find.text('Giờ bắt đầu'), findsOneWidget);

      // Verify "Thời lượng dự kiến" is COMPLETELY DELETED
      expect(find.text('Thời lượng dự kiến'), findsNothing);
      expect(find.text('1 giờ'), findsNothing);
      expect(find.text('2 giờ'), findsNothing);
      expect(find.text('4 giờ'), findsNothing);
      expect(find.text('6 giờ'), findsNothing);

      // Verify 24h & 60m dropdown headers are present
      expect(find.text('Giờ (00 - 23)'), findsOneWidget);
      expect(find.text('Phút (00 - 59)'), findsOneWidget);
      expect(find.text('Khung giờ phổ biến'), findsOneWidget);

      // Verify preset pills exist (e.g., 08:00, 13:30, 14:00)
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('13:30'), findsOneWidget);
      expect(find.text('14:00'), findsOneWidget);

      // Tap preset 13:30 -> time updates immediately
      await tester.tap(find.text('13:30'));
      await tester.pumpAndSettle();
      expect(find.text('13:30'), findsWidgets);

      // Today blocks earlier hours/minutes and quick presets; tomorrow allows them.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await tester.tap(find.text('Ngày thực hiện'));
      await tester.pumpAndSettle();
      final dateDialog = tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
      expect(dateDialog.firstDate, today);
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(today);
      await tester.pumpAndSettle();
      final selectors = tester.widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>)).toList();
      final minimum = now.add(const Duration(minutes: 1));
      for (final item in selectors[0].items!) {
        expect(item.value! >= now.hour, isTrue);
      }
      final hour = selectors[0].value!;
      if (hour == minimum.hour && minimum.day == today.day) {
        for (final item in selectors[1].items!) {
          expect(item.value! >= now.minute, isTrue);
        }
      }
      for (final preset in ['08:00', '09:00', '10:30', '13:30', '14:00', '15:30', '17:00', '18:00']) {
        final parts = preset.split(':');
        final time = DateTime(today.year, today.month, today.day, int.parse(parts[0]), int.parse(parts[1]));
        if (time.isBefore(now)) {
          expect(find.text(preset), findsNothing);
        }
      }
      await tester.tap(find.text('Ngày thực hiện'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(today.add(const Duration(days: 1)));
      await tester.pumpAndSettle();
      for (final selector in tester.widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>))) {
        expect(selector.items!.every((item) => item.enabled), isTrue);
      }

      // Verify buttons "Tiếp tục" and "Lưu bản nháp" are at the bottom
      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(find.text('Lưu bản nháp'), findsNothing);

      // Proceed to Step 4 (Địa chỉ)
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Verify Step 4 has "Lưu ý cho Đối tác / Partner" text field with notes
      expect(find.text('Địa chỉ'), findsOneWidget);
      expect(find.text('Lưu ý cho Đối tác / Partner'), findsOneWidget);
      expect(find.text('Thêm địa chỉ mới'), findsOneWidget);
      await tester.tap(find.text('Nhà riêng'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Người liên hệ: Chưa có'), findsOneWidget);
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();
      expect(find.text('Địa chỉ'), findsWidgets);
      expect(find.textContaining('Vui lòng bổ sung:'), findsOneWidget);


      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Step 4 address UI redesign: removes coordinates, adds top-corner change address button and modal sheet picker',
    (tester) async {
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean'],
                  'fields': [],
                },
              ];
            } else if (request.url.path.endsWith('/booking-draft')) {
              data = null;
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service('s-1', 'Dọn nhà theo giờ', 'Quét lau sàn', 'clean', 100000, '', [], slug: 'clean'),
      ];
      repo.store.addresses = [
        const Address(
          'a-1',
          'Nhà riêng',
          '123 Nguyen Trai',
          'Gọi trước khi đến',
          isDefault: true,
          city: 'TP. Hồ Chí Minh',
          buildingType: 'Nhà riêng',
          buildingDescription: 'Tầng 5',
          contactName: 'vu',
          contactPhone: '0909098678',
          latitude: 10.7769,
          longitude: 106.7009,
        ),
        const Address(
          'a-2',
          'Văn phòng',
          '456 Le Loi',
          'Bảo vệ mở cửa',
          isDefault: false,
          city: 'TP. Hồ Chí Minh',
          buildingType: 'Khác',
          buildingDescription: 'Tòa nhà Bitexco',
          contactName: 'Nguyen Van B',
          contactPhone: '0901234567',
        ),
      ];

      final c = CustomerController(repo)..data = repo.store.snapshot();
      c.draft = TaskDraft(
        serviceId: 's-1',
        address: repo.store.addresses.first,
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      );
      c.open(PageId.create);

      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Proceed (service already preselected)
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Step 2: Form step -> proceed to Step 3
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Step 3: Schedule -> proceed to Step 4
      await tester.ensureVisible(find.text('Tiếp tục'));
      await tester.tap(find.text('Tiếp tục'));
      await tester.pumpAndSettle();

      // Now on Step 4: Địa chỉ
      expect(find.text('Địa chỉ'), findsOneWidget);

      // Verify top-corner "Đổi địa chỉ" button exists
      expect(find.text('Đổi địa chỉ'), findsWidgets);

      // Verify coordinates are COMPLETELY REMOVED
      expect(find.textContaining('Tọa độ'), findsNothing);
      expect(find.textContaining('10.7769'), findsNothing);
      expect(find.textContaining('106.7009'), findsNothing);

      // Verify clean redesigned card information is present
      expect(find.text('Nhà riêng'), findsWidgets);
      expect(find.text('Địa chỉ mặc định'), findsOneWidget);
      expect(find.text('Loại: Nhà riêng'), findsOneWidget);
      expect(find.text('123 Nguyen Trai, TP. Hồ Chí Minh'), findsOneWidget);
      expect(find.textContaining('Người liên hệ: vu'), findsOneWidget);
      expect(find.textContaining('0909098678'), findsOneWidget);
      expect(find.textContaining('Mô tả vị trí: Tầng 5'), findsOneWidget);
      expect(find.textContaining('Ghi chú cho Partner: Gọi trước khi đến'), findsOneWidget);
      expect(find.text('Sửa địa chỉ'), findsOneWidget);

      // Tap top-corner "Đổi địa chỉ" button -> opens bottom sheet modal
      await tester.tap(find.text('Đổi địa chỉ').first);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and address options
      expect(find.text('Chọn địa chỉ dịch vụ'), findsOneWidget);
      expect(find.text('Văn phòng'), findsWidgets);

      // Select 'Văn phòng' from the bottom sheet
      await tester.tap(find.text('Văn phòng').last);
      await tester.pumpAndSettle();

      // Bottom sheet closed, now 'Văn phòng' is selected on the main screen!
      expect(find.text('Chọn địa chỉ dịch vụ'), findsNothing);
      expect(find.text('456 Le Loi, TP. Hồ Chí Minh'), findsOneWidget);
      expect(find.textContaining('Nguyen Van B'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'Step 5 review screen: redesigned cards and in-place popup modal editing without navigating back',
    (tester) async {
      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean', 'sofa'],
                  'fields': [],
                },
              ];
            } else if (request.url.path.endsWith('/booking-draft')) {
              data = {
                'serviceId': 's-clean',
                'selectedServiceIds': ['s-clean'],
                'schemaKey': 'clean',
                'details': {'area': '75'},
                'addressId': 'addr-1',
                'scheduledAt': DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String(),
                'notes': 'Gọi trước 15p',
              };
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service(
          's-clean',
          'Dọn dẹp nhà',
          'Dọn dẹp tiêu chuẩn',
          'clean',
          120000,
          '',
          [],
          slug: 'clean',
        ),
        const Service(
          's-sofa',
          'Giặt sofa',
          'Giặt sofa tại nhà',
          'sofa',
          180000,
          '',
          [],
          slug: 'sofa',
        ),
      ];
      repo.store.addresses = [
        const Address(
          'addr-1',
          'Nhà riêng',
          '123 Nguyễn Huệ',
          'Bấm chuông',
          city: 'TP. Hồ Chí Minh',
          buildingType: 'Chung cư',
          buildingDescription: 'Tầng 3',
          contactName: 'Anh Nam',
          contactPhone: '0912345678',
        ),
        const Address(
          'addr-2',
          'Văn phòng',
          '456 Lê Lợi',
          'Lầu 2',
          city: 'TP. Hồ Chí Minh',
          buildingType: 'Văn phòng',
          buildingDescription: 'Tòa nhà A',
          contactName: 'Chị Mai',
          contactPhone: '0987654321',
        ),
      ];
      final c = CustomerController(repo)..data = repo.store.snapshot();
      c.draft = TaskDraft(
        serviceId: 's-clean',
        address: repo.store.addresses.first,
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
      );
      c.open(PageId.create);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();

      // Advance through steps 1 -> 2 -> 3 -> 4 -> 5
      for (var i = 0; i < 4; i++) {
        await tester.scrollUntilVisible(
          find.text('Tiếp tục'),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();
      }

      // Verify we are now on Step 5 / 5 ("Kiểm tra")
      expect(find.text('BƯỚC 5/5'), findsOneWidget);
      expect(find.text('Kiểm tra'), findsOneWidget);

      // Verify the 4 redesigned review cards are present
      expect(find.text('Dịch vụ đã chọn'), findsOneWidget);
      expect(find.text('Thông tin dịch vụ'), findsNothing);
      expect(find.text('Thêm dịch vụ'), findsOneWidget);
      expect(find.text('Lịch hẹn'), findsOneWidget);
      expect(find.text('Địa chỉ và liên hệ'), findsOneWidget);

      // Verify "Chỉnh sửa" buttons exist (4 of them, one per section)
      expect(find.text('Chỉnh sửa'), findsNWidgets(2));

      // 1. Click "Chỉnh sửa" on Section 3: Lịch hẹn
      await tester.scrollUntilVisible(
        find.text('Lịch hẹn'),
        50,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // Tap Chỉnh sửa on Lịch hẹn (the 3rd edit button)
      await tester.tap(find.text('Chỉnh sửa').first);
      await tester.pumpAndSettle();

      // Verify in-place modal popup appears!
      expect(find.text('Thay đổi lịch hẹn'), findsOneWidget);
      expect(find.text('Cập nhật lịch hẹn'), findsOneWidget);
      // Crucial: Step 5 is STILL active in background, we did NOT navigate back to step 2!
      expect(find.text('BƯỚC 5/5'), findsOneWidget);

      // Tap "Cập nhật lịch hẹn" to save and close the popup
      await tester.tap(find.text('Cập nhật lịch hẹn'));
      await tester.pumpAndSettle();

      // Verify modal is dismissed and we are STILL in Step 5!
      expect(find.text('Thay đổi lịch hẹn'), findsNothing);
      expect(find.text('BƯỚC 5/5'), findsOneWidget);
      expect(find.text('Kiểm tra'), findsOneWidget);

      // 2. Click "Chỉnh sửa" on Section 1: Dịch vụ đã chọn
      await tester.scrollUntilVisible(
        find.text('Dịch vụ đã chọn'),
        -100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm dịch vụ'));
      await tester.pumpAndSettle();

      // Verify modal popup for services appears
      expect(find.text('Thêm dịch vụ'), findsNWidgets(2));
      expect(find.text('Xong'), findsOneWidget);
      expect(find.text('BƯỚC 5/5'), findsOneWidget);

      // Close the modal
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      // Verify we remain in Step 5!
      expect(find.text('Thêm dịch vụ'), findsOneWidget);
      expect(find.text('BƯỚC 5/5'), findsOneWidget);

      // 3. Click "Chỉnh sửa" on Section 4: Địa chỉ và liên hệ
      await tester.scrollUntilVisible(
        find.text('Địa chỉ và liên hệ'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chỉnh sửa').last);
      await tester.pumpAndSettle();

      // Verify modal popup for address & notes appears
      expect(find.text('Địa chỉ và ghi chú'), findsOneWidget);
      expect(find.text('Ghi chú cho Đối tác / Partner'), findsOneWidget);
      expect(find.text('Xong'), findsOneWidget);
      expect(find.text('BƯỚC 5/5'), findsOneWidget);

      // Close the modal
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      // Verify we remain in Step 5!
      expect(find.text('Địa chỉ và ghi chú'), findsNothing);
      expect(find.text('BƯỚC 5/5'), findsOneWidget);

      // Verify "Quay lại bước trước" button is still present if user wants to explicitly go back
      expect(find.text('Quay lại bước trước'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );

  testWidgets(
    'AppBar has home icon and tapping it returns directly to services page',
    (tester) async {
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            dynamic data;
            if (request.url.path.endsWith('/booking-schemas')) {
              data = [
                {
                  'key': 'clean',
                  'version': 1,
                  'serviceSlugs': ['clean'],
                  'fields': [],
                },
              ];
            } else if (request.url.path.endsWith('/booking-draft')) {
              data = null;
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repo = ApiCustomerRepository(session);
      repo.store.catalogueOverride = [
        const Service(
          's-1',
          'Dọn nhà theo giờ',
          'Quét lau sàn',
          'clean',
          100000,
          '',
          [],
          slug: 'clean',
        ),
      ];
      final c = CustomerController(repo)..data = repo.store.snapshot();

      // Controller navigates to Home first
      c.root(PageId.home);
      expect(c.route.page, PageId.home);

      // User enters booking service flow
      c.open(PageId.create);
      expect(c.route.page, PageId.create);

      tester.view.physicalSize = const Size(375, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: CustomerBooking(controller: c),
        ),
      );
      await tester.pumpAndSettle();

      // Home icon must be present in AppBar
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);

      // Select service to move forward in the flow
      await tester.tap(find.text('Dọn nhà theo giờ'));
      await tester.pumpAndSettle();

      // Tap home icon to return directly to services page
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pumpAndSettle();

      // Controller must have returned to Services page
      expect(c.route.page, PageId.services);

      await tester.pumpWidget(const SizedBox());
      c.dispose();
      repo.store.dispose();
      session.dispose();
    },
  );
}

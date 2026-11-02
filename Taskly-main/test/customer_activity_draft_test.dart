import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/app/customer_controller.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/features/booking_draft_activity.dart';
import 'package:taskly_mobile/features/customer_activity.dart';

void main() {
  testWidgets('BookingDraftActivity displays draft prominently with service name and delete action', (tester) async {
    Map<String, dynamic>? draftData = {
      'serviceId': 'service-clean',
      'schemaKey': 'clean',
      'details': {'area': '65'},
      'scheduledAt': DateTime.now().subtract(const Duration(minutes: 1)).toIso8601String(),
    };

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/pending-bookings')) {
        if (request.method == 'DELETE') {
          draftData = null;
          return http.Response(jsonEncode({'success': true, 'data': null}), 200);
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': draftData == null
                ? []
                : [
                    {
                      'id': 'pending-1',
                      'draft': draftData,
                    }
                  ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.contains('/pending-bookings/')) {
        draftData = null;
        return http.Response(jsonEncode({'success': true, 'data': null}), 200);
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final session = Session(
      api: Api(client: client, base: 'http://localhost/api/v1'),
    )
      ..access = 'access'
      ..expires = DateTime.now().add(const Duration(hours: 1));

    final repo = ApiCustomerRepository(session);
    repo.store.catalogueOverride = [
      const Service(
        'service-clean',
        'Kiểm tra sự cố máy lạnh',
        'Điện lạnh',
        'ac',
        100000,
        '',
        [],
      ),
    ];

    final controller = CustomerController(repo)..data = repo.store.snapshot();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingDraftActivity(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify draft header and badge
    expect(find.text('Chưa hoàn thành'), findsNothing);

    // Verify service name
    expect(find.text('Kiểm tra sự cố máy lạnh'), findsOneWidget);
    expect(find.text('Giờ hẹn đã qua'), findsOneWidget);
    expect(find.text('Sửa giờ'), findsOneWidget);
    expect(find.text('Tiếp tục'), findsNothing);

    // Tap cancel button -> triggers confirmation dialog
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();

    expect(find.text('Hủy đơn đặt dịch vụ?'), findsOneWidget);
    expect(find.text('Bạn có chắc chắn muốn hủy đơn đặt dịch vụ này không?'), findsOneWidget);
    await tester.tap(find.text('Hủy đơn'));
    await tester.pumpAndSettle();

    // Draft should be removed and hidden
    expect(draftData, isNull);
    expect(find.text('Kiểm tra sự cố máy lạnh'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    repo.store.dispose();
    session.dispose();
  });

  testWidgets('CustomerActivity shows draft at the top with clean single action button in empty state', (tester) async {
    final draftData = {
      'serviceId': 'service-ac',
      'schemaKey': 'ac',
      'details': {},
    };

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/pending-bookings')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'pending-ac',
                'draft': draftData,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/task-activity')) {
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': {}}), 200);
    });

    final session = Session(
      api: Api(client: client, base: 'http://localhost/api/v1'),
    )
      ..access = 'access'
      ..expires = DateTime.now().add(const Duration(hours: 1));

    final repo = ApiCustomerRepository(session);
    repo.store.catalogueOverride = [
      const Service(
        'service-ac',
        'Kiểm tra sự cố máy lạnh',
        'Điện lạnh',
        'ac',
        100000,
        '',
        [],
      ),
    ];

    final controller = CustomerController(repo)..data = repo.store.snapshot();

    await tester.pumpWidget(
      MaterialApp(
        home: CustomerActivity(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    // Verify draft appears at top
    expect(find.text('Đơn của bạn'), findsOneWidget);
    expect(find.text('Kiểm tra sự cố máy lạnh'), findsOneWidget);

    // Verify empty state has only ONE button: Đăng việc ngay
    expect(find.text('Đăng việc ngay'), findsOneWidget);

    // Verify duplicate "Khám phá dịch vụ" is gone
    expect(find.text('Khám phá dịch vụ'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    repo.store.dispose();
    session.dispose();
  });
}

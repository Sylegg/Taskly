import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';
import 'package:taskly_mobile/data/api_customer_repository.dart';
import 'package:taskly_mobile/domain/models.dart';
import 'package:taskly_mobile/app/customer_controller.dart';

void main() {
  test(
    'catalogue sync updates Customer and keeps data on network failure',
    () async {
      var visible = false, fail = false;
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            final path = request.url.path;
            dynamic data = [];
            if ((path.endsWith('/public/banners') ||
                path.endsWith('/public/articles'))) {
              data = [];
            } else if (path.endsWith('/public/services')) {
              if (fail) {
                return http.Response(
                  jsonEncode({
                    'success': false,
                    'error': {'message': 'Offline'},
                  }),
                  503,
                );
              }
              data = {
                'services': visible
                    ? [
                        {
                          'id': 'new-service',
                          'slug': 'new-service',
                          'name': 'Dịch vụ mới',
                          'shortDescription': 'Mô tả',
                          'suggestedPriceMin': 120000,
                          'currency': 'VND',
                        },
                      ]
                    : [],
              };
            } else if (path.endsWith('/users/me')) {
              data = {'fullName': 'Customer', 'phone': '', 'email': ''};
            } else if (path.endsWith('/settings') ||
                path.endsWith('/statistics')) {
              data = <String, dynamic>{};
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
      final repository = ApiCustomerRepository(session);
      final controller = CustomerController(repository);
      await controller.refresh();
      expect(controller.data!.services, isEmpty);
      visible = true;
      await controller.refreshCatalogue();
      expect(controller.data!.services.single.name, 'Dịch vụ mới');
      fail = true;
      await controller.refreshCatalogue();
      expect(controller.data!.services.single.id, 'new-service');
      fail = false;
      visible = false;
      await controller.refreshCatalogue();
      expect(controller.data!.services, isEmpty);
      controller.dispose();
      repository.store.dispose();
      session.dispose();
    },
  );
  test(
    'missing optional sections allow home but server errors still fail',
    () async {
      var status = 404;
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            final path = request.url.path;
            dynamic data;
            if (path.endsWith('/users/me')) {
              data = {'fullName': 'Customer', 'phone': '', 'email': ''};
            } else if (path.endsWith('/addresses')) {
              data = [];
            } else if ((path.endsWith('/public/banners') ||
                path.endsWith('/public/articles'))) {
              data = [];
            } else if (path.endsWith('/public/services')) {
              data = {'services': []};
            } else {
              return http.Response(
                jsonEncode({
                  'success': false,
                  'error': {'code': 'NOT_FOUND', 'message': 'Unavailable'},
                }),
                status,
              );
            }
            return http.Response(
              jsonEncode({'success': true, 'data': data}),
              200,
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repository = ApiCustomerRepository(session);
      final snapshot = await repository.load();
      expect(snapshot.methods, isEmpty);
      expect(snapshot.tasks, isEmpty);
      await expectLater(
        repository.addPaymentMethod('Cash', ''),
        throwsException,
      );
      for (final failureStatus in [500, 503]) {
        status = failureStatus;
        await expectLater(repository.load(), throwsException);
      }
      repository.store.dispose();
      session.dispose();
    },
  );

  test('account saves persist across repository recreation and API failure cannot fabricate success', () async {
    final methods = <Map<String, dynamic>>[];
    var enabled = true;
    var fail = false;
    final session = Session(
      api: Api(
        base: 'http://localhost/api/v1',
        client: MockClient((request) async {
          final path = request.url.path;
          dynamic data;
          if (fail) {
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': 'NETWORK', 'message': 'Unavailable'},
              }),
              503,
            );
          }
          expect(request.headers['Authorization'], 'Bearer access');
          if ((path.endsWith('/public/banners') ||
              path.endsWith('/public/articles'))) {
            data = [];
          } else if (path.endsWith('/public/services')) {
            data = {
              'services': [
                {
                  'id': 'service-1',
                  'slug': 'clean',
                  'name': 'Dọn nhà',
                  'shortDescription': 'Dọn dẹp',
                  'suggestedPriceMin': 100000,
                  'currency': 'VND',
                },
              ],
            };
          } else if (path.endsWith('/payment-methods')) {
            if (request.method == 'POST') {
              final body = jsonDecode(request.body);
              methods.add({...body, 'id': 'method-1', 'isDefault': true});
            }
            data = methods;
          } else if (path.endsWith('/settings')) {
            if (request.method == 'PUT') {
              enabled = jsonDecode(request.body)['notificationsEnabled'];
            }
            data = {'notificationsEnabled': enabled};
          } else if (path.endsWith('/addresses') || path.endsWith('/reviews')) {
            data = [];
          } else {
            data = {
              'fullName': 'Customer',
              'phone': '0909876902',
              'email': 'customer@example.com',
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
    final first = ApiCustomerRepository(session);
    await first.load();
    await first.addPaymentMethod('Tiền mặt', 'Trả trực tiếp');
    await first.setNotifications(false);
    final second = ApiCustomerRepository(session);
    final restored = await second.load();
    expect(restored.methods.single.name, 'Tiền mặt');
    expect(restored.notificationEnabled, false);
    expect(restored.tasks, isEmpty);
    expect((await second.newDraft()).paymentMethodId, 'method-1');
    await expectLater(
      second.pay('task', 'method-1'),
      throwsA(isA<Exception>()),
    );
    fail = true;
    await expectLater(
      second.addPaymentMethod('Bank', 'Owner'),
      throwsA(isA<Exception>()),
    );
    expect(methods.length, 1);
    first.store.dispose();
    second.store.dispose();
    session.dispose();
  });

  test(
    'profile allows editing phone number but rejects email changes',
    () async {
      Map<String, dynamic>? patchedBody;
      final session = Session(
        api: Api(
          base: 'http://localhost/api/v1',
          client: MockClient((request) async {
            final path = request.url.path;
            final headers = {'content-type': 'application/json; charset=utf-8'};
            if (path.endsWith('/users/me')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'fullName': 'Nguyễn Văn A',
                    'phone': '0901234567',
                    'email': 'customer@gmail.com',
                  },
                }),
                200,
                headers: headers,
              );
            }
            if (path.endsWith('/profile') && request.method == 'PATCH') {
              patchedBody = jsonDecode(request.body) as Map<String, dynamic>;
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {
                    'fullName': patchedBody!['fullName'],
                    'phone': patchedBody!['phone'],
                    'email': 'customer@gmail.com',
                  },
                }),
                200,
                headers: headers,
              );
            }
            if ((path.endsWith('/public/banners') ||
                path.endsWith('/public/articles'))) {
              return http.Response(
                jsonEncode({'success': true, 'data': []}),
                200,
                headers: headers,
              );
            } else if (path.endsWith('/public/services')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'services': []},
                }),
                200,
                headers: headers,
              );
            }
            if (path.endsWith('/settings')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'notificationsEnabled': true},
                }),
                200,
                headers: headers,
              );
            }
            if (path.endsWith('/statistics')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': {'total': 0, 'completed': 0},
                }),
                200,
                headers: headers,
              );
            }
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
              headers: headers,
            );
          }),
        ),
      );
      session.access = 'access';
      session.expires = DateTime.now().add(const Duration(hours: 1));
      final repository = ApiCustomerRepository(session);
      await repository.load();

      expect(repository.store.profile.phone, '0901234567');
      expect(repository.store.profile.email, 'customer@gmail.com');

      // Attempting to change email throws RepositoryFailure
      await expectLater(
        repository.saveProfile(
          'Nguyễn Văn A',
          '0987654321',
          'different@gmail.com',
        ),
        throwsA(isA<RepositoryFailure>()),
      );

      // Updating phone number with unchanged email succeeds
      await repository.saveProfile(
        'Nguyễn Văn B',
        '0987654321',
        'customer@gmail.com',
      );

      expect(patchedBody?['phone'], '0987654321');
      expect(patchedBody?['fullName'], 'Nguyễn Văn B');
      expect(repository.store.profile.phone, '0987654321');
      expect(repository.store.profile.name, 'Nguyễn Văn B');
      expect(repository.store.profile.email, 'customer@gmail.com');

      repository.store.dispose();
      session.dispose();
    },
  );
}

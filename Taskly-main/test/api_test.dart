import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';

void main() {
  test(
    'native login sends JSON and returns the real response envelope',
    () async {
      final api = Api(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/mobile/login');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body)['email'], 'test@example.com');
          expect(request.headers['Content-Type'], 'application/json');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'user': {'status': 'ACTIVE'},
              },
            }),
            200,
          );
        }),
      );
      final result = await api.call(
        '/auth/mobile/login',
        method: 'POST',
        body: {'email': 'test@example.com', 'password': 'Example1234'},
      );
      expect(result['user']['status'], 'ACTIVE');
      api.client.close();
    },
  );
  test(
    'backend errors preserve verification-required code and message',
    () async {
      final api = Api(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {
                'code': 'EMAIL_VERIFICATION_REQUIRED',
                'message': 'Verify email',
              },
            }),
            403,
          ),
        ),
      );
      await expectLater(
        api.call('/auth/mobile/login'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.code, 'code', 'EMAIL_VERIFICATION_REQUIRED')
              .having((e) => e.status, 'status', 403),
        ),
      );
      api.client.close();
    },
  );
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';

void main() {
  test('private verification upload uses bearer multipart and does not fabricate success', () async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j4WQAAAAASUVORK5CYII=',
    );
    var count = 0;
    final session =
        Session(
            api: Api(
              base: 'http://test/api/v1',
              client: MockClient((request) async {
                count++;
                expect(
                  request.url.path,
                  '/api/v1/verifications/00000000-0000-0000-0000-000000000001/documents/FRONT',
                );
                expect(request.headers['Authorization'], 'Bearer fixture');
                expect(
                  request.headers['content-type'],
                  startsWith('multipart/form-data'),
                );
                expect(
                  latin1.decode(request.bodyBytes).toLowerCase(),
                  contains('content-type: image/png'),
                );
                return http.Response(
                  jsonEncode({
                    'success': false,
                    'error': {
                      'code': 'STORAGE_UNAVAILABLE',
                      'message': 'Kho ảnh chưa sẵn sàng',
                    },
                  }),
                  503,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }),
            ),
          )
          ..access = 'fixture'
          ..expires = DateTime.now().add(const Duration(hours: 1));
    await expectLater(
      session.uploadVerificationImage(
        '00000000-0000-0000-0000-000000000001',
        'FRONT',
        bytes,
      ),
      throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 503)),
    );
    expect(count, 1);
    await expectLater(
      session.uploadVerificationImage(
        '00000000-0000-0000-0000-000000000001',
        'FRONT',
        [1, 2, 3],
      ),
      throwsA(isA<ApiFailure>().having((e) => e.code, 'code', 'IMAGE_TYPE')),
    );
    expect(count, 1);
    session.dispose();
  });
}

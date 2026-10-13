import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taskly_mobile/auth/api.dart';

class MemoryStorage extends FlutterSecureStorage {
  String? credential;
  MemoryStorage(this.credential);
  @override
  Future<String?> read({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => credential;
  @override
  Future<void> write({
    required String key,
    required String? value,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    credential = value;
  }

  @override
  Future<void> delete({
    required String key,
    AndroidOptions? aOptions,
    AppleOptions? iOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    credential = null;
  }
}

http.Response success(dynamic data) =>
    http.Response(jsonEncode({'success': true, 'data': data}), 200);
Map<String, dynamic> tokens() => {
  'accessToken': 'access',
  'refreshToken': 'rotated',
  'expiresAt': DateTime.now()
      .add(const Duration(minutes: 15))
      .toIso8601String(),
};

void main() {
  test(
    'offline sync keeps profile and clears the banner after recovery',
    () async {
      var unavailable = true;
      final session =
          Session(
              storage: MemoryStorage(null),
              api: Api(
                client: MockClient((request) async {
                  if (unavailable) throw http.ClientException('offline');
                  return success({'id': 'cached-user', 'fullName': 'Minh'});
                }),
              ),
            )
            ..user = {'id': 'cached-user', 'fullName': 'Minh'}
            ..access = 'access'
            ..expires = DateTime.now().add(const Duration(minutes: 10));
      await expectLater(session.syncUser(), throwsA(isA<ApiFailure>()));
      expect(session.offline, isTrue);
      expect(session.user?['id'], 'cached-user');
      unavailable = false;
      await session.syncUser();
      expect(session.offline, isFalse);
      session.dispose();
    },
  );
  test('restore rotates secure credential and loads server profile', () async {
    final storage = MemoryStorage('stored');
    final session = Session(
      storage: storage,
      api: Api(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/refresh')) {
            expect(jsonDecode(request.body)['refreshToken'], 'stored');
            return success(tokens());
          }
          expect(request.headers['Authorization'], 'Bearer access');
          return success({
            'id': 'user',
            'roles': ['CUSTOMER'],
            'activeMode': 'CUSTOMER',
          });
        }),
      ),
    );
    await session.restore();
    expect(session.user?['id'], 'user');
    expect(storage.credential, 'rotated');
    expect(session.loading, false);
    session.dispose();
  });
  test('invalid refresh clears local identity', () async {
    final storage = MemoryStorage('invalid');
    final session = Session(
      storage: storage,
      api: Api(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': {'code': 'SESSION_EXPIRED', 'message': 'Expired'},
            }),
            401,
          ),
        ),
      ),
    );
    await session.restore();
    expect(session.user, isNull);
    expect(storage.credential, isNull);
    expect(session.restoreError, isNull);
    session.dispose();
  });
  test(
    'concurrent refresh shares one call and logout prevents resurrection',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final storage = MemoryStorage('stored');
      final session = Session(
        storage: storage,
        api: Api(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/refresh')) {
              calls++;
              return response.future;
            }
            return success(null);
          }),
        ),
      )..refreshToken = 'stored';
      final first = session.refresh();
      final second = session.refresh();
      await Future<void>.delayed(Duration.zero);
      await session.logout();
      response.complete(success(tokens()));
      await Future.wait([first, second]);
      expect(calls, 1);
      expect(session.user, isNull);
      expect(session.access, isNull);
      expect(storage.credential, isNull);
      session.dispose();
    },
  );
}

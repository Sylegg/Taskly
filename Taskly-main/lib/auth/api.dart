import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'live_updates.dart';

import 'package:flutter/services.dart' show appFlavor;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiFailure implements Exception {
  final String code, message;
  final int status;
  ApiFailure(this.code, this.message, this.status);
  @override
  String toString() => message;
}

class Api {
  final http.Client client;
  final String base;
  Future<dynamic> uploadImage(
    String path,
    List<int> bytes, {
    required String token,
  }) async {
    if (kReleaseMode && !releaseTransportAllowed) {
      throw ApiFailure('CONFIG', 'API production cần HTTPS.', 0);
    }
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw ApiFailure(
        'IMAGE_SIZE',
        'Ảnh phải có dung lượng từ 1 byte đến 10 MB.',
        0,
      );
    }
    final png =
        bytes.length >= 8 &&
        listEquals(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    if (!png && !jpg) {
      throw ApiFailure('IMAGE_TYPE', 'Chỉ hỗ trợ ảnh PNG hoặc JPEG.', 0);
    }
    final request = http.MultipartRequest('POST', Uri.parse('$endpoint$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: png ? 'document.png' : 'document.jpg',
          contentType: MediaType('image', png ? 'png' : 'jpeg'),
        ),
      );
    try {
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 45));
      Map<String, dynamic> result;
      try {
        result =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw ApiFailure(
          'INVALID_RESPONSE',
          'Phản hồi tải ảnh không hợp lệ.',
          response.statusCode,
        );
      }
      if (response.statusCode >= 400 || result['success'] != true) {
        throw ApiFailure(
          result['error']?['code'] ?? 'UPLOAD_ERROR',
          result['error']?['message'] ?? 'Chưa tải được ảnh.',
          response.statusCode,
        );
      }
      return result['data'];
    } on SocketException {
      throw ApiFailure(
        'OFFLINE',
        'Mất kết nối. Ảnh chưa được xác nhận tải lên.',
        0,
      );
    } on TimeoutException {
      throw ApiFailure(
        'TIMEOUT',
        'Tải ảnh quá thời gian. Kiểm tra lại hồ sơ trước khi thử lại.',
        0,
      );
    }
  }

  Api({http.Client? client, String? base})
    : client = client ?? http.Client(),
      base =
          base ??
          const String.fromEnvironment('API_BASE_URL', defaultValue: '');

  String get endpoint => base.isNotEmpty
      ? base.replaceAll(RegExp(r'/+$'), '')
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? 'http://10.0.2.2:8080/api/v1'
            : 'http://localhost:8080/api/v1');

  bool get releaseTransportAllowed {
    final uri = Uri.parse(endpoint);
    return uri.scheme == 'https' ||
        (const bool.fromEnvironment('ALLOW_LOCAL_HTTP') &&
            uri.scheme == 'http' &&
            {'10.0.2.2', '127.0.0.1', 'localhost', '::1'}.contains(uri.host));
  }

  /// Public catalogue images use the same host as API requests on every device.
  String publicAssetUrl(String? path) {
    final value = path?.trim() ?? '';
    if (value.isEmpty) return '';
    final uri = Uri.tryParse(value);
    if (uri == null) return '';
    final resolved = Uri.parse('$endpoint/').resolveUri(uri);
    return {'http', 'https'}.contains(resolved.scheme)
        ? resolved.toString()
        : '';
  }

  Future<dynamic> call(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? token,
  }) async {
    if (kReleaseMode && !releaseTransportAllowed) {
      throw ApiFailure('CONFIG', 'API production cần HTTPS.', 0);
    }
    try {
      final request = http.Request(method, Uri.parse('$endpoint$path'));
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      if (body != null) request.body = jsonEncode(body);
      final response =
          await (() async => http.Response.fromStream(
            await client.send(request),
          ))().timeout(
            Duration(
              seconds:
                  const {
                    '/auth/register',
                    '/auth/resend-otp',
                    '/auth/forgot-password',
                  }.contains(path)
                  ? 45
                  : 15,
            ),
          );
      Map<String, dynamic> data;
      try {
        data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      } catch (_) {
        throw ApiFailure(
          'INVALID_RESPONSE',
          'Phản hồi máy chủ không hợp lệ.',
          response.statusCode,
        );
      }
      if (response.statusCode >= 400 || data['success'] != true) {
        throw ApiFailure(
          data['error']?['code'] ?? 'HTTP_ERROR',
          data['error']?['message'] ?? 'Không thể hoàn tất yêu cầu.',
          response.statusCode,
        );
      }
      return data['data'];
    } on SocketException {
      throw ApiFailure(
        'NETWORK',
        'Không thể kết nối TaskLy. Kiểm tra mạng và thử lại.',
        0,
      );
    } on http.ClientException {
      throw ApiFailure(
        'NETWORK',
        'Không thể kết nối TaskLy. Kiểm tra mạng và thử lại.',
        0,
      );
    } on TimeoutException {
      throw ApiFailure(
        'TIMEOUT',
        'Kết nối hết thời gian chờ. Vui lòng thử lại.',
        0,
      );
    }
  }
}

class Session extends ChangeNotifier {
  LiveUpdates? _liveUpdates;
  Stream<void> get liveChanges => (_liveUpdates ??= LiveUpdates((path) => request(path))).changes;
  static const appType =
      appFlavor == 'partner' ||
          (appFlavor == null && bool.fromEnvironment('PARTNER_APP'))
      ? 'PARTNER'
      : 'CUSTOMER';
  final Api api;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? user;
  String? access, refreshToken, restoreError;
  DateTime? expires;
  bool loading = true, remember = true;
  bool offline = false;
  Future<void>? _refreshing;
  Future<void>? _syncing;
  int _generation = 0;
  Session({Api? api, FlutterSecureStorage? storage})
    : api = api ?? Api(),
      storage = storage ?? const FlutterSecureStorage();
  Future<void> restore() async {
    loading = true;
    restoreError = null;
    notifyListeners();
    try {
      refreshToken = await storage.read(key: 'taskly.refresh');
      if (refreshToken != null) await refresh();
    } catch (e) {
      if (refreshToken != null) restoreError = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> syncUser() =>
      _syncing ??= _syncUser().whenComplete(() => _syncing = null);

  Future<void> _syncUser() async {
    final generation = _generation;
    dynamic profile;
    try {
      profile = await request('/users/me');
      offline = false;
    } on ApiFailure catch (failure) {
      if (generation == _generation &&
          {'NETWORK', 'TIMEOUT'}.contains(failure.code)) {
        offline = true;
        notifyListeners();
      }
      rethrow;
    }
    if (generation == _generation) {
      offline = false;
      user = Map<String, dynamic>.from(profile);
      notifyListeners();
    }
  }

  Future<void> logoutAll() async {
    await request('/auth/mobile/logout-all', method: 'POST');
    await logout();
  }

  Future<void> _accept(Map<String, dynamic> tokens, int generation) async {
    if (generation != _generation) return;
    refreshToken = tokens['refreshToken'];
    access = tokens['accessToken'];
    expires = DateTime.parse(tokens['expiresAt']);
    if (remember) {
      await storage.write(key: 'taskly.refresh', value: refreshToken);
    }
    if (generation != _generation) {
      await storage.delete(key: 'taskly.refresh');
      return;
    }
    final profile = await api.call('/users/me', token: access);
    if (generation == _generation) {
      user = Map<String, dynamic>.from(profile);
      notifyListeners();
    }
  }

  Future<void> login(
    String email,
    String password, {
    bool rememberMe = true,
    bool byPhone = false,
  }) async {
    remember = rememberMe;
    final generation = ++_generation;
    if (!remember) await storage.delete(key: 'taskly.refresh');
    await _accept(
      Map<String, dynamic>.from(
        await api.call(
          byPhone ? '/auth/mobile/login-phone' : '/auth/mobile/login',
          method: 'POST',
          body: {
            if (byPhone) 'phone': email else 'email': email,
            'password': password,
            'deviceName': 'TaskLy $appType Flutter',
            if (byPhone) 'appType': appType,
          },
        ),
      ),
      generation,
    );
  }

  Future<void> refresh() => _refreshing ??= _doRefresh().whenComplete(() {
    _refreshing = null;
  });
  Future<void> _doRefresh() async {
    final generation = _generation;
    if (refreshToken == null) {
      throw ApiFailure('SESSION_EXPIRED', 'Vui lòng đăng nhập lại.', 401);
    }
    try {
      await _accept(
        Map<String, dynamic>.from(
          await api.call(
            '/auth/mobile/refresh',
            method: 'POST',
            body: {'refreshToken': refreshToken, 'appType': appType},
          ),
        ),
        generation,
      );
    } on ApiFailure catch (e) {
      if ((e.status >= 400 && e.status < 500) && generation == _generation) {
        access = null;
        refreshToken = null;
        user = null;
        await storage.delete(key: 'taskly.refresh');
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    if (expires == null ||
        expires!.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      await refresh();
    }
    try {
      return await api.call(path, method: method, body: body, token: access);
    } on ApiFailure catch (e) {
      if (e.status != 401) rethrow;
      await refresh();
      if (method != 'GET') {
        throw ApiFailure(
          'RETRY_REQUIRED',
          'Phiên đã làm mới. Vui lòng thực hiện lại thao tác.',
          401,
        );
      }
      return api.call(path, token: access);
    }
  }

  Future<dynamic> uploadVerificationImage(
    String id,
    String side,
    List<int> bytes,
  ) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        !['FRONT', 'BACK', 'SELFIE'].contains(side)) {
      throw ApiFailure('KYC_PATH', 'Hồ sơ hoặc mặt ảnh không hợp lệ.', 0);
    }
    if (expires == null ||
        expires!.isBefore(DateTime.now().add(const Duration(seconds: 30)))) {
      await refresh();
    }
    if (access == null) {
      throw ApiFailure('SESSION_EXPIRED', 'Vui lòng đăng nhập lại.', 401);
    }
    try {
      return await api.uploadImage(
        '/verifications/$id/documents/$side',
        bytes,
        token: access!,
      );
    } on ApiFailure catch (e) {
      if (e.status != 401) rethrow;
      await refresh();
      throw ApiFailure(
        'RETRY_REQUIRED',
        'Phiên đã làm mới. Vui lòng tải lại ảnh.',
        401,
      );
    }
  }

  Future<void> logout() async {
    _liveUpdates?.dispose();
    _liveUpdates = null;
    ++_generation;
    final credential = refreshToken;
    access = null;
    refreshToken = null;
    user = null;
    restoreError = null;
    await storage.delete(key: 'taskly.refresh');
    notifyListeners();
    if (credential != null) {
      try {
        await api.call(
          '/auth/mobile/logout',
          method: 'POST',
          body: {'refreshToken': credential},
        );
      } catch (_) {
        /* Local logout remains effective offline. */
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _liveUpdates?.dispose();
    api.client.close();
    super.dispose();
  }
}

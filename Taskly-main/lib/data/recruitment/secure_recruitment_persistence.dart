import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/recruitment/recruitment_repository.dart';

/// Separate account-scoped encrypted metadata; never store identity image bytes.
class SecureRecruitmentPersistence implements RecruitmentPersistence {
  SecureRecruitmentPersistence(
    String accountId, {
    FlutterSecureStorage? storage,
  }) : key = 'taskly.recruitment.demo.v1.$accountId',
       storage = storage ?? const FlutterSecureStorage();
  final String key;
  final FlutterSecureStorage storage;
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String snapshot) =>
      storage.write(key: key, value: snapshot);
}

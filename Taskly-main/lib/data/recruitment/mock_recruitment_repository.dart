import 'dart:async';
import 'dart:convert';

import '../../domain/recruitment/recruitment_models.dart';
import '../../domain/recruitment/recruitment_policy.dart';
import '../../domain/recruitment/recruitment_repository.dart';

/// Demo metadata only. This adapter never calls identity, email or payment providers.
class MockRecruitmentRepository implements RecruitmentRepository {
  MockRecruitmentRepository({
    required this.persistence,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  final RecruitmentPersistence persistence;
  final DateTime Function() clock;
  final Map<String, PartnerApplication> _applications = {};
  final List<RecruitmentAudit> _audit = [];
  final Map<String, String> _requests = {};
  Future<void> _tail = Future.value();
  bool _loaded = false;
  static const schema = 'taskly.partner-recruitment';
  Future<T> _serial<T>(Future<T> Function() action) {
    final done = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        done.complete(await action());
      } catch (e, s) {
        done.completeError(e, s);
      }
    });
    return done.future;
  }

  Map<String, dynamic> _snapshot(
    Map<String, PartnerApplication> apps,
    List<RecruitmentAudit> audit,
    Map<String, String> requests,
  ) => {
    'schema': schema,
    'version': 1,
    'mode': 'DEMO_METADATA_ONLY',
    'applications': apps.values.map((a) => a.toJson()).toList(),
    'audit': audit.map((a) => a.toJson()).toList(),
    'requests': requests,
  };
  ({
    Map<String, PartnerApplication> apps,
    List<RecruitmentAudit> audit,
    Map<String, String> requests,
  })
  _parse(String text) {
    try {
      if (text.length > 2000000) throw const FormatException();
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['schema'] != schema ||
          j['version'] != 1 ||
          j['mode'] != 'DEMO_METADATA_ONLY' ||
          j.keys.any(
            (k) => !{
              'schema',
              'version',
              'mode',
              'applications',
              'audit',
              'requests',
            }.contains(k),
          )) {
        throw const FormatException();
      }
      final apps = <String, PartnerApplication>{};
      final users = <String>{};
      for (final entry in j['applications'] as List) {
        final a = PartnerApplication.fromJson(Map<String, dynamic>.from(entry));
        if (apps.containsKey(a.id) ||
            !users.add(a.userId) ||
            (a.status == RecruitmentStatus.active &&
                !a.eligibility.activationReady)) {
          throw const FormatException();
        }
        apps[a.id] = a;
      }
      final audit = (j['audit'] as List)
          .map((a) => RecruitmentAudit.fromJson(Map<String, dynamic>.from(a)))
          .toList();
      final requests = Map<String, String>.from(j['requests']);
      if (audit.any((a) => !apps.containsKey(a.applicationId))) {
        throw const FormatException();
      }
      return (apps: apps, audit: audit, requests: requests);
    } catch (_) {
      throw const RecruitmentFailure(
        'INVALID_SNAPSHOT',
        'Snapshot demo không hợp lệ. Dữ liệu hiện tại được giữ nguyên.',
      );
    }
  }

  Future<void> _load() async {
    if (_loaded) return;
    final saved = await persistence.read();
    if (saved != null) {
      final parsed = _parse(saved);
      _applications.addAll(parsed.apps);
      _audit.addAll(parsed.audit);
      _requests.addAll(parsed.requests);
    }
    _loaded = true;
  }

  Future<void> _commit(
    Map<String, PartnerApplication> apps,
    List<RecruitmentAudit> audit,
    Map<String, String> requests,
  ) async {
    await persistence.write(jsonEncode(_snapshot(apps, audit, requests)));
    _applications
      ..clear()
      ..addAll(apps);
    _audit
      ..clear()
      ..addAll(audit);
    _requests
      ..clear()
      ..addAll(requests);
  }

  void _admin(RecruitmentActor actor) {
    if (actor.id.isEmpty || actor.role == RecruitmentRole.applicant) {
      throw const RecruitmentFailure(
        'FORBIDDEN',
        'Cần quyền nhân viên tuyển dụng.',
      );
    }
  }

  String _redact(String text) => text
      .replaceAll(RegExp(r'[0-9]{8,}'), '[đã ẩn]')
      .replaceAll(RegExp(r'[^\s]+@[^\s]+'), '[email đã ẩn]');
  @override
  Future<PartnerApplication> application(String userId) => _serial(() async {
    await _load();
    if (userId.trim().isEmpty) {
      throw const RecruitmentFailure('USER_REQUIRED', 'Vui lòng đăng nhập.');
    }
    final existing = _applications.values
        .where((a) => a.userId == userId)
        .firstOrNull;
    if (existing != null) return existing;
    final now = clock();
    final app = PartnerApplication(
      id: 'application-$userId',
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );
    await _commit(
      {..._applications, app.id: app},
      List.of(_audit),
      Map.of(_requests),
    );
    return app;
  });
  @override
  Future<List<PartnerApplication>> applications(RecruitmentActor actor) =>
      _serial(() async {
        _admin(actor);
        await _load();
        return List.unmodifiable(_applications.values);
      });
  @override
  Future<List<RecruitmentAudit>> audit(RecruitmentActor actor) => _serial(
    () async {
      if (actor.id.trim().isEmpty || actor.role != RecruitmentRole.superAdmin) {
        throw const RecruitmentFailure('FORBIDDEN', 'Cần quyền xem nhật ký.');
      }
      await _load();
      return List.unmodifiable(_audit);
    },
  );
  @override
  Future<PartnerApplication> transition({
    required String applicationId,
    required int expectedVersion,
    required RecruitmentStatus next,
    required RecruitmentActor actor,
    required String requestId,
    String reason = '',
    List<String> requiredChanges = const [],
  }) => _serial(() async {
    await _load();
    final a = _applications[applicationId];
    if (a == null) {
      throw const RecruitmentFailure('NOT_FOUND', 'Không tìm thấy hồ sơ.');
    }
    RecruitmentPolicy.authorize(actor, a, next);
    if (requestId.trim().isEmpty) {
      throw const RecruitmentFailure('REQUEST_REQUIRED', 'Thiếu mã thao tác.');
    }
    final signature = jsonEncode([
      applicationId,
      actor.id,
      actor.role.name,
      next.name,
      expectedVersion,
      _redact(reason),
      requiredChanges.map(_redact).toList(),
    ]);
    final prior = _requests[requestId];
    if (prior != null) {
      if (prior != signature) {
        throw const RecruitmentFailure(
          'REQUEST_CONFLICT',
          'Mã thao tác đã dùng cho yêu cầu khác.',
        );
      }
      return a;
    }
    if (a.version != expectedVersion) {
      throw const RecruitmentFailure(
        'VERSION_CONFLICT',
        'Hồ sơ đã thay đổi. Vui lòng tải lại.',
      );
    }
    if (!RecruitmentPolicy.canTransition(a, next)) {
      throw const RecruitmentFailure(
        'INVALID_TRANSITION',
        'Chưa đủ điều kiện chuyển bước.',
      );
    }
    if ({
          RecruitmentStatus.rejected,
          RecruitmentStatus.actionRequired,
          RecruitmentStatus.suspended,
          RecruitmentStatus.escalated,
        }.contains(next) &&
        reason.trim().isEmpty) {
      throw const RecruitmentFailure(
        'REASON_REQUIRED',
        'Vui lòng ghi rõ lý do.',
      );
    }
    if (next == RecruitmentStatus.actionRequired && requiredChanges.isEmpty) {
      throw const RecruitmentFailure(
        'CHANGES_REQUIRED',
        'Chỉ rõ các mục cần bổ sung.',
      );
    }
    final now = clock();
    final updated = a.transition(
      next,
      now,
      reason: _redact(reason),
      requiredChanges: requiredChanges.map(_redact).toList(),
    );
    final log = RecruitmentAudit(
      actorId: actor.id,
      role: actor.role,
      applicationId: a.id,
      before: a.status,
      after: next,
      reason: _redact(reason),
      at: now,
      requestId: requestId,
    );
    await _commit({..._applications, a.id: updated}, [..._audit, log], {
      ..._requests,
      requestId: signature,
    });
    return updated;
  });
  @override
  Future<String> exportDemoSnapshot(RecruitmentActor actor) => _serial(
    () async {
      if (actor.id.trim().isEmpty || actor.role != RecruitmentRole.superAdmin) {
        throw const RecruitmentFailure(
          'FORBIDDEN',
          'Chỉ quản trị viên được xuất snapshot demo.',
        );
      }
      await _load();
      return jsonEncode(_snapshot(_applications, _audit, _requests));
    },
  );
  @override
  Future<void> importDemoSnapshot(String snapshot, RecruitmentActor actor) =>
      _serial(() async {
        if (actor.id.trim().isEmpty ||
            actor.role != RecruitmentRole.superAdmin) {
          throw const RecruitmentFailure(
            'FORBIDDEN',
            'Chỉ quản trị viên được nhập snapshot demo.',
          );
        }
        await _load();
        final parsed = _parse(snapshot);
        if (_applications.values.any((current) {
          final replacement = parsed.apps[current.id];
          return replacement == null ||
              replacement.version < current.version ||
              replacement.userId != current.userId;
        })) {
          throw const RecruitmentFailure(
            'STALE_SNAPSHOT',
            'Snapshot thiếu hồ sơ hoặc cũ hơn dữ liệu hiện tại.',
          );
        }
        // Demo snapshots are explicit backups, never authority for production KYC or job eligibility.
        await _commit(parsed.apps, parsed.audit, parsed.requests);
      });
}

class MemoryRecruitmentPersistence implements RecruitmentPersistence {
  String? snapshot;
  @override
  Future<String?> read() async => snapshot;
  @override
  Future<void> write(String value) async {
    snapshot = value;
  }
}

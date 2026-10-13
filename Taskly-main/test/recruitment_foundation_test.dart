import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taskly_mobile/domain/recruitment/recruitment_models.dart';
import 'package:taskly_mobile/domain/recruitment/recruitment_policy.dart';
import 'package:taskly_mobile/data/recruitment/mock_recruitment_repository.dart';
import 'package:taskly_mobile/data/recruitment/recruitment_seed.dart';

const admin = RecruitmentActor('demo-admin', RecruitmentRole.superAdmin);
void main() {
  final now = DateTime.utc(2026, 10, 9);
  test(
    'new applicants persist account separation and cannot accept work',
    () async {
      final persistence = MemoryRecruitmentPersistence();
      final repo = MockRecruitmentRepository(
        persistence: persistence,
        clock: () => now,
      );
      final a = await repo.application('alice');
      final b = await repo.application('bob');
      expect(a.id, isNot(b.id));
      expect(a.canAcceptJob, false);
      final resumed = MockRecruitmentRepository(
        persistence: persistence,
        clock: () => now,
      );
      expect((await resumed.application('alice')).id, a.id);
      await expectLater(
        repo.transition(
          applicationId: a.id,
          expectedVersion: 0,
          next: RecruitmentStatus.active,
          actor: const RecruitmentActor('alice', RecruitmentRole.applicant),
          requestId: 'skip',
        ),
        throwsA(isA<RecruitmentFailure>()),
      );
    },
  );
  test('roles cannot bypass preliminary or final decisions', () async {
    final repo = MockRecruitmentRepository(
      persistence: MemoryRecruitmentPersistence(),
      clock: () => now,
    );
    await repo.importDemoSnapshot(recruitmentDemoSeed(now), admin);
    const id = 'demo-application-6';
    await expectLater(
      repo.transition(
        applicationId: id,
        expectedVersion: 0,
        next: RecruitmentStatus.preliminaryApproved,
        actor: const RecruitmentActor('finance', RecruitmentRole.financeStaff),
        requestId: 'denied',
      ),
      throwsA(isA<RecruitmentFailure>()),
    );
    await expectLater(
      repo.transition(
        applicationId: id,
        expectedVersion: 0,
        next: RecruitmentStatus.preliminaryApproved,
        actor: const RecruitmentActor(
          'demo-applicant-6',
          RecruitmentRole.applicant,
        ),
        requestId: 'self',
      ),
      throwsA(isA<RecruitmentFailure>()),
    );
  });
  test(
    'request changes preserves earned steps and retry is idempotent',
    () async {
      final p = MemoryRecruitmentPersistence();
      final repo = MockRecruitmentRepository(persistence: p, clock: () => now);
      await repo.importDemoSnapshot(recruitmentDemoSeed(now), admin);
      Future<PartnerApplication> submit() => repo.transition(
        applicationId: 'demo-application-6',
        expectedVersion: 0,
        next: RecruitmentStatus.actionRequired,
        actor: const RecruitmentActor('kyc', RecruitmentRole.kycStaff),
        requestId: 'change-1',
        reason: 'Bổ sung ảnh mẫu',
        requiredChanges: ['portrait-sample'],
      );
      final a = await submit();
      await submit();
      expect(a.version, 1);
      expect(a.eligibility.examPassed, true);
      expect(a.eligibility.trainingComplete, true);
      expect((await repo.audit(admin)).length, 1);
      final restored = MockRecruitmentRepository(
        persistence: p,
        clock: () => now,
      );
      expect((await restored.application('demo-applicant-6')).requiredChanges, [
        'portrait-sample',
      ]);
    },
  );
  test('corrupt or stale snapshot never changes valid state', () async {
    final repo = MockRecruitmentRepository(
      persistence: MemoryRecruitmentPersistence(),
      clock: () => now,
    );
    await repo.application('alice');
    final before = await repo.exportDemoSnapshot(admin);
    await expectLater(
      repo.importDemoSnapshot('{"version":999}', admin),
      throwsA(isA<RecruitmentFailure>()),
    );
    expect(await repo.exportDemoSnapshot(admin), before);
    final bad = jsonDecode(before) as Map<String, dynamic>;
    bad['applications'][0]['documentNumber'] = '123456789012';
    await expectLater(
      repo.importDemoSnapshot(jsonEncode(bad), admin),
      throwsA(isA<RecruitmentFailure>()),
    );
  });
  test('only ACTIVE with every prerequisite can accept and suspension is immediate', () async {
    final repo = MockRecruitmentRepository(
      persistence: MemoryRecruitmentPersistence(),
      clock: () => now,
    );
    await repo.importDemoSnapshot(recruitmentDemoSeed(now), admin);
    final a = await repo.application('demo-applicant-12');
    expect(a.canAcceptJob, true);
    final suspended = await repo.transition(
      applicationId: a.id,
      expectedVersion: 0,
      next: RecruitmentStatus.suspended,
      actor: const RecruitmentActor('ops', RecruitmentRole.operationsManager),
      requestId: 'suspend',
      reason: 'Kiểm tra hồ sơ mẫu',
    );
    expect(suspended.canAcceptJob, false);
    final approved = a.transition(RecruitmentStatus.approved, now);
    expect(approved.canAcceptJob, false);
    expect(
      RecruitmentPolicy.canTransition(a, RecruitmentStatus.examInProgress),
      false,
    );
  });
  test('preliminary approval records eligibility without activation', () async {
    final repo = MockRecruitmentRepository(
      persistence: MemoryRecruitmentPersistence(),
      clock: () => now,
    );
    await repo.importDemoSnapshot(recruitmentDemoSeed(now), admin);
    final a = await repo.transition(
      applicationId: 'demo-application-6',
      expectedVersion: 0,
      next: RecruitmentStatus.preliminaryApproved,
      actor: const RecruitmentActor('kyc', RecruitmentRole.kycStaff),
      requestId: 'prelim',
    );
    expect(a.eligibility.preliminaryApproved, true);
    expect(a.canAcceptJob, false);
    expect(
      RecruitmentPolicy.canTransition(a, RecruitmentStatus.uniformPending),
      true,
    );
  });
  test(
    'stale decisions and failed persistence never overwrite valid state',
    () async {
      final p = FailingPersistence();
      final repo = MockRecruitmentRepository(persistence: p, clock: () => now);
      await repo.importDemoSnapshot(recruitmentDemoSeed(now), admin);
      final before = await repo.exportDemoSnapshot(admin);
      p.fail = true;
      await expectLater(
        repo.transition(
          applicationId: 'demo-application-6',
          expectedVersion: 0,
          next: RecruitmentStatus.actionRequired,
          actor: admin,
          requestId: 'atomic',
          reason: 'Sửa ảnh mẫu',
          requiredChanges: ['portrait-sample'],
        ),
        throwsA(isA<StateError>()),
      );
      expect(await repo.exportDemoSnapshot(admin), before);
      p.fail = false;
      await repo.transition(
        applicationId: 'demo-application-6',
        expectedVersion: 0,
        next: RecruitmentStatus.actionRequired,
        actor: admin,
        requestId: 'atomic',
        reason: 'Sửa ảnh mẫu',
        requiredChanges: ['portrait-sample'],
      );
      await expectLater(
        repo.transition(
          applicationId: 'demo-application-6',
          expectedVersion: 0,
          next: RecruitmentStatus.preliminaryReview,
          actor: admin,
          requestId: 'stale',
        ),
        throwsA(isA<RecruitmentFailure>()),
      );
    },
  );
  test(
    'seed has at least 15 fictional applicants and safe roundtrip',
    () async {
      final repo = MockRecruitmentRepository(
        persistence: MemoryRecruitmentPersistence(),
        clock: () => now,
      );
      await repo.importDemoSnapshot(recruitmentDemoSeed(now), admin);
      expect((await repo.applications(admin)).length, 15);
      final exported = await repo.exportDemoSnapshot(admin);
      expect(exported, contains('DEMO_METADATA_ONLY'));
      expect(exported, isNot(contains('documentNumber')));
      final second = MockRecruitmentRepository(
        persistence: MemoryRecruitmentPersistence(),
      );
      await second.importDemoSnapshot(exported, admin);
      expect((await second.applications(admin)).length, 15);
    },
  );
}

class FailingPersistence extends MemoryRecruitmentPersistence {
  bool fail = false;
  @override
  Future<void> write(String value) async {
    if (fail) {
      throw StateError('offline');
    }
    await super.write(value);
  }
}

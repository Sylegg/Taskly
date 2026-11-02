import 'recruitment_models.dart';

abstract interface class PartnerOnboardingRepository {
  Future<PartnerApplication> application(String userId);
  Future<PartnerApplication> transition({
    required String applicationId,
    required int expectedVersion,
    required RecruitmentStatus next,
    required RecruitmentActor actor,
    required String requestId,
    String reason = '',
    List<String> requiredChanges = const [],
  });
}

abstract interface class RecruitmentRepository
    implements PartnerOnboardingRepository {
  Future<List<PartnerApplication>> applications(RecruitmentActor actor);
  Future<List<RecruitmentAudit>> audit(RecruitmentActor actor);
  Future<String> exportDemoSnapshot(RecruitmentActor actor);
  Future<void> importDemoSnapshot(String snapshot, RecruitmentActor actor);
}

abstract interface class RecruitmentPersistence {
  Future<String?> read();
  Future<void> write(String snapshot);
}

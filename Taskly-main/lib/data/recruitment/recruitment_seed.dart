import 'dart:convert';

import '../../domain/recruitment/recruitment_models.dart';
import 'mock_recruitment_repository.dart';

/// Fictional metadata snapshots. No names, phones, emails, IDs or document images.
String recruitmentDemoSeed(DateTime now) {
  final statuses = [
    RecruitmentStatus.registered,
    RecruitmentStatus.registered,
    RecruitmentStatus.examFailed,
    RecruitmentStatus.examPassed,
    RecruitmentStatus.trainingRequired,
    RecruitmentStatus.profileIncomplete,
    RecruitmentStatus.preliminaryReview,
    RecruitmentStatus.actionRequired,
    RecruitmentStatus.preliminaryApproved,
    RecruitmentStatus.uniformPending,
    RecruitmentStatus.documentsReceived,
    RecruitmentStatus.finalReview,
    RecruitmentStatus.active,
    RecruitmentStatus.rejected,
    RecruitmentStatus.suspended,
  ];
  final advanced = {
    RecruitmentStatus.preliminaryReview,
    RecruitmentStatus.actionRequired,
    RecruitmentStatus.preliminaryApproved,
    RecruitmentStatus.uniformPending,
    RecruitmentStatus.documentsReceived,
    RecruitmentStatus.finalReview,
    RecruitmentStatus.active,
    RecruitmentStatus.rejected,
    RecruitmentStatus.suspended,
  };
  final prelim = {
    RecruitmentStatus.preliminaryApproved,
    RecruitmentStatus.uniformPending,
    RecruitmentStatus.documentsReceived,
    RecruitmentStatus.finalReview,
    RecruitmentStatus.active,
    RecruitmentStatus.suspended,
  };
  final received = {
    RecruitmentStatus.documentsReceived,
    RecruitmentStatus.finalReview,
    RecruitmentStatus.active,
    RecruitmentStatus.suspended,
  };
  final apps = <PartnerApplication>[];
  for (var i = 0; i < statuses.length; i++) {
    final s = statuses[i];
    final approved = {
      RecruitmentStatus.active,
      RecruitmentStatus.suspended,
    }.contains(s);
    apps.add(
      PartnerApplication(
        id: 'demo-application-$i',
        userId: 'demo-applicant-$i',
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now,
        status: s,
        documentsReceivedAt: received.contains(s)
            ? now.subtract(const Duration(hours: 12))
            : null,
        activatedAt: approved ? now : null,
        requiredChanges: s == RecruitmentStatus.actionRequired
            ? const ['portrait-sample']
            : const [],
        reason: s == RecruitmentStatus.rejected
            ? 'Hồ sơ mẫu chưa phù hợp, có thể đề nghị xem xét lại.'
            : '',
        eligibility: RecruitmentEligibility(
          registrationComplete: i != 0 && i != 1,
          recruiting: true,
          examPassed:
              advanced.contains(s) ||
              {
                RecruitmentStatus.examPassed,
                RecruitmentStatus.trainingRequired,
                RecruitmentStatus.profileIncomplete,
              }.contains(s),
          trainingComplete:
              advanced.contains(s) || s == RecruitmentStatus.profileIncomplete,
          agreementsCurrent: advanced.contains(s),
          profileComplete: advanced.contains(s),
          preliminaryApproved: prelim.contains(s),
          uniformResolved: received.contains(s),
          appointmentCheckedIn: received.contains(s),
          documentsValid: received.contains(s),
          finalApproved: approved,
          skillsConfigured: approved,
          areasConfigured: approved,
          availabilityConfigured: approved,
        ),
      ),
    );
  }
  return jsonEncode({
    'schema': MockRecruitmentRepository.schema,
    'version': 1,
    'mode': 'DEMO_METADATA_ONLY',
    'applications': apps.map((a) => a.toJson()).toList(),
    'audit': [],
    'requests': {},
  });
}

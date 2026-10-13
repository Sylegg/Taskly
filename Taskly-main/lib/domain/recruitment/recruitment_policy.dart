import 'recruitment_models.dart';

abstract final class RecruitmentPolicy {
  static const transitions = <RecruitmentStatus, Set<RecruitmentStatus>>{
    RecruitmentStatus.registered: {
      RecruitmentStatus.examRequired,
      RecruitmentStatus.waitlisted,
    },
    RecruitmentStatus.waitlisted: {RecruitmentStatus.registered},
    RecruitmentStatus.examRequired: {RecruitmentStatus.examInProgress},
    RecruitmentStatus.examInProgress: {
      RecruitmentStatus.examFailed,
      RecruitmentStatus.examPassed,
      RecruitmentStatus.expired,
    },
    RecruitmentStatus.examFailed: {RecruitmentStatus.examInProgress},
    RecruitmentStatus.expired: {RecruitmentStatus.examInProgress},
    RecruitmentStatus.examPassed: {RecruitmentStatus.trainingRequired},
    RecruitmentStatus.trainingRequired: {RecruitmentStatus.agreementRequired},
    RecruitmentStatus.agreementRequired: {RecruitmentStatus.profileIncomplete},
    RecruitmentStatus.profileIncomplete: {RecruitmentStatus.preliminaryReview},
    RecruitmentStatus.preliminaryReview: {
      RecruitmentStatus.preliminaryApproved,
      RecruitmentStatus.actionRequired,
      RecruitmentStatus.rejected,
      RecruitmentStatus.escalated,
    },
    RecruitmentStatus.preliminaryApproved: {
      RecruitmentStatus.uniformPending,
      RecruitmentStatus.documentAppointment,
    },
    RecruitmentStatus.uniformPending: {RecruitmentStatus.documentAppointment},
    RecruitmentStatus.documentAppointment: {
      RecruitmentStatus.documentsReceived,
      RecruitmentStatus.actionRequired,
    },
    RecruitmentStatus.documentsReceived: {RecruitmentStatus.finalReview},
    RecruitmentStatus.finalReview: {
      RecruitmentStatus.approved,
      RecruitmentStatus.actionRequired,
      RecruitmentStatus.rejected,
      RecruitmentStatus.escalated,
    },
    RecruitmentStatus.approved: {RecruitmentStatus.active},
    RecruitmentStatus.active: {RecruitmentStatus.suspended},
    RecruitmentStatus.suspended: {RecruitmentStatus.approved},
    RecruitmentStatus.actionRequired: {
      RecruitmentStatus.preliminaryReview,
      RecruitmentStatus.documentAppointment,
      RecruitmentStatus.finalReview,
    },
    RecruitmentStatus.rejected: {RecruitmentStatus.escalated},
    RecruitmentStatus.escalated: {
      RecruitmentStatus.preliminaryReview,
      RecruitmentStatus.finalReview,
      RecruitmentStatus.rejected,
    },
  };
  static bool canTransition(PartnerApplication a, RecruitmentStatus next) {
    if (!(transitions[a.status]?.contains(next) ?? false)) return false;
    final e = a.eligibility;
    return switch (next) {
      RecruitmentStatus.examRequired => e.registrationComplete && e.recruiting,
      RecruitmentStatus.waitlisted => !e.recruiting,
      RecruitmentStatus.examPassed => e.examPassed,
      RecruitmentStatus.trainingRequired => e.examPassed,
      RecruitmentStatus.agreementRequired => e.trainingComplete,
      RecruitmentStatus.profileIncomplete => e.agreementsCurrent,
      RecruitmentStatus.preliminaryReview => e.preliminaryReady,
      RecruitmentStatus.preliminaryApproved => e.preliminaryReady,
      RecruitmentStatus.uniformPending ||
      RecruitmentStatus.documentAppointment => e.preliminaryApproved,
      RecruitmentStatus.documentsReceived =>
        e.appointmentCheckedIn && e.documentsValid,
      RecruitmentStatus.finalReview =>
        e.finalReady && a.documentsReceivedAt != null,
      RecruitmentStatus.approved => e.finalReady,
      RecruitmentStatus.active => e.activationReady,
      _ => true,
    };
  }

  static void authorize(
    RecruitmentActor actor,
    PartnerApplication a,
    RecruitmentStatus next,
  ) {
    if (actor.id.isEmpty) {
      throw const RecruitmentFailure('UNAUTHENTICATED', 'Vui lòng đăng nhập.');
    }
    if (actor.role == RecruitmentRole.superAdmin) return;
    final applicant =
        actor.role == RecruitmentRole.applicant && actor.id == a.userId;
    final ownActions = {
      RecruitmentStatus.examRequired,
      RecruitmentStatus.examInProgress,
      RecruitmentStatus.trainingRequired,
      RecruitmentStatus.profileIncomplete,
      RecruitmentStatus.preliminaryReview,
      RecruitmentStatus.uniformPending,
      RecruitmentStatus.documentAppointment,
      RecruitmentStatus.active,
      RecruitmentStatus.waitlisted,
      RecruitmentStatus.escalated,
    };
    if (applicant &&
        ownActions.contains(next) &&
        !(next == RecruitmentStatus.preliminaryReview &&
            a.status == RecruitmentStatus.escalated)) {
      return;
    }
    final allowed = switch (actor.role) {
      RecruitmentRole.trainingManager => {
        RecruitmentStatus.examPassed,
        RecruitmentStatus.examFailed,
        RecruitmentStatus.expired,
        RecruitmentStatus.agreementRequired,
      },
      RecruitmentRole.kycStaff => {
        RecruitmentStatus.preliminaryApproved,
        RecruitmentStatus.actionRequired,
        RecruitmentStatus.rejected,
        RecruitmentStatus.escalated,
      },
      RecruitmentRole.receptionStaff => {
        RecruitmentStatus.documentsReceived,
        RecruitmentStatus.actionRequired,
      },
      RecruitmentRole.operationsManager => {
        RecruitmentStatus.finalReview,
        RecruitmentStatus.approved,
        RecruitmentStatus.rejected,
        RecruitmentStatus.suspended,
        RecruitmentStatus.actionRequired,
        RecruitmentStatus.escalated,
      },
      RecruitmentRole.recruitmentStaff => {
        RecruitmentStatus.registered,
        RecruitmentStatus.waitlisted,
        RecruitmentStatus.actionRequired,
      },
      _ => <RecruitmentStatus>{},
    };
    if (!allowed.contains(next)) {
      throw const RecruitmentFailure(
        'FORBIDDEN',
        'Bạn không có quyền thực hiện quyết định này.',
      );
    }
    if (actor.role == RecruitmentRole.kycStaff &&
        a.status == RecruitmentStatus.finalReview) {
      throw const RecruitmentFailure(
        'FORBIDDEN',
        'Duyệt cuối cần người quản lý được ủy quyền.',
      );
    }
  }
}

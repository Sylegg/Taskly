enum RecruitmentStatus {
  registered,
  examRequired,
  examInProgress,
  examFailed,
  examPassed,
  trainingRequired,
  agreementRequired,
  profileIncomplete,
  preliminaryReview,
  actionRequired,
  preliminaryApproved,
  uniformPending,
  documentAppointment,
  documentsReceived,
  finalReview,
  approved,
  active,
  rejected,
  suspended,
  waitlisted,
  cancelledByApplicant,
  expired,
  escalated,
}

enum RecruitmentRole {
  applicant,
  superAdmin,
  recruitmentStaff,
  trainingManager,
  kycStaff,
  receptionStaff,
  financeStaff,
  operationsManager,
}

class RecruitmentFailure implements Exception {
  const RecruitmentFailure(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}

class RecruitmentActor {
  const RecruitmentActor(this.id, this.role);
  final String id;
  final RecruitmentRole role;
}

class RecruitmentEligibility {
  const RecruitmentEligibility({
    this.registrationComplete = false,
    this.recruiting = true,
    this.examPassed = false,
    this.trainingComplete = false,
    this.agreementsCurrent = false,
    this.profileComplete = false,
    this.preliminaryApproved = false,
    this.uniformResolved = false,
    this.appointmentCheckedIn = false,
    this.documentsValid = false,
    this.finalApproved = false,
    this.skillsConfigured = false,
    this.areasConfigured = false,
    this.availabilityConfigured = false,
  });
  final bool registrationComplete,
      recruiting,
      examPassed,
      trainingComplete,
      agreementsCurrent,
      profileComplete,
      preliminaryApproved,
      uniformResolved,
      appointmentCheckedIn,
      documentsValid,
      finalApproved,
      skillsConfigured,
      areasConfigured,
      availabilityConfigured;
  bool get preliminaryReady =>
      registrationComplete &&
      recruiting &&
      examPassed &&
      trainingComplete &&
      agreementsCurrent &&
      profileComplete;
  bool get finalReady =>
      preliminaryApproved &&
      uniformResolved &&
      appointmentCheckedIn &&
      documentsValid &&
      agreementsCurrent;
  bool get activationReady =>
      finalReady &&
      finalApproved &&
      skillsConfigured &&
      areasConfigured &&
      availabilityConfigured;
  RecruitmentEligibility withApproval({
    bool? preliminaryApproved,
    bool? finalApproved,
  }) => RecruitmentEligibility(
    registrationComplete: registrationComplete,
    recruiting: recruiting,
    examPassed: examPassed,
    trainingComplete: trainingComplete,
    agreementsCurrent: agreementsCurrent,
    profileComplete: profileComplete,
    preliminaryApproved: preliminaryApproved ?? this.preliminaryApproved,
    uniformResolved: uniformResolved,
    appointmentCheckedIn: appointmentCheckedIn,
    documentsValid: documentsValid,
    finalApproved: finalApproved ?? this.finalApproved,
    skillsConfigured: skillsConfigured,
    areasConfigured: areasConfigured,
    availabilityConfigured: availabilityConfigured,
  );

  Map<String, dynamic> toJson() => {
    'registrationComplete': registrationComplete,
    'recruiting': recruiting,
    'examPassed': examPassed,
    'trainingComplete': trainingComplete,
    'agreementsCurrent': agreementsCurrent,
    'profileComplete': profileComplete,
    'preliminaryApproved': preliminaryApproved,
    'uniformResolved': uniformResolved,
    'appointmentCheckedIn': appointmentCheckedIn,
    'documentsValid': documentsValid,
    'finalApproved': finalApproved,
    'skillsConfigured': skillsConfigured,
    'areasConfigured': areasConfigured,
    'availabilityConfigured': availabilityConfigured,
  };
  factory RecruitmentEligibility.fromJson(Map<String, dynamic> j) {
    const keys = {
      'registrationComplete',
      'recruiting',
      'examPassed',
      'trainingComplete',
      'agreementsCurrent',
      'profileComplete',
      'preliminaryApproved',
      'uniformResolved',
      'appointmentCheckedIn',
      'documentsValid',
      'finalApproved',
      'skillsConfigured',
      'areasConfigured',
      'availabilityConfigured',
    };
    if (j.keys.any((k) => !keys.contains(k)) ||
        j.values.any((v) => v is! bool)) {
      throw const RecruitmentFailure(
        'INVALID_ELIGIBILITY',
        'Dữ liệu điều kiện không hợp lệ.',
      );
    }
    return RecruitmentEligibility(
      registrationComplete: j['registrationComplete'] == true,
      recruiting: j['recruiting'] != false,
      examPassed: j['examPassed'] == true,
      trainingComplete: j['trainingComplete'] == true,
      agreementsCurrent: j['agreementsCurrent'] == true,
      profileComplete: j['profileComplete'] == true,
      preliminaryApproved: j['preliminaryApproved'] == true,
      uniformResolved: j['uniformResolved'] == true,
      appointmentCheckedIn: j['appointmentCheckedIn'] == true,
      documentsValid: j['documentsValid'] == true,
      finalApproved: j['finalApproved'] == true,
      skillsConfigured: j['skillsConfigured'] == true,
      areasConfigured: j['areasConfigured'] == true,
      availabilityConfigured: j['availabilityConfigured'] == true,
    );
  }
}

class PartnerApplication {
  const PartnerApplication({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    this.status = RecruitmentStatus.registered,
    this.version = 0,
    this.eligibility = const RecruitmentEligibility(),
    this.documentsReceivedAt,
    this.activatedAt,
    this.requiredChanges = const [],
    this.reason = '',
  });
  final String id, userId, reason;
  final DateTime createdAt, updatedAt;
  final DateTime? documentsReceivedAt, activatedAt;
  final RecruitmentStatus status;
  final int version;
  final RecruitmentEligibility eligibility;
  final List<String> requiredChanges;
  bool get canAcceptJob =>
      status == RecruitmentStatus.active && eligibility.activationReady;
  PartnerApplication transition(
    RecruitmentStatus next,
    DateTime now, {
    String reason = '',
    List<String> requiredChanges = const [],
  }) => PartnerApplication(
    id: id,
    userId: userId,
    createdAt: createdAt,
    updatedAt: now,
    status: next,
    version: version + 1,
    eligibility: eligibility.withApproval(
      preliminaryApproved: next == RecruitmentStatus.preliminaryApproved
          ? true
          : null,
      finalApproved: next == RecruitmentStatus.approved ? true : null,
    ),
    documentsReceivedAt: next == RecruitmentStatus.documentsReceived
        ? documentsReceivedAt ?? now
        : documentsReceivedAt,
    activatedAt: next == RecruitmentStatus.active ? now : activatedAt,
    reason: reason,
    requiredChanges: List.unmodifiable(requiredChanges),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'status': status.name,
    'version': version,
    'eligibility': eligibility.toJson(),
    'documentsReceivedAt': documentsReceivedAt?.toUtc().toIso8601String(),
    'activatedAt': activatedAt?.toUtc().toIso8601String(),
    'requiredChanges': requiredChanges,
    'reason': reason,
  };
  factory PartnerApplication.fromJson(Map<String, dynamic> j) {
    const keys = {
      'id',
      'userId',
      'createdAt',
      'updatedAt',
      'status',
      'version',
      'eligibility',
      'documentsReceivedAt',
      'activatedAt',
      'requiredChanges',
      'reason',
    };
    if (j.keys.any((k) => !keys.contains(k)) ||
        j['id'] is! String ||
        j['userId'] is! String ||
        (j['id'] as String).isEmpty ||
        (j['userId'] as String).isEmpty ||
        j['version'] is! int ||
        j['version'] < 0 ||
        j['requiredChanges'] is! List ||
        (j['requiredChanges'] as List).any((v) => v is! String) ||
        j['reason'] is! String) {
      throw const RecruitmentFailure(
        'INVALID_APPLICATION',
        'Snapshot hồ sơ không hợp lệ.',
      );
    }
    return PartnerApplication(
      id: j['id'],
      userId: j['userId'],
      createdAt: DateTime.parse(j['createdAt']),
      updatedAt: DateTime.parse(j['updatedAt']),
      status: RecruitmentStatus.values.byName(j['status']),
      version: j['version'],
      eligibility: RecruitmentEligibility.fromJson(
        Map<String, dynamic>.from(j['eligibility']),
      ),
      documentsReceivedAt: j['documentsReceivedAt'] == null
          ? null
          : DateTime.parse(j['documentsReceivedAt']),
      activatedAt: j['activatedAt'] == null
          ? null
          : DateTime.parse(j['activatedAt']),
      requiredChanges: List.unmodifiable(
        (j['requiredChanges'] as List).cast<String>(),
      ),
      reason: j['reason'],
    );
  }
}

class RecruitmentAudit {
  const RecruitmentAudit({
    required this.actorId,
    required this.role,
    required this.applicationId,
    required this.before,
    required this.after,
    required this.reason,
    required this.at,
    required this.requestId,
  });
  final String actorId, applicationId, reason, requestId;
  final RecruitmentRole role;
  final RecruitmentStatus before, after;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'actorId': actorId,
    'role': role.name,
    'applicationId': applicationId,
    'before': before.name,
    'after': after.name,
    'reason': reason,
    'at': at.toUtc().toIso8601String(),
    'requestId': requestId,
  };
  factory RecruitmentAudit.fromJson(Map<String, dynamic> j) {
    const keys = {
      'actorId',
      'role',
      'applicationId',
      'before',
      'after',
      'reason',
      'at',
      'requestId',
    };
    if (j.length != keys.length ||
        j.keys.any((key) => !keys.contains(key)) ||
        j.values.any((value) => value is! String) ||
        [
          'actorId',
          'applicationId',
          'requestId',
        ].any((key) => (j[key] as String).trim().isEmpty)) {
      throw const RecruitmentFailure('INVALID_AUDIT', 'Nhật ký không hợp lệ.');
    }
    return RecruitmentAudit(
      actorId: j['actorId'],
      role: RecruitmentRole.values.byName(j['role']),
      applicationId: j['applicationId'],
      before: RecruitmentStatus.values.byName(j['before']),
      after: RecruitmentStatus.values.byName(j['after']),
      reason: j['reason'],
      at: DateTime.parse(j['at']),
      requestId: j['requestId'],
    );
  }
}

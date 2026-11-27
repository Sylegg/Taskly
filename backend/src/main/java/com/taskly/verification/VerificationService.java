package com.taskly.verification;

import com.taskly.common.exception.DomainException;
import com.taskly.storage.entity.FileScanStatus;
import com.taskly.storage.PrivateObjectStorageService;
import com.taskly.storage.StorageProperties;
import com.taskly.storage.entity.StoredObject;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.verification.dto.VerificationDtos;
import com.taskly.verification.entity.DocumentSide;
import com.taskly.verification.entity.IdentityVerification;
import com.taskly.verification.entity.TaskerProfile;
import com.taskly.verification.entity.VerificationDocument;
import com.taskly.verification.entity.VerificationHistory;
import com.taskly.verification.entity.VerificationStatus;
import com.taskly.verification.repository.IdentityVerificationRepository;
import com.taskly.verification.repository.TaskerProfileRepository;
import com.taskly.verification.repository.VerificationDocumentRepository;
import com.taskly.verification.repository.VerificationHistoryRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.EnumSet;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service
public class VerificationService {
    private final UserAccountRepository users;
    private final TaskerProfileRepository taskerProfiles;
    private final IdentityVerificationRepository verifications;
    private final VerificationDocumentRepository documents;
    private final VerificationHistoryRepository history;
    private final PrivateObjectStorageService storage;
    private final StorageProperties storageProperties;
    private final Clock clock;
    private final com.taskly.recruitment.RecruitmentService recruitment;
    @org.springframework.beans.factory.annotation.Value("${app.environment:production}")
    private String environment;

    public VerificationService(UserAccountRepository users, TaskerProfileRepository taskerProfiles,
                               IdentityVerificationRepository verifications,
                               VerificationDocumentRepository documents,
                               VerificationHistoryRepository history,
                               PrivateObjectStorageService storage,
                               StorageProperties storageProperties, Clock clock, com.taskly.recruitment.RecruitmentService recruitment) {
        this.users = users;
        this.taskerProfiles = taskerProfiles;
        this.verifications = verifications;
        this.documents = documents;
        this.history = history;
        this.storage = storage;
        this.storageProperties = storageProperties;
        this.clock = clock;
        this.recruitment = recruitment;
    }

    @Transactional
    public VerificationDtos.VerificationResponse start(UUID userId) {
        UserAccount user = requireTasker(userId);
        return response(startDraft(user, user, "Bắt đầu hồ sơ"));
    }

    private IdentityVerification startDraft(UserAccount user, UserAccount actor, String reason) {
        UUID userId = user.getId();
        users.lockForUpdate(userId).orElseThrow(() -> notFound("USER_NOT_FOUND", "Không tìm thấy tài khoản."));
        var latest = verifications.findFirstByUserIdOrderByCreatedAtDesc(userId);
        if (latest.isPresent() && EnumSet.of(VerificationStatus.DRAFT, VerificationStatus.SUBMITTED,
                VerificationStatus.UNDER_REVIEW, VerificationStatus.APPROVED).contains(latest.get().getStatus())) {
            if (latest.get().getStatus() == VerificationStatus.DRAFT) return latest.get();
            throw conflict("KYC_ALREADY_IN_PROGRESS", "Hồ sơ xác minh hiện tại chưa thể tạo lại.");
        }
        Instant now = clock.instant();
        taskerProfiles.findById(userId).orElseGet(() -> taskerProfiles.save(new TaskerProfile(user, now)));
        IdentityVerification verification = verifications.save(new IdentityVerification(user, now));
        history.save(new VerificationHistory(verification, VerificationStatus.NOT_STARTED,
                VerificationStatus.DRAFT, actor, reason, now));
        return verification;
    }

    @Transactional
    public VerificationDtos.VerificationResponse prepareOfficeDraft(
            UUID actorId, UUID applicationId, AdminVerificationController.OfficeDraftRequest request) {
        if (!request.consentRecorded() || request.legalName().trim().length() < 2)
            throw conflict("KYC_OFFICE_INCOMPLETE", "Cần họ tên trên CCCD và sự đồng ý của đối tác tại văn phòng.");
        var application = recruitment.requireOfficeKyc(applicationId);
        UserAccount actor = requireUser(actorId);
        UserAccount owner = requireTasker(application.userId());
        var draft = startDraft(owner, actor, "Tạo bản nháp CCCD tại văn phòng");
        if (draft.getDocumentType() != null || documents.countByVerificationIdAndSideIn(
                draft.getId(), List.of(DocumentSide.FRONT, DocumentSide.BACK, DocumentSide.SELFIE)) > 0) {
            throw conflict("KYC_DRAFT_EXISTS", "Hồ sơ đã có dữ liệu. Hãy bổ sung ảnh vào bản nháp hiện tại.");
        }
        var now = clock.instant();
        draft.setDocumentNumber(request.documentNumber());
        draft.updateDraft(request.legalName().trim(), "NATIONAL_ID", mask(request.documentNumber()), now);
        history.save(new VerificationHistory(draft, VerificationStatus.DRAFT, VerificationStatus.DRAFT,
                actor, "Nhập thông tin CCCD với sự đồng ý trực tiếp của đối tác", now));
        return response(draft);
    }

    @Transactional
    public VerificationDtos.VerificationResponse submitOfficeDraft(
            UUID actorId, UUID applicationId, UUID verificationId, boolean consent) {
        var application = recruitment.requireOfficeKyc(applicationId);
        var verification = verifications.findByIdAndUserId(verificationId, application.userId())
                .orElseThrow(() -> notFound("KYC_NOT_FOUND", "Không tìm thấy hồ sơ xác minh của đối tác."));
        if (verification.getStatus() != VerificationStatus.DRAFT || !"NATIONAL_ID".equals(verification.getDocumentType())
                || verification.getDocumentNumber() == null || !verification.getDocumentNumber().matches("[0-9]{12}")) {
            throw conflict("KYC_NOT_EDITABLE", "Chỉ có thể gửi bản nháp CCCD đã nhập đủ số định danh.");
        }
        requireCleanIdentitySides(verification.getId());
        return submitDraft(verification, requireUser(actorId), consent,
                "Nhân viên gửi hồ sơ sau khi đối chiếu giấy tờ gốc và xác nhận sự đồng ý trực tiếp");
    }

    @Transactional
    public VerificationDtos.VerificationResponse approveOfficeDraft(
            UUID actorId, UUID applicationId, UUID verificationId, boolean consent) {
        submitOfficeDraft(actorId, applicationId, verificationId, consent);
        return decide(actorId, verificationId, VerificationStatus.APPROVED,
                "Đã đối chiếu CCCD gốc và phê duyệt cùng chủ hồ sơ tại văn phòng.");
    }

    @Transactional
    public VerificationDtos.VerificationResponse submitAssisted(
            UUID actorId, UUID partnerId, UUID verificationId, long version, String legalName,
            String documentNumber, boolean ownerAuthorized, MultipartFile front, MultipartFile back) {
        if (!ownerAuthorized || legalName == null || legalName.trim().length() < 2 || legalName.trim().length() > 160
                || documentNumber == null || !documentNumber.matches("[0-9]{12}")) {
            throw new DomainException("KYC_INCOMPLETE", "Cần họ tên, 12 chữ số trên CCCD và sự đồng ý của đối tác.",
                    HttpStatus.UNPROCESSABLE_ENTITY);
        }
        UserAccount owner = lockPartner(partnerId);
        UserAccount actor = requireUser(actorId);
        var latest = currentAssistedRecord(partnerId, verificationId, version);
        boolean newDraft = latest == null || EnumSet.of(VerificationStatus.REJECTED, VerificationStatus.EXPIRED)
                .contains(latest.getStatus());
        if (!newDraft && latest.getStatus() != VerificationStatus.DRAFT && !pendingNationalId(latest)) {
            throw conflict("KYC_NOT_EDITABLE", "Hồ sơ định danh hiện tại chưa thể bổ sung CCCD.");
        }
        var verification = newDraft ? startDraft(owner, actor, "Admin tạo hồ sơ CCCD cho đối tác") : latest;
        boolean reusePhotos = "NATIONAL_ID".equals(verification.getDocumentType())
                && (verification.getDocumentNumber() == null || verification.getDocumentNumber().equals(documentNumber));
        if (front == null && (!reusePhotos || !hasCleanSide(verification.getId(), DocumentSide.FRONT))
                || back == null && (!reusePhotos || !hasCleanSide(verification.getId(), DocumentSide.BACK))) {
            throw new DomainException("KYC_SCAN_REQUIRED", "Chọn ảnh cho cả hai mặt CCCD còn thiếu hoặc cần thay.",
                    HttpStatus.UNPROCESSABLE_ENTITY);
        }
        if (front != null) storeDocument(verification, DocumentSide.FRONT, front);
        if (back != null) storeDocument(verification, DocumentSide.BACK, back);
        requireCleanIdentitySides(verification.getId());

        Instant now = clock.instant();
        var before = verification.getStatus();
        verification.setDocumentNumber(documentNumber);
        verification.updateDraft(legalName.trim(), "NATIONAL_ID", mask(documentNumber), now);
        if (before == VerificationStatus.DRAFT) verification.submit(now);
        else verification.resubmitAfterAdminUpdate(now);
        taskerProfiles.findById(partnerId).orElseGet(() -> taskerProfiles.save(new TaskerProfile(owner, now)))
                .updateKyc(VerificationStatus.SUBMITTED, now);
        history.save(new VerificationHistory(verification, before, VerificationStatus.SUBMITTED, actor,
                "Admin gửi hai mặt CCCD sau khi đối chiếu giấy tờ gốc và ghi nhận sự đồng ý của đối tác", now));
        return response(verification);
    }

    @Transactional
    public VerificationDtos.VerificationResponse approveAssisted(
            UUID actorId, UUID partnerId, UUID verificationId, long version) {
        lockPartner(partnerId);
        var verification = currentAssistedRecord(partnerId, verificationId, version);
        if (verification == null || !pendingNationalId(verification)
                || verification.getDocumentNumber() == null || !verification.getDocumentNumber().matches("[0-9]{12}")
                || verification.getLegalName() == null || verification.getLegalName().trim().length() < 2) {
            throw conflict("KYC_NOT_EDITABLE", "Cần gửi hồ sơ CCCD đầy đủ trước khi phê duyệt.");
        }
        return applyDecision(requireUser(actorId), verification, VerificationStatus.APPROVED,
                "Đã đối chiếu CCCD gốc và phê duyệt.");
    }

    private UserAccount lockPartner(UUID partnerId) {
        var owner = requireUser(partnerId);
        var application = recruitment.verificationApplication(partnerId);
        if (application == null && !owner.hasUsedPartnerApp()
                && owner.getRoles().stream().noneMatch(role -> role.getKey().equals("TASKER"))) {
            throw notFound("PARTNER_NOT_FOUND", "Không tìm thấy đối tác.");
        }
        return owner;
    }

    private IdentityVerification currentAssistedRecord(UUID partnerId, UUID verificationId, long version) {
        var latest = verifications.findFirstByUserIdOrderByCreatedAtDesc(partnerId).orElse(null);
        if (!Objects.equals(verificationId, latest == null ? null : latest.getId())
                || version != (latest == null ? -1 : latest.getVersion())) {
            throw conflict("KYC_CHANGED", "Hồ sơ CCCD đã thay đổi. Vui lòng tải lại hồ sơ.");
        }
        return latest;
    }

    private boolean pendingNationalId(IdentityVerification verification) {
        return "NATIONAL_ID".equals(verification.getDocumentType())
                && EnumSet.of(VerificationStatus.SUBMITTED, VerificationStatus.UNDER_REVIEW).contains(verification.getStatus());
    }

    private boolean hasCleanSide(UUID verificationId, DocumentSide side) {
        return documents.findByVerificationIdAndSide(verificationId, side)
                .filter(document -> document.getStoredObject().getScanStatus() == FileScanStatus.CLEAN).isPresent();
    }

    @Transactional(readOnly = true)
    public VerificationDtos.VerificationResponse current(UUID userId) {
        return verifications.findFirstByUserIdOrderByCreatedAtDesc(userId)
                .map(this::response)
                .orElse(null);
    }

    @Transactional(readOnly = true)
    public VerificationDtos.VerificationResponse currentOwner(UUID userId) {
        return verifications.findFirstByUserIdOrderByCreatedAtDesc(userId).map(value -> {
            var v = response(value);
            return new VerificationDtos.VerificationResponse(v.id(),v.userId(),v.status(),v.legalName(),v.documentType(),v.documentNumberMasked(),v.submittedAt(),v.decisionReason(),v.documents(),value.getDocumentNumber());
        }).orElse(null);
    }

    @Transactional
    public VerificationDtos.VerificationResponse updateDraft(
            UUID userId, UUID verificationId, VerificationDtos.DraftRequest request) {
        IdentityVerification verification = requireOwnedDraft(userId, verificationId);
        if (request.documentType().equals("NATIONAL_ID") && !request.documentNumber().isEmpty()
                && !request.documentNumber().matches("[0-9]{12}")) {
            throw new DomainException("KYC_NUMBER_INVALID", "CCCD phải gồm đúng 12 chữ số.", HttpStatus.UNPROCESSABLE_ENTITY);
        }

        String number=request.documentNumber().isBlank()?verification.getDocumentNumberMasked():mask(request.documentNumber());
        if ((!request.documentNumber().isBlank() && request.documentNumber().replaceAll("\\s+", "").length()<6)
                || (verification.getStatus()==VerificationStatus.SUBMITTED && (request.legalName().trim().length()<2 || number==null || number.length()<6))
                || (request.documentNumber().isBlank() && verification.getDocumentNumberMasked()!=null && verification.getDocumentType()!=null && !request.documentType().equals(verification.getDocumentType()))) {
            throw new DomainException("KYC_INCOMPLETE", "Nhập thông tin hợp lệ; cần số giấy tờ mới khi đổi loại giấy tờ.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        if (!request.documentNumber().isEmpty()) verification.setDocumentNumber(request.documentNumber());
        verification.updateDraft(request.legalName().trim(), request.documentType(), number, clock.instant());
        history.save(new VerificationHistory(verification, verification.getStatus(), verification.getStatus(),
                verification.getUser(), "Cập nhật thông tin định danh", clock.instant()));
        return response(verification);
    }

    @Transactional
    public VerificationDtos.VerificationResponse upload(
            UUID userId, UUID verificationId, DocumentSide side, MultipartFile file) {
        IdentityVerification verification = requireOwnedDraft(userId, verificationId);
        storeDocument(verification, side, file);
        verification.touch(clock.instant());
        history.save(new VerificationHistory(verification, verification.getStatus(), verification.getStatus(),
                verification.getUser(), "Bổ sung ảnh " + side, clock.instant()));
        return response(verification);
    }

    private void storeDocument(IdentityVerification verification, DocumentSide side, MultipartFile file) {
        StoredObject object = storage.uploadKycImage(verification.getUser(), side.name(), file);
        documents.findByVerificationIdAndSide(verification.getId(), side)
                .ifPresentOrElse(
                        existing -> existing.replace(object, clock.instant()),
                        () -> documents.save(new VerificationDocument(verification, object, side, clock.instant())));
    }

    @Transactional
    public VerificationDtos.VerificationResponse addAdminDraftDocument(
            UUID adminId, UUID verificationId, DocumentSide side, MultipartFile file, boolean ownerAuthorized) {
        if (!ownerAuthorized) {
            throw new DomainException("KYC_CONSENT_REQUIRED", "Cần có sự đồng ý của chủ hồ sơ để thêm ảnh.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        UserAccount admin = requireUser(adminId);
        IdentityVerification draft = requireVerification(verificationId);
        if (draft.getStatus() != VerificationStatus.DRAFT || !"NATIONAL_ID".equals(draft.getDocumentType())) {
            throw conflict("KYC_NOT_EDITABLE", "Chỉ có thể bổ sung ảnh cho bản nháp CCCD của đối tác.");
        }
        var application = recruitment.verificationApplication(draft.getUser().getId());
        if (application != null && application.firstSubmittedAt() != null && !application.editable()) {
            recruitment.requireOfficeKyc(application.id());
        }
        if (documents.findByVerificationIdAndSide(verificationId, side).isPresent()) {
            throw conflict("KYC_DOCUMENT_EXISTS", "Mục này đã có ảnh. Chủ hồ sơ có thể đổi ảnh trên app Partner.");
        }
        Instant now = clock.instant();
        var object = storage.uploadKycImage(draft.getUser(), side.name(), file);
        documents.save(new VerificationDocument(draft, object, side, now));
        draft.updateDraft(draft.getLegalName(), draft.getDocumentType(), draft.getDocumentNumberMasked(), now);
        history.save(new VerificationHistory(draft, VerificationStatus.DRAFT, VerificationStatus.DRAFT,
                admin, "Nhân viên bổ sung ảnh " + side + " với sự đồng ý của chủ hồ sơ", now));
        return response(draft);
    }

    @Transactional
    public VerificationDtos.VerificationResponse submit(
            UUID userId, UUID verificationId, VerificationDtos.SubmitRequest request) {
        IdentityVerification verification = requireOwnedDraft(userId, verificationId);
        return submitDraft(verification, verification.getUser(), request.consent(), "Gửi xét duyệt");
    }

    private VerificationDtos.VerificationResponse submitDraft(
            IdentityVerification verification, UserAccount actor, boolean consent, String reason) {
        UUID userId = verification.getUser().getId();
        if (!consent || verification.getLegalName() == null || verification.getLegalName().trim().length()<2
                || verification.getDocumentNumberMasked()==null || verification.getDocumentNumberMasked().length()<6 || verification.getDocumentType() == null
                || documents.countByVerificationIdAndSideIn(
                        verification.getId(), List.of(DocumentSide.FRONT, DocumentSide.BACK)) != 2) {
            throw new DomainException("KYC_INCOMPLETE", "Hoàn tất thông tin, hai mặt giấy tờ và đồng ý xử lý dữ liệu.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        Instant now = clock.instant();
        if (verification.getStatus() == VerificationStatus.SUBMITTED) return response(verification);
        verification.submit(now);
        taskerProfiles.findById(userId).orElseThrow().updateKyc(VerificationStatus.SUBMITTED, now);
        history.save(new VerificationHistory(verification, VerificationStatus.DRAFT,
                VerificationStatus.SUBMITTED, actor, reason, now));
        return response(verification);
    }

    @Transactional(readOnly = true)
    public VerificationDtos.PageResponse<VerificationDtos.VerificationResponse> queue(
            List<VerificationStatus> statuses, int page, int size) {
        var accepted = statuses == null || statuses.isEmpty()
                ? List.of(VerificationStatus.SUBMITTED, VerificationStatus.UNDER_REVIEW)
                : statuses;
        var result = verifications.findByStatusIn(
                accepted, PageRequest.of(page, Math.min(size, 100), Sort.by(Sort.Direction.ASC, "submittedAt")));
        return new VerificationDtos.PageResponse<>(
                result.getContent().stream().map(this::response).toList(),
                result.getNumber(), result.getSize(), result.getTotalElements(), result.getTotalPages());
    }

    @Transactional
    public VerificationDtos.VerificationResponse beginReview(UUID adminId, UUID verificationId) {
        UserAccount admin = requireUser(adminId);
        guardRecruitmentReview(verificationId);
        IdentityVerification verification = requireVerification(verificationId);
        VerificationStatus before = verification.getStatus();
        verification.beginReview(clock.instant());
        if (before != verification.getStatus()) {
            history.save(new VerificationHistory(verification, before, verification.getStatus(), admin, "Bắt đầu xét duyệt", clock.instant()));
        }
        return response(verification);
    }

    @Transactional
    public VerificationDtos.VerificationResponse decide(
            UUID adminId, UUID verificationId, VerificationStatus decision, String reason) {
        UserAccount admin = requireUser(adminId);
        guardRecruitmentReview(verificationId);
        return applyDecision(admin, requireVerification(verificationId), decision, reason);
    }

    private VerificationDtos.VerificationResponse applyDecision(
            UserAccount admin, IdentityVerification verification, VerificationStatus decision, String reason) {
        VerificationStatus before = verification.getStatus();
        if (decision == VerificationStatus.APPROVED) {
            if ("DEMO".equals(verification.getDocumentType())) {
                if (!java.util.Set.of("development","dev","local","test").contains(environment)) {
                    throw new DomainException("DEMO_KYC_DISABLED", "Không duyệt hồ sơ DEMO ở production.", HttpStatus.UNPROCESSABLE_ENTITY);
                }
            } else {
                requireCleanIdentitySides(verification.getId());
            }
        }
        Instant now = clock.instant();
        try {
            verification.decide(decision, admin, reason.trim(), now);
        } catch (IllegalStateException | IllegalArgumentException invalid) {
            throw new DomainException("KYC_STATE_INVALID", "Hồ sơ không thể nhận quyết định này.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        taskerProfiles.findById(verification.getUser().getId()).orElseThrow().updateKyc(decision, now);
        history.save(new VerificationHistory(verification, before, decision, admin, reason.trim(), now));
        if (decision == VerificationStatus.APPROVED) recruitment.notifyIdentityApproved(verification.getUser().getId(), reason.trim());
        return response(verification);
    }

    private void requireCleanIdentitySides(UUID verificationId) {
        var evidence = documents.findByVerificationId(verificationId);
        boolean complete = List.of(DocumentSide.FRONT, DocumentSide.BACK).stream().allMatch(side -> evidence.stream()
                .anyMatch(document -> document.getSide() == side && document.getStoredObject().getScanStatus()
                        == FileScanStatus.CLEAN));
        if (!complete) throw new DomainException("KYC_SCAN_REQUIRED",
                "Cần đủ hai mặt ảnh đã qua kiểm tra an toàn.", HttpStatus.UNPROCESSABLE_ENTITY);
    }

    @Transactional
    public VerificationDtos.SignedUrlResponse ownDocumentUrl(UUID userId, UUID verificationId, UUID documentId) {
        IdentityVerification verification = verifications.findByIdAndUserId(verificationId, userId)
                .orElseThrow(() -> notFound("KYC_NOT_FOUND", "Không tìm thấy hồ sơ xác minh."));
        var url = documentUrl(verification, documentId);
        history.save(new VerificationHistory(verification, verification.getStatus(), verification.getStatus(),
                requireUser(userId), "PRIVATE_DOCUMENT_READ " + documentId, clock.instant()));
        return url;
    }

    @Transactional
    public VerificationDtos.SignedUrlResponse adminDocumentUrl(UUID actorId, UUID verificationId, UUID documentId) {
        var verification = requireVerification(verificationId);
        var url = documentUrl(verification, documentId);
        history.save(new VerificationHistory(verification, verification.getStatus(), verification.getStatus(),
                requireUser(actorId), "PRIVATE_DOCUMENT_READ " + documentId, clock.instant()));
        return url;
    }

    private VerificationDtos.SignedUrlResponse documentUrl(IdentityVerification verification, UUID documentId) {
        VerificationDocument document = documents.findById(documentId)
                .filter(value -> documents.findByVerificationId(verification.getId()).stream()
                        .anyMatch(item -> item.getId().equals(value.getId())))
                .orElseThrow(() -> notFound("KYC_DOCUMENT_NOT_FOUND", "Không tìm thấy tài liệu."));
        return new VerificationDtos.SignedUrlResponse(
                storage.signedReadUrl(document.getStoredObject()), storageProperties.signedUrlSeconds());
    }

    private IdentityVerification requireOwnedDraft(UUID userId, UUID id) {
        var application = recruitment.verificationApplication(userId);
        IdentityVerification value = verifications.findByIdAndUserId(id, userId)
                .orElseThrow(() -> notFound("KYC_NOT_FOUND", "Không tìm thấy hồ sơ xác minh."));
        boolean amendment = value.getStatus() == VerificationStatus.SUBMITTED && application != null
                && java.util.Set.of("PRELIMINARY_REVIEW","ACTION_REQUIRED").contains(application.status()) && application.editable();
        if (value.getStatus() != VerificationStatus.DRAFT && !amendment) {
            throw new DomainException("KYC_NOT_EDITABLE", "Hồ sơ không còn ở trạng thái chỉnh sửa.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        if (application != null && application.firstSubmittedAt() != null && !application.editable()) {
            throw new DomainException("KYC_NOT_EDITABLE", "Hết thời hạn bổ sung hồ sơ.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        return value;
    }

    private void guardRecruitmentReview(UUID verificationId) {
        recruitment.requireVerificationReviewReady(verificationId);
    }

    private IdentityVerification requireVerification(UUID id) {
        return verifications.findById(id)
                .orElseThrow(() -> notFound("KYC_NOT_FOUND", "Không tìm thấy hồ sơ xác minh."));
    }

    private UserAccount requireTasker(UUID id) {
        UserAccount user = requireUser(id);
        if (user.getRoles().stream().noneMatch(role -> role.getKey().equals("TASKER"))) {
            throw new DomainException("TASKER_MODE_REQUIRED", "Hãy bật chế độ Tasker trước.", HttpStatus.FORBIDDEN);
        }
        return user;
    }

    private UserAccount requireUser(UUID id) {
        return users.findById(id).orElseThrow(() -> notFound("USER_NOT_FOUND", "Không tìm thấy tài khoản."));
    }

    private VerificationDtos.VerificationResponse response(IdentityVerification value) {
        var docs = documents.findByVerificationId(value.getId()).stream()
                .map(document -> new VerificationDtos.DocumentResponse(
                        document.getId(), document.getSide(), document.getStoredObject().getScanStatus()))
                .toList();
        return new VerificationDtos.VerificationResponse(
                value.getId(), value.getUser().getId(), value.getStatus(), value.getLegalName(),
                value.getDocumentType(), value.getDocumentNumberMasked(), value.getSubmittedAt(),
                value.getDecisionReason(), docs, null);
    }

    private String mask(String number) {
        String normalized = number.replaceAll("\\s+", "");
        int visible = Math.min(4, normalized.length());
        return "*".repeat(normalized.length() - visible) + normalized.substring(normalized.length() - visible);
    }

    private DomainException conflict(String code, String message) {
        return new DomainException(code, message, HttpStatus.CONFLICT);
    }

    private DomainException notFound(String code, String message) {
        return new DomainException(code, message, HttpStatus.NOT_FOUND);
    }
}


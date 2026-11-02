package com.taskly.verification;

import com.taskly.common.exception.DomainException;
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
        var latest = verifications.findFirstByUserIdOrderByCreatedAtDesc(userId);
        if (latest.isPresent() && EnumSet.of(VerificationStatus.DRAFT, VerificationStatus.SUBMITTED,
                VerificationStatus.UNDER_REVIEW, VerificationStatus.APPROVED).contains(latest.get().getStatus())) {
            if (latest.get().getStatus() == VerificationStatus.DRAFT) return response(latest.get());
            throw conflict("KYC_ALREADY_IN_PROGRESS", "Hồ sơ xác minh hiện tại chưa thể tạo lại.");
        }
        Instant now = clock.instant();
        taskerProfiles.findById(userId).orElseGet(() -> taskerProfiles.save(new TaskerProfile(user, now)));
        IdentityVerification verification = verifications.save(new IdentityVerification(user, now));
        history.save(new VerificationHistory(verification, VerificationStatus.NOT_STARTED,
                VerificationStatus.DRAFT, user, "Bắt đầu hồ sơ", now));
        return response(verification);
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
        StoredObject object = storage.uploadKycImage(verification.getUser(), side.name(), file);
        documents.findByVerificationIdAndSide(verificationId, side)
                .ifPresentOrElse(
                        existing -> existing.replace(object, clock.instant()),
                        () -> documents.save(new VerificationDocument(verification, object, side, clock.instant())));
        history.save(new VerificationHistory(verification, verification.getStatus(), verification.getStatus(),
                verification.getUser(), "Bổ sung ảnh " + side, clock.instant()));
        return response(verification);
    }

    @Transactional
    public VerificationDtos.VerificationResponse submit(
            UUID userId, UUID verificationId, VerificationDtos.SubmitRequest request) {
        IdentityVerification verification = requireOwnedDraft(userId, verificationId);
        if (!request.consent() || verification.getLegalName() == null || verification.getLegalName().trim().length()<2
                || verification.getDocumentNumberMasked()==null || verification.getDocumentNumberMasked().length()<6 || verification.getDocumentType() == null
                || documents.countByVerificationIdAndSideIn(
                        verificationId, List.of(DocumentSide.FRONT, DocumentSide.BACK)) != 2) {
            throw new DomainException("KYC_INCOMPLETE", "Hoàn tất thông tin, hai mặt giấy tờ và đồng ý xử lý dữ liệu.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        Instant now = clock.instant();
        if (verification.getStatus() == VerificationStatus.SUBMITTED) return response(verification);
        verification.submit(now);
        taskerProfiles.findById(userId).orElseThrow().updateKyc(VerificationStatus.SUBMITTED, now);
        history.save(new VerificationHistory(verification, VerificationStatus.DRAFT,
                VerificationStatus.SUBMITTED, verification.getUser(), "Gửi xét duyệt", now));
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
        IdentityVerification verification = requireVerification(verificationId);
        VerificationStatus before = verification.getStatus();
        if (decision == VerificationStatus.APPROVED) {
            if ("DEMO".equals(verification.getDocumentType())) {
                if (!java.util.Set.of("development","dev","local","test").contains(environment)) {
                    throw new DomainException("DEMO_KYC_DISABLED", "Không duyệt hồ sơ DEMO ở production.", HttpStatus.UNPROCESSABLE_ENTITY);
                }
            } else {
                var evidence = documents.findByVerificationId(verificationId);
                boolean complete = List.of(DocumentSide.FRONT, DocumentSide.BACK).stream().allMatch(side -> evidence.stream().anyMatch(document -> document.getSide() == side && document.getStoredObject().getScanStatus() == com.taskly.storage.entity.FileScanStatus.CLEAN));
                if (!complete) throw new DomainException("KYC_SCAN_REQUIRED", "Cần đủ hai mặt ảnh được kiểm tra an toàn trước khi duyệt.", HttpStatus.UNPROCESSABLE_ENTITY);
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


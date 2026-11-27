package com.taskly.verification;

import com.taskly.common.api.ApiResponse;
import com.taskly.verification.dto.VerificationDtos;
import com.taskly.verification.entity.DocumentSide;
import com.taskly.verification.entity.VerificationStatus;
import jakarta.validation.Valid;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/admin/verifications")
@PreAuthorize("hasAuthority('KYC_REVIEW')")
public class AdminVerificationController {
    private final VerificationService service;

    public AdminVerificationController(VerificationService service) { this.service = service; }

    public record OfficeDraftRequest(@NotBlank @Size(max = 160) String legalName,
                                     @NotBlank @Pattern(regexp = "[0-9]{12}") String documentNumber,
                                     @AssertTrue boolean consentRecorded) {}

    @PostMapping(value = "/assisted/{partnerId}/submit", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ApiResponse<VerificationDtos.VerificationResponse> assistedSubmit(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID partnerId,
            @RequestParam(required = false) UUID verificationId,
            @RequestParam(defaultValue = "-1") @Min(-1) long version,
            @RequestParam @NotBlank @Size(min = 2, max = 160) String legalName,
            @RequestParam @Pattern(regexp = "[0-9]{12}") String documentNumber,
            @RequestParam boolean ownerAuthorized,
            @RequestPart(value = "front", required = false) MultipartFile front,
            @RequestPart(value = "back", required = false) MultipartFile back) {
        return ApiResponse.success(service.submitAssisted(userId(jwt), partnerId, verificationId, version,
                legalName, documentNumber, ownerAuthorized, front, back));
    }

    @PostMapping("/assisted/{partnerId}/{verificationId}/approve")
    ApiResponse<VerificationDtos.VerificationResponse> assistedApprove(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID partnerId, @PathVariable UUID verificationId,
            @RequestParam @Min(0) long version) {
        return ApiResponse.success(service.approveAssisted(userId(jwt), partnerId, verificationId, version));
    }

    @PostMapping("/office/{applicationId}/draft")
    ApiResponse<VerificationDtos.VerificationResponse> officeDraft(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID applicationId,
            @Valid @RequestBody OfficeDraftRequest request) {
        return ApiResponse.success(service.prepareOfficeDraft(userId(jwt), applicationId, request));
    }

    @PostMapping("/office/{applicationId}/{verificationId}/submit")
    ApiResponse<VerificationDtos.VerificationResponse> officeSubmit(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID applicationId, @PathVariable UUID verificationId,
            @Valid @RequestBody VerificationDtos.SubmitRequest request) {
        return ApiResponse.success(service.submitOfficeDraft(userId(jwt), applicationId, verificationId, request.consent()));
    }

    @PostMapping("/office/{applicationId}/{verificationId}/approve")
    ApiResponse<VerificationDtos.VerificationResponse> officeApprove(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID applicationId, @PathVariable UUID verificationId,
            @Valid @RequestBody VerificationDtos.SubmitRequest request) {
        return ApiResponse.success(service.approveOfficeDraft(userId(jwt), applicationId, verificationId, request.consent()));
    }

    @PostMapping(value = "/{id}/documents/{side}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ApiResponse<VerificationDtos.VerificationResponse> addDraftDocument(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @PathVariable DocumentSide side,
            @RequestPart("file") MultipartFile file, @RequestParam boolean ownerAuthorized) {
        return ApiResponse.success(service.addAdminDraftDocument(userId(jwt), id, side, file, ownerAuthorized));
    }

    @GetMapping
    ApiResponse<VerificationDtos.PageResponse<VerificationDtos.VerificationResponse>> queue(
            @RequestParam(required = false) List<VerificationStatus> status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.success(service.queue(status, Math.max(page, 0), Math.max(1, Math.min(size, 100))));
    }

    @PostMapping("/{id}/begin-review")
    ApiResponse<VerificationDtos.VerificationResponse> beginReview(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        return ApiResponse.success(service.beginReview(userId(jwt), id));
    }

    @PostMapping("/{id}/approve")
    ApiResponse<VerificationDtos.VerificationResponse> approve(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody VerificationDtos.DecisionRequest request) {
        return ApiResponse.success(service.decide(userId(jwt), id, VerificationStatus.APPROVED, request.reason()));
    }

    @PostMapping("/{id}/reject")
    ApiResponse<VerificationDtos.VerificationResponse> reject(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody VerificationDtos.DecisionRequest request) {
        return ApiResponse.success(service.decide(userId(jwt), id, VerificationStatus.REJECTED, request.reason()));
    }

    @GetMapping("/{id}/documents/{documentId}/url")
    ApiResponse<VerificationDtos.SignedUrlResponse> documentUrl(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @PathVariable UUID documentId) {
        return ApiResponse.success(service.adminDocumentUrl(userId(jwt), id, documentId));
    }

    private UUID userId(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
}

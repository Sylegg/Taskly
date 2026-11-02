package com.taskly.verification;

import com.taskly.common.api.ApiResponse;
import com.taskly.verification.dto.VerificationDtos;
import com.taskly.verification.entity.VerificationStatus;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/verifications")
@PreAuthorize("hasAuthority('KYC_REVIEW')")
public class AdminVerificationController {
    private final VerificationService service;

    public AdminVerificationController(VerificationService service) { this.service = service; }

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

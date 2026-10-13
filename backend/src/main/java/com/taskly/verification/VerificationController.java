package com.taskly.verification;

import com.taskly.common.api.ApiResponse;
import com.taskly.verification.dto.VerificationDtos;
import com.taskly.verification.entity.DocumentSide;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1/verifications")
public class VerificationController {
    private final VerificationService service;

    public VerificationController(VerificationService service) { this.service = service; }

    @GetMapping("/me")
    ApiResponse<VerificationDtos.VerificationResponse> current(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(service.currentOwner(userId(jwt)));
    }

    @PostMapping
    ApiResponse<VerificationDtos.VerificationResponse> start(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(service.start(userId(jwt)));
    }

    @PatchMapping("/{id}/draft")
    ApiResponse<VerificationDtos.VerificationResponse> update(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody VerificationDtos.DraftRequest request) {
        return ApiResponse.success(service.updateDraft(userId(jwt), id, request));
    }

    @PostMapping(value = "/{id}/documents/{side}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ApiResponse<VerificationDtos.VerificationResponse> upload(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @PathVariable DocumentSide side, @RequestPart("file") MultipartFile file) {
        return ApiResponse.success(service.upload(userId(jwt), id, side, file));
    }

    @PostMapping("/{id}/submit")
    ApiResponse<VerificationDtos.VerificationResponse> submit(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id,
            @Valid @RequestBody VerificationDtos.SubmitRequest request) {
        return ApiResponse.success(service.submit(userId(jwt), id, request));
    }

    @GetMapping("/{id}/documents/{documentId}/url")
    ApiResponse<VerificationDtos.SignedUrlResponse> documentUrl(
            @AuthenticationPrincipal Jwt jwt, @PathVariable UUID id, @PathVariable UUID documentId) {
        return ApiResponse.success(service.ownDocumentUrl(userId(jwt), id, documentId));
    }

    private UUID userId(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
}

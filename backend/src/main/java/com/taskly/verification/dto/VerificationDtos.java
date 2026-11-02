package com.taskly.verification.dto;

import com.taskly.storage.entity.FileScanStatus;
import com.taskly.verification.entity.DocumentSide;
import com.taskly.verification.entity.VerificationStatus;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class VerificationDtos {
    private VerificationDtos() {}

    public record DraftRequest(
            @NotNull @Size(max = 160) String legalName,
            @NotBlank @Pattern(regexp = "^(NATIONAL_ID|PASSPORT)$") String documentType,
            @NotNull @Size(max = 30) String documentNumber
    ) {}

    public record SubmitRequest(@AssertTrue(message = "Bạn phải đồng ý xử lý dữ liệu xác minh") boolean consent) {}
    public record DecisionRequest(@NotBlank @Size(min = 5, max = 1000) String reason) {}

    public record DocumentResponse(UUID id, DocumentSide side, FileScanStatus scanStatus) {}

    public record VerificationResponse(
            UUID id,
            UUID userId,
            VerificationStatus status,
            String legalName,
            String documentType,
            String documentNumberMasked,
            Instant submittedAt,
            String decisionReason,
            List<DocumentResponse> documents,
            String documentNumber
    ) {}

    public record SignedUrlResponse(String url, int expiresInSeconds) {}
    public record PageResponse<T>(List<T> items, int page, int size, long totalElements, int totalPages) {}
}

package com.taskly.task;

import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
public class EarlyStartController {
    private final EarlyStartService earlyStartService;

    public EarlyStartController(EarlyStartService earlyStartService) {
        this.earlyStartService = earlyStartService;
    }

    private UUID user(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }

    public record CheckInRequest(
        BigDecimal latitude,
        BigDecimal longitude,
        String method,
        String requestId,
        String imageData
    ) {}

    public record CreateEarlyStartRequest(
        @NotNull Instant requestedStartAt,
        String reason,
        String requestId
    ) {}

    public record CustomerDecisionRequest(
        @NotBlank String action, // APPROVE or REJECT
        String reason
    ) {}

    public record StartJobRequest(
        String requestId
    ) {}

    // =========================================================================
    // PARTNER ENDPOINTS
    // =========================================================================

    @PostMapping("/partner/jobs/{id}/check-in")
    public ApiResponse<Map<String, Object>> checkIn(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id,
        @RequestBody(required = false) CheckInRequest body
    ) {
        BigDecimal lat = body != null ? body.latitude() : null;
        BigDecimal lng = body != null ? body.longitude() : null;
        String method = body != null ? body.method() : "GPS";
        String reqId = body != null ? body.requestId() : UUID.randomUUID().toString();
        return ApiResponse.success(earlyStartService.checkInWithPhoto(user(jwt), id, lat, lng, method, reqId, body != null ? body.imageData() : null));
    }

    @PostMapping("/partner/jobs/{id}/early-start-requests")
    public ApiResponse<EarlyStartService.EarlyStartRequestDto> createEarlyStart(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id,
        @Valid @RequestBody CreateEarlyStartRequest body
    ) {
        String reqId = body.requestId() != null ? body.requestId() : UUID.randomUUID().toString();
        return ApiResponse.success(earlyStartService.createEarlyStartRequest(
            user(jwt), id, body.requestedStartAt(), body.reason(), reqId
        ));
    }

    @GetMapping("/partner/jobs/{id}/early-start-requests")
    public ApiResponse<List<EarlyStartService.EarlyStartRequestDto>> getPartnerEarlyStartRequests(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id
    ) {
        return ApiResponse.success(earlyStartService.getEarlyStartRequests(id));
    }

    @PostMapping("/partner/jobs/{id}/start")
    public ApiResponse<Map<String, Object>> startJob(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id,
        @RequestBody(required = false) StartJobRequest body
    ) {
        String reqId = body != null && body.requestId() != null ? body.requestId() : UUID.randomUUID().toString();
        return ApiResponse.success(earlyStartService.startJob(user(jwt), id, reqId));
    }

    @GetMapping("/partner/jobs/{id}/start-eligibility")
    public ApiResponse<EarlyStartService.StartEligibilityDto> getPartnerStartEligibility(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id
    ) {
        return ApiResponse.success(earlyStartService.getStartEligibility(user(jwt), id, true));
    }

    // =========================================================================
    // CUSTOMER ENDPOINTS
    // =========================================================================

    @GetMapping("/customer/bookings/{id}/early-start-requests")
    public ApiResponse<List<EarlyStartService.EarlyStartRequestDto>> getCustomerEarlyStartRequests(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id
    ) {
        return ApiResponse.success(earlyStartService.getEarlyStartRequests(id));
    }

    @PostMapping("/customer/bookings/{id}/early-start-requests/{requestId}/decision")
    public ApiResponse<EarlyStartService.EarlyStartRequestDto> customerDecision(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id,
        @PathVariable UUID requestId,
        @Valid @RequestBody CustomerDecisionRequest body
    ) {
        return ApiResponse.success(earlyStartService.customerDecision(
            user(jwt), id, requestId, body.action(), body.reason()
        ));
    }

    @GetMapping("/customer/bookings/{id}/start-eligibility")
    public ApiResponse<EarlyStartService.StartEligibilityDto> getCustomerStartEligibility(
        @AuthenticationPrincipal Jwt jwt,
        @PathVariable UUID id
    ) {
        return ApiResponse.success(earlyStartService.getStartEligibility(user(jwt), id, false));
    }
}

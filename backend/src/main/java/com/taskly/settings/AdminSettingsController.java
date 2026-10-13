package com.taskly.settings;

import com.taskly.common.api.ApiResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public class AdminSettingsController {
    private final SystemSettingsService settingsService;

    public AdminSettingsController(SystemSettingsService settingsService) {
        this.settingsService = settingsService;
    }

    public record OperationsSettingsRequest(
        @Min(15) @Max(360) Integer minBufferMinutes,
        @Min(0) @Max(180) Integer travelSafetyMinutes,
        @Min(0) @Max(120) Integer earlyCheckinWindowMinutes,
        @Min(0) @Max(240) Integer maxEarlyStartMinutes,
        @Min(1) @Max(120) Integer earlyStartExpiryMinutes
    ) {}

    @GetMapping("/api/v1/admin/settings/operations")
    public ApiResponse<Map<String, Object>> getOperations() {
        return ApiResponse.success(settingsService.getOperationsSettings());
    }

    @PutMapping("/api/v1/admin/settings/operations")
    public ApiResponse<Map<String, Object>> updateOperations(@Valid @RequestBody OperationsSettingsRequest request) {
        int minBuffer = request.minBufferMinutes() != null ? request.minBufferMinutes() : settingsService.getMinBufferMinutes();
        int travelSafety = request.travelSafetyMinutes() != null ? request.travelSafetyMinutes() : settingsService.getTravelSafetyMinutes();
        return ApiResponse.success(settingsService.updateOperationsSettings(
            minBuffer,
            travelSafety,
            request.earlyCheckinWindowMinutes(),
            request.maxEarlyStartMinutes(),
            request.earlyStartExpiryMinutes()
        ));
    }

    @GetMapping("/api/v1/admin/operations/job-start-policy")
    public ApiResponse<Map<String, Object>> getJobStartPolicy() {
        return ApiResponse.success(settingsService.getOperationsSettings());
    }

    @PatchMapping("/api/v1/admin/operations/job-start-policy")
    public ApiResponse<Map<String, Object>> patchJobStartPolicy(@Valid @RequestBody OperationsSettingsRequest request) {
        int minBuffer = request.minBufferMinutes() != null ? request.minBufferMinutes() : settingsService.getMinBufferMinutes();
        int travelSafety = request.travelSafetyMinutes() != null ? request.travelSafetyMinutes() : settingsService.getTravelSafetyMinutes();
        return ApiResponse.success(settingsService.updateOperationsSettings(
            minBuffer,
            travelSafety,
            request.earlyCheckinWindowMinutes(),
            request.maxEarlyStartMinutes(),
            request.earlyStartExpiryMinutes()
        ));
    }
}

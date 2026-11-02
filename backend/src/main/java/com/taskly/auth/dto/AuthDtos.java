package com.taskly.auth.dto;

import com.taskly.user.entity.UserMode;
import com.taskly.user.entity.UserStatus;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

public final class AuthDtos {
    public enum AppType { CUSTOMER, PARTNER }
    private AuthDtos() {}

    public record RegisterRequest(
            @NotBlank @Email @Size(max = 320) String email,
            @NotBlank @Pattern(regexp = "^0[0-9]{9}$", message = "Số điện thoại phải có 10 chữ số và bắt đầu bằng 0") String phone,
            @NotBlank @Size(min = 2, max = 160) String fullName,
            @NotBlank @Size(min = 10, max = 128) String password,
            AppType appType
    ) {
        public RegisterRequest(String email, String phone, String fullName, String password) {
            this(email, phone, fullName, password, null);
        }
    }

    public record VerifyOtpRequest(
            @NotBlank @Email String email,
            @NotBlank @Pattern(regexp = "^[0-9]{6}$") String code
    ) {}

    public record ResendOtpRequest(@NotBlank @Email String email) {}

    public record LoginRequest(
            @NotBlank @Email String email,
            @NotBlank @Size(max = 128) String password,
            @Size(max = 200) String deviceName
    ) {}

    public record ForgotPasswordRequest(@NotBlank @Email String email) {}

    public record PhoneLoginRequest(
            @NotBlank @Pattern(regexp = "^0[0-9]{9}$", message = "Số điện thoại phải có 10 chữ số và bắt đầu bằng 0") String phone,
            @NotBlank @Size(max = 128) String password,
            @Size(max = 200) String deviceName,
            AppType appType
    ) {
        public PhoneLoginRequest(String phone, String password, String deviceName) {
            this(phone, password, deviceName, null);
        }
    }

    public record ResetPasswordRequest(
            @NotBlank @Email String email,
            @NotBlank @Pattern(regexp = "^[0-9]{6}$") String code,
            @NotBlank @Size(min = 10, max = 128) String newPassword
    ) {}

    public record UserSummary(
            UUID id,
            String email,
            String fullName,
            UserStatus status,
            UserMode activeMode,
            List<String> roles,
            List<String> permissions
    ) {}

    public record TokenResponse(String accessToken, String tokenType, Instant expiresAt, UserSummary user) {}

    public record RegistrationResponse(UUID userId, UserStatus status, String message) {}

    public record SessionResponse(
            UUID id,
            String deviceName,
            String userAgent,
            String ipAddress,
            Instant createdAt,
            Instant lastUsedAt,
            Instant expiresAt,
            boolean current
    ) {}
}

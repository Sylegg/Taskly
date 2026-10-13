package com.taskly.user.dto;

import com.taskly.user.entity.UserMode;
import com.taskly.user.entity.UserStatus;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

public final class UserDtos {
    private UserDtos() {}

    public record MeResponse(
            UUID id,
            String email,
            String phone,
            String fullName,
            String language,
            UserStatus status,
            UserMode activeMode,
            List<String> roles,
            List<String> permissions, boolean nameLocked
    ) {}

    public record UpdateProfileRequest(
            @NotBlank @Size(min = 2, max = 160) String fullName,
            @Pattern(regexp = "^$|^0[0-9]{9}$") String phone,
            @NotBlank @Pattern(regexp = "^(vi|en)$") String language
    ) {
        public UpdateProfileRequest(String fullName, String language) {
            this(fullName, null, language);
        }
    }

    public record ChangePasswordRequest(
            @NotBlank @Size(max = 128) String currentPassword,
            @NotBlank @Size(min = 10, max = 128) String newPassword
    ) {}

    public record SwitchModeRequest(UserMode mode) {}

    public record AddressRequest(
            @NotBlank @Size(max = 100) String label,
            @Size(max = 160) String recipientName,
            @Pattern(regexp = "^$|^0[0-9]{9}$") String recipientPhone,
            @NotBlank @Size(max = 500) String addressLine,
            @Size(max = 160) String ward,
            @Size(max = 160) String district,
            @NotBlank @Size(max = 160) String city,
            @DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
            @DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
            @Size(max = 500) String notes,
            boolean defaultAddress,
            @Size(max = 100) String buildingType,
            @Size(max = 500) String buildingDescription
    ) {}

    public record AddressResponse(
            UUID id,
            String label,
            String recipientName,
            String recipientPhone,
            String addressLine,
            String ward,
            String district,
            String city,
            BigDecimal latitude,
            BigDecimal longitude,
            String notes,
            boolean defaultAddress,
            String buildingType,
            String buildingDescription
    ) {}
}

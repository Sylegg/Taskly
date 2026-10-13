package com.taskly.user;

import com.taskly.common.api.ApiResponse;
import com.taskly.user.dto.UserDtos;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users/me")
public class UserController {
    private final UserService service;

    public UserController(UserService service) {
        this.service = service;
    }

    @GetMapping
    ApiResponse<UserDtos.MeResponse> me(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(service.me(userId(jwt)));
    }

    @PatchMapping("/profile")
    ApiResponse<UserDtos.MeResponse> updateProfile(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UserDtos.UpdateProfileRequest request) {
        return ApiResponse.success(service.updateProfile(userId(jwt), request));
    }

    @PostMapping("/change-password")
    ApiResponse<Void> changePassword(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UserDtos.ChangePasswordRequest request) {
        service.changePassword(userId(jwt), request);
        return ApiResponse.success(null, "Đổi mật khẩu thành công. Vui lòng đăng nhập lại.");
    }

    @PostMapping("/modes/tasker")
    ApiResponse<UserDtos.MeResponse> enableTasker(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(service.enableTasker(userId(jwt)));
    }

    @PostMapping("/mode")
    ApiResponse<UserDtos.MeResponse> switchMode(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UserDtos.SwitchModeRequest request) {
        return ApiResponse.success(service.switchMode(userId(jwt), request.mode()));
    }

    @GetMapping("/addresses")
    ApiResponse<List<UserDtos.AddressResponse>> addresses(@AuthenticationPrincipal Jwt jwt) {
        return ApiResponse.success(service.addresses(userId(jwt)));
    }

    @PostMapping("/addresses")
    ApiResponse<UserDtos.AddressResponse> createAddress(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody UserDtos.AddressRequest request) {
        return ApiResponse.success(service.createAddress(userId(jwt), request));
    }

    @PutMapping("/addresses/{id}")
    ApiResponse<UserDtos.AddressResponse> updateAddress(
            @AuthenticationPrincipal Jwt jwt,
            @PathVariable UUID id,
            @Valid @RequestBody UserDtos.AddressRequest request) {
        return ApiResponse.success(service.updateAddress(userId(jwt), id, request));
    }

    @PostMapping("/addresses/{id}/default")
    ApiResponse<Void> setDefault(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        service.setDefaultAddress(userId(jwt), id);
        return ApiResponse.success(null, "Đã cập nhật địa chỉ mặc định.");
    }

    @DeleteMapping("/addresses/{id}")
    ApiResponse<Void> deleteAddress(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID id) {
        service.deleteAddress(userId(jwt), id);
        return ApiResponse.success(null, "Đã xóa địa chỉ.");
    }

    private UUID userId(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}

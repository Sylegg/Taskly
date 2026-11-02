package com.taskly.auth;

import com.taskly.auth.dto.AuthDtos;
import com.taskly.common.api.ApiResponse;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.Duration;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.web.csrf.CsrfToken;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    private static final String REFRESH_COOKIE = "taskly_refresh";
    private final AuthService authService;
    private final RefreshTokenService refreshTokens;
    private final AuthProperties properties;
    private final Clock clock;

    public AuthController(AuthService authService, RefreshTokenService refreshTokens,
                          AuthProperties properties, Clock clock) {
        this.authService = authService;
        this.refreshTokens = refreshTokens;
        this.properties = properties;
        this.clock = clock;
    }

    @GetMapping("/csrf")
    ApiResponse<CsrfResponse> csrf(CsrfToken token) {
        return ApiResponse.success(new CsrfResponse(token.getHeaderName(), token.getToken()));
    }

    @PostMapping("/register")
    ApiResponse<AuthDtos.RegistrationResponse> register(@Valid @RequestBody AuthDtos.RegisterRequest request) {
        return ApiResponse.success(authService.register(request));
    }

    @PostMapping("/verify-otp")
    ApiResponse<Void> verify(@Valid @RequestBody AuthDtos.VerifyOtpRequest request) {
        authService.verifyRegistration(request);
        return ApiResponse.success(null, "Xác minh tài khoản thành công.");
    }

    @PostMapping("/resend-otp")
    ApiResponse<Void> resend(@Valid @RequestBody AuthDtos.ResendOtpRequest request) {
        authService.resendRegistrationOtp(request);
        return ApiResponse.success(null, "Nếu tài khoản đang chờ xác minh, mã mới đã được gửi.");
    }

    @PostMapping("/forgot-password")
    ApiResponse<Void> forgotPassword(@Valid @RequestBody AuthDtos.ForgotPasswordRequest request) {
        authService.forgotPassword(request);
        return ApiResponse.success(null, "Nếu email tồn tại, hướng dẫn khôi phục đã được gửi.");
    }

    @PostMapping("/reset-password")
    ApiResponse<Void> resetPassword(@Valid @RequestBody AuthDtos.ResetPasswordRequest request) {
        authService.resetPassword(request);
        return ApiResponse.success(null, "Mật khẩu đã được cập nhật. Vui lòng đăng nhập lại.");
    }

    @PostMapping("/login")
    ApiResponse<AuthDtos.TokenResponse> login(
            @Valid @RequestBody AuthDtos.LoginRequest request,
            HttpServletRequest servletRequest,
            HttpServletResponse response) {
        AuthService.LoginResult result = authService.login(request, context(request.deviceName(), servletRequest));
        setRefreshCookie(response, result.refreshToken());
        return ApiResponse.success(tokenResponse(result));
    }

    @PostMapping("/refresh")
    ApiResponse<AuthDtos.TokenResponse> refresh(HttpServletRequest request, HttpServletResponse response) {
        String raw = requireRefreshCookie(request);
        AuthService.LoginResult result = authService.refresh(raw, context(null, request));
        setRefreshCookie(response, result.refreshToken());
        return ApiResponse.success(tokenResponse(result));
    }

    @PostMapping("/logout")
    ApiResponse<Void> logout(HttpServletRequest request, HttpServletResponse response) {
        findCookie(request).ifPresent(raw -> refreshTokens.revoke(raw, clock.instant()));
        clearRefreshCookie(response);
        return ApiResponse.success(null, "Đã đăng xuất.");
    }

    @PostMapping("/logout-all")
    ApiResponse<Void> logoutAll(@AuthenticationPrincipal Jwt jwt, HttpServletResponse response) {
        refreshTokens.revokeAll(UUID.fromString(jwt.getSubject()), clock.instant());
        clearRefreshCookie(response);
        return ApiResponse.success(null, "Đã đăng xuất khỏi tất cả thiết bị.");
    }

    @GetMapping("/sessions")
    ApiResponse<List<AuthDtos.SessionResponse>> sessions(
            @AuthenticationPrincipal Jwt jwt, HttpServletRequest request) {
        UUID userId = UUID.fromString(jwt.getSubject());
        String currentHash = findCookie(request).map(refreshTokens::hash).orElse(null);
        var sessions = refreshTokens.activeSessions(userId, clock.instant()).stream()
                .map(token -> new AuthDtos.SessionResponse(
                        token.getId(), token.getDeviceName(), token.getUserAgent(), token.getIpAddress(),
                        token.getCreatedAt(), token.getLastUsedAt(), token.getExpiresAt(),
                        currentHash != null && token.getId().equals(sessionIdByHash(currentHash))))
                .toList();
        return ApiResponse.success(sessions);
    }

    @DeleteMapping("/sessions/{sessionId}")
    ApiResponse<Void> revokeSession(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID sessionId) {
        refreshTokens.revokeSession(UUID.fromString(jwt.getSubject()), sessionId, clock.instant());
        return ApiResponse.success(null, "Đã thu hồi phiên đăng nhập.");
    }

    private UUID sessionIdByHash(String hash) {
        return refreshTokens.findIdByHash(hash).orElse(null);
    }

    private AuthDtos.TokenResponse tokenResponse(AuthService.LoginResult result) {
        return new AuthDtos.TokenResponse(
                result.accessToken().value(), "Bearer", result.accessToken().expiresAt(), result.user());
    }

    private AuthService.ClientContext context(String deviceName, HttpServletRequest request) {
        String resolvedDevice = deviceName == null || deviceName.isBlank() ? "Trình duyệt web" : deviceName.trim();
        return new AuthService.ClientContext(
                resolvedDevice,
                truncate(request.getHeader("User-Agent"), 500),
                truncate(request.getRemoteAddr(), 64));
    }

    private void setRefreshCookie(HttpServletResponse response, RefreshTokenService.IssuedRefreshToken token) {
        ResponseCookie cookie = ResponseCookie.from(REFRESH_COOKIE, token.raw())
                .httpOnly(true)
                .secure(properties.secureCookies())
                .sameSite("Lax")
                .path("/api/v1/auth")
                .maxAge(Duration.between(clock.instant(), token.expiresAt()))
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }

    private void clearRefreshCookie(HttpServletResponse response) {
        response.addHeader(HttpHeaders.SET_COOKIE, ResponseCookie.from(REFRESH_COOKIE, "")
                .httpOnly(true).secure(properties.secureCookies()).sameSite("Lax")
                .path("/api/v1/auth").maxAge(Duration.ZERO).build().toString());
    }

    private String requireRefreshCookie(HttpServletRequest request) {
        return findCookie(request).orElseThrow(() ->
                new com.taskly.common.exception.DomainException(
                        "REFRESH_TOKEN_MISSING", "Phiên đăng nhập không tồn tại.", org.springframework.http.HttpStatus.UNAUTHORIZED));
    }

    private java.util.Optional<String> findCookie(HttpServletRequest request) {
        if (request.getCookies() == null) return java.util.Optional.empty();
        return Arrays.stream(request.getCookies())
                .filter(cookie -> REFRESH_COOKIE.equals(cookie.getName()))
                .map(Cookie::getValue)
                .findFirst();
    }

    private String truncate(String value, int max) {
        if (value == null) return null;
        return value.length() <= max ? value : value.substring(0, max);
    }

    public record CsrfResponse(String headerName, String token) {}
}

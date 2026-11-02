package com.taskly.auth;

import com.taskly.auth.dto.AuthDtos;
import com.taskly.common.api.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

/** Native clients send refresh credentials explicitly; web cookie endpoints stay CSRF protected. */
@RestController
@RequestMapping("/api/v1/auth/mobile")
public class MobileAuthController {
    private final AuthService auth;
    private final RefreshTokenService refresh;
    private final Clock clock;

    public MobileAuthController(AuthService auth, RefreshTokenService refresh, Clock clock) {
        this.auth = auth;
        this.refresh = refresh;
        this.clock = clock;
    }

    @PostMapping("/login")
    ApiResponse<MobileTokenResponse> login(@Valid @RequestBody AuthDtos.LoginRequest body,
                                          HttpServletRequest request) {
        return ApiResponse.success(tokens(auth.login(body, context(body.deviceName(), request))));
    }

    @PostMapping("/login-phone")
    ApiResponse<MobileTokenResponse> loginByPhone(@Valid @RequestBody AuthDtos.PhoneLoginRequest body,
                                                 HttpServletRequest request) {
        return ApiResponse.success(tokens(auth.loginByPhone(body, context(body.deviceName(), request))));
    }

    @PostMapping("/refresh")
    ApiResponse<MobileTokenResponse> refresh(@Valid @RequestBody RefreshRequest body,
                                            HttpServletRequest request) {
        AuthService.LoginResult result = auth.refresh(body.refreshToken(), context("TaskLy mobile", request));
        auth.recordAppUse(result.user().id(), body.appType());
        return ApiResponse.success(tokens(result));
    }

    @PostMapping("/logout")
    ApiResponse<Void> logout(@Valid @RequestBody RefreshRequest body) {
        refresh.revoke(body.refreshToken(), clock.instant());
        return ApiResponse.success(null);
    }

    @DeleteMapping("/sessions/{sessionId}")
    ApiResponse<Void> revokeSession(@AuthenticationPrincipal Jwt jwt, @PathVariable UUID sessionId) {
        refresh.revokeSession(UUID.fromString(jwt.getSubject()), sessionId, clock.instant());
        return ApiResponse.success(null);
    }

    @PostMapping("/logout-all")
    ApiResponse<Void> logoutAll(@AuthenticationPrincipal Jwt jwt) {
        refresh.revokeAll(UUID.fromString(jwt.getSubject()), clock.instant());
        return ApiResponse.success(null);
    }

    private AuthService.ClientContext context(String name, HttpServletRequest request) {
        String agent = request.getHeader("User-Agent");
        return new AuthService.ClientContext(name == null ? "TaskLy mobile" : name,
                agent == null ? null : agent.substring(0, Math.min(500, agent.length())), request.getRemoteAddr());
    }

    private MobileTokenResponse tokens(AuthService.LoginResult result) {
        return new MobileTokenResponse(result.accessToken().value(), "Bearer", result.accessToken().expiresAt(),
                result.refreshToken().raw(), result.refreshToken().expiresAt(), result.user());
    }

    public record RefreshRequest(@NotBlank @Size(max = 512) String refreshToken, AuthDtos.AppType appType) {}
    public record MobileTokenResponse(String accessToken, String tokenType, Instant expiresAt,
                                      String refreshToken, Instant refreshExpiresAt, AuthDtos.UserSummary user) {}
}

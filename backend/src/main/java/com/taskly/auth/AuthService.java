package com.taskly.auth;

import com.taskly.auth.dto.AuthDtos;
import com.taskly.common.exception.DomainException;
import com.taskly.rbac.entity.Permission;
import com.taskly.rbac.entity.Role;
import com.taskly.rbac.repository.RoleRepository;
import com.taskly.user.entity.UserAccount;
import com.taskly.user.entity.UserProfile;
import com.taskly.user.entity.UserStatus;
import com.taskly.user.repository.UserAccountRepository;
import com.taskly.user.repository.UserProfileRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final UserAccountRepository users;
    private final UserProfileRepository profiles;
    private final RoleRepository roles;
    private final PasswordEncoder passwordEncoder;
    private final OtpService otpService;
    private final OtpMailSender otpMailSender;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokens;
    private final AuthProperties properties;
    private final Clock clock;

    public AuthService(UserAccountRepository users, UserProfileRepository profiles, RoleRepository roles,
                       PasswordEncoder passwordEncoder, OtpService otpService, OtpMailSender otpMailSender,
                       JwtService jwtService, RefreshTokenService refreshTokens,
                       AuthProperties properties, Clock clock) {
        this.users = users;
        this.profiles = profiles;
        this.roles = roles;
        this.passwordEncoder = passwordEncoder;
        this.otpService = otpService;
        this.otpMailSender = otpMailSender;
        this.jwtService = jwtService;
        this.refreshTokens = refreshTokens;
        this.properties = properties;
        this.clock = clock;
    }

    @Transactional
    public AuthDtos.RegistrationResponse register(AuthDtos.RegisterRequest request) {
        String email = normalizeEmail(request.email());
        UserAccount pending = users.findByEmailIgnoreCase(email).orElse(null);
        if (pending != null
                && pending.getStatus() == UserStatus.PENDING_VERIFICATION
                && pending.getPhone().equals(request.phone())
                && passwordEncoder.matches(request.password(), pending.getPasswordHash())) {
            sendOtp("register", email);
            return new AuthDtos.RegistrationResponse(
                    pending.getId(), pending.getStatus(), "Mã xác minh mới đã được gửi tới email của bạn.");
        }
        if (users.existsByEmailIgnoreCase(email) || users.existsByPhone(request.phone())) {
            throw new DomainException("ACCOUNT_ALREADY_EXISTS", "Email hoặc số điện thoại đã được sử dụng.", HttpStatus.CONFLICT);
        }
        Role customerRole = roles.findByKey("CUSTOMER")
                .orElseThrow(() -> new IllegalStateException("CUSTOMER role seed is missing"));
        Instant now = clock.instant();
        UserAccount user = new UserAccount(email, request.phone(), passwordEncoder.encode(request.password()), customerRole, now);
        user.recordAppUse(request.appType(), now);
        try {
            user = users.save(user);
            profiles.save(new UserProfile(user, request.fullName().trim(), now));
        } catch (DataIntegrityViolationException conflict) {
            throw new DomainException("ACCOUNT_ALREADY_EXISTS", "Email hoặc số điện thoại đã được sử dụng.", HttpStatus.CONFLICT);
        }
        sendOtp("register", email);
        return new AuthDtos.RegistrationResponse(
                user.getId(), user.getStatus(), "Kiểm tra email để lấy mã xác minh.");
    }

    @Transactional
    public void verifyRegistration(AuthDtos.VerifyOtpRequest request) {
        String email = normalizeEmail(request.email());
        UserAccount user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new DomainException("OTP_INVALID", "Mã xác minh chưa đúng.", HttpStatus.UNPROCESSABLE_ENTITY));
        if (user.getStatus() == UserStatus.ACTIVE) return;
        if (user.getStatus() != UserStatus.PENDING_VERIFICATION) {
            throw new DomainException("ACCOUNT_UNAVAILABLE", "Tài khoản không thể xác minh.", HttpStatus.FORBIDDEN);
        }
        otpService.verify("register", email, request.code());
        user.verifyEmail(clock.instant());
    }

    @Transactional(readOnly = true)
    public void resendRegistrationOtp(AuthDtos.ResendOtpRequest request) {
        String email = normalizeEmail(request.email());
        users.findByEmailIgnoreCase(email)
                .filter(user -> user.getStatus() == UserStatus.PENDING_VERIFICATION)
                .ifPresent(user -> {
                    sendOtp("register", email);
                });
    }

    @Transactional(readOnly = true)
    public void forgotPassword(AuthDtos.ForgotPasswordRequest request) {
        String email = normalizeEmail(request.email());
        users.findByEmailIgnoreCase(email).ifPresent(user -> {
            sendOtp("password-reset", email);
        });
    }

    @Transactional
    public void resetPassword(AuthDtos.ResetPasswordRequest request) {
        String email = normalizeEmail(request.email());
        UserAccount user = users.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new DomainException("RESET_CODE_INVALID", "Mã khôi phục không hợp lệ.", HttpStatus.UNPROCESSABLE_ENTITY));
        otpService.verify("password-reset", email, request.code());
        Instant now = clock.instant();
        user.changePassword(passwordEncoder.encode(request.newPassword()), now);
        refreshTokens.revokeAll(user.getId(), now);
    }

    @Transactional(noRollbackFor = DomainException.class)
    public LoginResult loginByPhone(AuthDtos.PhoneLoginRequest request, ClientContext client) {
        UserAccount user = users.findByPhone(request.phone()).orElse(null);
        if (user == null) {
            throw new DomainException("INVALID_CREDENTIALS", "Số điện thoại hoặc mật khẩu chưa đúng.", HttpStatus.UNAUTHORIZED);
        }
        try {
            LoginResult result = login(new AuthDtos.LoginRequest(user.getEmail(), request.password(), request.deviceName()), client);
            user.recordAppUse(request.appType(), clock.instant());
            return result;
        } catch (DomainException failure) {
            if ("INVALID_CREDENTIALS".equals(failure.getCode())) {
                throw new DomainException("INVALID_CREDENTIALS", "Số điện thoại hoặc mật khẩu chưa đúng.", HttpStatus.UNAUTHORIZED);
            }
            throw failure;
        }
    }

    @Transactional(noRollbackFor = DomainException.class)
    public LoginResult login(AuthDtos.LoginRequest request, ClientContext client) {
        String email = normalizeEmail(request.email());
        UserAccount user = users.findByEmailIgnoreCase(email).orElse(null);
        Instant now = clock.instant();
        if (user == null || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            if (user != null) {
                user.recordLoginFailure(now, properties.loginMaxAttempts(), properties.loginCooldownSeconds());
            }
            throw invalidCredentials();
        }
        if (user.isLocked(now)) {
            throw new DomainException("LOGIN_COOLDOWN", "Đăng nhập tạm khóa. Vui lòng thử lại sau.", HttpStatus.TOO_MANY_REQUESTS);
        }
        if (user.getStatus() == UserStatus.PENDING_VERIFICATION) {
            throw new DomainException("EMAIL_VERIFICATION_REQUIRED", "Vui lòng xác minh email trước khi đăng nhập.", HttpStatus.FORBIDDEN);
        }
        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new DomainException("ACCOUNT_UNAVAILABLE", "Tài khoản hiện không thể đăng nhập.", HttpStatus.FORBIDDEN);
        }
        user.recordLoginSuccess(now);
        JwtService.IssuedAccessToken access = jwtService.issue(user, now);
        RefreshTokenService.IssuedRefreshToken refresh = refreshTokens.issue(
                user, request.deviceName(), client.userAgent(), client.ipAddress(), now);
        return new LoginResult(access, refresh, summary(user));
    }

    @Transactional(noRollbackFor = {RefreshTokenReuseException.class, DomainException.class})
    public LoginResult refresh(String rawToken, ClientContext client) {
        Instant now = clock.instant();
        RefreshTokenService.RotatedRefreshToken rotated = refreshTokens.rotate(
                rawToken, client.deviceName(), client.userAgent(), client.ipAddress(), now);
        UserAccount user = rotated.user();
        if (user.getStatus() != UserStatus.ACTIVE) {
            refreshTokens.revokeAll(user.getId(), now);
            throw new DomainException("ACCOUNT_UNAVAILABLE", "Tài khoản hiện không thể đăng nhập.", HttpStatus.FORBIDDEN);
        }
        return new LoginResult(jwtService.issue(user, now), rotated.refreshToken(), summary(user));
    }

    @Transactional(readOnly = true)
    public AuthDtos.UserSummary summary(UserAccount user) {
        String fullName = profiles.findById(user.getId()).map(UserProfile::getFullName).orElse("");
        List<String> roleKeys = user.getRoles().stream().map(Role::getKey).sorted().toList();
        List<String> permissions = user.getRoles().stream()
                .flatMap(role -> role.getPermissions().stream())
                .map(Permission::getKey).distinct().sorted().toList();
        return new AuthDtos.UserSummary(
                user.getId(), user.getEmail(), fullName, user.getStatus(), user.getActiveMode(), roleKeys, permissions);
    }

    @Transactional(readOnly = true)
    public UserAccount requireUser(UUID id) {
        return users.findById(id).orElseThrow(() ->
                new DomainException("USER_NOT_FOUND", "Không tìm thấy tài khoản.", HttpStatus.NOT_FOUND));
    }

    @Transactional
    public void recordAppUse(UUID userId, AuthDtos.AppType appType) {
        if (appType != null) requireUser(userId).recordAppUse(appType, clock.instant());
    }

    private void sendOtp(String purpose, String email) {
        String code = otpService.create(purpose, email);
        try {
            if ("register".equals(purpose)) {
                otpMailSender.sendVerification(email, code);
            } else {
                otpMailSender.sendPasswordReset(email, code);
            }
        } catch (DomainException failure) {
            if ("EMAIL_DELIVERY_FAILED".equals(failure.getCode())) {
                otpService.cancel(purpose, email);
            }
            throw failure;
        }
    }

    private String normalizeEmail(String email) { return email.trim().toLowerCase(); }

    private DomainException invalidCredentials() {
        return new DomainException("INVALID_CREDENTIALS", "Email hoặc mật khẩu chưa đúng.", HttpStatus.UNAUTHORIZED);
    }

    public record ClientContext(String deviceName, String userAgent, String ipAddress) {}
    public record LoginResult(
            JwtService.IssuedAccessToken accessToken,
            RefreshTokenService.IssuedRefreshToken refreshToken,
            AuthDtos.UserSummary user) {}
}

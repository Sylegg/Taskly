package com.taskly.auth;

import com.taskly.auth.entity.RefreshToken;
import com.taskly.auth.repository.RefreshTokenRepository;
import com.taskly.common.exception.DomainException;
import com.taskly.user.entity.UserAccount;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class RefreshTokenService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private final RefreshTokenRepository repository;
    private final AuthProperties properties;

    public RefreshTokenService(RefreshTokenRepository repository, AuthProperties properties) {
        this.repository = repository;
        this.properties = properties;
    }

    @Transactional
    public IssuedRefreshToken issue(UserAccount user, String device, String userAgent, String ip, Instant now) {
        return create(user, UUID.randomUUID(), null, device, userAgent, ip, now);
    }

    @Transactional(noRollbackFor = {RefreshTokenReuseException.class, DomainException.class})
    public RotatedRefreshToken rotate(String raw, String device, String userAgent, String ip, Instant now) {
        RefreshToken current = repository.findForUpdateByTokenHash(hash(raw))
                .orElseThrow(() -> invalid("REFRESH_TOKEN_INVALID"));
        if (current.getRevokedAt() != null) {
            revokeFamily(current.getFamilyId(), now);
            throw new RefreshTokenReuseException();
        }
        if (!current.isUsable(now)) throw invalid("REFRESH_TOKEN_EXPIRED");

        IssuedRefreshToken replacement = create(
                current.getUser(), current.getFamilyId(), current.getId(), device, userAgent, ip, now);
        current.rotate(replacement.id(), now);
        return new RotatedRefreshToken(current.getUser(), replacement);
    }

    @Transactional
    public void revoke(String raw, Instant now) {
        repository.findByTokenHash(hash(raw)).ifPresent(token -> token.revoke(now));
    }

    @Transactional
    public void revokeAll(UUID userId, Instant now) {
        repository.revokeAllForUser(userId, now);
    }

    @Transactional(readOnly = true)
    public java.util.Optional<UUID> findIdByHash(String hash) {
        return repository.findByTokenHash(hash).map(RefreshToken::getId);
    }

    @Transactional(readOnly = true)
    public List<RefreshToken> activeSessions(UUID userId, Instant now) {
        return repository.findByUserIdAndRevokedAtIsNullAndExpiresAtAfterOrderByCreatedAtDesc(userId, now);
    }

    @Transactional
    public void revokeSession(UUID userId, UUID sessionId, Instant now) {
        RefreshToken token = repository.findById(sessionId)
                .filter(value -> value.getUser().getId().equals(userId))
                .orElseThrow(() -> new DomainException("SESSION_NOT_FOUND", "Không tìm thấy phiên đăng nhập.", HttpStatus.NOT_FOUND));
        token.revoke(now);
    }

    public String hash(String raw) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(properties.refreshPepper().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest.digest(raw.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }

    private IssuedRefreshToken create(UserAccount user, UUID family, UUID parent, String device,
                                      String userAgent, String ip, Instant now) {
        byte[] random = new byte[48];
        RANDOM.nextBytes(random);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        RefreshToken token = new RefreshToken(
                user, hash(raw), family, parent, device, userAgent, ip,
                now, now.plus(properties.refreshTtlDays(), ChronoUnit.DAYS));
        repository.save(token);
        return new IssuedRefreshToken(token.getId(), raw, token.getExpiresAt());
    }

    private void revokeFamily(UUID familyId, Instant now) {
        repository.findByFamilyIdAndRevokedAtIsNull(familyId).forEach(token -> token.revoke(now));
    }

    private DomainException invalid(String code) {
        return new DomainException(code, "Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.", HttpStatus.UNAUTHORIZED);
    }

    public record IssuedRefreshToken(UUID id, String raw, Instant expiresAt) {}
    public record RotatedRefreshToken(UserAccount user, IssuedRefreshToken refreshToken) {}
}

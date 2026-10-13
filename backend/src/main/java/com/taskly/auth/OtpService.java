package com.taskly.auth;

import com.taskly.common.exception.DomainException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.HexFormat;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class OtpService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private final StringRedisTemplate redis;
    private final AuthProperties properties;

    public OtpService(StringRedisTemplate redis, AuthProperties properties) {
        this.redis = redis;
        this.properties = properties;
    }

    public String create(String purpose, String subject) {
        String normalized = subject.toLowerCase();
        String cooldownKey = "otp:cooldown:" + purpose + ":" + normalized;
        Boolean first = redis.opsForValue().setIfAbsent(
                cooldownKey, "1", Duration.ofSeconds(properties.otpResendSeconds()));
        if (!Boolean.TRUE.equals(first)) {
            throw new DomainException("OTP_RATE_LIMITED", "Vui lòng chờ trước khi yêu cầu mã mới.", HttpStatus.TOO_MANY_REQUESTS);
        }
        String code = String.format("%06d", RANDOM.nextInt(1_000_000));
        String value = hash(code) + ":0";
        redis.opsForValue().set(
                challengeKey(purpose, normalized),
                value,
                Duration.ofMinutes(properties.otpTtlMinutes()));
        return code;
    }

    public void cancel(String purpose, String subject) {
        String normalized = subject.toLowerCase();
        redis.delete(java.util.List.of(challengeKey(purpose, normalized),
                "otp:cooldown:" + purpose + ":" + normalized));
    }

    public void verify(String purpose, String subject, String code) {
        String key = challengeKey(purpose, subject.toLowerCase());
        String stored = redis.opsForValue().get(key);
        if (stored == null) {
            throw new DomainException("OTP_EXPIRED", "Mã xác minh đã hết hạn.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        String[] parts = stored.split(":", 2);
        int attempts = Integer.parseInt(parts[1]);
        if (attempts >= properties.otpMaxAttempts()) {
            redis.delete(key);
            throw new DomainException("OTP_ATTEMPTS_EXCEEDED", "Mã xác minh không còn hiệu lực.", HttpStatus.TOO_MANY_REQUESTS);
        }
        if (!MessageDigest.isEqual(parts[0].getBytes(StandardCharsets.UTF_8), hash(code).getBytes(StandardCharsets.UTF_8))) {
            Long ttlSeconds = redis.getExpire(key);
            if (ttlSeconds != null && ttlSeconds > 0) {
                redis.opsForValue().set(key, parts[0] + ":" + (attempts + 1), Duration.ofSeconds(ttlSeconds));
            }
            throw new DomainException("OTP_INVALID", "Mã xác minh chưa đúng.", HttpStatus.UNPROCESSABLE_ENTITY);
        }
        redis.delete(key);
    }

    private String challengeKey(String purpose, String subject) {
        return "otp:challenge:" + purpose + ":" + subject;
    }

    private String hash(String code) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            digest.update(properties.refreshPepper().getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest.digest(code.getBytes(StandardCharsets.UTF_8)));
        } catch (java.security.NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }
}

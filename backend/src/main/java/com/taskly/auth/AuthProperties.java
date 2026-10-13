package com.taskly.auth;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.auth")
public record AuthProperties(
        String accessSecret,
        String refreshPepper,
        long accessTtlMinutes,
        long refreshTtlDays,
        long otpTtlMinutes,
        long otpResendSeconds,
        int otpMaxAttempts,
        int loginMaxAttempts,
        long loginCooldownSeconds,
        boolean secureCookies
) {}

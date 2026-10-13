package com.taskly.config;

import com.taskly.auth.AuthProperties;
import jakarta.annotation.PostConstruct;
import java.util.Set;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

@Component
public class ProductionSafetyValidator {
    private static final Set<String> UNSAFE_PASSWORDS = Set.of("", "taskly_dev_only", "password", "admin");

    private final AppProperties properties;
    private final AuthProperties authProperties;
    private final Environment environment;

    public ProductionSafetyValidator(
            AppProperties properties,
            AuthProperties authProperties,
            Environment environment) {
        this.properties = properties;
        this.authProperties = authProperties;
        this.environment = environment;
    }

    @PostConstruct
    void validate() {
        if (!properties.security().productionProfile().equalsIgnoreCase(properties.environment())) {
            return;
        }
        requireSafe("POSTGRES_PASSWORD");
        requirePresent("JWT_ACCESS_SECRET");
        requirePresent("REFRESH_TOKEN_PEPPER");
        requirePresent("PAYMENT_WEBHOOK_SECRET");
        requirePresent("MINIO_ROOT_USER");
        requireSafe("MINIO_ROOT_PASSWORD");
        if (properties.cors().allowedOrigins().stream().anyMatch("*"::equals)) {
            throw new IllegalStateException("Wildcard CORS origin is forbidden in production");
        }
        if (!authProperties.secureCookies()) {
            throw new IllegalStateException("Secure refresh cookies are required in production");
        }
    }

    private void requirePresent(String key) {
        String value = environment.getProperty(key, "");
        if (value.isBlank()) {
            throw new IllegalStateException(key + " must be configured in production");
        }
    }

    private void requireSafe(String key) {
        String value = environment.getProperty(key, "");
        if (UNSAFE_PASSWORDS.contains(value) || value.length() < 16) {
            throw new IllegalStateException(key + " is unsafe for production");
        }
    }
}

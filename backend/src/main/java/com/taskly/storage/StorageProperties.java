package com.taskly.storage;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.storage")
public record StorageProperties(
        String endpoint,
        String accessKey,
        String secretKey,
        String privateBucket,
        long maxImageBytes,
        int signedUrlSeconds
) {}

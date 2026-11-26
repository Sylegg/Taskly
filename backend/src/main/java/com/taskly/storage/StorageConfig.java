package com.taskly.storage;

import io.minio.MinioClient;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableConfigurationProperties(StorageProperties.class)
public class StorageConfig {
    @Bean
    MinioClient minioClient(StorageProperties properties,
                            @Value("${app.storage.region:}") String region,
                            @Value("${app.storage.virtual-hosted-style:false}") boolean virtualHostedStyle) {
        var builder = MinioClient.builder()
                .endpoint(properties.endpoint())
                .credentials(properties.accessKey(), properties.secretKey());
        if (!region.isBlank()) {
            builder.region(region);
        }
        var client = builder.build();
        if (virtualHostedStyle) {
            client.enableVirtualStyleEndpoint();
        }
        return client;
    }
}

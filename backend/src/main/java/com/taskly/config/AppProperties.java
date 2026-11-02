package com.taskly.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(String environment, Cors cors, Security security) {
    public record Cors(List<String> allowedOrigins) {}
    public record Security(String productionProfile) {}
}

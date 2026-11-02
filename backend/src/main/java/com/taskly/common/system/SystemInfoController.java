package com.taskly.common.system;

import com.taskly.common.api.ApiResponse;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/system")
public class SystemInfoController {
    private final String environment;

    public SystemInfoController(@Value("${app.environment}") String environment) {
        this.environment = environment;
    }

    @GetMapping("/info")
    ApiResponse<Map<String, String>> info() {
        return ApiResponse.success(Map.of(
                "name", "TaskLy API",
                "environment", environment,
                "status", "foundation-ready"));
    }
}

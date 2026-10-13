package com.taskly.common.api;

import java.time.Instant;
import java.util.List;

public record ApiErrorResponse(boolean success, ErrorDetail error, Instant timestamp, String requestId) {
    public ApiErrorResponse(String code, String message, List<FieldErrorDetail> fieldErrors, String requestId) {
        this(false, new ErrorDetail(code, message, fieldErrors), Instant.now(), requestId);
    }

    public record ErrorDetail(String code, String message, List<FieldErrorDetail> fieldErrors) {}

    public record FieldErrorDetail(String field, String message) {}
}

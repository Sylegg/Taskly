package com.taskly.common.api;

import com.taskly.common.exception.DomainException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.ConstraintViolationException;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.slf4j.MDC;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.resource.NoResourceFoundException;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(DomainException.class)
    ResponseEntity<ApiErrorResponse> domain(DomainException exception) {
        return ResponseEntity.status(exception.getStatus())
                .body(error(exception.getCode(), exception.getMessage(), List.of()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiErrorResponse> validation(MethodArgumentNotValidException exception) {
        List<ApiErrorResponse.FieldErrorDetail> errors = exception.getBindingResult().getFieldErrors().stream()
                .map(this::toFieldError)
                .toList();
        return ResponseEntity.badRequest().body(error("VALIDATION_FAILED", "Dữ liệu chưa hợp lệ.", errors));
    }

    @ExceptionHandler(ConstraintViolationException.class)
    ResponseEntity<ApiErrorResponse> constraint(ConstraintViolationException exception) {
        var errors = exception.getConstraintViolations().stream()
                .map(value -> new ApiErrorResponse.FieldErrorDetail(
                        value.getPropertyPath().toString(), value.getMessage()))
                .toList();
        return ResponseEntity.badRequest().body(error("VALIDATION_FAILED", "Dữ liệu chưa hợp lệ.", errors));
    }

    @ExceptionHandler(AccessDeniedException.class)
    ResponseEntity<ApiErrorResponse> forbidden(AccessDeniedException exception) {
        return ResponseEntity.status(HttpStatus.FORBIDDEN)
                .body(error("FORBIDDEN", "Bạn không có quyền thực hiện thao tác này.", List.of()));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiErrorResponse> missingResource(NoResourceFoundException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND)
                .body(error("NOT_FOUND", "API endpoint is not available.", List.of()));
    }

    @ExceptionHandler(org.springframework.web.server.ResponseStatusException.class)
    ResponseEntity<ApiErrorResponse> requestStatus(org.springframework.web.server.ResponseStatusException exception) {
        return ResponseEntity.status(exception.getStatusCode())
                .body(error("REQUEST_REJECTED", exception.getReason() == null ? "Không thể xử lý yêu cầu." : exception.getReason(), List.of()));
    }

    @ExceptionHandler(Exception.class)
    ResponseEntity<ApiErrorResponse> unexpected(Exception exception, HttpServletRequest request) {
        String requestId = currentRequestId();
        log.error("Unhandled request failure method={} path={} requestId={}",
                request.getMethod(), request.getRequestURI(), requestId, exception);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(error("INTERNAL_ERROR", "Đã có lỗi xảy ra. Mã hỗ trợ: " + requestId, List.of()));
    }

    private ApiErrorResponse.FieldErrorDetail toFieldError(FieldError error) {
        return new ApiErrorResponse.FieldErrorDetail(error.getField(), error.getDefaultMessage());
    }

    private ApiErrorResponse error(String code, String message, List<ApiErrorResponse.FieldErrorDetail> fields) {
        return new ApiErrorResponse(code, message, fields, currentRequestId());
    }

    private String currentRequestId() {
        return MDC.get(RequestCorrelationFilter.MDC_KEY);
    }
}

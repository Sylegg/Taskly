package com.taskly.auth;

import com.taskly.common.exception.DomainException;
import org.springframework.http.HttpStatus;

public class RefreshTokenReuseException extends DomainException {
    public RefreshTokenReuseException() {
        super("REFRESH_TOKEN_REUSE_DETECTED", "Phiên đăng nhập có dấu hiệu bị tái sử dụng. Vui lòng đăng nhập lại.", HttpStatus.UNAUTHORIZED);
    }
}

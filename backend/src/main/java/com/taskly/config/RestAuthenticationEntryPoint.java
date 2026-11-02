package com.taskly.config;

import com.taskly.common.api.RequestCorrelationFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.slf4j.MDC;
import org.springframework.http.MediaType;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.stereotype.Component;

@Component
public class RestAuthenticationEntryPoint implements AuthenticationEntryPoint {
    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException exception
    ) throws IOException {
        String requestId = MDC.get(RequestCorrelationFilter.MDC_KEY);
        response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().printf(
                "{\"success\":false,\"error\":{\"code\":\"UNAUTHENTICATED\",\"message\":\"Vui lòng đăng nhập.\",\"fieldErrors\":[]},\"requestId\":\"%s\"}",
                requestId);
    }
}

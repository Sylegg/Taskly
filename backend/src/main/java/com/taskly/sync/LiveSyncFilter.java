package com.taskly.sync;

import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/** Runs after successful mutations, after controller transactions have committed. */
@Component
public class LiveSyncFilter extends OncePerRequestFilter {
    private final LiveSync sync;
    public LiveSyncFilter(LiveSync sync) { this.sync=sync; }
    @Override protected boolean shouldNotFilter(HttpServletRequest request) {
        String path=request.getRequestURI();
        return !path.startsWith("/api/v1/") || path.startsWith("/api/v1/auth/")
            || path.contains("/heartbeat") || path.endsWith("/booking-quotes")
            || !java.util.Set.of("POST","PUT","PATCH","DELETE").contains(request.getMethod());
    }
    @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain) throws ServletException,IOException {
        chain.doFilter(request,response);
        if(response.getStatus()>=200&&response.getStatus()<300) {
            try { sync.changed(); }
            catch(Exception e) { LoggerFactory.getLogger(getClass()).warn("Unable to publish live revision",e); }
        }
    }
}

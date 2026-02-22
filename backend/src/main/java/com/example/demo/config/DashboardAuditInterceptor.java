package com.example.demo.config;

import com.example.demo.service.DashboardAuthService;
import com.example.demo.service.JwtDashboardService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * Records dashboard admin API mutations in the audit log (visible only in managing dashboard).
 */
@Component
public class DashboardAuditInterceptor implements HandlerInterceptor {

    private final JwtDashboardService jwtService;
    private final DashboardAuthService authService;

    public DashboardAuditInterceptor(JwtDashboardService jwtService, DashboardAuthService authService) {
        this.jwtService = jwtService;
        this.authService = authService;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String method = request.getMethod();
        if ("GET".equalsIgnoreCase(method) || "OPTIONS".equalsIgnoreCase(method))
            return true;
        String auth = request.getHeader("Authorization");
        String token = (auth != null && auth.startsWith("Bearer ")) ? auth.substring(7) : null;
        if (token == null || !jwtService.isTokenValid(token))
            return true;
        String email = jwtService.getEmailFromToken(token);
        if (email == null || email.isBlank())
            return true;
        String path = request.getRequestURI();
        if (path != null && path.length() > 512) path = path.substring(0, 512);
        authService.recordAudit("API_" + method, path, email);
        return true;
    }
}

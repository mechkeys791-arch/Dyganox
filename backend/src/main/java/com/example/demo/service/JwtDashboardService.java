package com.example.demo.service;

import org.springframework.stereotype.Service;

/**
 * Stub implementation; dashboard JWT was removed. Kept so controllers compile.
 */
@Service
public class JwtDashboardService {

    public Boolean getManagingFromToken(String token) {
        return null;
    }

    public boolean isTokenValid(String token) {
        return false;
    }

    public String getEmailFromToken(String token) {
        return null;
    }
}

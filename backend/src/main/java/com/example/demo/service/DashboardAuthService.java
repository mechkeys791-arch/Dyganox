package com.example.demo.service;

import com.example.demo.model.DashboardAdmin;
import com.example.demo.model.DashboardAuditLog;
import org.springframework.stereotype.Service;

import java.util.Collections;
import java.util.List;

/**
 * Stub implementation; dashboard login was removed. Kept so controllers compile.
 */
@Service
public class DashboardAuthService {

    public boolean verifyOtp(String email, String otp) {
        return false;
    }

    public String issueTokenAfterOtp(String email) {
        return null;
    }

    public void recordLogout(String email) {}

    public List<DashboardAdmin> getRegisteredAdmins() {
        return Collections.emptyList();
    }

    public List<DashboardAuditLog> getAuditLog() {
        return Collections.emptyList();
    }

    public void setManagingPassword(String email, String password) {
        throw new UnsupportedOperationException("Dashboard managing auth disabled");
    }

    public void registerAdmin(String email, String adminPassword, String managingPassword, String role) {
        throw new UnsupportedOperationException("Dashboard auth disabled");
    }

    public boolean bootstrapOwnerIfEmpty(String password, String secret) {
        return false;
    }

    public void recordAudit(String action, String path, String email) {}

    public void seedOwnerIfNeeded(String ownerPassword) {}
}

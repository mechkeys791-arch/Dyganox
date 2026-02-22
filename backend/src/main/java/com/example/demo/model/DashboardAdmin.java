package com.example.demo.model;

import java.time.Instant;

/**
 * Dashboard admin model (stub for compile; dashboard auth was removed).
 */
public class DashboardAdmin {

    public static final String OWNER_EMAIL = "owner@dyganox.com";

    private String email;
    private String role;
    private Instant createdAt;
    private String passwordManagingHash;

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getRole() { return role; }
    public void setRole(String role) { this.role = role; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public String getPasswordManagingHash() { return passwordManagingHash; }
    public void setPasswordManagingHash(String passwordManagingHash) { this.passwordManagingHash = passwordManagingHash; }
}

package com.example.demo.model;

import java.time.Instant;

/**
 * Dashboard audit log model (stub for compile; dashboard auth was removed).
 */
public class DashboardAuditLog {

    private String email;
    private String action;
    private String details;
    private Instant atTime;

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getAction() { return action; }
    public void setAction(String action) { this.action = action; }
    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }
    public Instant getAtTime() { return atTime; }
    public void setAtTime(Instant atTime) { this.atTime = atTime; }
}

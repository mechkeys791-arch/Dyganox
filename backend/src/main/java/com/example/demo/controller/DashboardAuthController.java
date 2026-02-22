package com.example.demo.controller;

import com.example.demo.model.DashboardAdmin;
import com.example.demo.model.DashboardAuditLog;
import com.example.demo.service.DashboardAuthService;
import com.example.demo.service.JwtDashboardService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/dashboard-auth")
@CrossOrigin(origins = "*")
public class DashboardAuthController {

    private final DashboardAuthService authService;
    private final JwtDashboardService jwtService;

    public DashboardAuthController(DashboardAuthService authService, JwtDashboardService jwtService) {
        this.authService = authService;
        this.jwtService = jwtService;
    }

    private String tokenFromAuth(String auth) {
        return (auth != null && auth.startsWith("Bearer ")) ? auth.substring(7) : null;
    }

    private boolean isManaging(String token) {
        return token != null && Boolean.TRUE.equals(jwtService.getManagingFromToken(token));
    }

    @PostMapping("/verify-otp")
    public ResponseEntity<Map<String, Object>> verifyOtp(@RequestBody Map<String, String> body) {
        String email = body != null ? body.get("email") : null;
        String otp = body != null ? body.get("otp") : null;
        if (!authService.verifyOtp(email, otp)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("success", false, "message", "Invalid or expired OTP"));
        }
        String token = authService.issueTokenAfterOtp(email);
        if (token == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("success", false, "message", "Error issuing token"));
        }
        return ResponseEntity.ok(Map.of("success", true, "token", token, "managing", false));
    }

    @GetMapping("/me")
    public ResponseEntity<Map<String, Object>> me(@RequestHeader(value = "Authorization", required = false) String auth) {
        String token = tokenFromAuth(auth);
        if (token == null || !jwtService.isTokenValid(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        String email = jwtService.getEmailFromToken(token);
        String role = DashboardAdmin.OWNER_EMAIL.equalsIgnoreCase(email) ? "OWNER" : "ADMIN";
        boolean managing = isManaging(token);
        return ResponseEntity.ok(Map.of("email", email, "role", role, "managing", managing));
    }

    @PostMapping("/record-logout")
    public ResponseEntity<Map<String, Object>> recordLogout(@RequestHeader(value = "Authorization", required = false) String auth) {
        String token = tokenFromAuth(auth);
        if (token == null || !jwtService.isTokenValid(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        String email = jwtService.getEmailFromToken(token);
        authService.recordLogout(email);
        return ResponseEntity.ok(Map.of("success", true));
    }

    // ---------- Managing-only endpoints (require managing token) ----------

    @GetMapping("/registered-admins")
    public ResponseEntity<?> getRegisteredAdmins(@RequestHeader(value = "Authorization", required = false) String auth) {
        String token = tokenFromAuth(auth);
        if (token == null || !jwtService.isTokenValid(token) || !isManaging(token)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        List<DashboardAdmin> admins = authService.getRegisteredAdmins();
        List<Map<String, Object>> list = admins.stream()
                .map(a -> {
                    Map<String, Object> m = new HashMap<>();
                    m.put("email", a.getEmail());
                    m.put("role", a.getRole());
                    m.put("registeredAt", a.getCreatedAt().toString());
                    m.put("hasManagingPassword", a.getPasswordManagingHash() != null && !a.getPasswordManagingHash().isBlank());
                    return m;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(list);
    }

    @GetMapping("/audit-log")
    public ResponseEntity<?> getAuditLog(@RequestHeader(value = "Authorization", required = false) String auth) {
        String token = tokenFromAuth(auth);
        if (token == null || !jwtService.isTokenValid(token) || !isManaging(token)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        List<DashboardAuditLog> list = authService.getAuditLog();
        List<Map<String, Object>> out = list.stream()
                .map(a -> Map.<String, Object>of(
                        "email", a.getEmail(),
                        "action", a.getAction(),
                        "details", a.getDetails() != null ? a.getDetails() : "",
                        "atTime", a.getAtTime().toString()))
                .collect(Collectors.toList());
        return ResponseEntity.ok(out);
    }

    /** Set managing password for an admin (managing token required). */
    @PostMapping("/set-managing-password")
    public ResponseEntity<Map<String, Object>> setManagingPassword(
            @RequestHeader(value = "Authorization", required = false) String auth,
            @RequestBody Map<String, String> body) {
        String token = tokenFromAuth(auth);
        if (token == null || !jwtService.isTokenValid(token) || !isManaging(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        if (!DashboardAdmin.OWNER_EMAIL.equalsIgnoreCase(jwtService.getEmailFromToken(token))) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Only owner can set managing passwords"));
        }
        String email = body != null ? body.get("email") : null;
        String password = body != null ? body.get("password") : null;
        if (email == null || email.isBlank() || password == null || password.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "email and password required"));
        }
        try {
            authService.setManagingPassword(email.trim(), password);
            return ResponseEntity.ok(Map.of("success", true, "email", email.trim()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    /** Owner only: register new admin (from managing dashboard). */
    @PostMapping("/register-admin")
    public ResponseEntity<Map<String, Object>> registerAdmin(
            @RequestHeader(value = "Authorization", required = false) String auth,
            @RequestBody Map<String, String> body) {
        String token = tokenFromAuth(auth);
        if (token == null || !jwtService.isTokenValid(token) || !isManaging(token)) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        if (!DashboardAdmin.OWNER_EMAIL.equalsIgnoreCase(jwtService.getEmailFromToken(token))) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("error", "Only owner can register admins"));
        }
        String email = body != null ? body.get("email") : null;
        String adminPassword = body != null ? body.get("password") : null;
        String managingPassword = body != null ? body.get("managingPassword") : null;
        if (email == null || email.isBlank() || adminPassword == null || adminPassword.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "email and password (admin) required"));
        }
        try {
            authService.registerAdmin(email.trim(), adminPassword, managingPassword, body != null ? body.get("role") : null);
            return ResponseEntity.ok(Map.of("success", true, "email", email.trim()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    /** Bootstrap: create owner if not present (DB only). */
    @PostMapping("/bootstrap")
    public ResponseEntity<Map<String, Object>> bootstrap(@RequestBody Map<String, String> body) {
        String password = body != null ? body.get("password") : null;
        String managingPassword = body != null ? body.get("managingPassword") : null;
        String secret = body != null ? body.get("secret") : null;
        boolean created = authService.bootstrapOwnerIfEmpty(password, secret);
        if (!created) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of(
                    "success", false,
                    "message", "Bootstrap failed: owner already exists, password empty, or secret wrong."));
        }
        if (managingPassword != null && !managingPassword.isBlank()) {
            authService.setManagingPassword(DashboardAdmin.OWNER_EMAIL, managingPassword);
        }
        return ResponseEntity.ok(Map.of("success", true, "message", "Owner created. Use " + DashboardAdmin.OWNER_EMAIL + " with admin password (then OTP) or managing password (direct)."));
    }
}

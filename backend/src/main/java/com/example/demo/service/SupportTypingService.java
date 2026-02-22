package com.example.demo.service;

import org.springframework.stereotype.Service;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/** In-memory typing indicators for support chat. Admin and user each set when typing; cleared after ~5s. */
@Service
public class SupportTypingService {

    // userEmail -> timestamp (ms) until which admin is considered typing
    private final Map<String, Long> adminTypingUntil = new ConcurrentHashMap<>();
    // userEmail -> timestamp until which user is considered typing
    private final Map<String, Long> userTypingUntil = new ConcurrentHashMap<>();
    private static final long TYPING_DURATION_MS = 5000;

    public void setAdminTyping(String userEmail, boolean typing) {
        if (userEmail == null || userEmail.isBlank()) return;
        if (typing) {
            adminTypingUntil.put(userEmail.trim().toLowerCase(), System.currentTimeMillis() + TYPING_DURATION_MS);
        } else {
            adminTypingUntil.remove(userEmail.trim().toLowerCase());
        }
    }

    public boolean isAdminTyping(String userEmail) {
        if (userEmail == null || userEmail.isBlank()) return false;
        Long until = adminTypingUntil.get(userEmail.trim().toLowerCase());
        if (until == null) return false;
        if (System.currentTimeMillis() > until) {
            adminTypingUntil.remove(userEmail.trim().toLowerCase());
            return false;
        }
        return true;
    }

    public void setUserTyping(String userEmail, boolean typing) {
        if (userEmail == null || userEmail.isBlank()) return;
        if (typing) {
            userTypingUntil.put(userEmail.trim().toLowerCase(), System.currentTimeMillis() + TYPING_DURATION_MS);
        } else {
            userTypingUntil.remove(userEmail.trim().toLowerCase());
        }
    }

    public boolean isUserTyping(String userEmail) {
        if (userEmail == null || userEmail.isBlank()) return false;
        Long until = userTypingUntil.get(userEmail.trim().toLowerCase());
        if (until == null) return false;
        if (System.currentTimeMillis() > until) {
            userTypingUntil.remove(userEmail.trim().toLowerCase());
            return false;
        }
        return true;
    }

    // Mechanic help chat typing (mechanicEmail as key)
    private final Map<String, Long> mechanicAdminTypingUntil = new ConcurrentHashMap<>();
    private final Map<String, Long> mechanicTypingUntil = new ConcurrentHashMap<>();

    public void setMechanicAdminTyping(String mechanicEmail, boolean typing) {
        if (mechanicEmail == null || mechanicEmail.isBlank()) return;
        String k = mechanicEmail.trim().toLowerCase();
        if (typing) mechanicAdminTypingUntil.put(k, System.currentTimeMillis() + TYPING_DURATION_MS);
        else mechanicAdminTypingUntil.remove(k);
    }

    public boolean isMechanicAdminTyping(String mechanicEmail) {
        if (mechanicEmail == null || mechanicEmail.isBlank()) return false;
        Long until = mechanicAdminTypingUntil.get(mechanicEmail.trim().toLowerCase());
        if (until == null) return false;
        if (System.currentTimeMillis() > until) {
            mechanicAdminTypingUntil.remove(mechanicEmail.trim().toLowerCase());
            return false;
        }
        return true;
    }

    public void setMechanicTyping(String mechanicEmail, boolean typing) {
        if (mechanicEmail == null || mechanicEmail.isBlank()) return;
        String k = mechanicEmail.trim().toLowerCase();
        if (typing) mechanicTypingUntil.put(k, System.currentTimeMillis() + TYPING_DURATION_MS);
        else mechanicTypingUntil.remove(k);
    }

    public boolean isMechanicTyping(String mechanicEmail) {
        if (mechanicEmail == null || mechanicEmail.isBlank()) return false;
        Long until = mechanicTypingUntil.get(mechanicEmail.trim().toLowerCase());
        if (until == null) return false;
        if (System.currentTimeMillis() > until) {
            mechanicTypingUntil.remove(mechanicEmail.trim().toLowerCase());
            return false;
        }
        return true;
    }
}

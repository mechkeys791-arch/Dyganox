package com.example.demo.controller;

import com.example.demo.service.FcmService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Debug endpoint: check if FCM is initialized (Firebase key loaded).
 * curl http://localhost:8081/api/fcm-status
 */
@RestController
@RequestMapping("/api")
public class FcmStatusController {

    private final FcmService fcmService;

    public FcmStatusController(FcmService fcmService) {
        this.fcmService = fcmService;
    }

    @GetMapping("/fcm-status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        return ResponseEntity.ok(Map.of(
                "fcmInitialized", fcmService.isInitialized(),
                "message", fcmService.isInitialized()
                        ? "Firebase FCM ready - notifications will be sent"
                        : "Firebase NOT initialized - put firebase-service-account.json in backend/src/main/resources/ and restart"
        ));
    }
}

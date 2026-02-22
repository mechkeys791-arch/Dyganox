package com.example.demo.service;

import org.springframework.stereotype.Service;

/**
 * Stub FCM service; push notifications disabled. Kept so MechanicRequestController compiles.
 */
@Service
public class FcmService {

    public void sendMechanicRequestNotification(
            String fcmToken,
            Long requestId,
            String customerName,
            String serviceType,
            String customerPhone,
            double amount,
            Double distanceKm,
            String description) {
        // No-op: FCM not configured
    }
}

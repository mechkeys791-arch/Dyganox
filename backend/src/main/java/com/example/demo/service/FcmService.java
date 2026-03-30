package com.example.demo.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;

/**
 * Sends FCM push notifications to mechanics when a customer creates a request.
 * Uses notification + data payloads: notification ensures system displays when app is backgrounded/killed
 * (data-only messages are not reliably delivered on Android when app is not in foreground).
 * Data payload provides requestId for Accept/Reject handling.
 */
@Service
public class FcmService {

    private boolean initialized = false;

    @PostConstruct
    public void init() {
        if (FirebaseApp.getApps().isEmpty()) {
            try {
                Resource resource = new ClassPathResource("firebase-service-account.json");
                if (!resource.exists()) {
                    System.err.println("⚠️ Firebase FCM not initialized: firebase-service-account.json not found in classpath. Put it in backend/src/main/resources/");
                    return;
                }
                try (InputStream is = resource.getInputStream()) {
                    FirebaseOptions options = FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(is))
                            .build();
                    FirebaseApp.initializeApp(options);
                    initialized = true;
                    System.out.println("✅ Firebase initialized for FCM");
                }
            } catch (Exception e) {
                System.err.println("⚠️ Firebase FCM not initialized (missing or invalid service account file): " + e.getMessage());
            }
        } else {
            initialized = true;
        }
    }

    public boolean isInitialized() {
        return initialized;
    }

    public void sendMechanicRequestNotification(
            String fcmToken,
            Long requestId,
            String customerName,
            String serviceType,
            String customerPhone,
            double amount,
            Double distanceKm,
            String description) {
        if (!initialized) {
            System.err.println("⚠️ [FCM] NOT INITIALIZED - cannot send notification for requestId=" + requestId);
            return;
        }
        if (fcmToken == null || fcmToken.isBlank()) {
            System.err.println("⚠️ [Request " + requestId + "] Notification NOT sent: mechanic has no FCM token");
            return;
        }

        String customerDisplay = (customerName != null && !customerName.isBlank()) ? customerName : "Customer";
        String distanceStr = (distanceKm != null) ? String.format("%.1f km", distanceKm) : "";
        String title = "New request";
        String body = (customerName != null && !customerName.isBlank())
                ? customerName + " requested " + (serviceType != null ? serviceType : "service")
                : "A customer requested your service.";

        try {
            // Notification payload ensures system displays when app is backgrounded/killed.
            // Data-only messages are not reliably delivered on Android when app is not in foreground.
            Notification notification = Notification.builder()
                    .setTitle(title)
                    .setBody(body)
                    .build();
            AndroidConfig androidConfig = AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setNotification(AndroidNotification.builder()
                            .setChannelId("mechanic_requests")
                            .setPriority(AndroidNotification.Priority.HIGH)
                            .build())
                    .build();
            var builder = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(notification)
                    .setAndroidConfig(androidConfig)
                    .putData("type", "mechanic_request")
                    .putData("requestId", String.valueOf(requestId))
                    .putData("title", title)
                    .putData("body", body)
                    .putData("customerName", customerDisplay);
            if (distanceStr.length() > 0) {
                builder = builder.putData("distanceKm", distanceStr);
            }
            Message message = builder.build();

            String messageId = FirebaseMessaging.getInstance().send(message);
            System.out.println("✅ [FCM] SENT requestId=" + requestId + " -> " + messageId);
        } catch (Exception e) {
            System.err.println("❌ [FCM] SEND FAILED requestId=" + requestId + ": " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Notify a mechanic that a request was accepted by another mechanic – so they can dismiss/cancel it from their list.
     */
    public void sendRequestTakenNotification(String fcmToken, Long requestId) {
        if (!initialized) return;
        if (fcmToken == null || fcmToken.isBlank()) return;
        try {
            Notification notification = Notification.builder()
                    .setTitle("Request taken")
                    .setBody("Another mechanic accepted this request")
                    .build();
            AndroidConfig androidConfig = AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .setNotification(AndroidNotification.builder()
                            .setChannelId("mechanic_requests")
                            .setPriority(AndroidNotification.Priority.HIGH)
                            .build())
                    .build();
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(notification)
                    .setAndroidConfig(androidConfig)
                    .putData("type", "request_taken")
                    .putData("requestId", String.valueOf(requestId))
                    .putData("title", "Request taken")
                    .putData("body", "Another mechanic accepted this request")
                    .build();
            FirebaseMessaging.getInstance().send(message);
            System.out.println("✅ [FCM] request_taken sent requestId=" + requestId);
        } catch (Exception e) {
            System.err.println("❌ [FCM] request_taken FAILED requestId=" + requestId + ": " + e.getMessage());
        }
    }
}

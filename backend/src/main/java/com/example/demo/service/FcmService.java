package com.example.demo.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;

/**
 * Sends FCM push notifications to mechanics when a customer creates a request.
 * Uses data-only + high priority on Android so {@code onMessageReceived} runs in
 * {@link com.example.dyganox.DyganoxFirebaseMessagingService} when the app is backgrounded or killed.
 * If we send a top-level {@code notification} payload, Android delivers to the system tray only and
 * <em>does not</em> call {@code onMessageReceived}, so the custom alarm / Accept-Reject flow never runs.
 * Title/body are carried in the data map; the client shows notifications from that data.
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
            // Pure data + HIGH priority. Do not set Notification or AndroidConfig.notification — otherwise
            // Android delivers to the tray only and skips onMessageReceived when backgrounded.
            AndroidConfig androidConfig = AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .build();
            var builder = Message.builder()
                    .setToken(fcmToken)
                    .setAndroidConfig(androidConfig)
                    .putData("type", "mechanic_request")
                    .putData("requestId", String.valueOf(requestId))
                    .putData("title", title)
                    .putData("body", body)
                    .putData("customerName", customerDisplay);
            if (distanceStr.length() > 0) {
                builder = builder.putData("distanceKm", distanceStr);
            }
            // iOS: allow background delivery of data (optional; app may still need notification permission)
            builder = builder.setApnsConfig(ApnsConfig.builder()
                    .putHeader("apns-priority", "10")
                    .setAps(Aps.builder().setContentAvailable(true).build())
                    .build());
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
            AndroidConfig androidConfig = AndroidConfig.builder()
                    .setPriority(AndroidConfig.Priority.HIGH)
                    .build();
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setAndroidConfig(androidConfig)
                    .putData("type", "request_taken")
                    .putData("requestId", String.valueOf(requestId))
                    .putData("title", "Request taken")
                    .putData("body", "Another mechanic accepted this request")
                    .setApnsConfig(ApnsConfig.builder()
                            .putHeader("apns-priority", "10")
                            .setAps(Aps.builder().setContentAvailable(true).build())
                            .build())
                    .build();
            FirebaseMessaging.getInstance().send(message);
            System.out.println("✅ [FCM] request_taken sent requestId=" + requestId);
        } catch (Exception e) {
            System.err.println("❌ [FCM] request_taken FAILED requestId=" + requestId + ": " + e.getMessage());
        }
    }
}

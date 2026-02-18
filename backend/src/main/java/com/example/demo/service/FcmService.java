package com.example.demo.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;
import java.util.HashMap;
import java.util.Map;

/**
 * Sends FCM push notifications to mechanic devices.
 * Requires firebase-service-account.json in src/main/resources (see FIREBASE_SETUP.md).
 */
@Service
public class FcmService {

    @Value("${firebase.service-account:classpath:firebase-service-account.json}")
    private String serviceAccountPath;

    private boolean initialized = false;

    @PostConstruct
    public void init() {
        if (initialized) return;
        try {
            InputStream stream;
            if (serviceAccountPath.startsWith("classpath:")) {
                String resource = serviceAccountPath.substring("classpath:".length());
                stream = new ClassPathResource(resource).getInputStream();
            } else {
                stream = new java.io.FileInputStream(serviceAccountPath);
            }
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(stream))
                    .build();
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
            }
            initialized = true;
            System.out.println("✅ Firebase initialized for FCM");
        } catch (Exception e) {
            System.err.println("⚠️ Firebase FCM not initialized (missing or invalid service account file): " + e.getMessage());
        }
    }

    /**
     * Send a mechanic request notification to the mechanic's device with rich info.
     * Data payload includes requestId, title, body, and optional customerPhone, amount, distance for the app.
     */
    public void sendMechanicRequestNotification(String fcmToken, Long requestId, String customerName,
                                                 String serviceType, String customerPhone, Double amount,
                                                 Double distanceKm, String description) {
        if (!initialized) {
            System.err.println("⚠️ [FCM] NOT INITIALIZED. Add firebase-service-account.json to backend/src/main/resources and redeploy EC2.");
            return;
        }
        if (fcmToken == null || fcmToken.isBlank()) {
            System.err.println("⚠️ [FCM] NO TOKEN for requestId=" + requestId + ". Mechanic must open the app (mechanic dashboard) at least once on the device that should receive notifications.");
            return;
        }
        try {
            // Professional title: e.g. "New request • 2.5 km away"
            String title = "New service request";
            if (distanceKm != null && distanceKm > 0) {
                String distStr = distanceKm >= 1 ? String.format("%.1f km away", distanceKm) : String.format("%.0f m away", distanceKm * 1000);
                title = "New request • " + distStr;
            }

            // Body: Customer • Service • Amount • Distance (no phone for privacy)
            StringBuilder body = new StringBuilder();
            body.append(customerName != null ? customerName : "Customer");
            body.append(" • ");
            body.append(serviceType != null && !serviceType.isBlank() ? serviceType : "General service");
            if (amount != null && amount > 0) {
                body.append(" • ₹").append(String.format("%.0f", amount));
            }
            if (distanceKm != null && distanceKm > 0) {
                String distStr = distanceKm >= 1 ? String.format("%.1f km away", distanceKm) : String.format("%.0f m away", distanceKm * 1000);
                body.append(" • ").append(distStr);
            }
            body.append(" • Tap Accept or Reject");

            Map<String, String> data = new HashMap<>();
            data.put("type", "mechanic_request");
            data.put("requestId", String.valueOf(requestId));
            data.put("title", title);
            data.put("body", body.toString());
            if (customerPhone != null && !customerPhone.isBlank()) {
                data.put("customerPhone", customerPhone);
            }
            if (amount != null && amount > 0) {
                data.put("amount", String.format("%.2f", amount));
            }
            if (distanceKm != null && distanceKm > 0) {
                data.put("distanceKm", String.format("%.1f", distanceKm));
            }
            if (description != null && !description.isBlank()) {
                data.put("description", description.length() > 100 ? description.substring(0, 97) + "..." : description);
            }

            // Notification + data: system shows when app killed; our service shows Accept/Reject when app runs.
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .setNotification(Notification.builder().setTitle(title).setBody(body.toString()).build())
                    .putAllData(data)
                    .setAndroidConfig(AndroidConfig.builder()
                            .setPriority(AndroidConfig.Priority.HIGH)
                            .setNotification(AndroidNotification.builder()
                                    .setChannelId("mechanic_requests")
                                    .setDefaultSound(true)
                                    .setDefaultVibrateTimings(true)
                                    .build())
                            .build())
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            System.out.println("✅ [FCM] SENT requestId=" + requestId + " -> " + response);
        } catch (FirebaseMessagingException e) {
            System.err.println("❌ [FCM] SEND FAILED requestId=" + requestId + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
}

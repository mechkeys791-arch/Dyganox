package com.example.demo.service;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
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
     * Send a mechanic request notification to the mechanic's device.
     * Data payload includes requestId so the app can show Accept/Reject and call API.
     */
    public void sendMechanicRequestNotification(String fcmToken, Long requestId, String customerName, String serviceType) {
        if (!initialized) {
            System.err.println("⚠️ [FCM] NOT INITIALIZED. Add firebase-service-account.json to backend/src/main/resources and redeploy EC2.");
            return;
        }
        if (fcmToken == null || fcmToken.isBlank()) {
            System.err.println("⚠️ [FCM] NO TOKEN for requestId=" + requestId + ". Mechanic must open the app (mechanic dashboard) at least once on the device that should receive notifications.");
            return;
        }
        try {
            String title = "New service request";
            String body = customerName + " requested " + (serviceType != null ? serviceType : "service") + ". Accept or reject?";
            Map<String, String> data = new HashMap<>();
            data.put("type", "mechanic_request");
            data.put("requestId", String.valueOf(requestId));
            data.put("title", title);
            data.put("body", body);

            // Data-only message so Flutter always shows our local notification with Accept/Reject buttons.
            // If we sent .setNotification() too, Android would show a system notification (no actions) when app is backgrounded.
            Message message = Message.builder()
                    .setToken(fcmToken)
                    .putAllData(data)
                    .build();

            String response = FirebaseMessaging.getInstance().send(message);
            System.out.println("✅ [FCM] SENT requestId=" + requestId + " -> " + response);
        } catch (FirebaseMessagingException e) {
            System.err.println("❌ [FCM] SEND FAILED requestId=" + requestId + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
}

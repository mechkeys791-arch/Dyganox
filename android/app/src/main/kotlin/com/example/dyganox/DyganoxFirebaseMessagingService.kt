package com.example.dyganox

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/**
 * Custom FCM handler: when a mechanic_request arrives (foreground, background, or app killed),
 * starts MechanicAlarmService to play 30-sec alarm and show Accept/Reject notification.
 */
class DyganoxFirebaseMessagingService : FirebaseMessagingService() {

    override fun onNewToken(@NonNull token: String) {
        super.onNewToken(token)
        try {
            val liveDataClass = Class.forName("io.flutter.plugins.firebase.messaging.FlutterFirebaseTokenLiveData")
            val getInstance = liveDataClass.getMethod("getInstance")
            val instance = getInstance.invoke(null)
            instance?.javaClass?.getMethod("postToken", String::class.java)?.invoke(instance, token)
        } catch (_: Exception) {
            // Flutter will get new token on next getToken() when app opens
        }
    }

    override fun onMessageReceived(@NonNull remoteMessage: RemoteMessage) {
        Log.d(TAG, "onMessageReceived: from=${remoteMessage.from} dataKeys=${remoteMessage.data?.keys}")
        val data = remoteMessage.data
        if (data == null || data.isEmpty()) {
            Log.w(TAG, "onMessageReceived: ignored - empty data (backend must send data-only message with type, requestId)")
            return
        }
        if (data["type"] != "mechanic_request") {
            Log.w(TAG, "onMessageReceived: ignored - type=${data["type"]} (expected mechanic_request)")
            return
        }
        val requestId = data["requestId"]
        if (requestId.isNullOrBlank()) {
            Log.w(TAG, "onMessageReceived: ignored - requestId missing")
            return
        }
        val customerName = data["customerName"] ?: "Customer"
        val distanceKm = data["distanceKm"] ?: ""
        val title = data["title"] ?: "New request"
        val body = if (distanceKm.isNotEmpty()) "$customerName • $distanceKm" else (data["body"] ?: "A customer requested your service.")
        Log.d(TAG, "onMessageReceived: showing notification requestId=$requestId (foreground/background)")

        // Always show notification first so user always sees something (even if service fails on Android 12+ background)
        try {
            showFallbackNotification(requestId, title, body)
            Log.d(TAG, "Notification shown for requestId=$requestId")
        } catch (e: Exception) {
            Log.e(TAG, "showFallbackNotification failed", e)
        }

        // Then start MechanicAlarmService for alarm sound (will update same notification via same ID when possible)
        val alarmIntent = Intent(this, MechanicAlarmService::class.java).apply {
            action = MechanicAlarmService.ACTION_START_ALARM
            putExtra(MechanicAlarmService.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicAlarmService.EXTRA_TITLE, title)
            putExtra(MechanicAlarmService.EXTRA_BODY, body)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(alarmIntent)
            } else {
                startService(alarmIntent)
            }
            Log.d(TAG, "MechanicAlarmService started for requestId=$requestId")
        } catch (e: Exception) {
            Log.w(TAG, "startForegroundService failed (notification already shown)", e)
        }
    }

    /** Notification with View only - shows customer name + distance. Tapping opens mechanic dashboard. */
    private fun showFallbackNotification(requestId: String, title: String, body: String) {
        val channelId = "mechanic_requests"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Mechanic requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "New mechanic service requests"
                enableVibration(true)
                setShowBadge(true)
                setSound(android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_NOTIFICATION), null)
                enableLights(true)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        // Content intent & View action: tapping opens app to mechanic dashboard (bookings + request detail)
        val contentIntent = PendingIntent.getActivity(
            this, requestId.hashCode(),
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("open_request_id", requestId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notificationId = NOTIFICATION_ID
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .addAction(android.R.drawable.ic_menu_info_details, "View", contentIntent)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(notificationId, notification)
    }

    companion object {
        private const val TAG = "DyganoxFCM"
        private const val NOTIFICATION_ID = 9001
    }
}

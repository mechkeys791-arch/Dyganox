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
        val data = remoteMessage.data ?: return
        if (data["type"] != "mechanic_request") return
        val requestId = data["requestId"] ?: return
        val title = data["title"] ?: "New request"
        val body = data["body"] ?: "A customer requested your service."
        Log.d(TAG, "onMessageReceived requestId=$requestId")

        // Single notification: start MechanicAlarmService (alarm sound + one notification with Accept/Reject)
        val intent = Intent(this, MechanicAlarmService::class.java).apply {
            action = MechanicAlarmService.ACTION_START_ALARM
            putExtra(MechanicAlarmService.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicAlarmService.EXTRA_TITLE, title)
            putExtra(MechanicAlarmService.EXTRA_BODY, body)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            // Only if service fails (e.g. Android 12+ background): show one fallback notification with Accept/Reject
            Log.w(TAG, "startForegroundService failed, showing fallback notification", e)
            showFallbackNotification(requestId, title, body)
        }
    }

    /** Only when foreground service cannot start: one notification with Accept/Reject. */
    private fun showFallbackNotification(requestId: String, title: String, body: String) {
        val channelId = "mechanic_requests"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Mechanic requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { enableVibration(true); setShowBadge(true) }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val acceptIntent = Intent(this, MechanicRequestActionReceiver::class.java).apply {
            putExtra(MechanicRequestActionReceiver.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicRequestActionReceiver.EXTRA_ACTION, MechanicRequestActionReceiver.ACTION_ACCEPT)
        }
        val rejectIntent = Intent(this, MechanicRequestActionReceiver::class.java).apply {
            putExtra(MechanicRequestActionReceiver.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicRequestActionReceiver.EXTRA_ACTION, MechanicRequestActionReceiver.ACTION_REJECT)
        }
        val acceptPending = PendingIntent.getBroadcast(
            this, requestId.hashCode(), acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val rejectPending = PendingIntent.getBroadcast(
            this, requestId.hashCode() + 1, rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Reject", rejectPending)
            .addAction(android.R.drawable.ic_menu_call, "Accept", acceptPending)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(requestId.hashCode() and 0x7FFFFFFF, notification)
    }

    companion object {
        private const val TAG = "DyganoxFCM"
    }
}

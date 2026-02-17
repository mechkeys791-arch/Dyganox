package com.example.dyganox

import android.content.Intent
import android.os.Build
import androidx.annotation.NonNull
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

        val intent = Intent(this, MechanicAlarmService::class.java).apply {
            action = MechanicAlarmService.ACTION_START_ALARM
            putExtra(MechanicAlarmService.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicAlarmService.EXTRA_TITLE, data["title"] ?: "New request")
            putExtra(MechanicAlarmService.EXTRA_BODY, data["body"] ?: "A customer requested your service.")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }
}

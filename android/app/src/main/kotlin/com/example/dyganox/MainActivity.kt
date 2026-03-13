package com.example.dyganox

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "dyganox/mechanic_alarm"
    private val ROUTE_OPEN_ACCEPT = "/open-accept/"
    private var methodChannel: MethodChannel? = null
    private var openRequestDetailRetryCount: Int = 0

    companion object {
        @Volatile
        var pendingLaunchRequestId: String? = null
    }

    override fun getInitialRoute(): String? {
        intent?.getStringExtra("open_request_id")?.let { return "$ROUTE_OPEN_ACCEPT$it" }
        applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
            .getString("pending_accept_request_id", null)?.let { return "$ROUTE_OPEN_ACCEPT$it" }
        return super.getInitialRoute()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createFcmNotificationChannelIfNeeded()
        // Only set from Intent so we only show "new request" when actually launched from View/Accept tap (not on every app open)
        captureLaunchRequestId(intent)
        // Cold start from Accept: notify Flutter so request detail opens (backup if splash first-frame missed it)
        pendingLaunchRequestId?.let { requestId ->
            Handler(Looper.getMainLooper()).postDelayed({
                notifyFlutterOpenRequestDetail(requestId)
            }, 800)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Only set from the new intent (user tapped another View/Accept). Do NOT re-read from prefs so we don't show old request when just resuming app.
        captureLaunchRequestId(intent)
        pendingLaunchRequestId?.let { requestId ->
            notifyFlutterOpenRequestDetail(requestId)
        }
    }

    private fun captureLaunchRequestId(intent: Intent?) {
        intent?.getStringExtra("open_request_id")?.let { id ->
            if (!id.isNullOrBlank()) pendingLaunchRequestId = id
        }
    }

    /** Read and consume request id (one-time use). Used when Flutter asks for launch id; after returning we clear so it's not shown again. */
    private fun consumeLaunchRequestIdFromPrefs(): String? {
        val prefs = applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
        val id = prefs.getString("pending_accept_request_id", null)
        if (!id.isNullOrBlank()) {
            prefs.edit().remove("pending_accept_request_id").apply()
            pendingLaunchRequestId = id
        }
        return pendingLaunchRequestId ?: id
    }

    private fun clearLaunchRequestIdFromPrefs() {
        applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
            .edit()
            .remove("pending_accept_request_id")
            .apply()
    }

    /** So FCM notification (when app is killed) uses this channel and plays sound. */
    private fun createFcmNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            "mechanic_requests",
            "Mechanic requests",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "New mechanic service requests"
            setShowBadge(true)
            enableLights(true)
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    /** Tell Flutter to open the request detail page (e.g. when user tapped Accept and app was in background). */
    private fun notifyFlutterOpenRequestDetail(requestId: String) {
        Handler(Looper.getMainLooper()).postDelayed({
            // Critical: configureFlutterEngine may not have run yet on slower devices.
            // If the channel isn't ready, retry briefly instead of dropping the navigation.
            val channel = methodChannel
            if (channel == null) {
                if (openRequestDetailRetryCount < 15) {
                    openRequestDetailRetryCount++
                    notifyFlutterOpenRequestDetail(requestId)
                }
                return@postDelayed
            }

            openRequestDetailRetryCount = 0
            val result = object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            }
            channel.invokeMethod("openRequestDetail", requestId, result)
        }, 200)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "startAlarm" -> {
                        startMechanicAlarmService()
                        result.success(null)
                    }
                    "stopAlarm" -> {
                        stopMechanicAlarmService()
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        openAppNotificationSettings()
                        result.success(null)
                    }
                    "openBatterySettings" -> {
                        openAppBatterySettings()
                        result.success(null)
                    }
                    "getLaunchRequestId" -> {
                        // Return prefs value if we don't already have one from intent (e.g. app was killed after receiver wrote prefs)
                        if (pendingLaunchRequestId == null) {
                            val prefs = applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
                            prefs.getString("pending_accept_request_id", null)?.let { id ->
                                if (id.isNotBlank()) pendingLaunchRequestId = id
                            }
                        }
                        val idToReturn = pendingLaunchRequestId
                        // Consume: clear so we don't return the same id on next app open
                        result.success(idToReturn)
                        if (idToReturn != null) {
                            pendingLaunchRequestId = null
                            clearLaunchRequestIdFromPrefs()
                        }
                    }
                    "clearLaunchRequestId" -> {
                        pendingLaunchRequestId = null
                        clearLaunchRequestIdFromPrefs()
                        result.success(null)
                    }
                    "saveMechanicId" -> {
                        val id = call.arguments
                        val prefs = applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
                        when (id) {
                            is Int -> prefs.edit().putString("mechanic_id", id.toString()).apply()
                            is String -> prefs.edit().putString("mechanic_id", id).apply()
                            is Number -> prefs.edit().putString("mechanic_id", id.toString()).apply()
                            else -> prefs.edit().remove("mechanic_id").apply()
                        }
                        result.success(null)
                    }
                    "getMechanicId" -> {
                        val prefs = applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
                        result.success(prefs.getString("mechanic_id", null))
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // If we were launched from notification Accept, guarantee the open request detail signal
        // is fired AFTER the channel is ready.
        pendingLaunchRequestId?.let { requestId ->
            Handler(Looper.getMainLooper()).post {
                notifyFlutterOpenRequestDetail(requestId)
            }
        }
    }

    private fun startMechanicAlarmService() {
        val intent = Intent(this, MechanicAlarmService::class.java).apply {
            action = MechanicAlarmService.ACTION_START_ALARM
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopMechanicAlarmService() {
        val intent = Intent(this, MechanicAlarmService::class.java).apply {
            action = MechanicAlarmService.ACTION_STOP_ALARM
        }
        startService(intent)
    }

    private fun openAppNotificationSettings() {
        val intent = Intent().apply {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> {
                    action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
                else -> {
                    action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
                    data = Uri.parse("package:$packageName")
                }
            }
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun openAppBatterySettings() {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}

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
        captureLaunchRequestId(intent)
        captureLaunchRequestIdFromPrefs()
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
        captureLaunchRequestId(intent)
        captureLaunchRequestIdFromPrefs()
        // Notify Flutter to open request detail (lifecycle may not fire when app brought from background)
        pendingLaunchRequestId?.let { requestId ->
            notifyFlutterOpenRequestDetail(requestId)
        }
    }

    private fun captureLaunchRequestId(intent: Intent?) {
        intent?.getStringExtra("open_request_id")?.let { id ->
            pendingLaunchRequestId = id
        }
    }

    /** Read request id saved by MechanicRequestActionReceiver when user tapped Accept (survives even if Intent is lost). */
    private fun captureLaunchRequestIdFromPrefs() {
        if (pendingLaunchRequestId != null) return
        val prefs = applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
        prefs.getString("pending_accept_request_id", null)?.let { id ->
            pendingLaunchRequestId = id
        }
    }

    private fun consumeLaunchRequestIdFromPrefs(): String? {
        val prefs = applicationContext.getSharedPreferences("dyganox_launch", MODE_PRIVATE)
        return prefs.getString("pending_accept_request_id", null)
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
                        // Return id without clearing (so splash can read multiple times). Clear via clearLaunchRequestId.
                        consumeLaunchRequestIdFromPrefs()?.let { id ->
                            pendingLaunchRequestId = id
                        }
                        if (pendingLaunchRequestId == null) {
                            intent?.getStringExtra("open_request_id")?.let { id ->
                                pendingLaunchRequestId = id
                            }
                        }
                        result.success(pendingLaunchRequestId)
                    }
                    "clearLaunchRequestId" -> {
                        pendingLaunchRequestId = null
                        clearLaunchRequestIdFromPrefs()
                        result.success(null)
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

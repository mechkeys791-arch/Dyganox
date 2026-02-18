package com.example.dyganox

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "dyganox/mechanic_alarm"

    companion object {
        @Volatile
        var pendingLaunchRequestId: String? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createFcmNotificationChannelIfNeeded()
        captureLaunchRequestId(intent)
        captureLaunchRequestIdFromPrefs()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchRequestId(intent)
        captureLaunchRequestIdFromPrefs()
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                    // Always prefer prefs first (receiver writes with commit() before startActivity)
                    consumeLaunchRequestIdFromPrefs()?.let { id ->
                        pendingLaunchRequestId = id
                    }
                    if (pendingLaunchRequestId == null) {
                        intent?.getStringExtra("open_request_id")?.let { id ->
                            pendingLaunchRequestId = id
                        }
                    }
                    val id = pendingLaunchRequestId
                    pendingLaunchRequestId = null
                    if (id != null) clearLaunchRequestIdFromPrefs()
                    result.success(id)
                }
                else -> result.notImplemented()
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

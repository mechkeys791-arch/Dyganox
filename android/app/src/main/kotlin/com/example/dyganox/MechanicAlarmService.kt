package com.example.dyganox

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Plays alarm sound in a loop for 30 seconds when a mechanic request arrives.
 * Started from DyganoxFirebaseMessagingService (FCM) or MainActivity. Shows notification
 * with Accept/Reject actions. Works in background and when phone is off (screen locked).
 */
class MechanicAlarmService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var toneGenerator: ToneGenerator? = null
    private val handler = Handler(Looper.getMainLooper())
    private var beepRunnable: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_ALARM -> {
                stopAlarm()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START_ALARM -> {
                startForegroundAndPlayAlarm(intent)
                return START_NOT_STICKY
            }
        }
        return START_NOT_STICKY
    }

    private fun startForegroundAndPlayAlarm(intent: Intent) {
        val requestId = intent.getStringExtra(EXTRA_REQUEST_ID) ?: ""
        val title = intent.getStringExtra(EXTRA_TITLE) ?: "New request"
        val body = intent.getStringExtra(EXTRA_BODY) ?: "A customer requested your service."

        val channelId = "mechanic_alarm_service"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Mechanic request alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { setSound(null, null); enableVibration(true) }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        // Content intent: tapping notification body opens app to request detail (same as Accept)
        val contentIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                putExtra("open_request_id", requestId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notifBuilder = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
        if (requestId.isNotEmpty()) {
            notifBuilder.addAction(android.R.drawable.ic_menu_info_details, "View", contentIntent)
        }
        val notification = notifBuilder.build()
        try {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "Foreground notification shown requestId=$requestId")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            // Still post notification to tray so user sees it even if foreground fails
            getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, notification)
        }

        stopAlarm()
        try {
            val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

            if (alarmUri != null) {
                mediaPlayer = MediaPlayer().apply {
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                    )
                    setDataSource(applicationContext, alarmUri)
                    isLooping = true
                    prepare()
                    start()
                }
            } else {
                // Fallback: beep in a loop when device has no alarm URI (e.g. some emulators)
                startBeepLoop()
            }

            handler.postDelayed({
                stopAlarm()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }, 30_000)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to play alarm, trying beep fallback", e)
            startBeepLoop()
            handler.postDelayed({
                stopAlarm()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }, 30_000)
        }
    }

    private fun startBeepLoop() {
        try {
            toneGenerator = ToneGenerator(ToneGenerator.TONE_PROP_BEEP, 100)
            beepRunnable = object : Runnable {
                override fun run() {
                    try {
                        toneGenerator?.startTone(ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, 400)
                        handler.postDelayed(this, 500)
                    } catch (_: Exception) {}
                }
            }
            handler.post(beepRunnable!!)
        } catch (e: Exception) {
            Log.e(TAG, "Beep fallback failed", e)
        }
    }

    private fun stopAlarm() {
        beepRunnable?.let { handler.removeCallbacks(it) }
        beepRunnable = null
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
        } catch (_: Exception) {}
        mediaPlayer = null
        try {
            toneGenerator?.release()
        } catch (_: Exception) {}
        toneGenerator = null
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "MechanicAlarmService"
        private const val NOTIFICATION_ID = 9001
        const val ACTION_START_ALARM = "com.example.dyganox.START_ALARM"
        const val ACTION_STOP_ALARM = "com.example.dyganox.STOP_ALARM"
        const val EXTRA_REQUEST_ID = "requestId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }
}

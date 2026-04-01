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

        val channelId = "mechanic_requests"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Mechanic requests",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "New mechanic service requests"
                enableVibration(true)
                setShowBadge(true)
                setSound(android.media.RingtoneManager.getDefaultUri(android.media.RingtoneManager.TYPE_RINGTONE),
                    android.media.AudioAttributes.Builder().setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE).build())
                enableLights(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    setBypassDnd(true)
                }
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }

        val viewIntent = Intent(this, MechanicRequestActionReceiver::class.java).apply {
            putExtra(MechanicRequestActionReceiver.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicRequestActionReceiver.EXTRA_ACTION, MechanicRequestActionReceiver.ACTION_VIEW)
        }
        val acceptIntent = Intent(this, MechanicRequestActionReceiver::class.java).apply {
            putExtra(MechanicRequestActionReceiver.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicRequestActionReceiver.EXTRA_ACTION, MechanicRequestActionReceiver.ACTION_ACCEPT)
        }
        val rejectIntent = Intent(this, MechanicRequestActionReceiver::class.java).apply {
            putExtra(MechanicRequestActionReceiver.EXTRA_REQUEST_ID, requestId)
            putExtra(MechanicRequestActionReceiver.EXTRA_ACTION, MechanicRequestActionReceiver.ACTION_REJECT)
        }
        val viewPending = PendingIntent.getBroadcast(
            this, requestId.hashCode(), viewIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val acceptPending = PendingIntent.getBroadcast(
            this, requestId.hashCode() + 1, acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val rejectPending = PendingIntent.getBroadcast(
            this, requestId.hashCode() + 2, rejectIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notificationId = if (requestId.isNotEmpty()) (requestId.hashCode() and 0x7FFFFFFF).coerceAtLeast(9001) else NOTIFICATION_ID
        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(viewPending)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .addAction(android.R.drawable.ic_menu_info_details, "View", viewPending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Reject", rejectPending)
            .addAction(android.R.drawable.ic_menu_call, "Accept", acceptPending)
            .setOngoing(true)
            .setSilent(false)
            .setAutoCancel(true)
            .build()
        try {
            startForeground(notificationId, notification)
            Log.d(TAG, "Foreground notification shown requestId=$requestId (single with Accept/Reject)")
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            getSystemService(NotificationManager::class.java).notify(notificationId, notification)
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
        const val ACTION_START_ALARM = "com.dyganox.app.START_ALARM"
        const val ACTION_STOP_ALARM = "com.dyganox.app.STOP_ALARM"
        const val EXTRA_REQUEST_ID = "requestId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
    }
}

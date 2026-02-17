package com.example.dyganox

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL

/**
 * Handles Accept/Reject actions from the mechanic request notification.
 * Calls the backend API and stops the alarm service.
 */
class MechanicRequestActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val requestId = intent.getStringExtra(EXTRA_REQUEST_ID) ?: return
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return

        // Stop the alarm service when user taps Accept or Reject
        val stopIntent = Intent(context, MechanicAlarmService::class.java).apply {
            this.action = MechanicAlarmService.ACTION_STOP_ALARM
        }
        context.startService(stopIntent)

        Thread {
            try {
                val path = "${ApiConstants.MECHANIC_REQUESTS_PATH}/$requestId/$action"
                val url = URL(ApiConstants.BASE_URL + path)
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "PUT"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.connectTimeout = 10_000
                conn.readTimeout = 10_000
                val code = conn.responseCode
                Log.d(TAG, "API $action requestId=$requestId -> $code")
            } catch (e: Exception) {
                Log.e(TAG, "API $action failed requestId=$requestId", e)
            }
        }.start()
    }

    companion object {
        private const val TAG = "MechanicRequestAction"
        const val EXTRA_REQUEST_ID = "requestId"
        const val EXTRA_ACTION = "action"
        const val ACTION_ACCEPT = "accept"
        const val ACTION_REJECT = "reject"
    }
}

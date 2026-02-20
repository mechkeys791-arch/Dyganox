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
                if (action == ACTION_ACCEPT && code in 200..299) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        openAppToRequestDetail(context, requestId)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "API $action failed requestId=$requestId", e)
            }
        }.start()
    }

    private fun openAppToRequestDetail(context: Context, requestId: String) {
        // Persist request id so Flutter can read it (sync so activity sees it when it starts)
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING_ACCEPT_REQUEST_ID, requestId)
            .commit()
        // Explicit MainActivity intent with extra as well
        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("open_request_id", requestId)
        }
        context.startActivity(launch)
    }

    companion object {
        private const val TAG = "MechanicRequestAction"
        const val EXTRA_REQUEST_ID = "requestId"
        const val EXTRA_ACTION = "action"
        const val ACTION_ACCEPT = "accept"
        const val ACTION_REJECT = "reject"
        private const val PREFS_NAME = "dyganox_launch"
        private const val KEY_PENDING_ACCEPT_REQUEST_ID = "pending_accept_request_id"
    }
}

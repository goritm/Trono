package com.trono.trono

import android.app.Notification
import android.app.NotificationManager
import android.app.RemoteInput
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/// Handles inline quick replies (`RemoteInput`) directly from friend comment
/// notifications without opening the app.
class TronoReplyReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_QUICK_REPLY = "com.trono.trono.ACTION_QUICK_REPLY"
        const val KEY_REPLY_TEXT = "key_reply_text"
        const val EXTRA_LOG_ID = "extra_log_id"
        const val EXTRA_NOTIFICATION_ID = "extra_notification_id"
        private const val TRONO_TERRACOTTA = 0xFFE05A2B.toInt()
        private val networkExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_QUICK_REPLY) return
        val remoteInput = RemoteInput.getResultsFromIntent(intent) ?: return
        val replyText = remoteInput.getCharSequence(KEY_REPLY_TEXT)?.toString()?.trim().orEmpty()
        val logId = intent.getStringExtra(EXTRA_LOG_ID)?.trim().orEmpty()
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)
        if (replyText.isEmpty() || logId.isEmpty()) return

        val clamped = if (replyText.length > 280) replyText.substring(0, 280) else replyText
        val es = TronoNotificationChannels.isSpanish(context)

        // Immediately clear Android's inline reply spinner by updating the notification
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (manager != null && notificationId != 0) {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, TronoNotificationChannels.CHANNEL_FRIEND_COMMENTS)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            val confirmed = builder
                .setSmallIcon(R.drawable.ic_stat_trono)
                .setColor(TRONO_TERRACOTTA)
                .setContentTitle(if (es) "✓ Respuesta enviada" else "✓ Reply sent")
                .setContentText(clamped)
                .setAutoCancel(true)
                .build()
            manager.notify(notificationId, confirmed)
        }

        // Fast path: if Flutter is alive in memory, delegate to SocialController
        if (MainActivity.notifyQuickReply(logId, clamped)) {
            return
        }

        // Background fallback: post directly to Supabase REST with the cached user JWT
        val auth = TronoNotificationChannels.readAuthContext(context) ?: return
        val pendingResult = goAsync()
        networkExecutor.execute {
            try {
                val endpoint = "${auth.supabaseUrl.trimEnd('/')}/rest/v1/log_comments"
                val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    connectTimeout = 8000
                    readTimeout = 8000
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("apikey", auth.apiKey)
                    setRequestProperty("Authorization", "Bearer ${auth.accessToken}")
                    setRequestProperty("Prefer", "return=minimal")
                }
                val body = JSONObject().apply {
                    put("log_id", logId)
                    put("user_id", auth.userId)
                    put("body", clamped)
                }
                OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                    writer.write(body.toString())
                    writer.flush()
                }
                conn.responseCode
                conn.disconnect()
            } catch (_: Exception) {
            } finally {
                pendingResult.finish()
            }
        }
    }
}

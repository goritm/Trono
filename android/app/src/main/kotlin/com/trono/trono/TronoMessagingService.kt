package com.trono.trono

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.RemoteInput
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class TronoMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TRONO_TERRACOTTA = 0xFFE05A2B.toInt()
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        TronoNotificationChannels.saveFcmToken(applicationContext, token)
        MainActivity.notifyFcmToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)
        val data = message.data
        val event = data["event"]?.trim().orEmpty()
        if (event.isEmpty()) return

        val channelId = when (event) {
            "friend_throne" -> TronoNotificationChannels.CHANNEL_FRIEND_THRONES
            "friend_comment" -> TronoNotificationChannels.CHANNEL_FRIEND_COMMENTS
            "friend_reaction" -> TronoNotificationChannels.CHANNEL_FRIEND_REACTIONS
            else -> return
        }

        TronoNotificationChannels.ensureAll(applicationContext)

        if (!TronoNotificationChannels.isChannelEnabledLocally(applicationContext, channelId)) {
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        val manager =
            getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

        val es = TronoNotificationChannels.isSpanish(applicationContext)
        val actorName = data["actor_name"]?.trim().takeUnless { it.isNullOrEmpty() } ?: "Trono"
        val actorEmoji = data["actor_emoji"]?.trim().takeUnless { it.isNullOrEmpty() } ?: "👑"
        val locationKind = data["location_kind"]?.trim().orEmpty()
        val commentBody = data["comment_body"]?.trim().orEmpty()
        val reactionEmoji = data["reaction_emoji"]?.trim().takeUnless { it.isNullOrEmpty() } ?: "👑"
        val logId = data["log_id"]?.trim().orEmpty()

        val (title, body) = when (event) {
            "friend_throne" -> {
                val t = if (es) {
                    "$actorEmoji $actorName fue al trono"
                } else {
                    "$actorEmoji $actorName claimed a throne"
                }
                val b = when (locationKind) {
                    "work" -> if (es) "En el trabajo 💰" else "At work 💰"
                    "away" -> if (es) "Fuera de casa 🗺️" else "Away from home 🗺️"
                    "home" -> if (es) "En casa 🏠" else "At home 🏠"
                    else -> if (es) "Acaba de registrar un trono 👑" else "Just claimed a throne 👑"
                }
                t to b
            }
            "friend_comment" -> {
                val t = if (es) "💬 $actorName comentó" else "💬 $actorName commented"
                val b = commentBody.ifEmpty {
                    if (es) "Nuevo mensaje en el feed" else "New message on the feed"
                }
                t to b
            }
            "friend_reaction" -> {
                val t = if (es) {
                    "$reactionEmoji $actorName reaccionó"
                } else {
                    "$reactionEmoji $actorName reacted"
                }
                val b = if (es) {
                    "Reaccionó $reactionEmoji a tu trono"
                } else {
                    "Reacted $reactionEmoji to your throne"
                }
                t to b
            }
            else -> return
        }

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_OPEN_TAB, "social")
        }
        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val notificationId = 3000 + ((logId + event).hashCode() and 0x7FFF)
        val contentIntent = PendingIntent.getActivity(
            this,
            notificationId,
            launchIntent,
            pendingFlags
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_trono)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setColor(TRONO_TERRACOTTA)
            .setCategory(
                if (event == "friend_comment") {
                    Notification.CATEGORY_MESSAGE
                } else {
                    Notification.CATEGORY_SOCIAL
                }
            )
            .setAutoCancel(true)
            .setContentIntent(contentIntent)

        // Add inline WhatsApp-style quick reply on friend comments (Android 7+)
        if (event == "friend_comment" &&
            logId.isNotEmpty() &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
        ) {
            val replyLabel = if (es) "Responder" else "Reply"
            val remoteInput = RemoteInput.Builder(TronoReplyReceiver.KEY_REPLY_TEXT)
                .setLabel(replyLabel)
                .build()
            val replyIntent = Intent(this, TronoReplyReceiver::class.java).apply {
                action = TronoReplyReceiver.ACTION_QUICK_REPLY
                putExtra(TronoReplyReceiver.EXTRA_LOG_ID, logId)
                putExtra(TronoReplyReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            }
            val replyFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            val replyPending = PendingIntent.getBroadcast(
                this,
                notificationId + 10000,
                replyIntent,
                replyFlags
            )
            val replyAction = Notification.Action.Builder(
                Icon.createWithResource(this, android.R.drawable.ic_menu_send),
                replyLabel,
                replyPending
            )
                .addRemoteInput(remoteInput)
                .build()
            builder.addAction(replyAction)
        }

        manager.notify(notificationId, builder.build())
    }
}

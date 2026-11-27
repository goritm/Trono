package com.trono.trono

import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.util.Locale

object TronoNotificationChannels {
    const val GROUP_SOCIAL = "trono_social_group"
    const val GROUP_PERSONAL = "trono_personal_group"

    const val CHANNEL_FRIEND_THRONES = "trono_friend_thrones"
    const val CHANNEL_FRIEND_COMMENTS = "trono_friend_comments"
    const val CHANNEL_FRIEND_REACTIONS = "trono_friend_reactions"
    const val CHANNEL_REMINDERS = TronoReminderReceiver.CHANNEL_ID
    const val CHANNEL_LIVE_TIMER = TronoLiveTimerNotification.CHANNEL_ID

    private const val PREFS_NAME = "trono_push_prefs"
    private const val KEY_LOCALE = "locale"
    private const val KEY_NOTIFY_THRONES = "notify_friend_thrones"
    private const val KEY_NOTIFY_COMMENTS = "notify_friend_comments"
    private const val KEY_NOTIFY_REACTIONS = "notify_friend_reactions"
    private const val KEY_FCM_TOKEN = "fcm_token"

    fun savePreferences(
        context: Context,
        locale: String? = null,
        notifyThrones: Boolean? = null,
        notifyComments: Boolean? = null,
        notifyReactions: Boolean? = null
    ) {
        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        if (!locale.isNullOrBlank()) {
            editor.putString(KEY_LOCALE, locale.lowercase(Locale.ROOT))
        }
        if (notifyThrones != null) editor.putBoolean(KEY_NOTIFY_THRONES, notifyThrones)
        if (notifyComments != null) editor.putBoolean(KEY_NOTIFY_COMMENTS, notifyComments)
        if (notifyReactions != null) editor.putBoolean(KEY_NOTIFY_REACTIONS, notifyReactions)
        editor.apply()
    }

    fun saveFcmToken(context: Context, token: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_FCM_TOKEN, token)
            .apply()
    }

    fun readSavedFcmToken(context: Context): String? {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_FCM_TOKEN, null)
            ?.takeIf { it.isNotBlank() }
    }

    fun isSpanish(context: Context, localeOverride: String? = null): Boolean {
        val raw = localeOverride
            ?: context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                .getString(KEY_LOCALE, null)
            ?: Locale.getDefault().language
        return raw.lowercase(Locale.ROOT).startsWith("es")
    }

    fun isChannelEnabledLocally(context: Context, channelId: String): Boolean {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return when (channelId) {
            CHANNEL_FRIEND_THRONES -> prefs.getBoolean(KEY_NOTIFY_THRONES, true)
            CHANNEL_FRIEND_COMMENTS -> prefs.getBoolean(KEY_NOTIFY_COMMENTS, true)
            CHANNEL_FRIEND_REACTIONS -> prefs.getBoolean(KEY_NOTIFY_REACTIONS, true)
            else -> true
        }
    }

    /// Registers all 5 Trono NotificationChannels inside 2 clean channel groups
    /// so every category appears individually in Android system notification settings.
    fun ensureAll(context: Context, localeOverride: String? = null) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return

        val es = isSpanish(context, localeOverride)

        manager.createNotificationChannelGroups(
            listOf(
                NotificationChannelGroup(
                    GROUP_SOCIAL,
                    if (es) "Amigos y grupos" else "Friends & groups"
                ),
                NotificationChannelGroup(
                    GROUP_PERSONAL,
                    if (es) "Personal y cronómetro" else "Personal & timer"
                )
            )
        )

        val friendThrones = NotificationChannel(
            CHANNEL_FRIEND_THRONES,
            if (es) "Tronos de amigos" else "Friend thrones",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            group = GROUP_SOCIAL
            description = if (es) {
                "Avisos cuando un amigo de tu grupo va al trono"
            } else {
                "Alerts when a friend in your group claims a throne"
            }
        }

        val friendComments = NotificationChannel(
            CHANNEL_FRIEND_COMMENTS,
            if (es) "Mensajes y comentarios" else "Messages & comments",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            group = GROUP_SOCIAL
            description = if (es) {
                "Avisos cuando te llegan comentarios o mensajes en el feed"
            } else {
                "Alerts when new messages or comments arrive on your feed"
            }
        }

        val friendReactions = NotificationChannel(
            CHANNEL_FRIEND_REACTIONS,
            if (es) "Reacciones" else "Reactions",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            group = GROUP_SOCIAL
            description = if (es) {
                "Avisos cuando tus amigos reaccionan a tus tronos (👑🔥💀👏)"
            } else {
                "Alerts when friends react to your thrones (👑🔥💀👏)"
            }
        }

        val reminders = NotificationChannel(
            CHANNEL_REMINDERS,
            if (es) "Recordatorios" else "Reminders",
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            group = GROUP_PERSONAL
            description = if (es) {
                "Recordatorio de racha y resumen semanal local"
            } else {
                "Local streak guard and weekly recap reminders"
            }
        }

        val liveTimer = NotificationChannel(
            CHANNEL_LIVE_TIMER,
            if (es) "Cronómetro de Trono" else "Live Throne Timer",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            group = GROUP_PERSONAL
            description = if (es) {
                "Cronómetro en vivo en la barra de estado"
            } else {
                "Ongoing status-bar chronometer while a throne timer is active"
            }
            setShowBadge(false)
            setSound(null, null)
            enableVibration(false)
        }

        manager.createNotificationChannels(
            listOf(
                friendThrones,
                friendComments,
                friendReactions,
                reminders,
                liveTimer
            )
        )
    }

    fun openSystemSettings(context: Context, channelId: String? = null): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (!channelId.isNullOrBlank()) {
                    Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                        putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                    }
                } else {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    }
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", context.packageName, null)
                }
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }
}

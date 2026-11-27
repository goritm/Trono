package com.trono.trono

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationChannelGroup
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.util.Locale

object TronoNotificationChannels {
    data class AuthContext(
        val supabaseUrl: String,
        val apiKey: String,
        val accessToken: String,
        val userId: String
    )

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
    private const val KEY_AUTH_URL = "auth_supabase_url"
    private const val KEY_AUTH_KEY = "auth_api_key"
    private const val KEY_AUTH_TOKEN = "auth_access_token"
    private const val KEY_AUTH_UID = "auth_user_id"
    private const val TEST_NOTIF_ID = 2810
    private const val TRONO_TERRACOTTA = 0xFFE05A2B.toInt()

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

    fun saveAuthContext(
        context: Context,
        supabaseUrl: String,
        apiKey: String,
        accessToken: String,
        userId: String
    ) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_AUTH_URL, supabaseUrl.trim())
            .putString(KEY_AUTH_KEY, apiKey.trim())
            .putString(KEY_AUTH_TOKEN, accessToken.trim())
            .putString(KEY_AUTH_UID, userId.trim())
            .apply()
    }

    fun clearAuthContext(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .remove(KEY_AUTH_TOKEN)
            .remove(KEY_AUTH_UID)
            .apply()
    }

    fun readAuthContext(context: Context): AuthContext? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val url = prefs.getString(KEY_AUTH_URL, null)?.trim().orEmpty()
        val key = prefs.getString(KEY_AUTH_KEY, null)?.trim().orEmpty()
        val token = prefs.getString(KEY_AUTH_TOKEN, null)?.trim().orEmpty()
        val uid = prefs.getString(KEY_AUTH_UID, null)?.trim().orEmpty()
        if (url.isEmpty() || key.isEmpty() || token.isEmpty() || uid.isEmpty()) {
            return null
        }
        return AuthContext(url, key, token, uid)
    }

    fun sendTestNotification(context: Context, localeOverride: String? = null): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = context.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }
        ensureAll(context, localeOverride)
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false

        val es = isSpanish(context, localeOverride)
        val title = if (es) "👑 ¡Notificaciones listas!" else "👑 Notifications ready!"
        val body = if (es) {
            "Así se verán los avisos de tus amigos en Trono."
        } else {
            "This is how friend alerts from Trono will look."
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(MainActivity.EXTRA_OPEN_TAB, "social")
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val contentIntent = PendingIntent.getActivity(context, TEST_NOTIF_ID, launchIntent, flags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_FRIEND_COMMENTS)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_trono)
            .setColor(TRONO_TERRACOTTA)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        manager.notify(TEST_NOTIF_ID, notification)
        return true
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

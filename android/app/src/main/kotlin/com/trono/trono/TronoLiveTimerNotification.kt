package com.trono.trono

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Locale

object TronoLiveTimerNotification {
    const val NOTIFICATION_ID = 2601
    const val CHANNEL_ID = "trono_live_timer"
    private const val TIMER_START_MS_KEY = "timer_start_ms"
    private const val PREF_LOCALE_KEY = "live_timer_locale"

    private const val REQ_FINISH = 2602
    private const val REQ_CANCEL = 2603
    private const val REQ_CONTENT = 2604
    private const val TRONO_TERRACOTTA = 0xFFE05A2B.toInt()

    fun hasPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return context.checkSelfPermission(
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun persistStartAndLocale(context: Context, startMillis: Long, locale: String?) {
        val prefs = HomeWidgetPlugin.getData(context)
        val editor = prefs.edit().putLong(TIMER_START_MS_KEY, startMillis)
        if (!locale.isNullOrBlank()) {
            editor.putString(PREF_LOCALE_KEY, locale.lowercase(Locale.ROOT))
        }
        editor.apply()
    }

    fun show(
        context: Context,
        startMillis: Long,
        title: String? = null,
        body: String? = null,
        saveLabel: String? = null,
        cancelLabel: String? = null,
        locale: String? = null
    ): Boolean {
        if (startMillis <= 0L) {
            dismiss(context)
            return false
        }

        // Belt-and-suspenders: keep timer_start_ms in HomeWidget prefs so
        // ACTION_FINISH_TIMER computes exact duration even when 0 widgets are placed.
        persistStartAndLocale(context, startMillis, locale)

        if (!hasPermission(context)) return false

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
                ?: return false

        val savedLocale = locale
            ?: HomeWidgetPlugin.getData(context).getString(PREF_LOCALE_KEY, null)
        val isEs = (savedLocale ?: Locale.getDefault().language)
            .lowercase(Locale.ROOT)
            .startsWith("es")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                if (isEs) "Cronómetro de Trono" else "Live Throne Timer",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = if (isEs) {
                    "Cronómetro en vivo en la barra de estado mientras la sesión está activa"
                } else {
                    "Ongoing status-bar chronometer while a throne timer is active"
                }
                setShowBadge(false)
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }

        val resolvedTitle = title?.takeIf { it.isNotBlank() }
            ?: if (isEs) "👑 Cronómetro en marcha" else "👑 Throne timer active"
        val resolvedBody = body?.takeIf { it.isNotBlank() }
            ?: if (isEs) "Pulsa ✓ Guardar al terminar" else "Tap ✓ Save when you finish"
        val resolvedSave = saveLabel?.takeIf { it.isNotBlank() }
            ?: if (isEs) "✓ Guardar" else "✓ Save"
        val resolvedCancel = cancelLabel?.takeIf { it.isNotBlank() }
            ?: if (isEs) "✕ Cancelar" else "✕ Cancel"

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            REQ_CONTENT,
            launchIntent,
            pendingFlags
        )

        val finishPending = PendingIntent.getBroadcast(
            context,
            REQ_FINISH,
            Intent(context, TronoWidgetProvider::class.java).apply {
                action = TronoWidgetProvider.ACTION_FINISH_TIMER
            },
            pendingFlags
        )

        val cancelPending = PendingIntent.getBroadcast(
            context,
            REQ_CANCEL,
            Intent(context, TronoWidgetProvider::class.java).apply {
                action = TronoWidgetProvider.ACTION_CANCEL_TIMER
            },
            pendingFlags
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        builder
            .setSmallIcon(R.drawable.ic_stat_trono)
            .setContentTitle(resolvedTitle)
            .setContentText(resolvedBody)
            .setWhen(startMillis)
            .setShowWhen(true)
            .setUsesChronometer(true)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_STOPWATCH)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(TRONO_TERRACOTTA)
            .setContentIntent(contentIntent)
            .addAction(
                buildAction(
                    context,
                    android.R.drawable.ic_menu_save,
                    resolvedSave,
                    finishPending
                )
            )
            .addAction(
                buildAction(
                    context,
                    android.R.drawable.ic_menu_close_clear_cancel,
                    resolvedCancel,
                    cancelPending
                )
            )

        manager.notify(NOTIFICATION_ID, builder.build())
        return true
    }

    fun dismiss(context: Context) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        manager?.cancel(NOTIFICATION_ID)
    }

    private fun buildAction(
        context: Context,
        iconRes: Int,
        label: String,
        pendingIntent: PendingIntent
    ): Notification.Action {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Notification.Action.Builder(
                Icon.createWithResource(context, iconRes),
                label,
                pendingIntent
            ).build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Action.Builder(iconRes, label, pendingIntent).build()
        }
    }
}

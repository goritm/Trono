package com.trono.trono

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundWorker
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import io.flutter.FlutterInjector

class TronoWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_QUICK_LOG_POOP = "com.trono.trono.ACTION_QUICK_LOG_POOP"
        const val ACTION_START_TIMER = "com.trono.trono.ACTION_START_TIMER"
        const val ACTION_FINISH_TIMER = "com.trono.trono.ACTION_FINISH_TIMER"
        const val ACTION_CANCEL_TIMER = "com.trono.trono.ACTION_CANCEL_TIMER"

        private const val TIMER_START_MS_KEY = "timer_start_ms"
        private const val FLASH_UNTIL_KEY = "widget_flash_until"
        private const val FLASH_DURATION_MS = 1400L
        private const val MAX_DURATION_SECONDS = 14400L
        private const val STALE_TIMER_MS = 12L * 60L * 60L * 1000L

        private const val CHILD_IDLE = 0
        private const val CHILD_SUCCESS = 1
        private const val CHILD_TIMER = 2

        private val mainHandler = Handler(Looper.getMainLooper())
        private var pendingResetRunnable: Runnable? = null
    }

    private fun broadcastPendingIntent(
        context: Context,
        actionName: String,
        requestCode: Int
    ): PendingIntent {
        val intent = Intent(context, TronoWidgetProvider::class.java).apply {
            action = actionName
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    private fun launchAppPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(context, 100, intent, flags)
    }

    private fun bindClickIntents(context: Context, views: RemoteViews) {
        views.setOnClickPendingIntent(R.id.widget_header, launchAppPendingIntent(context))
        views.setOnClickPendingIntent(
            R.id.btn_log_poop,
            broadcastPendingIntent(context, ACTION_QUICK_LOG_POOP, 201)
        )
        views.setOnClickPendingIntent(
            R.id.btn_start_timer,
            broadcastPendingIntent(context, ACTION_START_TIMER, 202)
        )
        views.setOnClickPendingIntent(
            R.id.btn_finish_timer,
            broadcastPendingIntent(context, ACTION_FINISH_TIMER, 203)
        )
        views.setOnClickPendingIntent(
            R.id.btn_cancel_timer,
            broadcastPendingIntent(context, ACTION_CANCEL_TIMER, 204)
        )
    }

    private fun enqueueBackgroundLog(context: Context, uriString: String) {
        try {
            val flutterLoader = FlutterInjector.instance().flutterLoader()
            flutterLoader.startInitialization(context)
            flutterLoader.ensureInitializationComplete(context, null)
            val bgIntent = Intent().apply {
                data = Uri.parse(uriString)
            }
            HomeWidgetBackgroundWorker.enqueueWork(context, bgIntent)
        } catch (_: Exception) {
        }
    }

    private fun scheduleFlashReset(context: Context) {
        pendingResetRunnable?.let { mainHandler.removeCallbacks(it) }
        val appCtx = context.applicationContext
        val reset = Runnable {
            val prefs = HomeWidgetPlugin.getData(appCtx)
            prefs.edit().remove(FLASH_UNTIL_KEY).apply()
            val mgr = AppWidgetManager.getInstance(appCtx)
            val widgetIds = mgr.getAppWidgetIds(
                ComponentName(appCtx, TronoWidgetProvider::class.java)
            )
            if (widgetIds.isNotEmpty()) {
                val timerStartMs = readActiveTimerStartMs(prefs)
                val targetChild = if (timerStartMs > 0L) CHILD_TIMER else CHILD_IDLE
                val backPartial = RemoteViews(appCtx.packageName, R.layout.trono_widget).apply {
                    setTextViewText(
                        R.id.widget_today_count,
                        prefs.getInt("today_poop", 0).toString()
                    )
                    setTextViewText(
                        R.id.widget_avg_text,
                        "${prefs.getString("avg_daily", "0.0") ?: "0.0"}/d"
                    )
                    setDisplayedChild(R.id.widget_button_flipper, targetChild)
                }
                mgr.partiallyUpdateAppWidget(widgetIds, backPartial)
            }
        }
        pendingResetRunnable = reset
        mainHandler.postDelayed(reset, FLASH_DURATION_MS)
    }

    private fun readActiveTimerStartMs(prefs: SharedPreferences): Long {
        val startMs = try {
            prefs.getLong(TIMER_START_MS_KEY, 0L)
        } catch (_: ClassCastException) {
            prefs.getInt(TIMER_START_MS_KEY, 0).toLong()
        }
        if (startMs <= 0L) return 0L
        val ageMs = System.currentTimeMillis() - startMs
        if (ageMs < -60_000L || ageMs > STALE_TIMER_MS) return 0L
        return startMs
    }

    private fun getWidgetIds(context: Context): Pair<AppWidgetManager, IntArray> {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, TronoWidgetProvider::class.java)
        )
        return manager to ids
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_QUICK_LOG_POOP -> {
                handleLogAndFlash(context, durationSeconds = null)
                return
            }
            ACTION_START_TIMER -> {
                val nowMs = System.currentTimeMillis()
                val prefs = HomeWidgetPlugin.getData(context)
                prefs.edit()
                    .putLong(TIMER_START_MS_KEY, nowMs)
                    .remove(FLASH_UNTIL_KEY)
                    .apply()

                pendingResetRunnable?.let { mainHandler.removeCallbacks(it) }
                val (manager, ids) = getWidgetIds(context)
                if (ids.isNotEmpty()) {
                    val partial = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                        setChronometer(
                            R.id.widget_chronometer,
                            SystemClock.elapsedRealtime(),
                            null,
                            true
                        )
                        setDisplayedChild(R.id.widget_button_flipper, CHILD_TIMER)
                        bindClickIntents(context, this)
                    }
                    manager.partiallyUpdateAppWidget(ids, partial)
                }
                return
            }
            ACTION_FINISH_TIMER -> {
                val prefs = HomeWidgetPlugin.getData(context)
                val startMs = readActiveTimerStartMs(prefs)
                val durationSecs = if (startMs > 0L) {
                    ((System.currentTimeMillis() - startMs) / 1000L)
                        .coerceIn(1L, MAX_DURATION_SECONDS)
                } else {
                    1L
                }
                prefs.edit().putLong(TIMER_START_MS_KEY, 0L).apply()
                handleLogAndFlash(context, durationSeconds = durationSecs)
                return
            }
            ACTION_CANCEL_TIMER -> {
                val prefs = HomeWidgetPlugin.getData(context)
                prefs.edit()
                    .putLong(TIMER_START_MS_KEY, 0L)
                    .remove(FLASH_UNTIL_KEY)
                    .apply()

                val (manager, ids) = getWidgetIds(context)
                if (ids.isNotEmpty()) {
                    val partial = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                        setChronometer(
                            R.id.widget_chronometer,
                            SystemClock.elapsedRealtime(),
                            null,
                            false
                        )
                        setDisplayedChild(R.id.widget_button_flipper, CHILD_IDLE)
                        bindClickIntents(context, this)
                    }
                    manager.partiallyUpdateAppWidget(ids, partial)
                }
                return
            }
        }
        super.onReceive(context, intent)
    }

    private fun handleLogAndFlash(context: Context, durationSeconds: Long?) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val currentToday = widgetData.getInt("today_poop", 0)
        val newToday = currentToday + 1
        val flashUntil = System.currentTimeMillis() + FLASH_DURATION_MS

        widgetData.edit()
            .putInt("today_poop", newToday)
            .putLong(FLASH_UNTIL_KEY, flashUntil)
            .putLong(TIMER_START_MS_KEY, 0L)
            .apply()

        val (manager, ids) = getWidgetIds(context)
        if (ids.isNotEmpty()) {
            val partial = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                setChronometer(
                    R.id.widget_chronometer,
                    SystemClock.elapsedRealtime(),
                    null,
                    false
                )
                setTextViewText(R.id.widget_today_count, newToday.toString())
                setDisplayedChild(R.id.widget_button_flipper, CHILD_SUCCESS)
            }
            manager.partiallyUpdateAppWidget(ids, partial)
        }

        val uriString = if (durationSeconds != null && durationSeconds > 0L) {
            "trono://log?type=poop&duration=$durationSeconds"
        } else {
            "trono://log?type=poop"
        }
        enqueueBackgroundLog(context, uriString)
        scheduleFlashReset(context)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val todayPoop = widgetData.getInt("today_poop", 0)
        val avgDaily = widgetData.getString("avg_daily", "0.0") ?: "0.0"
        val isFlashing = System.currentTimeMillis() < widgetData.getLong(FLASH_UNTIL_KEY, 0L)
        val timerStartMs = readActiveTimerStartMs(widgetData)

        for (appWidgetId in appWidgetIds) {
            if (isFlashing) {
                val partial = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                    setTextViewText(R.id.widget_today_count, todayPoop.toString())
                    setTextViewText(R.id.widget_avg_text, "$avgDaily/d")
                }
                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, partial)
            } else {
                val views = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                    setTextViewText(R.id.widget_today_count, todayPoop.toString())
                    setTextViewText(R.id.widget_avg_text, "$avgDaily/d")
                    if (timerStartMs > 0L) {
                        val elapsedMs = (System.currentTimeMillis() - timerStartMs).coerceAtLeast(0L)
                        setChronometer(
                            R.id.widget_chronometer,
                            SystemClock.elapsedRealtime() - elapsedMs,
                            null,
                            true
                        )
                        setDisplayedChild(R.id.widget_button_flipper, CHILD_TIMER)
                    } else {
                        setChronometer(
                            R.id.widget_chronometer,
                            SystemClock.elapsedRealtime(),
                            null,
                            false
                        )
                        setDisplayedChild(R.id.widget_button_flipper, CHILD_IDLE)
                    }
                    bindClickIntents(context, this)
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}

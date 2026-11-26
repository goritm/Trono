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
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundWorker
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import io.flutter.FlutterInjector

class TronoWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_QUICK_LOG_POOP = "com.trono.trono.ACTION_QUICK_LOG_POOP"
        private const val FLASH_UNTIL_KEY = "widget_flash_until"
        private const val FLASH_DURATION_MS = 1400L
        private val mainHandler = Handler(Looper.getMainLooper())
        private var pendingResetRunnable: Runnable? = null
    }

    private fun quickLogPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, TronoWidgetProvider::class.java).apply {
            action = ACTION_QUICK_LOG_POOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(context, 201, intent, flags)
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

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_QUICK_LOG_POOP) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val currentToday = widgetData.getInt("today_poop", 0)
            val newToday = currentToday + 1
            val flashUntil = System.currentTimeMillis() + FLASH_DURATION_MS

            widgetData.edit()
                .putInt("today_poop", newToday)
                .putLong(FLASH_UNTIL_KEY, flashUntil)
                .apply()

            // 1. Smoothly flip ViewFlipper to child 1 (green "¡GUARDADO!") via partial update
            //    so the layout is NEVER re-inflated (zero flicker!).
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, TronoWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val partial = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                    setTextViewText(R.id.widget_today_count, newToday.toString())
                    setDisplayedChild(R.id.widget_button_flipper, 1)
                }
                manager.partiallyUpdateAppWidget(ids, partial)
            }

            // 2. Persist real BathroomLog via Flutter HomeWidget background worker
            try {
                val flutterLoader = FlutterInjector.instance().flutterLoader()
                flutterLoader.startInitialization(context)
                flutterLoader.ensureInitializationComplete(context, null)
                val bgIntent = Intent().apply {
                    data = Uri.parse("trono://log?type=poop")
                }
                HomeWidgetBackgroundWorker.enqueueWork(context, bgIntent)
            } catch (_: Exception) {
            }

            // 3. Schedule smooth flip back to child 0 ("+1 PUPU"), cancelling any prior timer
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
                    val backPartial = RemoteViews(appCtx.packageName, R.layout.trono_widget).apply {
                        setTextViewText(
                            R.id.widget_today_count,
                            prefs.getInt("today_poop", 0).toString()
                        )
                        setTextViewText(
                            R.id.widget_avg_text,
                            "${prefs.getString("avg_daily", "0.0") ?: "0.0"}/d"
                        )
                        setDisplayedChild(R.id.widget_button_flipper, 0)
                    }
                    mgr.partiallyUpdateAppWidget(widgetIds, backPartial)
                }
            }
            pendingResetRunnable = reset
            mainHandler.postDelayed(reset, FLASH_DURATION_MS)
            return
        }
        super.onReceive(context, intent)
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

        for (appWidgetId in appWidgetIds) {
            if (isFlashing) {
                // While green confirmation is active, ONLY update numbers partially
                // so Dart's sync NEVER re-inflates or flickers the ViewFlipper!
                val partial = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                    setTextViewText(R.id.widget_today_count, todayPoop.toString())
                    setTextViewText(R.id.widget_avg_text, "$avgDaily/d")
                }
                appWidgetManager.partiallyUpdateAppWidget(appWidgetId, partial)
            } else {
                val views = RemoteViews(context.packageName, R.layout.trono_widget).apply {
                    setTextViewText(R.id.widget_today_count, todayPoop.toString())
                    setTextViewText(R.id.widget_avg_text, "$avgDaily/d")
                    setDisplayedChild(R.id.widget_button_flipper, 0)
                    setOnClickPendingIntent(R.id.widget_header, launchAppPendingIntent(context))
                    setOnClickPendingIntent(R.id.btn_log_poop, quickLogPendingIntent(context))
                }
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
        }
    }
}

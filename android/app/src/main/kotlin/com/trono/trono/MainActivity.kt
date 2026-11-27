package com.trono.trono

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SHORTCUT_CHANNEL = "com.trono.trono/shortcuts"
        private const val EXTRA_SHORTCUT_ACTION = "shortcut_action"
        private const val REMINDERS_CHANNEL = "com.trono.trono/reminders"
        private const val REQUEST_CODE_NOTIFICATIONS = 2501
    }

    private var shortcutChannel: MethodChannel? = null
    private var pendingShortcutAction: String? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractShortcutAction(intent)?.let { pendingShortcutAction = it }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        shortcutChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SHORTCUT_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialShortcut" -> {
                        val action = pendingShortcutAction
                        pendingShortcutAction = null
                        result.success(action)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            REMINDERS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> handleRequestNotificationPermission(result)
                "scheduleReminder" -> handleScheduleReminder(call, result)
                "cancelReminder" -> handleCancelReminder(call, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = extractShortcutAction(intent) ?: return
        val channel = shortcutChannel
        if (channel != null) {
            channel.invokeMethod("onShortcut", action)
        } else {
            pendingShortcutAction = action
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
        }
    }

    private fun handleRequestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }
        val alreadyGranted = checkSelfPermission(
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (alreadyGranted) {
            result.success(true)
            return
        }
        pendingNotificationPermissionResult?.success(false)
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE_NOTIFICATIONS
        )
    }

    private fun handleScheduleReminder(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id")
        val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong()
        val title = call.argument<String>("title")?.trim().orEmpty()
        val body = call.argument<String>("body")?.trim().orEmpty()
        if (id == null || triggerAtMillis == null || title.isEmpty() || body.isEmpty()) {
            result.success(false)
            return
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            result.success(false)
            return
        }

        val intent = Intent(this, TronoReminderReceiver::class.java).apply {
            putExtra(TronoReminderReceiver.EXTRA_ID, id)
            putExtra(TronoReminderReceiver.EXTRA_TITLE, title)
            putExtra(TronoReminderReceiver.EXTRA_BODY, body)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            pendingIntentFlags()
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        } else {
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
        }
        result.success(true)
    }

    private fun handleCancelReminder(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id")
        if (id != null) {
            val intent = Intent(this, TronoReminderReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                id,
                intent,
                pendingIntentFlags()
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            alarmManager?.cancel(pendingIntent)
            pendingIntent.cancel()

            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancel(id)
        }
        result.success(null)
    }

    private fun pendingIntentFlags(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
    }

    private fun extractShortcutAction(intent: Intent?): String? {
        val raw = intent?.getStringExtra(EXTRA_SHORTCUT_ACTION)?.trim()
        return if (raw.isNullOrEmpty()) null else raw
    }
}

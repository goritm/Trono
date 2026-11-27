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
import android.os.Handler
import android.os.Looper
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private data class PendingLiveTimer(
        val startMillis: Long,
        val title: String?,
        val body: String?,
        val saveLabel: String?,
        val cancelLabel: String?,
        val locale: String?
    )

    companion object {
        const val EXTRA_OPEN_TAB = "open_tab"
        private const val SHORTCUT_CHANNEL = "com.trono.trono/shortcuts"
        private const val EXTRA_SHORTCUT_ACTION = "shortcut_action"
        private const val REMINDERS_CHANNEL = "com.trono.trono/reminders"
        private const val LIVE_TIMER_CHANNEL = "com.trono.trono/live_timer"
        private const val PUSH_CHANNEL = "com.trono.trono/push"
        private const val REQUEST_CODE_NOTIFICATIONS = 2501
        private const val REQUEST_CODE_LIVE_TIMER_NOTIFICATIONS = 2605
        private const val PREFS_LIVE_TIMER = "trono_live_timer_prefs"
        private const val KEY_ASKED_LIVE_TIMER_PERM = "asked_live_timer_notif_perm"

        private val mainHandler = Handler(Looper.getMainLooper())
        @Volatile
        private var activeLiveTimerChannel: MethodChannel? = null
        @Volatile
        private var activePushChannel: MethodChannel? = null

        fun notifyLiveTimerAction(action: String) {
            val channel = activeLiveTimerChannel ?: return
            mainHandler.post {
                try {
                    channel.invokeMethod("onTimerAction", action)
                } catch (_: Exception) {
                }
            }
        }

        fun notifyFcmToken(token: String) {
            val channel = activePushChannel ?: return
            mainHandler.post {
                try {
                    channel.invokeMethod("onFcmToken", token)
                } catch (_: Exception) {
                }
            }
        }

        fun notifyQuickReply(logId: String, body: String): Boolean {
            val channel = activePushChannel ?: return false
            mainHandler.post {
                try {
                    channel.invokeMethod(
                        "onQuickReply",
                        mapOf("logId" to logId, "body" to body)
                    )
                } catch (_: Exception) {
                }
            }
            return true
        }
    }

    private var shortcutChannel: MethodChannel? = null
    private var pendingShortcutAction: String? = null
    private var pendingOpenTab: String? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var pendingLiveTimerResult: MethodChannel.Result? = null
    private var pendingLiveTimerPayload: PendingLiveTimer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        TronoNotificationChannels.ensureAll(this)
        extractShortcutAction(intent)?.let { pendingShortcutAction = it }
        extractOpenTab(intent)?.let { pendingOpenTab = it }
    }

    override fun onDestroy() {
        activeLiveTimerChannel = null
        activePushChannel = null
        super.onDestroy()
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

        activeLiveTimerChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LIVE_TIMER_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "showLiveTimer" -> handleShowLiveTimer(call, result)
                    "dismissLiveTimer" -> {
                        pendingLiveTimerPayload = null
                        pendingLiveTimerResult?.success(false)
                        pendingLiveTimerResult = null
                        TronoLiveTimerNotification.dismiss(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        activePushChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PUSH_CHANNEL
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "ensureChannels" -> {
                        val locale = call.argument<String>("locale")
                        val thrones = call.argument<Boolean>("notifyFriendThrones")
                        val comments = call.argument<Boolean>("notifyFriendComments")
                        val reactions = call.argument<Boolean>("notifyFriendReactions")
                        TronoNotificationChannels.savePreferences(
                            context = this,
                            locale = locale,
                            notifyThrones = thrones,
                            notifyComments = comments,
                            notifyReactions = reactions
                        )
                        TronoNotificationChannels.ensureAll(this, locale)
                        result.success(null)
                    }
                    "getFcmToken" -> handleGetFcmToken(result)
                    "openNotificationSettings" -> {
                        val channelId = call.argument<String>("channelId")
                        val ok = TronoNotificationChannels.openSystemSettings(this, channelId)
                        result.success(ok)
                    }
                    "sendTestNotification" -> {
                        val locale = call.argument<String>("locale")
                        val ok = TronoNotificationChannels.sendTestNotification(this, locale)
                        result.success(ok)
                    }
                    "syncAuthSession" -> {
                        val url = call.argument<String>("url").orEmpty()
                        val apiKey = call.argument<String>("apiKey").orEmpty()
                        val accessToken = call.argument<String>("accessToken").orEmpty()
                        val userId = call.argument<String>("userId").orEmpty()
                        if (url.isNotEmpty() && apiKey.isNotEmpty() &&
                            accessToken.isNotEmpty() && userId.isNotEmpty()
                        ) {
                            TronoNotificationChannels.saveAuthContext(
                                this,
                                url,
                                apiKey,
                                accessToken,
                                userId
                            )
                        }
                        result.success(null)
                    }
                    "clearAuthSession" -> {
                        TronoNotificationChannels.clearAuthContext(this)
                        result.success(null)
                    }
                    "getInitialOpenTab" -> {
                        val tab = pendingOpenTab
                        pendingOpenTab = null
                        result.success(tab)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        extractOpenTab(intent)?.let { tab ->
            val pChannel = activePushChannel
            if (pChannel != null) {
                pChannel.invokeMethod("onOpenTab", tab)
            } else {
                pendingOpenTab = tab
            }
        }
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
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        if (requestCode == REQUEST_CODE_NOTIFICATIONS) {
            pendingNotificationPermissionResult?.success(granted)
            pendingNotificationPermissionResult = null
        } else if (requestCode == REQUEST_CODE_LIVE_TIMER_NOTIFICATIONS) {
            val payload = pendingLiveTimerPayload
            pendingLiveTimerPayload = null
            val shown = if (granted && payload != null) {
                TronoLiveTimerNotification.show(
                    context = this,
                    startMillis = payload.startMillis,
                    title = payload.title,
                    body = payload.body,
                    saveLabel = payload.saveLabel,
                    cancelLabel = payload.cancelLabel,
                    locale = payload.locale
                )
            } else {
                false
            }
            pendingLiveTimerResult?.success(shown)
            pendingLiveTimerResult = null
        }
    }

    private fun handleShowLiveTimer(call: MethodCall, result: MethodChannel.Result) {
        val startMillis = call.argument<Number>("startMillis")?.toLong() ?: 0L
        if (startMillis <= 0L) {
            TronoLiveTimerNotification.dismiss(this)
            result.success(false)
            return
        }
        val title = call.argument<String>("title")
        val body = call.argument<String>("body")
        val saveLabel = call.argument<String>("saveLabel")
        val cancelLabel = call.argument<String>("cancelLabel")
        val locale = call.argument<String>("locale")

        if (TronoLiveTimerNotification.hasPermission(this)) {
            val shown = TronoLiveTimerNotification.show(
                context = this,
                startMillis = startMillis,
                title = title,
                body = body,
                saveLabel = saveLabel,
                cancelLabel = cancelLabel,
                locale = locale
            )
            result.success(shown)
            return
        }

        // Persist start & locale even if notification permission is missing
        TronoLiveTimerNotification.persistStartAndLocale(this, startMillis, locale)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val prefs = getSharedPreferences(PREFS_LIVE_TIMER, Context.MODE_PRIVATE)
            val alreadyAsked = prefs.getBoolean(KEY_ASKED_LIVE_TIMER_PERM, false)
            if (!alreadyAsked) {
                prefs.edit().putBoolean(KEY_ASKED_LIVE_TIMER_PERM, true).apply()
                pendingLiveTimerResult?.success(false)
                pendingLiveTimerResult = result
                pendingLiveTimerPayload = PendingLiveTimer(
                    startMillis = startMillis,
                    title = title,
                    body = body,
                    saveLabel = saveLabel,
                    cancelLabel = cancelLabel,
                    locale = locale
                )
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE_LIVE_TIMER_NOTIFICATIONS
                )
                return
            }
        }
        result.success(false)
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

    private fun handleGetFcmToken(result: MethodChannel.Result) {
        try {
            if (FirebaseApp.getApps(this).isEmpty()) {
                result.success(TronoNotificationChannels.readSavedFcmToken(this))
                return
            }
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    val token = task.result?.trim().orEmpty()
                    if (token.isNotEmpty()) {
                        TronoNotificationChannels.saveFcmToken(this, token)
                        result.success(token)
                        return@addOnCompleteListener
                    }
                }
                result.success(TronoNotificationChannels.readSavedFcmToken(this))
            }
        } catch (_: Exception) {
            result.success(TronoNotificationChannels.readSavedFcmToken(this))
        }
    }

    private fun extractShortcutAction(intent: Intent?): String? {
        val raw = intent?.getStringExtra(EXTRA_SHORTCUT_ACTION)?.trim()
        return if (raw.isNullOrEmpty()) null else raw
    }

    private fun extractOpenTab(intent: Intent?): String? {
        val raw = intent?.getStringExtra(EXTRA_OPEN_TAB)?.trim()
        return if (raw.isNullOrEmpty()) null else raw
    }
}

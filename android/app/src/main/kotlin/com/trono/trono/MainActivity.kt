package com.trono.trono

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val SHORTCUT_CHANNEL = "com.trono.trono/shortcuts"
        private const val EXTRA_SHORTCUT_ACTION = "shortcut_action"
    }

    private var shortcutChannel: MethodChannel? = null
    private var pendingShortcutAction: String? = null

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

    private fun extractShortcutAction(intent: Intent?): String? {
        val raw = intent?.getStringExtra(EXTRA_SHORTCUT_ACTION)?.trim()
        return if (raw.isNullOrEmpty()) null else raw
    }
}

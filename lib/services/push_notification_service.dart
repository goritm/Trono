import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/push_notification_config.dart';

/// Native Android bridge for:
/// 1. Registering & localizing all 5 Android NotificationChannels on startup.
/// 2. Reading & listening to Firebase Cloud Messaging (FCM) tokens safely.
/// 3. Opening Android's system per-app / per-channel notification settings.
/// 4. Routing social notification taps straight to the Friends tab.
class PushNotificationService {
  PushNotificationService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.trono.trono/push',
  );

  final MethodChannel _channel;
  bool _listening = false;

  Future<void> ensureChannels({
    required Locale locale,
    SocialNotificationPrefs? prefs,
  }) async {
    try {
      await _channel.invokeMethod<void>('ensureChannels', {
        'locale': locale.languageCode == 'es' ? 'es' : 'en',
        ...?prefs?.toPlatformMap(),
      });
    } on MissingPluginException {
      // Safe no-op on non-Android platforms or unmocked tests.
    } on PlatformException {
      // Safe no-op.
    }
  }

  Future<String?> getFcmToken() async {
    try {
      final token = await _channel.invokeMethod<String>('getFcmToken');
      final clean = token?.trim() ?? '';
      return clean.isEmpty ? null : clean;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<bool> openSystemNotificationSettings({String? channelId}) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openNotificationSettings',
        channelId != null ? {'channelId': channelId} : null,
      );
      return opened ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<String?> consumeInitialOpenTab() async {
    try {
      final tab = await _channel.invokeMethod<String>('getInitialOpenTab');
      final clean = tab?.trim() ?? '';
      return clean.isEmpty ? null : clean;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void startListening({
    void Function(String token)? onTokenRefresh,
    void Function(String tab)? onOpenTab,
  }) {
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onFcmToken') {
        final token = (call.arguments as String?)?.trim() ?? '';
        if (token.isNotEmpty) onTokenRefresh?.call(token);
      } else if (call.method == 'onOpenTab') {
        final tab = (call.arguments as String?)?.trim() ?? '';
        if (tab.isNotEmpty) onOpenTab?.call(tab);
      }
    });
  }

  void dispose() {
    if (_listening) {
      _channel.setMethodCallHandler(null);
      _listening = false;
    }
  }
}

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Action triggered directly from the Android status-bar Chronometer
/// notification buttons (`✓ Save` / `✕ Cancel`).
enum LiveTimerAction {
  finish,
  cancel;

  static LiveTimerAction? tryParse(String? raw) {
    if (raw == null) return null;
    return switch (raw.trim().toLowerCase()) {
      'finish' => LiveTimerAction.finish,
      'cancel' => LiveTimerAction.cancel,
      _ => null,
    };
  }
}

/// Platform payload for displaying an ongoing Android status-bar Chronometer
/// notification while a throne timer is active.
class LiveTimerNotificationPayload {
  const LiveTimerNotificationPayload({
    required this.startMillis,
    required this.locale,
    required this.title,
    required this.body,
    required this.saveLabel,
    required this.cancelLabel,
  });

  final int startMillis;
  final String locale;
  final String title;
  final String body;
  final String saveLabel;
  final String cancelLabel;

  factory LiveTimerNotificationPayload.forLocale(
    DateTime start,
    Locale locale,
  ) {
    final isEs = locale.languageCode == 'es';
    return LiveTimerNotificationPayload(
      startMillis: start.millisecondsSinceEpoch,
      locale: isEs ? 'es' : 'en',
      title: isEs ? '👑 Cronómetro en marcha' : '👑 Throne timer active',
      body: isEs
          ? 'Pulsa ✓ Guardar al terminar'
          : 'Tap ✓ Save when you finish',
      saveLabel: isEs ? '✓ Guardar' : '✓ Save',
      cancelLabel: isEs ? '✕ Cancelar' : '✕ Cancel',
    );
  }

  Map<String, Object> toPlatformMap() => {
    'startMillis': startMillis,
    'locale': locale,
    'title': title,
    'body': body,
    'saveLabel': saveLabel,
    'cancelLabel': cancelLabel,
  };
}

/// Zero-dependency bridge to Android's native `Notification.Builder` with
/// `setUsesChronometer(true)`. Safely no-ops on non-Android platforms or tests.
class LiveTimerNotificationService {
  LiveTimerNotificationService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.trono.trono/live_timer',
  );

  final MethodChannel _channel;
  bool _listening = false;

  Future<bool> showTimer(DateTime start, {required Locale locale}) async {
    final payload = LiveTimerNotificationPayload.forLocale(start, locale);
    try {
      final shown = await _channel.invokeMethod<bool>(
        'showLiveTimer',
        payload.toPlatformMap(),
      );
      return shown ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> dismissTimer() async {
    try {
      await _channel.invokeMethod<void>('dismissLiveTimer');
    } on MissingPluginException {
      // Safe no-op on non-Android platforms or unmocked tests.
    } on PlatformException {
      // Safe no-op if platform cannot dismiss.
    }
  }

  void startListening(void Function(LiveTimerAction action) onAction) {
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTimerAction') {
        final action = LiveTimerAction.tryParse(call.arguments as String?);
        if (action != null) {
          onAction(action);
        }
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

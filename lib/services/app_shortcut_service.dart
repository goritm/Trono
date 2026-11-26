import 'package:flutter/services.dart';

enum AppShortcutAction {
  claimThrone,
  startTimer;

  static AppShortcutAction? tryParse(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    return switch (normalized) {
      'claim_throne' => AppShortcutAction.claimThrone,
      'start_timer' => AppShortcutAction.startTimer,
      _ => null,
    };
  }
}

typedef ShortcutActionCallback = void Function(AppShortcutAction action);

/// Bridges native Android static App Shortcuts (`com.trono.trono/shortcuts`)
/// into Dart for both cold launches and warm `onNewIntent` resumes.
class AppShortcutService {
  AppShortcutService({MethodChannel? channel})
    : _channel = channel ?? defaultChannel;

  static const MethodChannel defaultChannel = MethodChannel(
    'com.trono.trono/shortcuts',
  );

  final MethodChannel _channel;
  ShortcutActionCallback? _listener;

  Future<AppShortcutAction?> consumeInitialShortcut() async {
    try {
      final raw = await _channel.invokeMethod<String>('getInitialShortcut');
      return AppShortcutAction.tryParse(raw);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  void startListening(ShortcutActionCallback onAction) {
    _listener = onAction;
    _channel.setMethodCallHandler(_handleCall);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method != 'onShortcut') return;
    final action = AppShortcutAction.tryParse(call.arguments?.toString());
    if (action != null) {
      _listener?.call(action);
    }
  }

  void dispose() {
    _listener = null;
    _channel.setMethodCallHandler(null);
  }
}

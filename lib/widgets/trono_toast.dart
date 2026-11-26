import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Shows a floating Trono toast that ALWAYS auto-dismisses after [duration],
/// even when an action button (e.g. Undo) is attached.
///
/// In Material 3 (`material_ui` 1.11+), `SnackBar` defaults `persist: true`
/// whenever `action != null`, which would otherwise leave toasts stuck forever.
void showTronoToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  showTronoToastOnMessenger(
    ScaffoldMessenger.of(context),
    message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );
}

void showTronoToastOnMessenger(
  ScaffoldMessengerState messenger,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final hasAction = actionLabel != null && onAction != null;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      persist: false,
      duration: duration ??
          (hasAction
              ? const Duration(seconds: 4)
              : const Duration(milliseconds: 2500)),
      action: hasAction
          ? SnackBarAction(
              label: actionLabel,
              textColor: TronoColors.gold,
              onPressed: onAction,
            )
          : null,
    ),
  );
}

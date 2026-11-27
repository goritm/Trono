# Spec: Ongoing Android Status-Bar Chronometer Notification (Live Timer)

- **Status:** Implemented
- **Target Version / PR:** `v2.7.0` / PR #26
- **Branch:** `feat/v2.7-live-timer-notification`

## 1. Goal
> Whenever a throne timer is active — whether started from the **in-app Hero Timer**, an **App Shortcut**, or the **Android Home Screen Widget** — show a silent, battery-free, ongoing Android status-bar notification powered by `Notification.Builder.setUsesChronometer(true)` with direct **`✓ Save`** and **`✕ Cancel`** action buttons.

## 2. Non-Goals
- No third-party notification plugins (100% native Android `NotificationManager` + `MethodChannel`).
- No foreground service (`FOREGROUND_SERVICE` permission not needed — Android's native chronometer ticks in SystemUI without waking the app process).
- No cloud/Supabase sync of timer notification state.
- No push notifications for friend reactions/comments (separate future milestone).

## 3. Data Model & Privacy Contract
- **100% Device-Only:** Timer start timestamp (`timer_start_ms`), notification channel (`trono_live_timer`), and one-time Android 13+ permission prompt flag (`asked_live_timer_notif_perm`) remain strictly on-device.
- **SQLite / Supabase migrations required:** None.
- **Shared Broadcast Actions:** Notification buttons reuse `TronoWidgetProvider.ACTION_FINISH_TIMER` and `TronoWidgetProvider.ACTION_CANCEL_TIMER` so tapping **`✓ Save`** persists the throne with exact elapsed seconds + silent GPS even if the app is killed or no Home Screen Widget is placed!

## 4. User Experience & Copy
- **Channel:** `trono_live_timer` (`IMPORTANCE_LOW`, silent, no badge, `CATEGORY_STOPWATCH`, `setOngoing(true)`, `setOnlyAlertOnce(true)`).
- **Chronometer:** `setWhen(timerStartMs)` + `setShowWhen(true)` + `setUsesChronometer(true)` so SystemUI renders a live ticking `MM:SS` timer in the shade, lock screen, and Android status-bar pill.
- **Tap notification body:** Opens `MainActivity` (`FLAG_ACTIVITY_NEW_TASK | FLAG_ACTIVITY_CLEAR_TOP`).
- **Action buttons (EN default / ES parity):**
  - EN: Title `👑 Throne timer active`, Body `Tap ✓ Save when you finish`, Actions `✓ Save` | `✕ Cancel`.
  - ES: Title `👑 Cronómetro en marcha`, Body `Pulsa ✓ Guardar al terminar`, Actions `✓ Guardar` | `✕ Cancelar`.
- **Android 13+ (`POST_NOTIFICATIONS`) permission:**
  - If already granted: notification appears immediately.
  - If not yet granted and started from the app: asks once (never nags again if declined); if granted, immediately shows the active timer notification.
  - If started from the widget without permission: safely no-ops without crashing.
- **Instant in-app reconciliation:** Tapping `✓ Save` or `✕ Cancel` in the notification dismisses the notification, updates any widgets, and immediately notifies `MainActivity` -> `LiveTimerNotificationService` so an open app updates without waiting for lifecycle resume.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** `LiveTimerNotificationPayload.forLocale(start, Locale('en'))` and `Locale('es')`, **when** serialized via `toPlatformMap()`, **then** it contains exact `startMillis`, localized `title`, `body`, `saveLabel`, and `cancelLabel` matching brand-first copy (EN default / ES parity).
2. **Given** a mocked `MethodChannel('com.trono.trono/live_timer')`, **when** `LiveTimerNotificationService.showTimer(...)` and `dismissTimer()` are invoked, **then** `showLiveTimer` and `dismissLiveTimer` are sent with the expected arguments.
3. **Given** a non-Android platform or unmocked channel throwing `MissingPluginException`, **when** `showTimer` or `dismissTimer` is invoked, **then** it completes cleanly without throwing.
4. **Given** `LiveTimerNotificationService.startListening(callback)`, **when** native Android invokes `onTimerAction` with `'finish'` or `'cancel'`, **then** the callback receives `LiveTimerAction.finish` or `LiveTimerAction.cancel` (ignoring unknown payloads).
5. **Given** `TronoController`, **when** `startTimer()`, `cancelTimer()`, `quickLog()` (while running), `syncTimerFromExternal(...)`, and `setLocale(...)` (while running) are invoked, **then** `LiveTimerNotificationService` is called to show, dismiss, or re-localize the notification accordingly.

## 6. Edge Cases
- **No Home Screen Widget placed:** `TronoLiveTimerNotification.show` ensures `timer_start_ms` is persisted in `HomeWidgetPreferences` so `ACTION_FINISH_TIMER` computes exact duration and writes to SQLite even when 0 widgets exist.
- **Double-log prevention:** Tapping `✓ Save` in the notification executes `ACTION_FINISH_TIMER` in `TronoWidgetProvider` (which enqueues SQLite write via `goAsync()`), while `onTimerAction('finish')` in Flutter ONLY clears the in-app timer (`syncTimerFromExternal(null)`) and reloads logs — never triggers a second `quickLog()`.
- **Locale changed mid-session:** `TronoController.setLocale` refreshes the ongoing notification copy immediately while preserving the original `startMillis`.
- **App cold-started with an active timer:** `TronoController.init()` re-syncs the ongoing notification so it stays consistent after process death.

## 7. TDD Verification Plan
- **RED → GREEN Unit Tests:** `test/live_timer_notification_test.dart` covering all 5 acceptance criteria.
- **Native Verification:** `./gradlew :app:compileDebugKotlin` → `BUILD SUCCESSFUL` with 0 warnings in `:app`.
- **Full Suite:** `dart analyze` → `No issues found!`, `flutter test` → 100% passing.

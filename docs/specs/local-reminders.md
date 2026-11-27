# Spec: Local Smart Reminders (Streak Guard & Weekly Recap)

- **Status:** Implemented
- **Target Version / PR:** `v2.5.0` / PR #__
- **Branch:** `feat/v2.5-local-reminders`

## 1. Goal
> Help users keep their logging streak alive and revisit their weekly Trono Wrapped without ever sending push tokens or personal data to a server, via 100% local, opt-in smart reminders powered by native Android `AlarmManager` + `NotificationManager` with zero extra pub dependencies.

## 2. Non-Goals
- No remote push notifications (FCM / APNs / Supabase Edge Functions).
- No third-party Flutter notification plugin (avoids Gradle core library desugaring risks in CI release builds).
- No iOS `UNUserNotificationCenter` implementation in this PR (Dart service safely no-ops when the native channel is unavailable).
- No SQLite or Supabase schema changes.
- Reminders are **OFF by default** (strictly opt-in).

## 3. Data Model & Privacy Contract
- **Local-only fields (`SharedPreferences`):**
  - `streak_reminder_enabled` (`bool`, default `false`)
  - `streak_reminder_hour` (`int`, default `20`; UI exposes evening presets `19:00`, `20:00`, `21:00`, `22:00`)
  - `weekly_recap_reminder_enabled` (`bool`, default `false`)
- **Local-only native state:** Android `AlarmManager` pending intents (IDs `1001` for Streak Guard, `1002` for Weekly Recap) and local notification channel `trono_reminders`.
- **Cloud-synced fields (Supabase):** None. Reminder preferences, streak alerts, exact GPS coordinates, and work pay rate NEVER leave the device.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Entry point:** `SettingsScreen` → new **Reminders / Recordatorios** `ChunkyCard` section (placed below Appearance & Language).
- **Controls:**
  1. **🔥 Streak reminder / Recordatorio de racha** (`SwitchListTile`):
     - Subtitle shows chosen evening hour and smart-suppression note (`Check-in at 20:00 · skipped if you already logged today` / `Aviso a las 20:00 · se omite si ya registraste hoy`).
     - When enabled, displays an inline **Reminder time / Hora del aviso** `ChoiceChip` row (`19:00 · 20:00 · 21:00 · 22:00`).
  2. **✨ Sunday Wrapped recap / Resumen semanal del domingo** (`SwitchListTile`):
     - Subtitle explains schedule (`Sundays at 19:00 · check your weekly stats & Wrapped card` / `Domingos a las 19:00 · revisa tus stats y tu Trono Wrapped`).
- **Permission flow (Android 13+):**
  - Toggling either reminder ON calls `requestPermission` over `MethodChannel('com.trono.trono/reminders')`.
  - If denied, the toggle stays OFF and a friendly toast (`showTronoToast`) explains how to enable notifications in Android settings.
- **Localized notification content:** Title & body are resolved in Dart from `AppStrings` using the user's selected in-app locale (`en` or `es`) and passed to Android when scheduling. Switching app language immediately reschedules active reminders in the new language.
- **Copy rule:** Brand-first `throne` / `thrones` (EN) and `trono` / `tronos` (ES) with `👑`; zero juvenile words (`poop` / `pupú`).

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a user has NOT logged a throne today (`loggedToday == false`) and the current time is before the chosen reminder hour (`now < today(hour:00)`), **when** `ReminderScheduleCalculator.nextStreakReminder(...)` runs, **then** it schedules for **today at `hour:00`**.
2. **Given** a user HAS already logged at least one throne today (`loggedToday == true`), **when** `ReminderScheduleCalculator.nextStreakReminder(...)` runs (even before `hour:00`), **then** it suppresses today's alert and schedules for **tomorrow at `hour:00`**.
3. **Given** the chosen reminder hour has already passed today (`now >= today(hour:00)`), **when** `ReminderScheduleCalculator.nextStreakReminder(...)` runs, **then** it schedules for **tomorrow at `hour:00`**.
4. **Given** any date/time `now`, **when** `ReminderScheduleCalculator.nextWeeklyRecap(now: now)` runs, **then** it returns the next Sunday at `19:00` strictly after `now` (including returning next week's Sunday if `now` is Sunday at or after `19:00`).
5. **Given** `LocalReminderService.syncReminders(...)` is called with `streakEnabled == true` and `weeklyEnabled == false`, **when** syncing against the platform channel, **then** it calls `scheduleReminder` for Streak Guard (`id: 1001`) and `cancelReminder` for Weekly Recap (`id: 1002`).
6. **Given** the user enables Streak Guard in `SettingsScreen` and platform permission is **denied**, **when** toggling the switch, **then** the switch remains OFF, the preference stays `false`, and a toast is shown.
7. **Given** Streak Guard is enabled and the user logs a throne via `TronoController.quickLog` / `saveLog`, deletes a log via `deleteLog`, or changes language via `setLocale`, **when** the action completes, **then** `LocalReminderService.syncReminders` is re-invoked with the updated `loggedToday`, `currentStreak`, and localized copy.
8. **Given** a platform without the native channel (unit tests, iOS, desktop), **when** any `LocalReminderService` method is called, **then** `MissingPluginException` / `PlatformException` is caught gracefully without throwing.

## 6. Edge Cases
- **Android 13+ (`POST_NOTIFICATIONS`) denied:** `MainActivity` returns `false` from `requestPermission`; `TronoController` refuses to enable the toggle and UI displays a toast. On API < 33, `requestPermission` returns `true` immediately.
- **Android 12+/14+ exact alarm restrictions:** Uses `AlarmManager.setAndAllowWhileIdle` (no `SCHEDULE_EXACT_ALARM` permission required), avoiding crashes or store policy issues.
- **Month/year boundaries & DST transitions:** `DateTime(year, month, day + offset, hour)` preserves local wall-clock hour across DST and calendar boundaries.
- **Upgrading existing users:** All reminder keys default cleanly (`false`, `20`, `false`); zero migration needed.
- **Offline / no network:** 100% local; works identically offline.
- **Dark mode & Light mode:** Uses `ChunkyCard`, `SwitchListTile`, `_ColorIcon`, and `ChoiceChip` from the active theme.

## 7. TDD Verification Plan
- **Unit & widget tests to write first (RED → GREEN):**
  - `test/local_reminders_test.dart`:
    - `ReminderScheduleCalculator.nextStreakReminder` (before hour unlogged, already logged today smart suppression, exact/past hour rollover, month/year boundary).
    - `ReminderScheduleCalculator.nextWeeklyRecap` (mid-week, Sunday morning before 19:00, Sunday at 19:00 exact, Sunday night after 19:00).
    - `ReminderConfig` defaults & `copyWith`.
    - `LocalReminderService` MethodChannel integration (`requestPermission`, `scheduleReminder`, `cancelReminder`, `syncReminders`, and graceful `MissingPluginException` / `PlatformException` handling).
    - `TronoController` persistence + automatic rescheduling on `init()`, `quickLog()`, `saveLog()`, `deleteLog()`, and `setLocale()` (EN ↔ ES localized copy).
    - `SettingsScreen` widget tests: Reminders card renders in EN & ES, enabling Streak Guard reveals hour chips (`19:00`–`22:00`) and persists selection, permission-denied keeps toggle OFF and shows `showTronoToast`.
- **Verification:**
  - `dart analyze` → **0 errors, 0 warnings, 0 infos**.
  - `flutter test` → 100% passing.

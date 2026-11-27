# Spec: Android Home Screen Widget Live Timer (2-Way App Sync)

- **Status:** Implemented
- **Target Version / PR:** `v2.7.0` / PR #25
- **Branch:** `feat/v2.7-widget-timer`

## 1. Goal
> Let users start, watch, finish, or cancel a live throne session timer directly from the **Android Home Screen Widget** without opening the app — powered by Android's native battery-free `<Chronometer>` inside the existing flicker-free `ViewFlipper` — with full **2-way synchronization** between the widget and the in-app timer.

## 2. Non-Goals
- Persistent Android status-bar Chronometer notifications (planned for a future PR).
- Selecting WFH/Office mode directly inside the 2×2 widget (widget keeps silent GPS + Favorite Places auto-labeling).
- No SQLite or Supabase schema changes.

## 3. Data Model & Privacy Contract
- **Local-only state:** `timer_start_ms` (epoch milliseconds, `0` when idle) stored strictly on-device in Android `HomeWidget` `SharedPreferences`. Never uploaded to Supabase.
- **Background log creation:** `trono://log?type=poop&duration=<seconds>` persists a normal local `BathroomLog` with exact `durationSeconds`, silent GPS coordinates (local-only), and Favorite Place / Home classification.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy
- **Widget Idle State (ViewFlipper child 0):**
  - Left primary button (`👑 +1`): 1-tap instant throne log (unchanged speed).
  - Right compact button (`⏱`): 1-tap starts live widget `<Chronometer>` (Obsidian + Warm Gold).
- **Widget Confirmation Flash (ViewFlipper child 1):**
  - `✓ +1!` green/gold flash for 1.4s via `partiallyUpdateAppWidget` (zero flicker), then returns to child 0.
- **Widget Active Timer State (ViewFlipper child 2):**
  - Left tappable Obsidian/Gold card displaying live ticking `<Chronometer>` (`MM:SS`) + `✓` finish cue: tapping finishes the timer, saves the throne with exact elapsed seconds + silent GPS, increments today's count, and flashes `✓ +1!`.
  - Right compact `✕` button cancels the timer cleanly without saving.
- **2-Way Sync:**
  - Starting or cancelling/finishing the timer in the **app** immediately updates the widget's `<Chronometer>`.
  - Starting, finishing, or cancelling the timer on the **widget** immediately syncs to `TronoController` when the app opens or resumes.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a background callback URI `trono://log?type=poop&duration=245`, **when** `WidgetLogPayload.tryParseUri(uri)` runs, **then** it returns `type == BathroomType.poop` and `durationSeconds == 245`.
2. **Given** a URI without `duration` (`trono://log?type=poop`) or with invalid/zero/negative duration (`duration=0`, `duration=-5`, `duration=abc`), **when** `WidgetLogPayload.tryParseUri(uri)` runs, **then** `durationSeconds` is `null` (never throws or stores negative durations).
3. **Given** a valid external `timerStart` timestamp read from the widget (e.g. 90 seconds ago), **when** `TronoController.syncTimerFromExternal(timerStart)` runs, **then** `isTimerRunning` becomes `true` and `elapsedTimerSeconds >= 90`.
4. **Given** an active in-app timer, **when** `TronoController.syncTimerFromExternal(null)` runs (e.g. timer was finished or cancelled from the widget while backgrounded), **then** `isTimerRunning` becomes `false` and `elapsedTimerSeconds == 0`.
5. **Given** `TronoController.startTimer()` / `cancelTimer()` / `quickLog()`, **when** invoked, **then** `WidgetSyncService.syncTimerState(...)` is invoked with the exact start timestamp (or `null` on cancel/finish).

## 6. Edge Cases
- **Very long forgotten timer (e.g. > 6 hours):** `WidgetLogPayload` clamps duration to a sensible max (`14400` seconds = 4h) and ignores stale external start timestamps older than 12 hours when hydrating on app resume.
- **Missing `home_widget` channel in unit tests / non-Android:** All `WidgetSyncService` calls catch `MissingPluginException` silently without throwing.
- **Widget partial updates during flash:** `onUpdate` preserves active timer state (child 2) or flash state (child 1) without flickering back to child 0.

## 7. TDD Verification Plan
- **Unit tests to write first (RED → GREEN):**
  - `test/widget_timer_test.dart`: `WidgetLogPayload.tryParseUri` (with duration, without duration, invalid/negative/clamped duration, null/missing type), `TronoController.syncTimerFromExternal` hydration & cancellation & stale-timestamp guard, and `TronoController` timer lifecycle invoking `timerSyncCallback`.
- **Verification:**
  - `dart analyze` → **No issues found!**
  - `flutter test` → 100% passing.

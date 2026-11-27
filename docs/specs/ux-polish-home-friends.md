# Spec: V2.7 UX Polish — Dual-Mode Hero Timer, Clean Home & Simplified Friends

- **Status:** Implemented
- **Target Version / PR:** `v2.7.0` / PR #24
- **Branch:** `feat/v2.7-ux-polish-home-friends`

## 1. Goal
> Make Trono's two most-used tabs (**Home** and **Friends**) calmer and more intuitive: replace the confusing 3-button Home utility bar with a **dual-mode Hero button** that transforms into a live session timer (with real-time 💰 earnings preview during Office/WFH sessions), move **+ Past** discreetly to the History header, remove **False Alarm** from primary Home shortcuts, reorder Friends tabs to **Feed | Ranking | Challenges**, and simplify group sharing to 2 crystal-clear choices (**Share with friends** vs **Private**).

## 2. Non-Goals
- Android Home Widget live `<Chronometer>` and persistent Android timer notifications are planned for V2.8 (out of scope here).
- Do NOT remove `ShareLevel.summaryOnly` from the Dart enum or Supabase Postgres trigger so historical rows and existing privacy tests remain 100% backwards-compatible.
- No SQLite or Supabase migrations.

## 3. Data Model & Privacy Contract
- **Local-only fields:** Live timer state (`_activeTimerStart`, `_elapsedSeconds`) and `hourlyRate` remain strictly local on-device.
- **Sharing defaults:** New installs and default preferences use `ShareLevel.full` (`Share with friends`) or `ShareLevel.private` (`Private`). Exact GPS coordinates (`latitude`, `longitude`) and salary STILL never leave the device.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Friends (`SocialScreen`):**
  - Pinned 3-way tab order: **`Feed` | `Ranking` | `Challenges`** (`Feed` | `Ranking` | `Retos`).
  - Remove the noisy `"Summary only"` badge from `_FeedItemCard`.
  - Move comments out of the reaction emoji strip into a dedicated, unmistakable footer row below reactions (`Add a comment... ›` when empty, or 1-line latest comment preview + `View N comments ›` when populated).
- **2-State Sharing (`SettingsScreen` & `LogDetailSheet`):**
  - Show only `ShareLevel.selectableValues`: **`👥 Share with friends`** (`👥 Compartir con amigos`) and **`🔒 Private`** (`🔒 Solo para mí`).
  - Legacy `summary_only` stored preference normalizes cleanly to `ShareLevel.full`; editing an older `summary_only` log displays as `Share with friends`.
- **Home (`HomeScreen`):**
  - **Location selector:** Replaces the cramped 5-segment strip with a single thumb-friendly tactile pill (`Location: Auto (GPS) ▾`, highlighted gold with `💰` when WFH/Work is active) that opens a clean bottom sheet showing full unabbreviated labels + subtitles (`Auto (GPS)`, `Home`, `WFH / Teletrabajo`, `Work / Trabajo`, `Away`).
  - **Idle state:**
    - Hero 3D button: `👑 CLAIM THRONE` (1-tap instant save).
    - Single clean secondary button below: **`⏱️ Start timer`** (`⏱️ Iniciar cronómetro`).
    - History header row: section title on left + compact **`+ Past`** (`+ Pasada`) button on right.
    - No False Alarm shortcut on Home (remains accessible inside `LogDetailSheet` under Visit Type).
  - **Active Timer state:**
    - Hero 3D button transforms into an Obsidian + Warm Gold live session card showing live `MM:SS` clock, live `💰 +€X.XX` readout when `hourlyRate > 0` and `WFH`/`Work` is selected, and *"Tap to finish & save 👑"*.
    - Single clean secondary button below: **`Cancel timer`** (`Cancelar cronómetro`).

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** `SocialScreen` with an active group, **when** rendered, **then** the 3 pinned tabs appear in exact order `Feed` → `Ranking` → `Challenges`, and tapping `Ranking` shows the leaderboard while `Challenges` shows `GroupChallengesCard` & Group Awards.
2. **Given** `SettingsScreen` or `LogDetailSheet`, **when** privacy options render, **then** only 2 choices (`Share with friends` and `Private`) are shown (no `Summary only` chip).
3. **Given** `HomeScreen` in idle state, **when** rendered, **then** False Alarm is NOT shown on Home, `+ Past` appears in the history header, and a single `Start timer` button sits below the hero button.
4. **Given** the user taps `Start timer` on `HomeScreen`, **when** the timer starts, **then** the Hero button transforms into the Obsidian/Gold live timer card (`Tap to finish & save 👑`) with live `💰` readout if WFH/Work + salary are active, tapping the Hero card finishes & saves the throne with duration, and tapping `Cancel` discards the timer without logging.

## 6. Edge Cases
- **Legacy `summary_only` logs in SQLite/Supabase:** `ShareLevel.fromDb('summary_only')` continues returning `ShareLevel.summaryOnly` for backwards-compatible deserialization; `LogDetailSheet` selects `Share with friends` chip cleanly.
- **Live earnings during timer:** Only shown when `hourlyRate > 0` and `_locationMode` is `wfh` or `work` (never shown for personal Home/Away).
- **Dark mode & EN/ES parity:** Obsidian + Warm Gold active timer card and solid button surfaces work cleanly in both light & dark themes.

## 7. TDD Verification Plan
- **Tests to write first (RED → GREEN):**
  - `test/ux_polish_v27_test.dart`:
    - `ShareLevel.selectableValues` has only `[full, private]` and `SettingsService` normalizes legacy `summary_only` default to `full`.
    - `SocialScreen` tab order `Feed | Ranking | Challenges` (EN & ES) and absence of `"Summary only"` badge on feed card.
    - `HomeScreen` idle layout (no False Alarm button, single `Start timer`, `+ Past` in history header), active dual-mode Hero Timer transformation (with live `💰` readout for WFH/Work + salary), finish-and-save tap, and cancel tap.
    - `LogDetailSheet` & `SettingsScreen` show 2 sharing chips only.
- **Verification:**
  - `dart analyze` → **No issues found!**
  - `flutter test` → 100% passing.

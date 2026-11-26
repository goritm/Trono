# Spec: Group Weekly Challenges & Group Streak (Social++, V2.5)

- **Status:** Implemented
- **Target Version / PR:** `v2.5.0` / PR #__
- **Branch:** `feat/v2.5-group-challenges`

## 1. Goal
> Boost cooperative momentum in Trono's private friend groups with a **🔥 Group Streak** counter and **3 auto-scaled Weekly Challenges** (Squad Goal, Away Squad, Synced Duo) — computed 100% client-side from existing `SocialController` data with zero backend migrations.

## 2. Non-Goals
- No Supabase schema changes, new tables, RPCs, or migrations.
- No push notifications or server-side weekly reset cron jobs.
- No extra XP grants or changes to individual rank progression in this PR.
- No new privacy settings (strictly respects existing `shared_logs` visibility).

## 3. Data Model & Privacy Contract
- **Local-only fields (SQLite / SharedPreferences):** None added. All challenge progress and streak counts are derived in memory from `SocialController` (`feed`, `weeklyLeaderboard`, `selectedGroup`).
- **Cloud-synced fields (Supabase):** Unchanged. Exact GPS coordinates (`latitude`, `longitude`) and salary (`hourlyRate`) never leave the device. Logs marked `private` never enter `shared_logs` and are excluded automatically.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Entry point:** `Friends` (`Amigos`) tab (`SocialScreen`), rendered as `GroupChallengesCard` directly below `_ActiveGroupHeaderCard` for the active group.
- **Layout & Visual Design (Tactile Chunky 3D):**
  - Wrapped in `ChunkyCard` with solid opaque surfaces (light & dark mode).
  - Header row: Trophy icon + `WEEKLY CHALLENGES` / `RETOS SEMANALES` + completion pill (`2/3`).
  - Streak strip: **🔥 Group Streak pill** (`🔥 4d streak` / `🔥 Racha 4d`) + compact weekly activity pill (`4/7 active days` / `4/7 días activos`).
  - 3 mission rows with emoji, localized title & subtitle, `current/target` readout, checkmark icon when completed, and rounded progress bar (`TronoColors.terracotta` in progress → `TronoColors.sage` when completed).
  - Celebratory solid gold banner (`#FFF8E6` light / `#2B2618` dark with `TronoColors.gold` border) when all 3 weekly missions are completed (`allCompleted == true`).
- **Copy reminder:** Uses brand-first `throne` / `thrones` (EN default) and `trono` / `tronos` (ES full parity) with `👑`. No `poop` / `pupú` in user-facing copy.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a group with shared throne logs on consecutive local calendar days ending today (or yesterday if today has no log yet), **when** `GroupChallengesEngine.compute(...)` runs, **then** `groupStreakDays` equals the exact consecutive day count, ignoring `falseAlarm` entries and counting multiple logs on the same day once.
2. **Given** a group with `memberCount` members, **when** `GroupChallengesEngine.compute(...)` runs, **then** targets auto-scale to `teamVolume = max(7, memberCount * 7)`, `awaySquad = max(3, memberCount * 2)`, and `syncedDuo = 1`.
3. **Given** a non-empty `weeklyLeaderboard`, **when** `GroupChallengesEngine.compute(...)` runs, **then** `teamVolume.current` uses the leaderboard sum of `poopCount` and `awaySquad.current` uses the leaderboard sum of `awayCount`; **when** `weeklyLeaderboard` is empty, both fall back to 7-day `feed` throne items (`locationKind?.isAwayFromHome == true` for `awaySquad`).
4. **Given** two different group members log a shared throne within 15 minutes during the last 7 days, **when** `GroupChallengesEngine.compute(...)` runs, **then** `syncedDuo.current >= 1` and `syncedDuo.isCompleted == true`; same-user logs or pairs older than 7 days are excluded.
5. **Given** all 3 weekly challenges have `current >= target`, **when** `GroupChallengesCard` renders, **then** `snapshot.allCompleted` is `true`, progress bars clamp cleanly to `1.0` in `TronoColors.sage`, and the solid gold completion banner is shown in both EN/ES and light/dark themes.

## 6. Edge Cases
- **Offline / empty feed & empty leaderboard:** Renders cleanly with `0d streak`, `0/3`, and safe minimum targets (`7`, `3`, `1`) with no division-by-zero or NaN.
- **Upgrading existing users:** Pure client-side computation over existing `SocialController` state; zero migrations or cache resets required.
- **Timezone / DST / month boundaries:** Streak and `activeDaysThisWeek` use local calendar dates stepped via `DateTime(y, m, d - 1)` so 23h/25h DST transitions never break streaks, and `activeDaysThisWeek` stays bounded in `0..7`.
- **Signed out or no active group:** `SocialController.challenges` returns an empty `GroupChallengesSnapshot`.

## 7. TDD Verification Plan
- **Unit tests to write first (RED → GREEN):**
  - `test/group_challenges_test.dart`: empty state, streak calculation (today, yesterday, broken, multi-log day, falseAlarm exclusion, month/calendar boundary), auto-scaled targets, 7-day window filtering, leaderboard vs feed fallback, away+work counting, synced duo 15-min & distinct-user rules, progress clamping & `allCompleted`.
- **Widget tests:**
  - `test/group_challenges_test.dart`: `GroupChallengesCard` in EN light mode (in-progress), ES dark mode (all completed with gold banner), and empty state.
- **Verification:**
  - `dart analyze` (0 errors, 0 warnings, 0 infos)
  - `flutter test` (100% passing)

# Spec: Android App Shortcuts & Update Release Notes

- **Status:** Implemented
- **Target Version / PR:** `v2.5.0` / PR #17
- **Branch:** `feat/v2.5-shortcuts-and-changelog`

## 1. Goal
> Make 1-tap logging even faster from the Android launcher via native **App Shortcuts** (long-press Trono icon → *Claim Throne* or *Start Timer*) and let users preview **GitHub Release Notes ("What's new")** inside the in-app update banner and Settings before downloading a new APK — while eliminating the last 2 analyzer `info`s so `dart analyze` reports zero issues.

## 2. Non-Goals
- No iOS Home Screen Quick Actions in this PR (Android-first; Dart service safely no-ops on platforms without the native channel).
- No heavy Markdown renderer dependency; GitHub release bodies are formatted into clean, readable lines via a pure Dart parser.
- No SQLite or Supabase schema changes.

## 3. Data Model & Privacy Contract
- **Local-only fields:** None added. Shortcut actions trigger existing local `TronoController.quickLog` / `startTimer` methods.
- **Cloud-synced fields:** Unchanged. Exact GPS & salary stay strictly local. Release notes are already returned inside the existing anonymous read-only GitHub Releases API response (`AppReleaseInfo.releaseNotes`).
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Android App Shortcuts (long-press launcher icon):**
  - `claim_throne`: **EN** `Claim Throne` / **ES** `Registrar Trono` — opens Trono to Home tab and immediately logs 1 throne with instant toast + Undo.
  - `start_timer`: **EN** `Start Timer` / **ES** `Cronómetro` — opens Trono to Home tab and starts the live timer (idempotent if already running).
  - If App Lock is enabled, the shortcut action is queued and runs automatically right after unlocking.
- **Release Notes ("What's new"):**
  - `UpdateBannerCard`: shows a crisp **"What's new"** / **"Ver novedades"** link whenever `release.releaseNotes` is non-empty, opening `showReleaseNotesSheet`.
  - `SettingsScreen`: tapping the available-update `ListTile` opens `showReleaseNotesSheet` when notes exist (or downloads directly if empty).
  - `showReleaseNotesSheet`: Chunky 3D bottom sheet displaying release tag (`vX.Y.Z`), cleaned bullet list of changes, and primary **Download** button.
- **Copy reminder:** Brand-first `throne` / `thrones` (EN) and `trono` / `tronos` (ES) with `👑`.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a raw shortcut string `'claim_throne'` or `'start_timer'`, **when** `AppShortcutAction.tryParse(...)` runs, **then** it returns the matching enum value; unknown/empty strings return `null`.
2. **Given** a pending shortcut received on cold start or warm start, **when** `AppShortcutService` dispatches it, **then** the registered handler executes once (and pending state is cleared).
3. **Given** a GitHub Release markdown body with headings (`## What's Changed`), bullets (`- ...`, `* ...`), bold (`**...**`), and links (`[text](url)`), **when** `ReleaseNotesFormatter.extractLines(body)` runs, **then** it returns clean, readable human lines without raw markdown syntax or blank lines.
4. **Given** an `AppReleaseInfo` with `releaseNotes`, **when** `UpdateBannerCard` renders, **then** the **"What's new"** button is visible and tapping it opens the Release Notes sheet displaying formatted lines and invoking `onDownload` from the sheet's Download button.
5. **Given** an `AppReleaseInfo` without `releaseNotes`, **when** `UpdateBannerCard` renders, **then** the **"What's new"** button is hidden cleanly.

## 6. Edge Cases
- **App Lock enabled on shortcut launch:** Action is deferred in `_TronoShellState` until `onUnlocked` fires so locked history is never bypassed or logged while locked.
- **Timer already running when `start_timer` shortcut fires:** No-op (does not reset elapsed time).
- **Missing native channel (tests / iOS / desktop):** `AppShortcutService` catches `MissingPluginException` silently without throwing.
- **Empty or whitespace-only release notes:** Treated as `null` / empty list.

## 7. TDD Verification Plan
- **Unit & widget tests to write first (RED → GREEN):**
  - `test/shortcuts_and_changelog_test.dart`: `AppShortcutAction.tryParse`, `AppShortcutService` cold/warm dispatch & graceful `MissingPluginException`, `ReleaseNotesFormatter.extractLines` markdown cleanup, `UpdateBannerCard` What's New button visibility & bottom sheet interaction (EN & ES).
- **Verification:**
  - `dart analyze` → **0 errors, 0 warnings, 0 infos**.
  - `flutter test` → 100% passing.

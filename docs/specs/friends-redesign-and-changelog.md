# Spec: Friends UX Redesign, Seasonal Wrapped Flag & Installed Changelog

- **Status:** Implemented
- **Target Version / PR:** `v2.6.0` / PR #20
- **Branch:** `feat/v2.6-friends-redesign-and-changelog`

## 1. Goal
> Simplify the **Friends** (`SocialScreen`) experience to match the calm, pinned-tab pattern of **Stats** and **Map** — moving group switching & invite management into a clean header pill + bottom sheet, separating **Feed**, **Challenges (Retos & Logros)**, and **Ranking** into 3 pinned tabs, gating Personal & Group Wrapped behind a Spotify-style seasonal feature flag (`FeatureFlags.showWrapped`), and making the current version's changelog always accessible from **Settings → App Updates**.

## 2. Non-Goals
- Comments on shared feed logs (`log_comments` Supabase table + Realtime) are intentionally scoped to the next PR (#21).
- Do NOT delete `WrappedScreen`, `GroupWrappedScreen`, `InsightsEngine.buildWrapped`, or `SocialPlusEngine.buildGroupWeeklyWrapped` — only hide their entry-point buttons while `FeatureFlags.showWrapped` is `false`.
- No SQLite or Supabase migrations.

## 3. Data Model & Privacy Contract
- **Local-only / Cloud-synced data:** Unchanged. Exact GPS, Favorite Places, salary, and reminder schedules remain strictly local.
- **Installed Changelog Fetch:** Anonymous read-only `GET https://api.github.com/repos/goritm/Trono/releases/tags/v<version>` using the existing `UpdateCheckerService` HTTP client (zero user data sent, in-memory cache per session, silent error handling when offline).
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Friends (`SocialScreen`) Layout:**
  - `Scaffold` with pinned `AppBar`:
    - Title: `Friends` / `Amigos`.
    - Right actions (only 2 clean controls):
      1. **Group Switcher Pill** (`👑 <GroupName> ▾`): opens a clean **Groups & Invite Bottom Sheet** listing all groups, active group members, invite code (Copy + Share), Create group, Join with code, and Leave group.
      2. **Profile Avatar Button** (compact emoji square with subtle pending-sync dot if needed): opens Edit Profile / Sign out.
  - Pinned 3-way `SegmentedButton` right below `AppBar` (identical styling to `Stats` & `Map`):
    - **Feed** (`Feed` / `Feed`): live activity feed starting immediately at the top (plus a compact 1-line invite nudge only when `memberCount <= 1`).
    - **Challenges** (`Challenges` / `Retos`): `GroupChallengesCard` (Group Streak + 3 Weekly Missions) + Group Awards grid/cards.
    - **Ranking** (`Ranking` / `Ranking`): `7d · 30d · All` filter chips + medal podium cards.
- **Seasonal Wrapped Flag (`lib/config/feature_flags.dart`):**
  - `FeatureFlags.showWrapped = false` hides the Personal Wrapped AppBar button & bottom banner in `CalendarStatsScreen` and hides Group Weekly Wrapped buttons in `SocialScreen`.
- **Always-Accessible Changelog in Settings:**
  - New `ListTile` in **Settings → App Updates**: `What’s new` / `Novedades de esta versión` (`vX.Y.Z`).
  - Opens `showReleaseNotesSheet` in read-only mode (`onDownload == null`, showing a clean Close CTA without a Download button).

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a signed-in user with 2 groups in `SocialScreen`, **when** the screen renders, **then** the 3 pinned tabs (`Feed`, `Challenges`, `Ranking`) and the header Group Switcher pill are visible, Feed shows logs immediately without stacked Challenges/Badges above it, and tapping `Challenges` displays `GroupChallengesCard` & Group Awards.
2. **Given** the user taps the header Group Switcher pill, **when** the bottom sheet opens, **then** all groups, invite code actions, Create group, and Join with code are accessible cleanly.
3. **Given** `FeatureFlags.showWrapped == false`, **when** `CalendarStatsScreen` or `SocialScreen` renders, **then** neither Personal Wrapped nor Group Weekly Wrapped buttons are visible.
4. **Given** `UpdateCheckerService.fetchReleaseByTag('2.5.0')`, **when** GitHub returns a valid release JSON for `v2.5.0`, **then** it parses `AppReleaseInfo` with `releaseNotes` and caches the response in memory; when offline/404, it returns `null` without throwing.
5. **Given** `showReleaseNotesSheet` called with `onDownload: null`, **when** rendered, **then** the formatted release notes and Close button are displayed and no Download button is shown.

## 6. Edge Cases
- **Signed-in user with 0 groups:** Header shows compact `+ Group` pill; body renders `_NoGroupsCard` cleanly without showing the 3-tab bar.
- **Narrow screens (360dp) with long group names:** Group Switcher pill constrains width (`maxWidth: 145`) with `TextOverflow.ellipsis`.
- **Offline when tapping "What’s new" in Settings:** Shows a friendly non-blocking `showTronoToast`.
- **Dark mode & EN/ES parity:** All new cards, sheets, and badges use opaque theme tokens and full EN/ES strings.

## 7. TDD Verification Plan
- **Unit & widget tests to write first (RED → GREEN):**
  - `test/friends_redesign_and_changelog_test.dart`:
    - `UpdateCheckerService.releaseByTagUri` & `fetchReleaseByTag` (success, caching, offline/404).
    - `showReleaseNotesSheet` read-only mode (`onDownload: null` hides download CTA).
    - `FeatureFlags.showWrapped` hides Personal Wrapped entry points in `CalendarStatsScreen`.
    - `SocialScreen` 3-tab separation (`Feed` vs `Challenges` vs `Ranking`) and Group Switcher bottom sheet.
- **Verification:**
  - `dart analyze` → **No issues found!**
  - `flutter test` → 100% passing.

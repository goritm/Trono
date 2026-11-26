# Spec: In-App Update Checker (GitHub Releases)

- **Status:** Implemented
- **Target Version / PR:** `v2.4.0` / PR #13
- **Branch:** `feat/v2.4-in-app-update-checker`

## 1. Goal
Because Trono is distributed directly as signed Android APKs via GitHub Releases (not Google Play), users in private groups need a zero-friction, free way to know when a new version is available and download the updated `.apk` in one tap.

## 2. Non-Goals
- Automatic silent APK downloading or `REQUEST_INSTALL_PACKAGES` in-app installer (avoids scary Android sideload permissions; opening the direct `.apk` URL in the system browser triggers Android's native Download Manager cleanly).
- Paid update servers or third-party analytics SDKs.
- Forced / blocking update modals (Trono remains 100% usable offline and never blocks logging).

## 3. Data Model & Privacy Contract
- **Local-only fields (`SharedPreferences`):**
  - `update_last_checked_ms`: timestamp (epoch ms) of the last automatic check (12-hour throttle).
  - `update_dismissed_tag`: tag string (e.g. `v2.4.0`) dismissed by the user on the Home banner.
- **Network call (read-only, anonymous):**
  - `GET https://api.github.com/repos/goritm/Trono/releases/latest` with `Accept: application/vnd.github+json` and `User-Agent: Trono-App`, 5-second timeout.
  - Zero user identifiers, zero logs, zero GPS/salary data ever sent.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Home (`Registrar`):** When a newer published release exists and has not been dismissed for that tag, show a compact, tactile Warm Gold/Obsidian banner (`UpdateBannerCard`) right above the HUD card with:
  - Version badge (`v2.4.0 disponible`), brief subtitle, **Descargar** button (launches `.apk` download URL externally), and `×` dismiss button.
- **Settings (`Ajustes`):** Add an **Actualizaciones / Versión** card at the bottom showing the currently installed version (`Trono vX.Y.Z`), update status, and a **"Buscar actualizaciones"** button that forces a fresh check (ignoring the 12h throttle and dismissed state) and shows a `showTronoToast` or download CTA.
- Spanish copy strictly uses `pupú` / `Pupú` / `pupús` where applicable.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** installed version `2.3.0` and latest GitHub Release `v2.4.0` with a `.apk` asset, **when** the update checker runs, **then** it reports `hasUpdate == true`, picks the `.apk` `browser_download_url` as `downloadUrl`, and surfaces `UpdateBannerCard` on Home.
2. **Given** latest release has no `.apk` asset, **when** parsed, **then** `downloadUrl` falls back to the release `html_url`.
3. **Given** latest release is `draft: true` or `prerelease: true`, or its version is `<=` installed version, **when** checked, **then** it reports `hasUpdate == false`.
4. **Given** the user dismisses the banner for `v2.4.0`, **when** the app restarts on `v2.3.0`, **then** the Home banner stays hidden for `v2.4.0`, **but** re-appears if `v2.5.0` is later published (and Settings manual check still finds `v2.4.0`).
5. **Given** an automatic check ran less than 12 hours ago, **when** another automatic check is requested, **then** no network request is made; **when** the user taps *"Buscar actualizaciones"* in Settings (`force: true`), **then** it performs a fresh request immediately.
6. **Given** the device is offline, times out, or GitHub returns 403/500, **when** checked automatically, **then** it fails silently with zero exceptions or disruptive toasts.

## 6. Edge Cases
- Offline / airplane mode / slow DNS: 5-second timeout, caught cleanly.
- SemVer multi-digit comparison: `2.10.0` MUST be greater than `2.9.9` (numeric comparison, never lexicographic string compare).
- Build metadata / prefixes: strips leading `v` and trailing `+buildNumber` (e.g. `v2.4.0+4` → `2.4.0`).
- Invalid/non-semver tags (e.g. `nightly`): safely returns `null` without throwing.

## 7. TDD Verification Plan
- **Unit tests written first (RED → GREEN) in `test/update_checker_test.dart`:**
  - `SemVer.tryParse` & numeric comparison (`2.10.0 > 2.9.9`, prefixes/build numbers, invalid strings).
  - `AppUpdateChecker.parseLatestRelease` (prefers `.apk` asset, falls back to `html_url`, skips draft/prerelease).
  - `UpdateCheckerService` 12h throttle, `force: true` bypass, dismissal per tag, and offline error resilience.
- **Widget tests in `test/update_checker_test.dart`:**
  - `UpdateBannerCard` renders version tag, triggers download callback, and triggers dismiss callback.
- **Final checks:** `dart analyze` (0 errors, 0 warnings) & `flutter test` (100% passing).

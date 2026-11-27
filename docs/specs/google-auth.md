# Spec: Google Sign-In & Sign-Up via Supabase OAuth (PKCE Deep Link)

- **Status:** Implemented
- **Target Version / PR:** `v2.7.0` / PR #27
- **Branch:** `feat/v2.7-google-auth`

## 1. Goal
> Allow users to create an account or sign in to **Trono Cloud** in 1 tap using **Continue with Google** via Supabase OAuth (`OAuthProvider.google`) with PKCE deep-link return (`com.trono.trono://login-callback`) — working across Friends, Settings, and Onboarding without requiring any extra native SDK or Play Console SHA-1 setup.

## 2. Non-Goals
- Native Android One-Tap / `google_sign_in` ID Token flow (deferred to a later release if desired; shares the exact same Supabase `auth.users` & `public.profiles` records).
- Apple Sign-In or other OAuth providers.
- Any Postgres schema or RLS migration (existing `private.handle_new_user()` trigger and `public.profiles` RLS policies already handle Google OAuth users cleanly).

## 3. Data Model & Privacy Contract
- **Redirect URI:** `com.trono.trono://login-callback` (non-web mobile deep link) registered in Android `AndroidManifest.xml` (`MainActivity`) and iOS `Info.plist` (`CFBundleURLTypes`).
- **Supabase Security:** Uses ONLY `SupabaseConfig.url` and modern publishable key (`sb_publishable_...`). OAuth Client Secret lives strictly on Supabase servers — NEVER in client code.
- **Profile Metadata Fallback:** When creating a missing `public.profiles` row on first sync, `SupabaseSyncService.resolveDisplayNameFromMetadata` checks `display_name` → `full_name` → `name` → email prefix → `'Trono'` (trimmed & clamped to 32 chars matching `profiles.display_name` CHECK constraint). Never used for authorization.
- **Device-Only Invariants Unchanged:** Exact GPS (`latitude`, `longitude`), Home coords, Favorite Places, and hourly salary remain 100% local on-device.

## 4. User Experience & Copy
- **Auth Sheet (`showAuthSheet` / `_AuthSheet`):**
  - Displays a prominent Chunky 3D **Continue with Google** (`Continuar con Google`) button with a crisp Google `G` emblem in both **Create free account** and **Sign in** tabs, separated from the email/password form by an `or with email` (`o con correo`) divider.
  - Works seamlessly across all 3 entry points: **Onboarding**, **Friends tab**, and **Settings → Account & Cloud**.
- **OAuth Browser Handoff & Auto-Dismiss:**
  - Tapping **Continue with Google** launches the external browser / Custom Tab via `SupabaseSyncService.signInWithGoogle()` (forcing `LaunchMode.externalApplication` on Android as handled by `supabase_flutter` so Google never blocks the user-agent).
  - Shows a clear non-blocking status banner (`Complete sign-in with Google in your browser to continue.` / `Completa el acceso con Google en el navegador para continuar.`) so if the user cancels the browser tab, they are never stuck on an infinite spinner.
  - `_AuthSheet` listens to `SocialController`: the instant `isSignedIn` becomes `true` after deep-link return, the sheet auto-closes cleanly!

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** `SupabaseConfig.oauthRedirectUrl`, **when** inspected, **then** it equals `'com.trono.trono://login-callback'`.
2. **Given** OAuth user metadata from Google (`full_name` / `name` / very long string > 32 chars / empty), **when** `SupabaseSyncService.resolveDisplayNameFromMetadata(...)` runs, **then** it prioritizes `display_name` → `full_name` → `name` → email prefix → `'Trono'` and clamps to max 32 chars.
3. **Given** `SocialController.signInWithGoogle()`, **when** invoked, **then** it delegates to `SupabaseSyncService.signInWithGoogle()` and returns its launch status (`true` / `false`).
4. **Given** `_AuthSheet` opened in EN or ES locale, **when** rendered, **then** it displays the **Continue with Google** (`Continuar con Google`) button and `or with email` (`o con correo`) divider in both Sign Up and Sign In modes.
5. **Given** the user taps **Continue with Google**, **when** `signInWithGoogle()` returns `true` and `SocialController` subsequently transitions to `isSignedIn == true`, **then** `_AuthSheet` shows the browser-handoff hint and automatically closes upon sign-in.
6. **Given** `signInWithGoogle()` returns `false` or throws `AuthException`, **when** the user taps **Continue with Google**, **then** `_AuthSheet` displays an error message and stays interactive.

## 6. Edge Cases
- **User cancels Chrome Custom Tab:** Buttons remain enabled after launching browser so the user can retry Google or use email/password immediately.
- **Offline / Cloud unconfigured:** `signInWithGoogle()` throws a clear error handled inside `_AuthSheet` without crashing.
- **Existing email/password user:** Automatic account linking / sign-in is handled natively by Supabase Auth; existing `public.profiles` row is never overwritten.

## 7. TDD Verification Plan
- **RED → GREEN Tests:** `test/google_auth_test.dart` covering all 6 acceptance criteria.
- **Native Verification:** `./gradlew :app:compileDebugKotlin` → `BUILD SUCCESSFUL` verifying `AndroidManifest.xml` deep link & `<queries>` entries.
- **Full Suite:** `dart analyze` → `No issues found!`, `flutter test` → 100% passing.

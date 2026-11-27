# Spec: Native Android Google One-Tap Sign-In (Credential Manager + OAuth Fallback)

- **Status:** Implemented
- **Target Version / PR:** `v2.8.1` / PR #30
- **Branch:** `fix/v2.8.1-quick-false-alarm-and-hero-logo`

## 1. Goal
> Upgrade **Continue with Google** on Android from Chrome Custom Tabs to the native 1-tap **Android Credential Manager** bottom sheet (`GetGoogleIdOption` + `Supabase.auth.signInWithIdToken`) with cryptographic SHA-256 nonce verification — while preserving automatic seamless fallback to Chrome OAuth if Play Services or `default_web_client_id` is unavailable.

## 2. Non-Goals
- No third-party `google_sign_in` Flutter plugin dependency (uses official AndroidX `credentials` + `googleid` directly, keeping AGP 9.3 builds clean and fast).
- No client secrets in app code (only public `default_web_client_id` auto-generated from `google-services.json` or optional `GOOGLE_WEB_CLIENT_ID` dart-define).

## 3. Security & Privacy Contract
- **Cryptographic Nonce:** Generates a 32-byte `Random.secure()` `rawNonce` in Dart, sends `sha256(rawNonce)` to Android `GetGoogleIdOption.setNonce(...)`, and passes `rawNonce` to `Supabase.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: ..., nonce: rawNonce)` so Supabase verifies the ID token nonce server-side.
- **Zero Secrets in Repo:** Client ID is read from `R.string.default_web_client_id` (generated from gitignored `google-services.json`) or optional `--dart-define=GOOGLE_WEB_CLIENT_ID=...`.

## 4. Acceptance Criteria (Given / When / Then)
1. **Given** `GoogleNativeAuthService.generateNonce()`, **when** called twice, **then** it produces distinct 32+ char URL-safe strings and `hashNonce(raw)` returns its lowercase 64-char SHA-256 hex digest.
2. **Given** a mocked `MethodChannel('com.trono.trono/google_auth')` returning `{'status': 'ok', 'idToken': 'jwt.token'}`, **when** `requestIdToken()` runs, **then** it returns `GoogleNativeAuthStatus.ok` with both `idToken` and the matching `rawNonce`.
3. **Given** native returns `{'status': 'cancelled'}`, **when** `requestIdToken()` runs, **then** it returns `GoogleNativeAuthStatus.cancelled` (so UI stops spinning without opening Chrome or showing an error).
4. **Given** native returns `{'status': 'unavailable'}` or throws `MissingPluginException`, **when** `requestIdToken()` runs, **then** it returns `GoogleNativeAuthStatus.unavailable` so `SupabaseSyncService.signInWithGoogle()` automatically falls back to browser OAuth.

## 5. TDD Verification Plan
- `test/native_google_auth_test.dart`: covers all 4 acceptance criteria.
- `./gradlew :app:processDebugMainManifest :app:compileDebugKotlin`: `BUILD SUCCESSFUL` with 0 warnings in `:app`.
- `dart analyze` → `No issues found!`, `flutter test` → 100% passing.

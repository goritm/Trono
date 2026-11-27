# Spec: Social Push Notifications (FCM + Native Android Channels)

- **Status:** Implemented
- **Target Version / PR:** `v2.8.0` / PR #28
- **Branch:** `feat/v2.8-social-push-notifications`

## 1. Goal
> Deliver instant, 1-second Android push notifications via **Supabase Edge Function + Firebase Cloud Messaging (FCM HTTP v1)** whenever a friend in your group claims a throne, posts a comment/message, or adds a reaction — backed by **3 independent native Android Notification Channels** so users can toggle, silence, or customize sounds for each category individually in **Android System Notification Settings** AND inside **Trono Settings**.

## 2. Non-Goals
- No third-party FlutterFire Dart plugins (`firebase_core`/`firebase_messaging`) that conflict with AGP 9.3; uses native Android `com.google.firebase:firebase-messaging` SDK directly with conditional Gradle application so builds never break without `google-services.json`.
- No exact GPS coordinates, salary, or `private` logs are ever included in push payloads.
- No iOS APNs implementation in this PR (Android-first; `push_tokens.platform` supports `'ios'` for future expansion).

## 3. Data Model & Privacy Contract
- **Supabase Migration (`supabase/migrations/20261127000002_social_push_notifications.sql`):**
  - Enables `pg_net` (`extensions` schema).
  - Creates `public.push_tokens` (`id`, `user_id` FK `ON DELETE CASCADE`, `token` UNIQUE, `platform`, `locale`, `notify_friend_thrones`, `notify_friend_comments`, `notify_friend_reactions`, `created_at`, `updated_at`) with index on `user_id` and strict RLS (`TO authenticated` + `(select auth.uid()) = user_id` for SELECT/INSERT/UPDATE/DELETE).
  - Creates RPC `public.upsert_my_push_token(...)` (`SECURITY DEFINER`, `SET search_path = ''`, explicit `auth.uid()` check) to safely reassign a device token if a user switches accounts on the same phone.
  - Creates `private.push_webhook_config` (non-exposed schema, revoked from `public`/`anon`/`authenticated`) + `private.dispatch_social_push()` trigger (`AFTER INSERT` on `public.shared_logs`, `public.log_comments`, `public.log_reactions`) invoking the Edge Function asynchronously via `net.http_post`.
  - **Privacy & Anti-Spam Guards:**
    - `private` logs never enter `shared_logs` → never trigger push notifications.
    - `shared_logs` pushes only fire for `type = 'poop'` with `timestamp >= now() - interval '15 minutes'` (prevents offline-sync backfill storms).
    - Actor never receives their own push notification.
    - Exact GPS & salary never exist in Supabase or push payloads.
- **Supabase Edge Function (`supabase/functions/send-social-push/index.ts`):**
  - Verifies `x-trono-webhook-secret` header (`401` on mismatch).
  - Resolves group-mate recipients respecting per-category boolean flags (`notify_friend_thrones`, `notify_friend_comments`, `notify_friend_reactions`).
  - Sends **data-only** FCM HTTP v1 payloads (RS256 service-account JWT via Web Crypto) so Android renders localized EN/ES notifications on the exact channel even when the app is killed, and auto-prunes `UNREGISTERED` tokens.
  - Gracefully returns `200 { ok: true, skipped }` when `FIREBASE_SERVICE_ACCOUNT_JSON` secret is not configured yet.

## 4. Android Native Channels & UX
- **5 Native Android `NotificationChannel`s registered on app launch** (grouped into *Friends & Social* and *Personal & Timer*):
  1. `trono_friend_thrones` — **Friend thrones** / **Tronos de amigos** (`IMPORTANCE_DEFAULT`)
  2. `trono_friend_comments` — **Messages & comments** / **Mensajes y comentarios** (`IMPORTANCE_HIGH`)
  3. `trono_friend_reactions` — **Reactions** / **Reacciones** (`IMPORTANCE_DEFAULT`)
  4. `trono_reminders` — **Reminders** / **Recordatorios** (`IMPORTANCE_DEFAULT`)
  5. `trono_live_timer` — **Live Throne Timer** / **Cronómetro en vivo** (`IMPORTANCE_LOW`)
- **In-App Settings (`SettingsScreen`):**
  - 3 independent toggles (`Friend thrones`, `Messages & comments`, `Reactions`) persisted locally in `SharedPreferences` and synced to `public.push_tokens`.
  - Direct **"Android notification settings"** row opening `Settings.ACTION_APP_NOTIFICATION_SETTINGS` so users can customize each channel natively.
- **Tap Deep-Nav:** Tapping any social notification opens Trono directly to the **Friends** tab.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** `SocialNotificationChannel` enum values, **when** inspected, **then** their Android channel IDs are exactly `'trono_friend_thrones'`, `'trono_friend_comments'`, and `'trono_friend_reactions'`.
2. **Given** `SocialNotificationPrefs` defaults and `copyWith`, **when** serialized via `toPlatformMap()`, **then** all 3 boolean flags default to `true` and update independently.
3. **Given** a mocked `MethodChannel('com.trono.trono/push')`, **when** `PushNotificationService.ensureChannels(locale)`, `getFcmToken()`, `openSystemNotificationSettings()`, and `consumeInitialOpenTab()` are called, **then** the expected platform methods & arguments are invoked (and `MissingPluginException` degrades cleanly without throwing).
4. **Given** `SocialController` with a signed-in fake service and mocked push channel returning an FCM token, **when** initialized or when a social notification toggle changes, **then** `upsertMyPushToken` is invoked with the token, locale, and updated preferences, and `deletePushToken` is invoked on `signOut()`.
5. **Given** `SettingsScreen` rendered in EN and ES, **when** toggling Friend thrones / Messages & comments / Reactions or tapping Android notification settings, **then** preferences persist and `openNotificationSettings` is called on the platform channel.

## 6. Edge Cases
- **No `google-services.json` yet:** Conditional Gradle plugin (`if (file("google-services.json").exists())`) compiles cleanly; `getFcmToken()` returns `null` safely without crashing.
- **Android 13+ notification permission denied:** `TronoMessagingService` checks `POST_NOTIFICATIONS` before calling `notify()`.
- **Offline toggle change:** Local `SharedPreferences` updates immediately; Supabase `upsert_my_push_token` syncs next time online/signed in.

## 7. TDD Verification Plan
- **RED → GREEN Tests:** `test/social_push_notifications_test.dart` covering all 5 acceptance criteria.
- **Database Verification:** `get_advisors` (`security` + `performance`) after applying `20261127000002_social_push_notifications.sql` → 0 new warnings.
- **Native + Dart Verification:** `dart analyze` → `No issues found!`, `flutter test` → 100% passing, `./gradlew :app:processDebugMainManifest :app:compileDebugKotlin` → `BUILD SUCCESSFUL`.

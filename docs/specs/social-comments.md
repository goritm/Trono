# Spec: Comments on Shared Feed Logs

- **Status:** Implemented
- **Target Version / PR:** `v2.6.0` / stacked on PR #20 (`feat/v2.6-friends-redesign-and-changelog`)
- **Branch:** `feat/v2.6-social-comments`

## 1. Goal
Allow friends inside a private Trono group to leave short, real-time comments (1–280 characters) on shared feed thrones (`summary_only` or `full`), keeping the feed cards clean via a compact `💬` pill that opens a dedicated Comments Bottom Sheet.

## 2. Non-Goals
- Editing existing comments after posting (users can delete their own comments and post a new one).
- Nested/threaded replies, @mentions, image/media attachments, or push notifications for comments.
- Commenting on `private` logs (private logs never enter `shared_logs`).
- Offline comment queue / local SQLite caching of comments (comments require an active cloud session and revert cleanly on error).

## 3. Data Model & Privacy Contract
- **Local-only fields (SQLite / SharedPreferences):** None. Exact GPS coordinates (`latitude`, `longitude`), Home base, Favorite Places, and work salary remain strictly local and are never exposed in comments or feed queries.
- **Cloud-synced fields (Supabase — new `public.log_comments` table):**
  - `id` (`uuid`, primary key, default `gen_random_uuid()`)
  - `log_id` (`uuid`, not null, references `public.shared_logs(log_id) on delete cascade`)
  - `user_id` (`uuid`, not null, references `public.profiles(id) on delete cascade`)
  - `body` (`text`, not null, `check (char_length(btrim(body)) between 1 and 280)`)
  - `created_at` (`timestamptz`, not null, default `now()`)
- **Row-Level Security (RLS) Contract on `public.log_comments`:**
  - RLS enabled; all policies scoped `TO authenticated` using `(select auth.uid())` and `private.shares_group_with(...)`.
  - `SELECT`: allowed only if the authenticated user is the owner of the referenced `shared_logs` row OR shares a group with its owner.
  - `INSERT`: allowed only if `user_id = (select auth.uid())` AND the authenticated user can view the referenced `shared_logs` row.
  - `DELETE`: allowed only if `user_id = (select auth.uid())` (authors can delete only their own comments).
  - `UPDATE`: disallowed (no policy).
  - Cascade privacy guarantee: because `log_id` references `public.shared_logs(log_id) on delete cascade`, `private` or deleted logs can never receive comments, and switching a log to `private` (which deletes its `shared_logs` projection via `private.sync_shared_log()`) automatically deletes all its comments.
- **Supabase Migration Required:**
  - `supabase/migrations/20261127000001_log_comments.sql` creating `public.log_comments`, indexes (`idx_log_comments_log_created`, `idx_log_comments_user_id`), RLS policies, and idempotently adding `public.log_comments` to `supabase_realtime`. Backwards-compatible; zero breaking changes to existing tables.

## 4. User Experience & Copy (ES / EN)
- **Feed Card Entry Point (`_FeedItemCard`):**
  - Alongside the 4 reaction pills (`👑 🔥 💀 👏`), display a compact `💬` Comment pill (`ValueKey('feed_comment_btn_${item.logId}')`) showing `💬` when there are 0 comments or `💬 <count>` when comments exist (subtle highlight if comments > 0).
- **Comments Bottom Sheet (`_CommentsSheet`):**
  - Keyboard-aware modal sheet (`isScrollControlled: true`, respects `viewInsets.bottom` + safe area).
  - **Header:** Author avatar, display name, throne type & relative timestamp, plus comment count badge.
  - **Body (Scrollable):**
    - Empty state when 0 comments: `No comments yet — be the first!` (EN) / `Sin comentarios aún — ¡sé el primero!` (ES).
    - Chronological list (oldest → newest) of comments showing avatar emoji, display name, relative timestamp, comment text, and a subtle delete icon button (`ValueKey('comment_delete_btn_${comment.id}')`) **only** on comments authored by the current user (`comment.userId == currentUserId`).
  - **Composer Bar:** TextField (`maxLength: 280`, hint `Add a comment...` / `Añade un comentario...`) + Terracotta send button (`ValueKey('comment_send_btn')`), disabled when trimmed text is empty or submitting.
  - **Error Handling:** Optimistic insert/delete updates the UI immediately; on network/server failure, rolls back cleanly and displays a `showTronoToast(...)` error message.
  - **Theme & Copy:** Full Light & Dark mode support via `TronoColors`, brand-first copy (`throne` / `trono`), English default + full Spanish parity.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a shared log in a group feed, **when** `LogComment.fromMap` parses a joined Supabase row with nested `profiles`, **then** `id`, `logId`, `userId`, `displayName`, `avatarEmoji`, `body`, and local `createdAt` are accurately populated (with safe defaults if profile fields are missing).
2. **Given** raw user comment input, **when** `LogComment.validateBody` is called with empty/whitespace-only text or text exceeding 280 characters (after trimming), **then** it returns `null`; otherwise it returns the trimmed valid string (1..280 chars).
3. **Given** an authenticated group member on the Friends → Feed tab, **when** they tap the `💬` pill on a feed card, **then** the Comments Bottom Sheet opens displaying the log header, existing comments in chronological order, and a delete button exclusively on the current user's own comments.
4. **Given** the Comments Bottom Sheet is open, **when** the user types a valid comment and taps send (`comment_send_btn`), **then** the comment appears immediately (optimistically), the feed card pill count increments, and the optimistic placeholder is replaced with the persisted server comment upon success (or rolled back cleanly on error).
5. **Given** the user's own comment in the Comments Bottom Sheet, **when** they tap its delete icon, **then** the comment is removed immediately (optimistically) and stays removed on server success (or restores on error).
6. **Given** Supabase RLS on `public.log_comments`, **when** tested transactionally (`BEGIN ... ROLLBACK`), **then** a group mate can `INSERT` and `SELECT` comments on a shared log, a non-member cannot `SELECT` or `INSERT`, a user cannot `DELETE` another user's comment, and empty or >280-char bodies are rejected by the check constraint.

## 6. Edge Cases
- **Offline / network failure:** Optimistic add/delete reverts to previous state and shows a toast via `showTronoToast`; never crashes or leaves stuck spinners.
- **Whitespace / >280 chars:** Client trims and enforces 1..280 chars before sending; Postgres `CHECK (char_length(btrim(body)) between 1 and 280)` enforces it server-side.
- **Realtime updates:** Subscribing to `public.log_comments` inside `subscribeToSocialUpdates` triggers debounced `refreshSocial()`, automatically updating the open sheet via `ListenableBuilder` on `SocialController`.
- **Upgrading existing users:** Purely additive table + nullable/defaulted `comments = const []` on `SharedFeedItem`; zero local SQLite migration required.
- **Log deleted or switched to `private`:** `ON DELETE CASCADE` from `shared_logs` cleans up comments; if open sheet's log disappears from feed, sheet gracefully uses the fallback snapshot item.

## 7. TDD Verification Plan
- **Unit tests to write first (RED → GREEN):**
  - `test/social_comments_test.dart`:
    - `LogComment.fromMap` parsing (nested `profiles`, fallbacks, timestamp conversion).
    - `LogComment.validateBody` (empty, spaces-only, trimmed valid, exact 280 chars, 281 chars).
    - `SharedFeedItem.copyWith(comments: ...)` and `SharedFeedItem.fromMap(..., comments: ...)`.
    - `SocialController.addComment` & `deleteComment` optimistic update, server reconciliation, and rollback on failure.
- **Widget tests:**
  - `test/social_comments_test.dart`:
    - Feed card displays `💬` pill (without count when 0, with count `2` when 2 comments).
    - Tapping `feed_comment_btn_<logId>` opens Comments Bottom Sheet showing empty state or chronological comments.
    - Delete icon appears ONLY on current user's own comments, NOT on friends' comments.
    - Typing a comment and tapping `comment_send_btn` adds the comment and updates the sheet + pill count; tapping delete removes own comment.
    - Full EN & ES copy verification.
- **Manual / DB verification:**
  - `dart analyze` (0 errors, 0 warnings)
  - `flutter test` (100% passing)
  - Supabase `apply_migration` on `cxibpwmcnehnaaowpumx` + transactional RLS test (`BEGIN ... ROLLBACK`) via `execute_sql` + `get_advisors` (`security`, `performance`).

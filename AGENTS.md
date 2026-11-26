# AGENTS.md — Trono Engineering Guide

This repository contains **Trono**, an offline-first, bilingual (ES default / EN) Flutter mobile app (Android-first, iOS-ready) with Supabase multiplayer sync, interactive territory maps, gamification, and an Android Home Screen Widget.

All human contributors and AI coding agents MUST follow the workflows, invariants, and conventions in this document.

---

## 1. Development Methodology: SDD + TDD

We build **Trono** using **Spec-Driven Development (SDD)** paired with **Test-Driven Development (TDD)**.

### Phase 1 — SDD (Spec First)
Before writing production code for any new feature, schema change, or non-trivial refactor:
1. Create a short spec in `docs/specs/<slug>.md` using [docs/specs/_template.md](docs/specs/_template.md). *(Skip only for 1–2 line copy/typo fixes.)*
2. Define explicitly:
   - **Goal & Non-Goals** (keep scope tight; one milestone = one branch & PR).
   - **Privacy & Data Contract** (local SQLite vs `SharedPreferences` vs Supabase cloud; confirm what MUST stay local).
   - **Acceptance Criteria** in clear `Given / When / Then` statements.
   - **Edge Cases** (offline mode, empty state, DST/midnight boundaries, upgrade from previous DB version, dark mode).
3. Resolve ambiguous product or UX decisions with the user **before** coding.

### Phase 2 — TDD (Red → Green → Refactor)
1. **Isolate pure logic:** Place domain calculations, mappers, engines, and privacy redaction in pure, UI-free Dart files under `lib/models/` or `lib/services/` so they are trivially unit-testable.
2. **RED:** Write unit tests (for engines, serialization, migrations, privacy rules) and/or widget tests (for user flows and regressions) in `test/` **first**, directly encoding the spec's acceptance criteria. Run `flutter test` and verify the new tests fail for the expected reason.
3. **GREEN:** Write the simplest, cleanest implementation that makes all tests pass.
4. **REFACTOR:** Eliminate duplication, refine widget composition and naming, and ensure all tests remain green.
5. **VERIFY (Definition of Done):**
   - `dart analyze` → **0 errors, 0 warnings**.
   - `flutter test` → **100% passing** (including new tests for the feature/bugfix).
   - Any bug fix MUST include a regression test that would have caught the bug.
   - Any Supabase DDL/RLS change MUST be verified with a transactional RLS test (`BEGIN ... ROLLBACK`) and `get_advisors` (`security` + `performance`).

---

## 2. Architecture & Navigation Map

### Clean 4-Tab Navigation (V2.3+)
- **Bottom `NavigationBar` (4 tabs):**
  1. **⚡ Registrar (`HomeScreen`):** Instant 1-tap logging, compact location selector (`Auto · Casa · Trabajo · Fuera`), live timer / false alarm / past visit bar, today's swipeable history (`LogTile`). Top bar hosts `Trono` icon + Streak/XP pills (XP & `NV.X` jump to Awards) + `⚙️` Settings button.
  2. **📊 Stats (`CalendarStatsScreen`):** Pinned 3-way sub-tabs:
     - `Calendario`: Monthly heatmap, Peak Hours, Personal Records.
     - `Análisis`: Daily average, Monthly Comparison, 8-week trend chart, Paid on the Throne, Insights, Trono Wrapped.
     - `Logros`: Embedded `AchievementsScreen` (Rank Ladder + 22 Badges).
  3. **🗺️ Mapa (`MapScreen`):** Pinned 2-way sub-tabs:
     - `Mapa`: Interactive OpenStreetMap (`flutter_map`) with filters and clustered pins.
     - `Lugares ⭐`: Embedded `FavoritePlacesScreen` (Home vs Away territory ratio, saved GPS Favorite Places, Top Bathrooms ⭐).
  4. **👥 Amigos (`SocialScreen`):** Private 6-letter invite-code groups, live Realtime feed with `⚡ Dúo Sincronizado` detection and emoji reactions (`👑`, `🔥`, `💀`, `👏`), 7d/30d/All leaderboards, group badges, and Group Weekly Wrapped.
- **Top-Right Settings/Profile (`SettingsScreen`):** Pushed via `Navigator.push`, wrapped in its own `Scaffold` + `ListenableBuilder`, containing Account & Cloud Sync, direct **🏆 Logros y Rangos** shortcut, Appearance/Language/Replay Welcome, Location & Favorites, Salary (local), Security/Biometric/PIN lock, and JSON/CSV Backup.

### State & Data Layers
- **Local DB (`lib/data/database_helper.dart`):** `LocalBathroomRepository` (`trono.db`, SQLite v3). Source of truth for instant 0 ms offline-first writes. Always write forward-compatible `onUpgrade` migrations (`if (oldVersion < N)`).
- **Local Settings (`lib/services/settings_service.dart`):** `SharedPreferences` for theme, locale, Home GPS, Favorite Places, salary, PIN hash (SHA-256), onboarding flag, and selected group.
- **State Controllers:**
  - `TronoController` (`lib/state/trono_controller.dart`): owns local logs, derived stats, gamification, insights, monthly comparison, favorite places, and live timer.
  - `SocialController` (`lib/state/social_controller.dart`): owns Supabase auth, offline-first sync, groups, live feed, optimistic reactions, leaderboards, and `SocialPlusEngine`.

---

## 3. Non-Negotiable Privacy & Security Invariants

1. **Device-Only Data (NEVER synced to cloud):**
   - Exact GPS coordinates (`latitude`, `longitude`) on logs.
   - Home base coordinates and `FavoritePlace` coordinates.
   - Work salary (`hourlyRate`).
   - When pulling remote logs from Supabase, `CloudLogMapper.fromSupabaseRow` MUST preserve existing local-only fields (`latitude`, `longitude`, `rating`).
2. **Per-Log Share Privacy (`ShareLevel`):**
   - `private`: owner-only; MUST NOT appear in `shared_logs`, group feeds, or leaderboards.
   - `summary_only`: redacted at the **Postgres trigger level** (`private.sync_shared_log()`) so `bristol_type`, `size`, `effort`, `duration_seconds`, `color`, `tags`, `note`, and `place_label` are `NULL` in `shared_logs`.
   - `full`: shared with group mates (still never includes lat/lng or salary).
3. **Supabase Security Rules:**
   - Client app uses ONLY `SupabaseConfig.url` and modern publishable key (`sb_publishable_...`). **NEVER** embed or commit `service_role` or secret keys.
   - Enable RLS on **every** table in `public`. Use `TO authenticated` + `(select auth.uid())` (never deprecated `auth.role()`, never `user_metadata` for authorization).
   - `UPDATE` policies MUST specify both `USING` and `WITH CHECK` (plus a `SELECT` policy).
   - Put RLS helper functions in non-exposed `private` schema with `SET search_path = ''` and explicit `auth.uid()` checks.
   - Commit every schema migration to `supabase/migrations/`.
4. **Signing Secrets:**
   - `android/key.properties`, `*.jks`, and `*.keystore` are strictly gitignored and NEVER committed. CI/CD decodes them from GitHub Actions Secrets.

---

## 4. Flutter, Dart & UI Conventions

- **SDK:** Flutter 3.50+ / Dart 3.14+.
- **Material Import:** Always import `package:material_ui/material_ui.dart` (NOT deprecated `package:flutter/material.dart`).
- **Localizations:** Always use `GlobalMaterialLocalizations.delegates` (includes Material, Widgets, and Cupertino delegates).
- **Copy & Terminology:**
  - App name: **Trono** (package `trono`, Android `com.trono.trono`). Never use old draft names.
  - Spanish default (`Locale('es')`) + full English parity (`Locale('en')`) in `lib/l10n/app_strings.dart`.
  - In Spanish, ALWAYS write **`pupú` / `Pupú` / `pupús`** (with accent on `ú`). Never `popó` or unaccented `pupu` in user-facing text.
- **Visual Design System (Tactile Chunky 3D):**
  - Palette (`lib/theme/app_theme.dart`): Terracotta (`#E05A2B`), Warm Gold (`#F5B82E`), Obsidian (`#1E222B`), Sage (`#2F855A`), Coral (`#D64545`), on Warm Cream (`#F7F4EE`, light) / Deep Obsidian (`#13161C`, dark).
  - Use `ChunkyButton`, `ChunkyCard` (Material-backed so `ListTile` ink splashes work cleanly), and `ChunkyHudPill` from `lib/widgets/chunky_widgets.dart`.
  - **Opaque surfaces over lips:** Never use semi-transparent card fills over an opaque colored `lipColor` (use solid tones like `#FFF8E6` light / `#2B2618` dark for gold highlights).
  - **GridView inside scrollables:** Always pass `padding: EdgeInsets.zero` to avoid inherited `MediaQuery.padding.top` gaps.
  - **Safe animations:** Never pass overshooting curves (e.g. `Curves.easeOutBack`) into a `TweenSequence` (throws in release mode as a grey `ErrorWidget`). Use monotonic curves (`Curves.easeOutCubic`, `Curves.easeOut`).
  - **Toasts / SnackBars:** Always call `showTronoToast(...)` or `showTronoToastOnMessenger(...)` from `lib/widgets/trono_toast.dart` (sets `persist: false` so toasts with *Undo* auto-dismiss cleanly in `material_ui 1.11+`, and shows the theme's `×` close icon). Never call raw `ScaffoldMessenger.of(context).showSnackBar(...)`.
- **Android Home Widget:** Keep `TronoWidgetProvider.kt` + `trono_widget.xml` flicker-free (`ViewFlipper` + `partiallyUpdateAppWidget`).

---

## 5. Git, PR & Release Workflow

- **Git identity:** NEVER modify global `~/.gitconfig`. This repository's local `.git/config` is pre-configured with the personal GitHub identity (`goritm/Trono`).
- **Branching:** One feature or fix per branch from up-to-date `main` (`feat/...`, `fix/...`, `docs/...`), opened as a Pull Request via `gh pr create`.
- **Commits:** Clear Conventional Commits (`feat(scope): ...`, `fix(scope): ...`, `docs: ...`, `test: ...`).
- **CI/CD & Releases:**
  - `.github/workflows/ci.yml` runs `dart analyze` and `flutter test` on every PR and push to `main`.
  - `.github/workflows/release.yml` builds and signs `trono-vX.Y.Z.apk` and publishes a GitHub Release when a tag `v*.*.*` is pushed (or via `workflow_dispatch`). Always increment the Android `versionCode` (`+N`) in `pubspec.yaml` before tagging a new release.

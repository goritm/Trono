# Spec: Trigger Lab (Food & Digestive Trigger Correlation)

- **Status:** Implemented
- **Target Version / PR:** `v2.5.0` / PR #16
- **Branch:** `feat/v2.5-trigger-lab`

## 1. Goal
> Help users turn their logged food & lifestyle tags (`☕ Coffee`, `🌶️ Spicy`, `🧀 Dairy`, `🍺 Alcohol`, `🍔 Fast food`, `🥗 Fiber`, `🍫 Sweets`, `😰 Stress`) into actionable, easy-to-read correlations against their **Bristol Scale** (1–7) and **Effort / Urgency** levels — 100% locally on-device inside **Stats → Insights**.

## 2. Non-Goals
- No medical diagnosis or clinical advice; Trigger Lab reports purely descriptive personal statistics from the user's own history.
- No new tag editor UI or custom tag creation in this PR (uses the existing 8 digestive trigger tags in `LogDetailSheet`).
- No Supabase schema changes, cloud sync changes, or SQLite migrations.

## 3. Data Model & Privacy Contract
- **Local-only fields (SQLite / SharedPreferences):** None added; derived in memory from local `BathroomLog` entries (`type`, `tags`, `bristolType`, `effort`).
- **Cloud-synced fields (Supabase):** Unchanged. Exact GPS coordinates and salary remain strictly local; Trigger Lab never sends or fetches network data.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Entry point:** `Stats` tab → `Insights` (`Análisis`) sub-tab, displayed as `TriggerLabCard` using Trono's Tactile Chunky 3D cards (`ChunkyCard`, solid opaque surfaces in light & dark mode).
- **Key states:**
  - **Empty / Insufficient data** (no trigger tag has ≥ 2 throne logs): shows an inviting empty card explaining how to tag food/triggers + Bristol scale when logging, with current progress toward unlocking.
  - **Populated:**
    - Header (`TRIGGER LAB` / `LABORATORIO DE TRIGGERS`) + baseline Bristol pill when baseline data exists.
    - Quick highlight pills when detected: **Best Ally** (highest ideal-zone ally) and **Top Disruptor** (strongest softer/firmer/intense shift).
    - Interactive trigger rows showing tag label, sample count (`4×`), a compact 1–7 Bristol visual bar comparing tag average vs baseline, delta pill (`+1.6`, `-1.1`, `Ideal`), and impact badge (`Ally`, `Softer`, `Firmer`, `Intense`, `Neutral`).
    - Tapping any row toggles a focused detail breakdown (avg Bristol vs baseline, % in ideal Bristol 3–4 zone, and % urgent/struggled when effort data exists).
- **Copy reminder:** Uses brand-first `throne` / `thrones` (EN default) and `trono` / `tronos` (ES full parity) with `👑`.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** fewer than 2 throne logs share any recognized trigger tag, **when** `TriggerLabEngine.analyze(logs)` runs, **then** `hasEnoughData` is `false`, `triggers` is empty, and `TriggerLabCard` renders the empty state cleanly.
2. **Given** `falseAlarm` logs or legacy non-trigger tags (`home`, `work`, `travel`, `restaurant`, `morning`, `late_night`), **when** `TriggerLabEngine.analyze(logs)` runs, **then** they are excluded from trigger correlations and Bristol baselines.
3. **Given** ≥ 2 throne logs tagged `spicy` with Bristol 6 and baseline logs around Bristol 4, **when** `TriggerLabEngine.analyze(logs)` runs, **then** `spicy` reports `avgBristol == 6.0`, positive `bristolDelta == +2.0`, `impact == TriggerImpact.softer`, and appears as `topDisruptor`.
4. **Given** ≥ 2 throne logs tagged `fiber` with Bristol 3–4 (≥ 70% ideal) and low effort/urgency, **when** `TriggerLabEngine.analyze(logs)` runs, **then** `fiber` reports `impact == TriggerImpact.ally`, `idealRate == 100%`, and appears as `bestAlly`.
5. **Given** ≥ 2 throne logs tagged `coffee` with `EffortLevel.urgent` (≥ 50% urgent/struggled) and neutral Bristol, **when** `TriggerLabEngine.analyze(logs)` runs, **then** `coffee` reports `impact == TriggerImpact.intense` and `urgentOrStruggledRate >= 50`.
6. **Given** a populated `TriggerLabCard`, **when** the user taps a trigger row, **then** the inspector detail panel updates to display that trigger's Bristol average, ideal-zone %, and effort breakdown.

## 6. Edge Cases
- **Tagged logs without Bristol or Effort:** Trigger still appears once `totalCount >= 2`, with `avgBristol == null`, `idealRate == null`, and `impact == TriggerImpact.neutral` (no division-by-zero or NaN).
- **All logs share the same tag:** Comparator falls back gracefully to `baselineBristol` so `bristolDelta == 0.0`.
- **Single-tag log vs multi-tag log:** A log with `['coffee', 'spicy']` contributes to both triggers accurately.
- **Dark mode & EN/ES switching:** All badges and highlights use solid opaque theme colors and localized `AppStrings`.

## 7. TDD Verification Plan
- **Unit tests to write first (RED → GREEN):**
  - `test/trigger_lab_test.dart`: empty/below-threshold handling, falseAlarm & legacy-tag filtering, baseline & delta calculation, `ally` / `softer` / `firmer` / `intense` / `neutral` classification, multi-tag logs, missing Bristol/effort null-safety, deterministic sorting.
- **Widget tests:**
  - `test/trigger_lab_test.dart`: `TriggerLabCard` empty state (EN & ES), populated state with Ally/Disruptor highlights, tapping rows to switch inspector breakdown.
- **Verification:**
  - `dart analyze` (0 errors, 0 warnings)
  - `flutter test` (100% passing)

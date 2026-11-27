# Spec: Hybrid Work (WFH / Teletrabajo) & Per-Log Paid Earnings Pill

- **Status:** Implemented
- **Target Version / PR:** `v2.6.0`
- **Branch:** `feat/v2.6-hybrid-work-earnings`

## 1. Goal
> Let hybrid and remote workers log **WFH / Teletrabajo** thrones in 1 tap (counted as Home for Territory Map / Home-vs-Away stats and as Work for Paid on the Throne & work achievements), and show a crisp golden **per-log earnings pill** on every work/WFH throne card in Home and Calendar when a local pay rate is configured.

## 2. Non-Goals
- No SQLite database version bump or schema migration.
- No Supabase DDL, RLS, or trigger migrations.
- No syncing of `hourlyRate` or per-log monetary amounts to Supabase or social feeds.
- No separate WFH-only map filter or separate WFH breakdown chart (can be added later if requested).

## 3. Data Model & Privacy Contract
- **Local-only fields (SQLite / SharedPreferences):**
  - `hourlyRate` and `currencySymbol` remain 100% local in `SharedPreferences` (`SettingsService`). Per-log earnings (`LogEarnings`) are derived purely in memory on the device and NEVER persisted to cloud or shared with friends.
  - Exact GPS coordinates (`latitude`, `longitude`) remain device-only.
- **WFH representation (zero migrations):**
  - Stored as `locationKind: LocationKind.home` paired with the reserved internal tag `BathroomLog.wfhTag` (`'wfh'`) in `tags`.
  - `BathroomLog.isWfh` returns `tags.contains(BathroomLog.wfhTag)`.
  - `BathroomLog.effectiveLocationKind` resolves to `LocationKind.home` when `locationKind == LocationKind.home` or `tags.contains(BathroomLog.wfhTag)`.
  - `BathroomLog.isWorkVisit` returns `effectiveLocationKind == LocationKind.work || tags.contains('work') || isWfh`.
- **Cloud-synced fields (Supabase):**
  - `location_kind` (`'home'`) and `tags` (when `shareLevel == full`) sync via existing columns with zero schema changes; `hourlyRate` and exact GPS NEVER leave the device.
- **SQLite / Supabase migrations required:** None.

## 4. User Experience & Copy (ES / EN)
- **Home Screen (`HomeScreen`):**
  - Compact 1-row location mode selector extended to 5 options:
    - EN: `Auto · Home · WFH · Work · Away`
    - ES: `Auto · Casa · Teletr. · Ofi · Fuera`
  - Uses `FittedBox(fit: BoxFit.scaleDown)` + `maxLines: 1` so all 5 tabs fit cleanly on 360dp narrow screens with zero overflow.
  - Selecting `WFH` updates the hero button subtitle (`💻 WFH · 1 tap logs instantly` / `💻 Teletrabajo · 1 toque guarda al instante`) and saves `locationKind: LocationKind.home` + `tags: ['wfh']` on tap (for both Throne and False alarm).
- **Detail / Edit Bottom Sheet (`LogDetailSheet`):**
  - Location chips row shows 4 options:
    - EN: `🏠 Home · 💻 WFH · 💼 Work · 🌍 Away`
    - ES: `🏠 Casa · 💻 Teletrabajo · 💼 Trabajo · 🌍 Fuera`
  - Selecting `WFH` sets `locationKind = LocationKind.home` and includes `'wfh'` in tags; selecting any other location removes `'wfh'`.
  - `'wfh'` is never shown as a raw tag chip in Food & Triggers.
- **Log Card (`LogTile`) in Home & Calendar:**
  - WFH logs display `💻 WFH` (EN) / `💻 Teletrabajo` (ES) as their location chip without duplicating `'wfh'` in the tags list.
  - When `hourlyRate > 0` and `log.isWorkVisit` is true, renders a solid opaque Warm Gold pill (`ValueKey('log_tile_earnings_${log.id}')`, `#FFF8E6` light / `#2B2618` dark, `TronoColors.gold` border):
    - Exact duration (`durationSeconds > 0`): `💰 +€2.50`
    - Estimated fallback (`300s` throne / `120s` false alarm): `💰 ~€1.50`
- **Light & dark mode:** Solid opaque gold pill surface respects light (`#FFF8E6`) and dark (`#2B2618`) palettes with high-contrast text.

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** a log with `locationKind: LocationKind.home` and tag `'wfh'`, **when** evaluating `effectiveLocationKind`, `isWfh`, and `isWorkVisit`, **then** `effectiveLocationKind == LocationKind.home`, `isWfh == true`, and `isWorkVisit == true`, while a plain Home log without `'wfh'` has `isWorkVisit == false`.
2. **Given** a work or WFH log and `hourlyRate = 30.0`, **when** calling `InsightsEngine.calculateLogEarnings`, **then** an exact 300s log returns `amount = 2.50, isEstimated = false`, a log without duration returns `amount = 2.50, isEstimated = true` (throne) or `1.00, isEstimated = true` (false alarm), and non-work logs or null/zero `hourlyRate` return `null`.
3. **Given** a mix of Office (`LocationKind.work`), WFH (`LocationKind.home` + `'wfh'`), and plain Home logs, **when** calling `InsightsEngine.calculatePaidOnThrone` and `StatsCalculator.calculate`, **then** Paid on the Throne includes both Office and WFH logs, while Territory / Home-vs-Away counts WFH under Home.
4. **Given** `LogTile` with `hourlyRate = 30.0` and `currencySymbol = '€'`, **when** rendered for a WFH log, **then** it displays `💻 WFH` (without a duplicate raw `wfh` tag chip) and displays the golden pill (`💰 +€2.50` when exact or `💰 ~€2.50` when estimated), and hides the pill when `hourlyRate` is null or the log is non-work.
5. **Given** `HomeScreen` rendered at a 360dp narrow viewport width, **when** selecting `WFH` and tapping the hero log button, **then** there are zero layout overflow errors and the saved log has `locationKind == LocationKind.home` and `tags.contains('wfh')`.

## 6. Edge Cases
- **Offline / no network:** 100% local calculation; zero network dependencies.
- **Upgrading existing users:** Zero schema changes; existing Home/Work/Away logs behave identically; JSON/CSV backup and Supabase sync round-trip `'wfh'` in existing `tags` field.
- **Zero or negative hourlyRate:** Treated as unset (`calculateLogEarnings` returns `null`, pill hidden).
- **Favorite place selected in edit sheet:** Selecting a non-home favorite place clears WFH so location state stays consistent.
- **False alarms during work/WFH:** Use 120s estimated fallback when no duration is recorded, consistent with `PaidOnThroneSummary`.

## 7. TDD Verification Plan
- **Unit & widget tests (RED → GREEN):**
  - `test/hybrid_work_earnings_test.dart`
- **Verification commands:**
  - `dart analyze` (0 errors, 0 warnings)
  - `flutter test` (100% passing)

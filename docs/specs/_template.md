# Spec: <Feature Name>

- **Status:** Draft | Approved | Implemented
- **Target Version / PR:** `vX.Y.Z` / PR #__
- **Branch:** `feat/<slug>`

## 1. Goal
> One or two sentences describing the user problem and desired outcome.

## 2. Non-Goals
- Explicitly list what is out of scope for this PR to avoid scope creep.

## 3. Data Model & Privacy Contract
- **Local-only fields (SQLite / SharedPreferences):**
- **Cloud-synced fields (Supabase):** *(Confirm exact GPS lat/lng and salary NEVER leave the device.)*
- **SQLite / Supabase migrations required:** None | Describe schema delta & backwards compatibility.

## 4. User Experience & Copy (ES / EN)
- Entry points & navigation placement.
- Key states: empty, loading, populated, offline, error, light & dark mode.
- Copy reminder: use brand-first `throne` / `thrones` (EN) and `trono` / `tronos` (ES) with `👑` (no `poop` / `pupú` in user-facing text).

## 5. Acceptance Criteria (Given / When / Then)
1. **Given** ..., **when** ..., **then** ...
2. **Given** ..., **when** ..., **then** ...
3. **Given** ..., **when** ..., **then** ...

## 6. Edge Cases
- Offline / no network:
- Upgrading existing users (existing DB rows / settings):
- Timezone / DST / empty history:

## 7. TDD Verification Plan
- **Unit tests to write first (RED → GREEN):**
  - `test/...`
- **Widget / integration tests:**
  - `test/...`
- **Manual / DB verification:**
  - `dart analyze` (0 errors, 0 warnings)
  - `flutter test` (all passing)
  - *(If Supabase touched)* Transactional RLS test + `get_advisors` (`security`, `performance`)

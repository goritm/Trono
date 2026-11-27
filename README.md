# 👑 Trono

> **Offline-first Flutter mobile app (Android-first, iOS-ready) for claiming your throne, mapping conquered territory, unlocking XP ranks, and competing in private Supabase friend groups.**

[![Download Latest APK](https://img.shields.io/github/v/release/goritm/Trono?label=Download%20Android%20APK&color=E05A2B&style=for-the-badge)](https://github.com/goritm/Trono/releases/latest)

---

## ✨ Highlights

- **⚡ 1-Tap Instant Logging (`Log`):** Tactile 3D hero button with animations, instant 0 ms local SQLite save, quick location selector (`Auto · Home · Work · Away`), live session timer, false alarm, past visits, and swipe-to-edit/delete with Undo.
- **📊 Deep Stats, Trends & Trigger Lab (`Stats`):**
  - **Calendar:** Interactive monthly heatmap, peak hours chart, and personal records.
  - **Insights:** Daily averages (7d / 30d / all-time), **Monthly Comparison** (*This Month vs Last Month*), **8-week trend chart**, **🧪 Trigger Lab** (correlating food & lifestyle tags against Bristol scale & effort), **Paid on the Throne** (100% local salary estimate), automatic pattern insights, and shareable **Trono Wrapped** PNG cards.
  - **Awards:** 7 XP ranks (*Bathroom Rookie* → *Throne Deity*) and 22 unlockable badges with real confetti celebrations.
- **🗺️ Interactive Territory Map & Favorite Places (`Map`):**
  - OpenStreetMap (`flutter_map`) with filters (`All · Month · Away · Work · Home`) and clustered pins.
  - **Places ⭐:** Home vs Away survival ratio, saved GPS **Favorite Places** with 150 m auto-labeling, **1–5 ⭐ bathroom ratings**, and **Top Bathrooms** ranking.
- **👥 Private Multiplayer Groups (`Friends` · Supabase):**
  - Offline-first cloud sync with strict Postgres Row-Level Security (RLS).
  - Private 6-letter invite-code groups, live Realtime feed with **⚡ Synced Duo** detection (≤15 min apart) and emoji reactions (`👑`, `🔥`, `💀`, `👏`), **🏆 Weekly Group Challenges & Group Streak**, 7d/30d/All leaderboards, 6 group awards, and shareable **Group Weekly Wrapped** cards.
- **🔒 Privacy by Design:** Exact GPS coordinates (`latitude`, `longitude`), Favorite Places coordinates, work salary, and local reminder schedules **never leave your device**. Per-log share levels (`private`, `summary_only`, `full`) are enforced at the Postgres trigger level.
- **📱 Android Extras:** Flicker-free 2×2 **Home Screen Widget** (`👑 +1 Trono` with silent GPS), native **Android App Shortcuts** (long-press icon → *Claim Throne* / *Start Timer*), optional **🔔 Local Smart Reminders** (evening Streak Guard + Sunday Weekly Recap), Biometric/PIN lock, 3-step welcome onboarding, JSON/CSV backup, EN (default) / ES bilingual UI, light/dark themes, and automatic **in-app GitHub Releases update checker** with *"What’s new"* changelog preview.

---

## 📥 Download & Install (Android)

Download the latest signed release APK directly from [**GitHub Releases**](https://github.com/goritm/Trono/releases/latest) — future updates install seamlessly in place without losing data.

---

## 🛠️ Local Development

We follow **SDD (Spec-Driven Development) + TDD (Test-Driven Development)** documented in [AGENTS.md](AGENTS.md) and [docs/specs/_template.md](docs/specs/_template.md).

```bash
flutter pub get
dart analyze
flutter test
flutter build apk --release
```

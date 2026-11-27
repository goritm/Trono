import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bathroom_log.dart';
import '../models/favorite_place.dart';
import '../models/reminder_schedule.dart';

class SettingsService {
  static const _kThemeMode = 'theme_mode';
  static const _kLocaleCode = 'locale_code';
  static const _kDefaultShareLevel = 'default_share_level';
  static const _kLockEnabled = 'lock_enabled';
  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kPinHash = 'pin_hash';
  static const _kActiveTimerStart = 'active_timer_start';
  static const _kUnlockedAchievements = 'unlocked_achievements';
  static const _kHighestRankLevel = 'highest_rank_level';
  static const _kHomeLat = 'home_lat';
  static const _kHomeLng = 'home_lng';
  static const _kAutoGps = 'auto_gps';
  static const _kHourlyRate = 'hourly_rate';
  static const _kCurrencySymbol = 'currency_symbol';
  static const _kSelectedGroupId = 'selected_group_id';
  static const _kOnboardingCompleted = 'onboarding_completed';
  static const _kFavoritePlaces = 'favorite_places';
  static const _kUpdateLastCheckedMs = 'update_last_checked_ms';
  static const _kUpdateDismissedTag = 'update_dismissed_tag';
  static const _kStreakReminderEnabled = 'streak_reminder_enabled';
  static const _kStreakReminderHour = 'streak_reminder_hour';
  static const _kWeeklyRecapReminderEnabled = 'weekly_recap_reminder_enabled';

  late final SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  ThemeMode get themeMode {
    final val = _prefs.getString(_kThemeMode);
    return switch (val) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final val = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _prefs.setString(_kThemeMode, val);
  }

  Locale get locale {
    final code = _prefs.getString(_kLocaleCode) ?? 'en';
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    await _prefs.setString(_kLocaleCode, locale.languageCode);
  }

  ShareLevel get defaultShareLevel {
    final raw = _prefs.getString(_kDefaultShareLevel);
    if (raw == 'private') return ShareLevel.private;
    return ShareLevel.full;
  }

  Future<void> setDefaultShareLevel(ShareLevel level) async {
    await _prefs.setString(_kDefaultShareLevel, level.dbValue);
  }

  bool get lockEnabled => _prefs.getBool(_kLockEnabled) ?? false;

  Future<void> setLockEnabled(bool enabled) async {
    await _prefs.setBool(_kLockEnabled, enabled);
  }

  bool get biometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? true;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_kBiometricEnabled, enabled);
  }

  bool get hasPin => (_prefs.getString(_kPinHash) ?? '').isNotEmpty;

  String _hashPin(String pin) {
    final bytes = utf8.encode('trono_salt_v1:$pin');
    return sha256.convert(bytes).toString();
  }

  Future<void> setPin(String pin) async {
    await _prefs.setString(_kPinHash, _hashPin(pin));
  }

  Future<void> clearPin() async {
    await _prefs.remove(_kPinHash);
  }

  bool verifyPin(String pin) {
    final saved = _prefs.getString(_kPinHash);
    if (saved == null || saved.isEmpty) return false;
    return saved == _hashPin(pin);
  }

  DateTime? get activeTimerStart {
    final ms = _prefs.getInt(_kActiveTimerStart);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setActiveTimerStart(DateTime? start) async {
    if (start == null) {
      await _prefs.remove(_kActiveTimerStart);
    } else {
      await _prefs.setInt(_kActiveTimerStart, start.millisecondsSinceEpoch);
    }
  }

  Set<String> get knownUnlockedAchievements {
    return (_prefs.getStringList(_kUnlockedAchievements) ?? const []).toSet();
  }

  Future<void> setKnownUnlockedAchievements(Set<String> ids) async {
    await _prefs.setStringList(_kUnlockedAchievements, ids.toList());
  }

  int get highestRankLevel => _prefs.getInt(_kHighestRankLevel) ?? 1;

  Future<void> setHighestRankLevel(int level) async {
    await _prefs.setInt(_kHighestRankLevel, level);
  }

  // V1.5 Home Coordinates & Auto-GPS
  double? get homeLat => _prefs.getDouble(_kHomeLat);
  double? get homeLng => _prefs.getDouble(_kHomeLng);
  bool get hasHomeLocation => homeLat != null && homeLng != null;

  Future<void> setHomeLocation(double? lat, double? lng) async {
    if (lat == null || lng == null) {
      await _prefs.remove(_kHomeLat);
      await _prefs.remove(_kHomeLng);
    } else {
      await _prefs.setDouble(_kHomeLat, lat);
      await _prefs.setDouble(_kHomeLng, lng);
    }
  }

  bool get autoGpsEnabled => _prefs.getBool(_kAutoGps) ?? true;

  Future<void> setAutoGpsEnabled(bool enabled) async {
    await _prefs.setBool(_kAutoGps, enabled);
  }

  // V1.6 Paid on the Throne (100% local salary estimate)
  double? get hourlyRate => _prefs.getDouble(_kHourlyRate);
  String get currencySymbol => _prefs.getString(_kCurrencySymbol) ?? '€';

  Future<void> setHourlyRate(double? rate) async {
    if (rate == null || rate <= 0) {
      await _prefs.remove(_kHourlyRate);
    } else {
      await _prefs.setDouble(_kHourlyRate, rate);
    }
  }

  Future<void> setCurrencySymbol(String symbol) async {
    await _prefs.setString(_kCurrencySymbol, symbol);
  }

  // V2 Social selected group
  String? get selectedGroupId => _prefs.getString(_kSelectedGroupId);

  Future<void> setSelectedGroupId(String? groupId) async {
    if (groupId == null || groupId.isEmpty) {
      await _prefs.remove(_kSelectedGroupId);
    } else {
      await _prefs.setString(_kSelectedGroupId, groupId);
    }
  }

  // V2.2 Onboarding completion flag
  bool get onboardingCompleted =>
      _prefs.getBool(_kOnboardingCompleted) ?? false;

  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool(_kOnboardingCompleted, completed);
  }

  // V2.2 Favorite Places (100% local on device)
  List<FavoritePlace> get favoritePlaces {
    final raw = _prefs.getString(_kFavoritePlaces);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(FavoritePlace.fromJson)
          .where((p) => p.id.isNotEmpty && p.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> setFavoritePlaces(List<FavoritePlace> places) async {
    final encoded = jsonEncode(places.map((p) => p.toJson()).toList());
    await _prefs.setString(_kFavoritePlaces, encoded);
  }

  // V2.4 In-App GitHub Releases Update Checker
  DateTime? get updateLastCheckedAt {
    final ms = _prefs.getInt(_kUpdateLastCheckedMs);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> setUpdateLastCheckedAt(DateTime dt) async {
    await _prefs.setInt(_kUpdateLastCheckedMs, dt.millisecondsSinceEpoch);
  }

  String? get dismissedUpdateTag => _prefs.getString(_kUpdateDismissedTag);

  Future<void> setDismissedUpdateTag(String? tag) async {
    if (tag == null || tag.isEmpty) {
      await _prefs.remove(_kUpdateDismissedTag);
    } else {
      await _prefs.setString(_kUpdateDismissedTag, tag);
    }
  }

  // V2.5 Local Smart Reminders (100% on-device)
  bool get streakReminderEnabled =>
      _prefs.getBool(_kStreakReminderEnabled) ?? false;

  Future<void> setStreakReminderEnabled(bool enabled) async {
    await _prefs.setBool(_kStreakReminderEnabled, enabled);
  }

  int get streakReminderHour =>
      _prefs.getInt(_kStreakReminderHour) ?? ReminderConfig.defaultStreakHour;

  Future<void> setStreakReminderHour(int hour) async {
    await _prefs.setInt(_kStreakReminderHour, hour.clamp(0, 23));
  }

  bool get weeklyRecapReminderEnabled =>
      _prefs.getBool(_kWeeklyRecapReminderEnabled) ?? false;

  Future<void> setWeeklyRecapReminderEnabled(bool enabled) async {
    await _prefs.setBool(_kWeeklyRecapReminderEnabled, enabled);
  }

  ReminderConfig get reminderConfig => ReminderConfig(
    streakEnabled: streakReminderEnabled,
    streakHour: streakReminderHour,
    weeklyEnabled: weeklyRecapReminderEnabled,
  );
}

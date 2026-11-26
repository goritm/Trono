import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/bathroom_log.dart';

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
    final code = _prefs.getString(_kLocaleCode) ?? 'es';
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    await _prefs.setString(_kLocaleCode, locale.languageCode);
  }

  ShareLevel get defaultShareLevel =>
      ShareLevel.fromDb(_prefs.getString(_kDefaultShareLevel));

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
}

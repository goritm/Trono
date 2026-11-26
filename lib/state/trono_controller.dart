import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../models/achievement.dart';
import '../models/bathroom_log.dart';
import '../models/stats_summary.dart';
import '../services/settings_service.dart';
import '../services/widget_sync_service.dart';

class UnlockEvent {
  const UnlockEvent({
    required this.newAchievements,
    required this.newRank,
  });

  final List<AchievementProgress> newAchievements;
  final UserRank? newRank;

  bool get hasAnything => newAchievements.isNotEmpty || newRank != null;
}

class TronoController extends ChangeNotifier {
  TronoController({
    required BathroomRepository repository,
    required SettingsService settings,
  }) : _repo = repository,
       _settings = settings;

  final BathroomRepository _repo;
  final SettingsService _settings;
  final _uuid = const Uuid();

  List<BathroomLog> _logs = const [];
  StatsSummary _stats = StatsCalculator.calculate(const []);
  GamificationSnapshot _gamification = GamificationEngine.evaluate(const []);

  bool _isLoading = true;
  DateTime? _activeTimerStart;
  Timer? _ticker;
  int _elapsedSeconds = 0;

  // Settings mirrors
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('es');
  ShareLevel _defaultShareLevel = ShareLevel.summaryOnly;
  bool _lockEnabled = false;
  bool _biometricEnabled = true;

  List<BathroomLog> get logs => _logs;
  StatsSummary get stats => _stats;
  GamificationSnapshot get gamification => _gamification;
  bool get isLoading => _isLoading;

  bool get isTimerRunning => _activeTimerStart != null;
  int get elapsedTimerSeconds => _elapsedSeconds;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  ShareLevel get defaultShareLevel => _defaultShareLevel;
  bool get lockEnabled => _lockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasPin => _settings.hasPin;

  Future<void> init() async {
    _themeMode = _settings.themeMode;
    _locale = _settings.locale;
    _defaultShareLevel = _settings.defaultShareLevel;
    _lockEnabled = _settings.lockEnabled;
    _biometricEnabled = _settings.biometricEnabled;

    _activeTimerStart = _settings.activeTimerStart;
    if (_activeTimerStart != null) {
      _startTicker();
    }

    await reloadLogs(suppressNotifications: true);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reloadLogs({bool suppressNotifications = false}) async {
    _logs = await _repo.getAllLogs();
    _stats = StatsCalculator.calculate(_logs);
    _gamification = GamificationEngine.evaluate(_logs);

    if (suppressNotifications) {
      // Sync baseline unlocked achievements so we don't spam on startup
      final unlockedIds = _gamification.achievements
          .where((a) => a.isUnlocked)
          .map((a) => a.id)
          .toSet();
      await _settings.setKnownUnlockedAchievements(unlockedIds);
      await _settings.setHighestRankLevel(_gamification.currentRank.level);
    }

    await WidgetSyncService.syncStats(
      _stats,
      lastType: _logs.isNotEmpty ? _logs.first.type : null,
    );
    notifyListeners();
  }

  /// Instant 1-tap log creation. Returns the saved log + any newly unlocked badges/rank.
  Future<(BathroomLog, UnlockEvent)> quickLog(BathroomType type) async {
    int? durationSecs;
    if (_activeTimerStart != null) {
      final diff = DateTime.now().difference(_activeTimerStart!).inSeconds;
      if (diff > 0) durationSecs = diff;
      await cancelTimer();
    }

    final now = DateTime.now();
    final log = BathroomLog(
      id: _uuid.v4(),
      type: type,
      timestamp: now,
      durationSeconds: durationSecs,
      shareLevel: _defaultShareLevel,
      createdAt: now,
      updatedAt: now,
    );

    await _repo.upsertLog(log);
    final unlocks = await _refreshAndDetectUnlocks();
    return (log, unlocks);
  }

  Future<UnlockEvent> saveLog(BathroomLog log) async {
    final updated = log.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );
    await _repo.upsertLog(updated);
    return _refreshAndDetectUnlocks();
  }

  Future<void> deleteLog(String id) async {
    await _repo.softDeleteLog(id);
    await reloadLogs(suppressNotifications: true);
  }

  Future<int> importLogs(List<BathroomLog> incoming) async {
    if (incoming.isEmpty) return 0;
    await _repo.upsertLogsBatch(incoming);
    await reloadLogs(suppressNotifications: true);
    return incoming.length;
  }

  Future<UnlockEvent> _refreshAndDetectUnlocks() async {
    final prevUnlocked = _settings.knownUnlockedAchievements;
    final prevRankLevel = _settings.highestRankLevel;

    _logs = await _repo.getAllLogs();
    _stats = StatsCalculator.calculate(_logs);
    _gamification = GamificationEngine.evaluate(_logs);

    final nowUnlocked =
        _gamification.achievements.where((a) => a.isUnlocked).toList();
    final newlyUnlocked =
        nowUnlocked.where((a) => !prevUnlocked.contains(a.id)).toList();

    UserRank? newRank;
    if (_gamification.currentRank.level > prevRankLevel) {
      newRank = _gamification.currentRank;
      await _settings.setHighestRankLevel(newRank.level);
    }

    if (newlyUnlocked.isNotEmpty) {
      final allIds = {...prevUnlocked, ...nowUnlocked.map((a) => a.id)};
      await _settings.setKnownUnlockedAchievements(allIds);
    }

    await WidgetSyncService.syncStats(
      _stats,
      lastType: _logs.isNotEmpty ? _logs.first.type : null,
    );
    notifyListeners();

    return UnlockEvent(newAchievements: newlyUnlocked, newRank: newRank);
  }

  // Live timer controls
  Future<void> startTimer() async {
    _activeTimerStart = DateTime.now();
    _elapsedSeconds = 0;
    await _settings.setActiveTimerStart(_activeTimerStart);
    _startTicker();
    notifyListeners();
  }

  Future<void> cancelTimer() async {
    _ticker?.cancel();
    _ticker = null;
    _activeTimerStart = null;
    _elapsedSeconds = 0;
    await _settings.setActiveTimerStart(null);
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    if (_activeTimerStart == null) return;
    _elapsedSeconds =
        DateTime.now().difference(_activeTimerStart!).inSeconds.clamp(0, 86400);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeTimerStart == null) return;
      _elapsedSeconds = DateTime.now()
          .difference(_activeTimerStart!)
          .inSeconds
          .clamp(0, 86400);
      notifyListeners();
    });
  }

  // Settings mutators
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _settings.setThemeMode(mode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    await _settings.setLocale(locale);
    notifyListeners();
  }

  Future<void> setDefaultShareLevel(ShareLevel level) async {
    _defaultShareLevel = level;
    await _settings.setDefaultShareLevel(level);
    notifyListeners();
  }

  Future<void> setLockEnabled(bool enabled) async {
    _lockEnabled = enabled;
    await _settings.setLockEnabled(enabled);
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _settings.setBiometricEnabled(enabled);
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await _settings.setPin(pin);
    notifyListeners();
  }

  Future<void> clearPin() async {
    await _settings.clearPin();
    notifyListeners();
  }

  bool verifyPin(String pin) => _settings.verifyPin(pin);

  List<BathroomLog> logsForDay(DateTime day) {
    final target = DateUtils.dateOnly(day);
    return _logs.where((l) => DateUtils.dateOnly(l.timestamp) == target).toList();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

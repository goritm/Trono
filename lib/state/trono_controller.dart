import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../l10n/app_strings.dart';
import '../models/achievement.dart';
import '../models/app_update.dart';
import '../models/bathroom_log.dart';
import '../models/favorite_place.dart';
import '../models/insights.dart';
import '../models/monthly_comparison.dart';
import '../models/reminder_schedule.dart';
import '../models/stats_summary.dart';
import '../models/trigger_lab.dart';
import '../services/local_reminder_service.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/update_checker_service.dart';
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
    UpdateCheckerService? updateChecker,
    LocalReminderService? reminderService,
  }) : _repo = repository,
       _settings = settings,
       _updateChecker =
           updateChecker ?? UpdateCheckerService(settings: settings),
       _reminderService = reminderService ?? LocalReminderService();

  final BathroomRepository _repo;
  final SettingsService _settings;
  final UpdateCheckerService _updateChecker;
  final LocalReminderService _reminderService;
  final _uuid = const Uuid();
  VoidCallback? _onLogsMutated;

  void setOnLogsMutated(VoidCallback? callback) {
    _onLogsMutated = callback;
  }

  List<BathroomLog> _logs = const [];
  StatsSummary _stats = StatsCalculator.calculate(const []);
  GamificationSnapshot _gamification = GamificationEngine.evaluate(const []);
  PaidOnThroneSummary _paidOnThrone = InsightsEngine.calculatePaidOnThrone(
    const [],
    hourlyRate: null,
  );
  List<TronoInsight> _insights = const [];
  MonthlyComparisonSnapshot _monthlyComparison =
      MonthlyComparisonEngine.compute(const []);
  TriggerLabSnapshot _triggerLab = TriggerLabEngine.analyze(const []);

  bool _isLoading = true;
  DateTime? _activeTimerStart;
  Timer? _ticker;
  int _elapsedSeconds = 0;

  // Settings mirrors
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');
  ShareLevel _defaultShareLevel = ShareLevel.summaryOnly;
  bool _lockEnabled = false;
  bool _biometricEnabled = true;

  // V1.5 Location & Home mirrors
  double? _homeLat;
  double? _homeLng;
  bool _autoGpsEnabled = true;

  // V1.6 Paid on the Throne mirrors
  double? _hourlyRate;
  String _currencySymbol = '€';

  // V2.2 Onboarding mirror
  bool _onboardingCompleted = false;

  // V2.2 Favorite Places & Top Bathrooms mirrors
  List<FavoritePlace> _favoritePlaces = const [];
  List<TopPlaceStat> _topPlaces = const [];

  // V2.4 In-App Update Checker mirrors
  String _installedVersion = '2.5.0';
  AppReleaseInfo? _availableUpdate;
  bool _isCheckingUpdate = false;
  bool _disposed = false;

  // V2.5 Local Smart Reminders mirrors
  bool _streakReminderEnabled = false;
  int _streakReminderHour = ReminderConfig.defaultStreakHour;
  bool _weeklyRecapReminderEnabled = false;

  List<BathroomLog> get logs => _logs;
  StatsSummary get stats => _stats;
  GamificationSnapshot get gamification => _gamification;
  PaidOnThroneSummary get paidOnThrone => _paidOnThrone;
  List<TronoInsight> get insights => _insights;
  List<FavoritePlace> get favoritePlaces => _favoritePlaces;
  List<TopPlaceStat> get topPlaces => _topPlaces;
  MonthlyComparisonSnapshot get monthlyComparison => _monthlyComparison;
  TriggerLabSnapshot get triggerLab => _triggerLab;
  bool get isLoading => _isLoading;

  bool get isTimerRunning => _activeTimerStart != null;
  int get elapsedTimerSeconds => _elapsedSeconds;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  ShareLevel get defaultShareLevel => _defaultShareLevel;
  bool get lockEnabled => _lockEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get hasPin => _settings.hasPin;

  double? get homeLat => _homeLat;
  double? get homeLng => _homeLng;
  bool get hasHomeLocation => _homeLat != null && _homeLng != null;
  bool get autoGpsEnabled => _autoGpsEnabled;

  double? get hourlyRate => _hourlyRate;
  bool get hasHourlyRate => _hourlyRate != null && _hourlyRate! > 0;
  String get currencySymbol => _currencySymbol;
  bool get onboardingCompleted => _onboardingCompleted;

  String get installedVersion => _installedVersion;
  AppReleaseInfo? get availableUpdate => _availableUpdate;
  bool get isCheckingUpdate => _isCheckingUpdate;
  bool get showHomeUpdateBanner =>
      _updateChecker.shouldShowHomeBanner(_availableUpdate);

  bool get streakReminderEnabled => _streakReminderEnabled;
  int get streakReminderHour => _streakReminderHour;
  bool get weeklyRecapReminderEnabled => _weeklyRecapReminderEnabled;
  ReminderConfig get reminderConfig => ReminderConfig(
    streakEnabled: _streakReminderEnabled,
    streakHour: _streakReminderHour,
    weeklyEnabled: _weeklyRecapReminderEnabled,
  );

  List<BathroomLog> get geotaggedLogs =>
      _logs.where((l) => l.hasCoordinates).toList();

  Future<void> init() async {
    _themeMode = _settings.themeMode;
    _locale = _settings.locale;
    _defaultShareLevel = _settings.defaultShareLevel;
    _lockEnabled = _settings.lockEnabled;
    _biometricEnabled = _settings.biometricEnabled;
    _homeLat = _settings.homeLat;
    _homeLng = _settings.homeLng;
    _autoGpsEnabled = _settings.autoGpsEnabled;
    _hourlyRate = _settings.hourlyRate;
    _currencySymbol = _settings.currencySymbol;
    _onboardingCompleted = _settings.onboardingCompleted;
    _favoritePlaces = _settings.favoritePlaces;
    _streakReminderEnabled = _settings.streakReminderEnabled;
    _streakReminderHour = _settings.streakReminderHour;
    _weeklyRecapReminderEnabled = _settings.weeklyRecapReminderEnabled;

    _activeTimerStart = _settings.activeTimerStart;
    if (_activeTimerStart != null) {
      _startTicker();
    }

    await reloadLogs(suppressNotifications: true);
    if (!_onboardingCompleted && _logs.isNotEmpty) {
      _onboardingCompleted = true;
      await _settings.setOnboardingCompleted(true);
    }
    _installedVersion = await _updateChecker.getInstalledVersion();
    _isLoading = false;
    notifyListeners();

    // Non-blocking, 12h-throttled update check (silent when offline)
    unawaited(checkForUpdates(force: false));
  }

  Future<UpdateCheckResult> checkForUpdates({bool force = false}) async {
    if (_disposed || _isCheckingUpdate) {
      return const UpdateCheckResult(status: UpdateCheckStatus.throttled);
    }
    _isCheckingUpdate = true;
    notifyListeners();
    try {
      final result = await _updateChecker.checkForUpdate(force: force);
      if (_disposed) return result;
      if (result.installedVersion != null) {
        _installedVersion = result.installedVersion!;
      }
      if (result.status == UpdateCheckStatus.updateAvailable) {
        _availableUpdate = result.release;
      } else if (result.status == UpdateCheckStatus.upToDate) {
        _availableUpdate = null;
      }
      return result;
    } finally {
      _isCheckingUpdate = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> dismissUpdateBanner() async {
    final tag = _availableUpdate?.tagName;
    if (tag == null) return;
    await _updateChecker.dismissRelease(tag);
    notifyListeners();
  }

  Future<void> reloadLogs({bool suppressNotifications = false}) async {
    _logs = await _repo.getAllLogs();
    _recomputeDerived();

    if (suppressNotifications) {
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
    await _syncReminders();
    notifyListeners();
  }

  void _recomputeDerived() {
    _stats = StatsCalculator.calculate(
      _logs,
      homeLat: _homeLat,
      homeLng: _homeLng,
    );
    _gamification = GamificationEngine.evaluate(
      _logs,
      homeLat: _homeLat,
      homeLng: _homeLng,
    );
    _paidOnThrone = InsightsEngine.calculatePaidOnThrone(
      _logs,
      hourlyRate: _hourlyRate,
    );
    _insights = InsightsEngine.generateInsights(_logs, _stats);
    _topPlaces = FavoritePlacesEngine.computeTopPlaces(_logs, _favoritePlaces);
    _monthlyComparison = MonthlyComparisonEngine.compute(
      _logs,
      homeLat: _homeLat,
      homeLng: _homeLng,
    );
    _triggerLab = TriggerLabEngine.analyze(_logs);
  }

  WrappedSnapshot buildWrapped(WrappedPeriod period) {
    return InsightsEngine.buildWrapped(
      _logs,
      period: period,
      homeLat: _homeLat,
      homeLng: _homeLng,
      hourlyRate: _hourlyRate,
    );
  }

  Future<void> setSalaryConfig({
    required double? hourlyRate,
    required String currencySymbol,
  }) async {
    _hourlyRate = (hourlyRate != null && hourlyRate > 0) ? hourlyRate : null;
    _currencySymbol = currencySymbol;
    await _settings.setHourlyRate(_hourlyRate);
    await _settings.setCurrencySymbol(_currencySymbol);
    _recomputeDerived();
    notifyListeners();
  }

  /// Instant 1-tap log creation. Saves immediately (0ms), then silently enriches
  /// with GPS coordinates in the background if permission is granted.
  Future<(BathroomLog, UnlockEvent)> quickLog(
    BathroomType type, {
    LocationKind? locationKind,
  }) async {
    int? durationSecs;
    if (_activeTimerStart != null) {
      final diff = DateTime.now().difference(_activeTimerStart!).inSeconds;
      if (diff > 0) durationSecs = diff;
      await cancelTimer();
    }

    final now = DateTime.now();
    // If user explicitly tapped "Home" shortcut and has saved Home coords, attach them immediately!
    final initialLat =
        (locationKind == LocationKind.home && _homeLat != null) ? _homeLat : null;
    final initialLng =
        (locationKind == LocationKind.home && _homeLng != null) ? _homeLng : null;

    final log = BathroomLog(
      id: _uuid.v4(),
      type: type,
      timestamp: now,
      durationSeconds: durationSecs,
      locationKind: locationKind,
      latitude: initialLat,
      longitude: initialLng,
      shareLevel: _defaultShareLevel,
      createdAt: now,
      updatedAt: now,
    );

    await _repo.upsertLog(log);
    final unlocks = await _refreshAndDetectUnlocks();
    _onLogsMutated?.call();

    // Non-blocking background GPS enrichment when auto-GPS is enabled
    if (_autoGpsEnabled && !log.hasCoordinates) {
      unawaited(_enrichLogWithSilentGps(log.id, explicitKind: locationKind));
    }

    return (log, unlocks);
  }

  Future<void> _enrichLogWithSilentGps(
    String logId, {
    LocationKind? explicitKind,
  }) async {
    final pos = await LocationService.tryGetPositionSilently();
    if (pos == null) return;

    final idx = _logs.indexWhere((l) => l.id == logId);
    if (idx < 0) return;
    final current = _logs[idx];
    if (current.hasCoordinates) return;

    final matched = FavoritePlacesEngine.matchPlace(
      pos.latitude,
      pos.longitude,
      _favoritePlaces,
    );

    final inferredKind = explicitKind ??
        current.locationKind ??
        matched?.locationKind ??
        LocationService.classifyAgainstHome(
          pos.latitude,
          pos.longitude,
          homeLat: _homeLat,
          homeLng: _homeLng,
        );

    final hasExistingPlace =
        current.placeLabel != null && current.placeLabel!.trim().isNotEmpty;
    final inferredPlace = hasExistingPlace ? current.placeLabel : matched?.name;

    final enriched = current.copyWith(
      latitude: pos.latitude,
      longitude: pos.longitude,
      locationKind: inferredKind,
      placeLabel: inferredPlace,
      syncStatus: SyncStatus.pendingSync,
      updatedAt: DateTime.now(),
    );
    await _repo.upsertLog(enriched);
    await reloadLogs(suppressNotifications: true);
    _onLogsMutated?.call();
  }

  Future<UnlockEvent> saveLog(BathroomLog log) async {
    final updated = log.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pendingSync,
    );
    await _repo.upsertLog(updated);
    final unlocks = await _refreshAndDetectUnlocks();
    _onLogsMutated?.call();
    return unlocks;
  }

  Future<void> deleteLog(String id) async {
    await _repo.softDeleteLog(id);
    await reloadLogs(suppressNotifications: true);
    _onLogsMutated?.call();
  }

  Future<int> importLogs(List<BathroomLog> incoming) async {
    if (incoming.isEmpty) return 0;
    await _repo.upsertLogsBatch(incoming);
    await reloadLogs(suppressNotifications: true);
    _onLogsMutated?.call();
    return incoming.length;
  }

  Future<UnlockEvent> _refreshAndDetectUnlocks() async {
    final prevUnlocked = _settings.knownUnlockedAchievements;
    final prevRankLevel = _settings.highestRankLevel;

    _logs = await _repo.getAllLogs();
    _recomputeDerived();

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
    await _syncReminders();
    notifyListeners();

    return UnlockEvent(newAchievements: newlyUnlocked, newRank: newRank);
  }

  // V1.5 Location & Home controls
  Future<bool> captureCurrentAsHome() async {
    final pos = await LocationService.requestAndGetPosition();
    if (pos == null) return false;
    _homeLat = pos.latitude;
    _homeLng = pos.longitude;
    await _settings.setHomeLocation(_homeLat, _homeLng);
    _recomputeDerived();
    notifyListeners();
    return true;
  }

  Future<void> clearHomeLocation() async {
    _homeLat = null;
    _homeLng = null;
    await _settings.setHomeLocation(null, null);
    _recomputeDerived();
    notifyListeners();
  }

  Future<void> setAutoGpsEnabled(bool enabled) async {
    _autoGpsEnabled = enabled;
    await _settings.setAutoGpsEnabled(enabled);
    if (enabled) {
      // Prompt once nicely when user enables auto-GPS
      await LocationService.requestAndGetPosition();
    }
    notifyListeners();
  }

  // V2.2 Favorite Places controls (100% local on device)
  Future<FavoritePlace> addFavoritePlace({
    required String name,
    required String emoji,
    required LocationKind locationKind,
    required double latitude,
    required double longitude,
    double radiusMeters = 150.0,
  }) async {
    final place = FavoritePlace(
      id: _uuid.v4(),
      name: name.trim(),
      emoji: emoji,
      locationKind: locationKind,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      createdAt: DateTime.now(),
    );
    _favoritePlaces = [place, ..._favoritePlaces];
    await _settings.setFavoritePlaces(_favoritePlaces);
    _recomputeDerived();
    notifyListeners();
    return place;
  }

  Future<void> deleteFavoritePlace(String id) async {
    _favoritePlaces = _favoritePlaces.where((p) => p.id != id).toList();
    await _settings.setFavoritePlaces(_favoritePlaces);
    _recomputeDerived();
    notifyListeners();
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
    if (_streakReminderEnabled || _weeklyRecapReminderEnabled) {
      await _syncReminders();
    }
  }

  // V2.5 Local Smart Reminders controls
  Future<bool> setStreakReminderEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _reminderService.requestPermission();
      if (!granted) {
        _streakReminderEnabled = false;
        await _settings.setStreakReminderEnabled(false);
        notifyListeners();
        return false;
      }
    }
    _streakReminderEnabled = enabled;
    await _settings.setStreakReminderEnabled(enabled);
    await _syncReminders();
    notifyListeners();
    return true;
  }

  Future<void> setStreakReminderHour(int hour) async {
    _streakReminderHour = hour.clamp(0, 23);
    await _settings.setStreakReminderHour(_streakReminderHour);
    await _syncReminders();
    notifyListeners();
  }

  Future<bool> setWeeklyRecapReminderEnabled(bool enabled) async {
    if (enabled) {
      final granted = await _reminderService.requestPermission();
      if (!granted) {
        _weeklyRecapReminderEnabled = false;
        await _settings.setWeeklyRecapReminderEnabled(false);
        notifyListeners();
        return false;
      }
    }
    _weeklyRecapReminderEnabled = enabled;
    await _settings.setWeeklyRecapReminderEnabled(enabled);
    await _syncReminders();
    notifyListeners();
    return true;
  }

  Future<void> _syncReminders() async {
    final s = AppStrings(_locale);
    await _reminderService.syncReminders(
      config: reminderConfig,
      loggedToday: _stats.todayPoop > 0,
      currentStreak: _stats.currentStreak,
      streakTitle: s.streakReminderNotifTitle,
      streakBody: s.streakReminderNotifBody(_stats.currentStreak),
      weeklyTitle: s.weeklyRecapNotifTitle,
      weeklyBody: s.weeklyRecapNotifBody,
    );
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

  Future<void> completeOnboarding() async {
    if (_onboardingCompleted) return;
    _onboardingCompleted = true;
    await _settings.setOnboardingCompleted(true);
    notifyListeners();
  }

  Future<void> resetOnboarding() async {
    _onboardingCompleted = false;
    await _settings.setOnboardingCompleted(false);
    notifyListeners();
  }

  bool verifyPin(String pin) => _settings.verifyPin(pin);

  List<BathroomLog> logsForDay(DateTime day) {
    final target = DateUtils.dateOnly(day);
    return _logs.where((l) => DateUtils.dateOnly(l.timestamp) == target).toList();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'data/database_helper.dart';
import 'l10n/app_strings.dart';
import 'models/bathroom_log.dart';
import 'screens/calendar_stats_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/social_screen.dart';
import 'services/app_shortcut_service.dart';
import 'services/live_timer_notification_service.dart';
import 'services/settings_service.dart';
import 'services/supabase_sync_service.dart';
import 'services/widget_sync_service.dart';
import 'state/social_controller.dart';
import 'state/trono_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/trono_toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = SettingsService();
  await settings.init();
  await WidgetSyncService.initialize();
  await SupabaseSyncService.instance.initialize();

  final controller = TronoController(
    repository: LocalBathroomRepository.instance,
    settings: settings,
  );
  await controller.init();

  final socialController = SocialController(
    tronoController: controller,
    repository: LocalBathroomRepository.instance,
    settings: settings,
  );
  await socialController.init();

  runApp(
    TronoApp(
      controller: controller,
      socialController: socialController,
    ),
  );
}

class TronoApp extends StatelessWidget {
  const TronoApp({
    super.key,
    required this.controller,
    required this.socialController,
  });

  final TronoController controller;
  final SocialController socialController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: 'Trono',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: controller.themeMode,
          locale: controller.locale,
          supportedLocales: const [Locale('en'), Locale('es')],
          localizationsDelegates: const [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          home: _TronoShell(
            controller: controller,
            socialController: socialController,
          ),
        );
      },
    );
  }
}

class _TronoShell extends StatefulWidget {
  const _TronoShell({
    required this.controller,
    required this.socialController,
  });

  final TronoController controller;
  final SocialController socialController;

  @override
  State<_TronoShell> createState() => _TronoShellState();
}

class _TronoShellState extends State<_TronoShell> with WidgetsBindingObserver {
  int _tabIndex = 0;
  final _statsSubTab = ValueNotifier<int>(0);
  final _shortcutService = AppShortcutService();
  final _liveTimerService = LiveTimerNotificationService();
  AppShortcutAction? _pendingShortcut;
  late bool _locked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.controller.lockEnabled;
    _shortcutService.startListening(_onShortcutAction);
    _liveTimerService.startListening(_onLiveTimerNotificationAction);
    unawaited(_initShortcuts());
  }

  void _onLiveTimerNotificationAction(LiveTimerAction action) {
    if (!mounted) return;
    widget.controller.syncTimerFromExternal(null);
    if (action == LiveTimerAction.finish) {
      // Background worker persists SQLite immediately; reload now & shortly
      // after so an open app reflects the new log without double-logging.
      Future<void> refresh() async {
        if (!mounted) return;
        await widget.controller.reloadLogs(suppressNotifications: true);
        if (widget.socialController.isSignedIn) {
          unawaited(widget.socialController.syncNow(refreshFeedAfter: true));
        }
      }

      unawaited(refresh());
      unawaited(Future<void>.delayed(const Duration(milliseconds: 1200), refresh));
    }
  }

  Future<void> _initShortcuts() async {
    final initial = await _shortcutService.consumeInitialShortcut();
    if (initial != null && mounted) {
      _onShortcutAction(initial);
    }
  }

  void _onShortcutAction(AppShortcutAction action) {
    if (!mounted) return;
    if ((_locked && widget.controller.lockEnabled) ||
        !widget.controller.onboardingCompleted) {
      _pendingShortcut = action;
      return;
    }
    _pendingShortcut = null;
    unawaited(_executeShortcutAction(action));
  }

  Future<void> _executeShortcutAction(AppShortcutAction action) async {
    if (!mounted) return;
    if (_tabIndex != 0) {
      setState(() => _tabIndex = 0);
    }
    final s = AppStrings.of(context);
    switch (action) {
      case AppShortcutAction.claimThrone:
        final (log, _) = await widget.controller.quickLog(BathroomType.poop);
        if (!mounted) return;
        showTronoToast(
          context,
          s.savedInstantToast,
          actionLabel: s.undoAction,
          onAction: () => widget.controller.deleteLog(log.id),
        );
      case AppShortcutAction.startTimer:
        if (!widget.controller.isTimerRunning) {
          widget.controller.startTimer();
        }
        showTronoToast(context, s.shortcutTimerStartedToast);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shortcutService.dispose();
    _liveTimerService.dispose();
    _statsSubTab.dispose();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          controller: widget.controller,
          social: widget.socialController,
        ),
      ),
    );
  }

  void _openAwards() {
    _statsSubTab.value = 2;
    setState(() => _tabIndex = 1);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh in case user logged or started/stopped timer from Android Home Widget
      unawaited(widget.controller.refreshExternalTimer());
      unawaited(
        widget.controller.reloadLogs(suppressNotifications: true).then((_) {
          if (widget.socialController.isSignedIn) {
            unawaited(widget.socialController.syncNow(refreshFeedAfter: true));
          }
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked && widget.controller.lockEnabled) {
      return LockScreen(
        controller: widget.controller,
        onUnlocked: () {
          setState(() => _locked = false);
          final pending = _pendingShortcut;
          if (pending != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _onShortcutAction(pending);
            });
          }
        },
      );
    }

    if (!widget.controller.onboardingCompleted) {
      return OnboardingScreen(
        controller: widget.controller,
        social: widget.socialController,
      );
    }

    if (_pendingShortcut != null) {
      final pending = _pendingShortcut!;
      _pendingShortcut = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_executeShortcutAction(pending));
      });
    }

    final s = AppStrings.of(context);
    final screens = [
      HomeScreen(
        controller: widget.controller,
        onOpenSettings: () => _openSettings(context),
        onOpenAwards: _openAwards,
      ),
      CalendarStatsScreen(
        controller: widget.controller,
        subTabNotifier: _statsSubTab,
        onOpenSettings: () => _openSettings(context),
      ),
      MapScreen(
        controller: widget.controller,
        isRootTab: true,
        onOpenSettings: () => _openSettings(context),
      ),
      SocialScreen(
        social: widget.socialController,
        onOpenSettings: () => _openSettings(context),
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.bolt_outlined),
            selectedIcon: const Icon(Icons.bolt_rounded),
            label: s.navLog,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: s.navStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map_rounded),
            label: s.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: s.navSocial,
          ),
        ],
      ),
    );
  }
}

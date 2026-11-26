import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'data/database_helper.dart';
import 'l10n/app_strings.dart';
import 'screens/calendar_stats_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/social_screen.dart';
import 'services/settings_service.dart';
import 'services/supabase_sync_service.dart';
import 'services/widget_sync_service.dart';
import 'state/social_controller.dart';
import 'state/trono_controller.dart';
import 'theme/app_theme.dart';

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
  late bool _locked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = widget.controller.lockEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      // Refresh in case user logged directly from Android Home Widget
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
        onUnlocked: () => setState(() => _locked = false),
      );
    }

    if (!widget.controller.onboardingCompleted) {
      return OnboardingScreen(
        controller: widget.controller,
        social: widget.socialController,
      );
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
      SocialScreen(social: widget.socialController),
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

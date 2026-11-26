import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;

import 'data/database_helper.dart';
import 'l10n/app_strings.dart';
import 'screens/achievements_screen.dart';
import 'screens/calendar_stats_screen.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';
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
          supportedLocales: const [Locale('es'), Locale('en')],
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
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
    super.dispose();
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

    final s = AppStrings.of(context);
    final screens = [
      HomeScreen(controller: widget.controller),
      CalendarStatsScreen(controller: widget.controller),
      SocialScreen(social: widget.socialController),
      AchievementsScreen(controller: widget.controller),
      SettingsScreen(
        controller: widget.controller,
        social: widget.socialController,
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
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month_rounded),
            label: s.navCalendar,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups_rounded),
            label: s.navSocial,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emoji_events_outlined),
            selectedIcon: const Icon(Icons.emoji_events_rounded),
            label: s.navAchievements,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: s.navSettings,
          ),
        ],
      ),
    );
  }
}

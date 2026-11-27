import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trono/data/database_helper.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/screens/home_screen.dart';
import 'package:trono/services/settings_service.dart';
import 'package:trono/services/update_checker_service.dart';
import 'package:trono/state/trono_controller.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/log_detail_sheet.dart';

class _MemoryRepo implements BathroomRepository {
  final List<BathroomLog> _items = [];

  @override
  Future<void> clearAll() async => _items.clear();

  @override
  Future<List<BathroomLog>> getAllLogs() async => List.of(_items);

  @override
  Future<List<BathroomLog>> getAllLogsIncludingDeleted() async =>
      List.of(_items);

  @override
  Future<List<BathroomLog>> getPendingSyncLogs() async => const [];

  @override
  Future<void> markLogsSynced(List<String> ids) async {}

  @override
  Future<void> softDeleteLog(String id) async =>
      _items.removeWhere((e) => e.id == id);

  @override
  Future<void> upsertLog(BathroomLog log) async {
    _items.removeWhere((e) => e.id == log.id);
    _items.add(log);
  }

  @override
  Future<void> upsertLogsBatch(List<BathroomLog> logs) async {
    for (final l in logs) {
      await upsertLog(l);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('V2.8.1 Quick Follow-Up False Alarm & Clean Home Brand Header', () {
    testWidgets(
      'LogDetailSheet in quickFollowUp mode shows False alarm chip and saves BathroomType.falseAlarm',
      (tester) async {
        final now = DateTime(2026, 11, 27, 14, 0);
        final initial = BathroomLog(
          id: 'log-1',
          type: BathroomType.poop,
          timestamp: now,
          createdAt: now,
          updatedAt: now,
        );
        LogDetailSheetResult? sheetResult;

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('es'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      sheetResult = await showLogDetailSheet(
                        ctx,
                        mode: LogSheetMode.quickFollowUp,
                        initialLog: initial,
                        defaultShareLevel: ShareLevel.full,
                      );
                    },
                    child: const Text('Open Quick'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Quick'));
        await tester.pumpAndSettle();

        // Both Throne & False alarm chips are available right away in quickFollowUp
        expect(find.text('👑 Trono'), findsOneWidget);
        expect(find.text('💨 Falsa alarma'), findsOneWidget);
        // Date/Time picker stays hidden in quickFollowUp
        expect(find.text('Fecha y hora'), findsNothing);

        // Switching to False alarm hides Bristol scale and saves as falseAlarm
        await tester.tap(find.text('💨 Falsa alarma'));
        await tester.pumpAndSettle();
        expect(find.text('Escala de Bristol'), findsNothing);

        await tester.tap(find.text('LISTO'));
        await tester.pumpAndSettle();

        expect(sheetResult?.savedLog, isNotNull);
        expect(sheetResult!.savedLog!.type, BathroomType.falseAlarm);
      },
    );

    testWidgets(
      'HomeScreen places Trono title on the left and transparent vector mark on the right (no square icon image)',
      (tester) async {
        final ctrl = (await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({});
          final settings = SettingsService();
          await settings.init();
          final c = TronoController(
            repository: _MemoryRepo(),
            settings: settings,
            updateChecker: UpdateCheckerService(
              settings: settings,
              currentVersionProvider: () async => '2.8.1',
              httpGet: (_) async => null,
            ),
            onTimerSynced: (_) async {},
            readExternalTimerStart: () async => null,
          );
          await c.init();
          return c;
        }))!;
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('es')],
            localizationsDelegates: const [
              AppStrings.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            theme: AppTheme.light(),
            home: Scaffold(
              body: HomeScreen(controller: ctrl, onOpenSettings: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text('Trono');
        final markFinder = find.byKey(const ValueKey('home_brand_mark'));

        expect(titleFinder, findsOneWidget);
        expect(markFinder, findsOneWidget);
        // No square raster trono_icon.png inside HomeScreen header
        expect(find.byType(Image), findsNothing);

        final titleRect = tester.getRect(titleFinder);
        final markRect = tester.getRect(markFinder);
        expect(markRect.left, greaterThan(titleRect.left));
      },
    );
  });
}

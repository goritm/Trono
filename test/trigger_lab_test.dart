import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:trono/l10n/app_strings.dart';
import 'package:trono/models/bathroom_log.dart';
import 'package:trono/models/trigger_lab.dart';
import 'package:trono/theme/app_theme.dart';
import 'package:trono/widgets/trigger_lab_card.dart';

BathroomLog _log(
  String id, {
  BathroomType type = BathroomType.poop,
  int? bristol,
  EffortLevel? effort,
  List<String> tags = const [],
  int dayOffset = 0,
}) {
  final ts = DateTime(2026, 11, 1 + dayOffset, 9, 0);
  return BathroomLog(
    id: id,
    timestamp: ts,
    type: type,
    bristolType: bristol,
    effort: effort,
    tags: tags,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  group('TriggerLabEngine (V2.5)', () {
    test('returns empty snapshot when no trigger reaches minSampleSize (2)', () {
      final snap = TriggerLabEngine.analyze([
        _log('1', bristol: 4, tags: ['coffee']),
        _log('2', bristol: 5, tags: ['spicy']),
        _log('3', bristol: 4),
      ]);

      expect(snap.hasEnoughData, isFalse);
      expect(snap.triggers, isEmpty);
      expect(snap.taggedLogCount, 2);
      expect(snap.baselineBristol, closeTo(4.33, 0.01));
      expect(snap.bestAlly, isNull);
      expect(snap.topDisruptor, isNull);
    });

    test('excludes falseAlarm logs and legacy non-trigger tags', () {
      final snap = TriggerLabEngine.analyze([
        _log('1', type: BathroomType.falseAlarm, bristol: 7, tags: ['spicy']),
        _log('2', type: BathroomType.falseAlarm, bristol: 7, tags: ['spicy']),
        _log('3', bristol: 4, tags: ['home', 'morning']),
        _log('4', bristol: 4, tags: ['home', 'morning']),
      ]);

      expect(snap.hasEnoughData, isFalse);
      expect(snap.triggers, isEmpty);
      expect(snap.taggedLogCount, 0);
      expect(snap.baselineBristol, closeTo(4.0, 0.01));
    });

    test('classifies softer, firmer, ally, intense, and neutral accurately', () {
      final logs = <BathroomLog>[
        // Neutral baseline (Bristol 4, normal effort)
        _log('b1', bristol: 4, effort: EffortLevel.normal),
        _log('b2', bristol: 4, effort: EffortLevel.normal),
        _log('b3', bristol: 3, effort: EffortLevel.effortless),
        // Fiber -> Ally (Bristol 4, 100% ideal, effortless)
        _log('f1', bristol: 4, effort: EffortLevel.effortless, tags: ['fiber']),
        _log('f2', bristol: 4, effort: EffortLevel.effortless, tags: ['fiber']),
        _log('f3', bristol: 3, effort: EffortLevel.normal, tags: ['fiber']),
        // Spicy -> Softer (Bristol 6, +2.x delta)
        _log('s1', bristol: 6, effort: EffortLevel.urgent, tags: ['spicy']),
        _log('s2', bristol: 6, effort: EffortLevel.normal, tags: ['spicy']),
        // Dairy -> Firmer (Bristol 2, negative delta)
        _log('d1', bristol: 2, effort: EffortLevel.struggled, tags: ['dairy']),
        _log('d2', bristol: 2, effort: EffortLevel.normal, tags: ['dairy']),
        // Coffee -> Intense (neutral Bristol 4, but 100% urgent effort)
        _log('c1', bristol: 4, effort: EffortLevel.urgent, tags: ['coffee']),
        _log('c2', bristol: 4, effort: EffortLevel.urgent, tags: ['coffee']),
        // Sweets -> Neutral (no Bristol or effort recorded)
        _log('sw1', tags: ['sweets']),
        _log('sw2', tags: ['sweets']),
      ];

      final snap = TriggerLabEngine.analyze(logs);

      expect(snap.hasEnoughData, isTrue);
      expect(snap.triggers.length, 5);

      final byTag = {for (final t in snap.triggers) t.tagKey: t};

      final fiber = byTag['fiber']!;
      expect(fiber.totalCount, 3);
      expect(fiber.idealRate, 100);
      expect(fiber.impact, TriggerImpact.ally);

      final spicy = byTag['spicy']!;
      expect(spicy.avgBristol, closeTo(6.0, 0.01));
      expect(spicy.bristolDelta, greaterThan(1.5));
      expect(spicy.impact, TriggerImpact.softer);

      final dairy = byTag['dairy']!;
      expect(dairy.avgBristol, closeTo(2.0, 0.01));
      expect(dairy.bristolDelta, lessThan(-1.5));
      expect(dairy.impact, TriggerImpact.firmer);

      final coffee = byTag['coffee']!;
      expect(coffee.avgBristol, closeTo(4.0, 0.01));
      expect(coffee.urgentOrStruggledRate, 100);
      expect(coffee.impact, TriggerImpact.intense);

      final sweets = byTag['sweets']!;
      expect(sweets.avgBristol, isNull);
      expect(sweets.idealRate, isNull);
      expect(sweets.urgentOrStruggledRate, isNull);
      expect(sweets.impact, TriggerImpact.neutral);

      expect(snap.bestAlly?.tagKey, 'fiber');
      expect(snap.topDisruptor?.tagKey, isIn(['spicy', 'dairy']));
    });

    test('handles multi-tag logs and single-tag universe without NaN', () {
      final snap = TriggerLabEngine.analyze([
        _log('1', bristol: 4, tags: ['coffee', 'fiber']),
        _log('2', bristol: 4, tags: ['coffee', 'fiber']),
      ]);

      expect(snap.hasEnoughData, isTrue);
      expect(snap.taggedLogCount, 2);
      for (final t in snap.triggers) {
        expect(t.bristolDelta, 0.0);
        expect(t.bristolDelta!.isNaN, isFalse);
      }
    });
  });

  group('TriggerLabCard widget (V2.5)', () {
    testWidgets('renders empty state cleanly in English and Spanish', (tester) async {
      final emptySnap = TriggerLabEngine.analyze(const []);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(body: SingleChildScrollView(child: TriggerLabCard(snapshot: emptySnap))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRIGGER LAB'), findsOneWidget);
      expect(find.textContaining('2 thrones'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          locale: const Locale('es'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(body: SingleChildScrollView(child: TriggerLabCard(snapshot: emptySnap))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LABORATORIO DE TRIGGERS'), findsOneWidget);
      expect(find.textContaining('2 tronos'), findsOneWidget);
    });

    testWidgets('renders populated triggers, highlights, and switches inspector on tap', (tester) async {
      final snap = TriggerLabEngine.analyze([
        _log('b1', bristol: 4, effort: EffortLevel.normal),
        _log('b2', bristol: 4, effort: EffortLevel.normal),
        _log('f1', bristol: 4, effort: EffortLevel.effortless, tags: ['fiber']),
        _log('f2', bristol: 4, effort: EffortLevel.effortless, tags: ['fiber']),
        _log('f3', bristol: 3, effort: EffortLevel.normal, tags: ['fiber']),
        _log('s1', bristol: 6, effort: EffortLevel.urgent, tags: ['spicy']),
        _log('s2', bristol: 6, effort: EffortLevel.urgent, tags: ['spicy']),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: [
            AppStrings.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: Scaffold(body: SingleChildScrollView(child: TriggerLabCard(snapshot: snap))),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRIGGER LAB'), findsOneWidget);
      expect(find.byKey(const ValueKey('trigger_row_fiber')), findsOneWidget);
      expect(find.byKey(const ValueKey('trigger_row_spicy')), findsOneWidget);

      // Tap spicy row to inspect its Bristol & effort metrics
      await tester.tap(find.byKey(const ValueKey('trigger_row_spicy')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bristol 6.0'), findsOneWidget);
      expect(find.textContaining('100%'), findsWidgets);
    });
  });
}

import 'bathroom_log.dart';

/// Recognized food & lifestyle trigger tags tracked by Trigger Lab.
/// Legacy location/time tags (home, work, morning, etc.) are intentionally excluded.
const List<String> kTriggerLabTagKeys = [
  'coffee',
  'spicy',
  'dairy',
  'alcohol',
  'fast_food',
  'fiber',
  'sweets',
  'stress',
];

enum TriggerImpact {
  ally,
  softer,
  firmer,
  intense,
  neutral,
}

class TriggerStat {
  const TriggerStat({
    required this.tagKey,
    required this.totalCount,
    required this.bristolCount,
    required this.avgBristol,
    required this.bristolDelta,
    required this.idealRate,
    required this.effortCount,
    required this.urgentOrStruggledRate,
    required this.impact,
  });

  final String tagKey;
  final int totalCount;
  final int bristolCount;
  final double? avgBristol;

  /// Difference between this trigger's avg Bristol and non-tagged baseline
  /// (falls back to overall baseline if all logs contain this tag).
  final double? bristolDelta;

  /// Percentage (0..100) of Bristol-scored logs in the ideal 3–4 zone.
  final int? idealRate;

  final int effortCount;

  /// Percentage (0..100) of effort-scored logs marked urgent or struggled.
  final int? urgentOrStruggledRate;

  final TriggerImpact impact;

  bool get isDisruptor =>
      impact == TriggerImpact.softer ||
      impact == TriggerImpact.firmer ||
      impact == TriggerImpact.intense;
}

class TriggerLabSnapshot {
  const TriggerLabSnapshot({
    required this.triggers,
    required this.baselineBristol,
    required this.baselineIdealRate,
    required this.taggedLogCount,
    required this.bestAlly,
    required this.topDisruptor,
  });

  final List<TriggerStat> triggers;
  final double? baselineBristol;
  final int? baselineIdealRate;
  final int taggedLogCount;
  final TriggerStat? bestAlly;
  final TriggerStat? topDisruptor;

  bool get hasEnoughData => triggers.isNotEmpty;
}

class TriggerLabEngine {
  static const int minSampleSize = 2;

  static TriggerLabSnapshot analyze(
    List<BathroomLog> logs, {
    int minSamples = minSampleSize,
  }) {
    final thrones = logs.where((l) => l.type.includesPoop).toList();
    if (thrones.isEmpty) {
      return const TriggerLabSnapshot(
        triggers: [],
        baselineBristol: null,
        baselineIdealRate: null,
        taggedLogCount: 0,
        bestAlly: null,
        topDisruptor: null,
      );
    }

    final recognizedSet = kTriggerLabTagKeys.toSet();

    // Overall Bristol baseline across all throne logs with a Bristol score.
    int totalBristolSum = 0;
    int totalBristolCount = 0;
    int totalIdealCount = 0;
    int taggedLogCount = 0;

    final tagLogs = <String, List<BathroomLog>>{};

    for (final log in thrones) {
      if (log.bristolType != null) {
        totalBristolSum += log.bristolType!;
        totalBristolCount++;
        if (log.bristolType! >= 3 && log.bristolType! <= 4) {
          totalIdealCount++;
        }
      }

      bool hasRecognizedTag = false;
      final seenOnLog = <String>{};
      for (final tag in log.tags) {
        if (recognizedSet.contains(tag) && seenOnLog.add(tag)) {
          hasRecognizedTag = true;
          tagLogs.putIfAbsent(tag, () => <BathroomLog>[]).add(log);
        }
      }
      if (hasRecognizedTag) {
        taggedLogCount++;
      }
    }

    final double? baselineBristol = totalBristolCount > 0
        ? totalBristolSum / totalBristolCount
        : null;
    final int? baselineIdealRate = totalBristolCount > 0
        ? ((totalIdealCount / totalBristolCount) * 100).round()
        : null;

    final stats = <TriggerStat>[];
    for (final entry in tagLogs.entries) {
      final tagKey = entry.key;
      final matching = entry.value;
      if (matching.length < minSamples) continue;

      int tagBristolSum = 0;
      int tagBristolCount = 0;
      int tagIdealCount = 0;
      int effortCount = 0;
      int difficultCount = 0;

      for (final log in matching) {
        if (log.bristolType != null) {
          tagBristolSum += log.bristolType!;
          tagBristolCount++;
          if (log.bristolType! >= 3 && log.bristolType! <= 4) {
            tagIdealCount++;
          }
        }
        if (log.effort != null) {
          effortCount++;
          if (log.effort == EffortLevel.urgent ||
              log.effort == EffortLevel.struggled) {
            difficultCount++;
          }
        }
      }

      final double? avgBristol = tagBristolCount > 0
          ? tagBristolSum / tagBristolCount
          : null;
      final int? idealRate = tagBristolCount > 0
          ? ((tagIdealCount / tagBristolCount) * 100).round()
          : null;
      final int? urgentOrStruggledRate = effortCount > 0
          ? ((difficultCount / effortCount) * 100).round()
          : null;

      // Compare against throne logs WITHOUT this tag (fallback to overall baseline
      // when every Bristol-scored log carries this tag).
      double? bristolDelta;
      if (avgBristol != null && baselineBristol != null) {
        final otherCount = totalBristolCount - tagBristolCount;
        final double comparator = otherCount > 0
            ? (totalBristolSum - tagBristolSum) / otherCount
            : baselineBristol;
        bristolDelta = avgBristol - comparator;
      }

      final impact = _classifyImpact(
        bristolCount: tagBristolCount,
        avgBristol: avgBristol,
        bristolDelta: bristolDelta,
        idealRate: idealRate,
        effortCount: effortCount,
        urgentOrStruggledRate: urgentOrStruggledRate,
      );

      stats.add(
        TriggerStat(
          tagKey: tagKey,
          totalCount: matching.length,
          bristolCount: tagBristolCount,
          avgBristol: avgBristol,
          bristolDelta: bristolDelta,
          idealRate: idealRate,
          effortCount: effortCount,
          urgentOrStruggledRate: urgentOrStruggledRate,
          impact: impact,
        ),
      );
    }

    // Sort deterministically: highest sample count, then strongest Bristol shift,
    // then alphabetically by tagKey.
    stats.sort((a, b) {
      final byCount = b.totalCount.compareTo(a.totalCount);
      if (byCount != 0) return byCount;
      final deltaA = (a.bristolDelta ?? 0.0).abs();
      final deltaB = (b.bristolDelta ?? 0.0).abs();
      final byDelta = deltaB.compareTo(deltaA);
      if (byDelta != 0) return byDelta;
      return a.tagKey.compareTo(b.tagKey);
    });

    TriggerStat? bestAlly;
    for (final s in stats) {
      if (s.impact != TriggerImpact.ally) continue;
      if (bestAlly == null ||
          (s.idealRate ?? 0) > (bestAlly.idealRate ?? 0) ||
          ((s.idealRate ?? 0) == (bestAlly.idealRate ?? 0) &&
              s.totalCount > bestAlly.totalCount)) {
        bestAlly = s;
      }
    }

    TriggerStat? topDisruptor;
    double bestScore = -1;
    for (final s in stats) {
      if (!s.isDisruptor) continue;
      final score = (s.bristolDelta?.abs() ?? 0.0) * 10 +
          ((s.urgentOrStruggledRate ?? 0) / 10.0);
      if (score > bestScore) {
        bestScore = score;
        topDisruptor = s;
      }
    }

    return TriggerLabSnapshot(
      triggers: stats,
      baselineBristol: baselineBristol,
      baselineIdealRate: baselineIdealRate,
      taggedLogCount: taggedLogCount,
      bestAlly: bestAlly,
      topDisruptor: topDisruptor,
    );
  }

  static TriggerImpact _classifyImpact({
    required int bristolCount,
    required double? avgBristol,
    required double? bristolDelta,
    required int? idealRate,
    required int effortCount,
    required int? urgentOrStruggledRate,
  }) {
    if (bristolCount >= 2 && avgBristol != null) {
      final delta = bristolDelta ?? 0.0;
      if (avgBristol >= 5.0 || delta >= 0.7) {
        return TriggerImpact.softer;
      }
      if (avgBristol <= 2.5 || delta <= -0.7) {
        return TriggerImpact.firmer;
      }
    }

    if (effortCount >= 2 &&
        urgentOrStruggledRate != null &&
        urgentOrStruggledRate >= 50) {
      return TriggerImpact.intense;
    }

    if (bristolCount >= 2 &&
        idealRate != null &&
        idealRate >= 70 &&
        (urgentOrStruggledRate == null || urgentOrStruggledRate < 35) &&
        (bristolDelta?.abs() ?? 0.0) <= 0.8) {
      return TriggerImpact.ally;
    }

    return TriggerImpact.neutral;
  }
}

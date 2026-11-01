import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';

/// One performed segment of an exercise: a normal set, or one part of a
/// rest-pause set (the main set is the first segment, each mini-set another).
typedef Segment = ({double? weight, int reps});

/// A completed set of one exercise with its mini-sets, as input for stats.
class LoggedSet {
  const LoggedSet({
    required this.sessionId,
    required this.startedAt,
    required this.log,
    this.miniSets = const [],
  });

  final int sessionId;
  final DateTime startedAt;
  final SetLog log;
  final List<MiniSetLog> miniSets;

  List<Segment> get segments => [
        (weight: log.weightKg, reps: log.reps ?? 0),
        for (final m in miniSets) (weight: m.weightKg, reps: m.reps),
      ];
}

/// The exercise as performed in one session.
class SessionPoint {
  const SessionPoint({
    required this.sessionId,
    required this.date,
    required this.maxWeight,
    required this.bestRepsAtMax,
    required this.totalReps,
    required this.volumeKg,
    required this.sets,
    required this.segments,
  });

  final int sessionId;
  final DateTime date;

  /// Heaviest weight used, null if the session had no weighted segment.
  final double? maxWeight;

  /// Most reps in one segment at [maxWeight].
  final int bestRepsAtMax;
  final int totalReps;
  final double volumeKg;

  /// Main sets only.
  final int sets;

  /// Every segment in the order performed (the progression pattern).
  final List<Segment> segments;
}

/// Best performance at one weight across all sessions.
class WeightRecord {
  const WeightRecord(
      {required this.weight, required this.bestReps, required this.sets});

  /// null = no weight (bodyweight).
  final double? weight;
  final int bestReps;

  /// Main sets done at this weight (by the main set's weight).
  final int sets;
}

class ExerciseProgress {
  const ExerciseProgress({required this.points, required this.records});

  static const empty = ExerciseProgress(points: [], records: []);

  /// Oldest first.
  final List<SessionPoint> points;

  /// Heaviest weight first; the no-weight record (if any) is last.
  final List<WeightRecord> records;

  bool get isEmpty => points.isEmpty;

  double? get maxWeight {
    double? best;
    for (final r in records) {
      final w = r.weight;
      if (w != null && (best == null || w > best)) best = w;
    }
    return best;
  }

  double get totalVolumeKg => points.fold(0.0, (sum, p) => sum + p.volumeKg);
}

/// Builds the progress of one exercise from its completed sets.
ExerciseProgress buildExerciseProgress(Iterable<LoggedSet> sets) {
  final bySession = <int, List<LoggedSet>>{};
  for (final s in sets) {
    bySession.putIfAbsent(s.sessionId, () => <LoggedSet>[]).add(s);
  }

  final points = <SessionPoint>[];
  for (final entry in bySession.entries) {
    final list = [...entry.value]..sort((a, b) {
        final byIndex = a.log.setIndex.compareTo(b.log.setIndex);
        return byIndex != 0 ? byIndex : a.log.id.compareTo(b.log.id);
      });
    final segments = [for (final s in list) ...s.segments];
    double? maxWeight;
    for (final seg in segments) {
      final w = seg.weight;
      if (w != null && (maxWeight == null || w > maxWeight)) maxWeight = w;
    }
    var bestRepsAtMax = 0;
    var totalReps = 0;
    var volume = 0.0;
    for (final seg in segments) {
      totalReps += seg.reps;
      volume += (seg.weight ?? 0) * seg.reps;
      if (seg.weight == maxWeight && seg.reps > bestRepsAtMax) {
        bestRepsAtMax = seg.reps;
      }
    }
    points.add(SessionPoint(
      sessionId: entry.key,
      date: list.first.startedAt,
      maxWeight: maxWeight,
      bestRepsAtMax: bestRepsAtMax,
      totalReps: totalReps,
      volumeKg: volume,
      sets: list.length,
      segments: segments,
    ));
  }
  points.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.sessionId.compareTo(b.sessionId);
  });

  final bestReps = <double?, int>{};
  final setCount = <double?, int>{};
  for (final s in sets) {
    for (final seg in s.segments) {
      final current = bestReps[seg.weight] ?? 0;
      if (seg.reps > current) bestReps[seg.weight] = seg.reps;
    }
    setCount[s.log.weightKg] = (setCount[s.log.weightKg] ?? 0) + 1;
  }
  final weights = {...bestReps.keys, ...setCount.keys}.toList()
    ..sort((a, b) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return b.compareTo(a);
    });
  final records = [
    for (final w in weights)
      WeightRecord(
          weight: w, bestReps: bestReps[w] ?? 0, sets: setCount[w] ?? 0),
  ];

  return ExerciseProgress(points: points, records: records);
}

/// Progression pattern of a session, grouped by consecutive equal weights:
/// "60 kg × 8, 6 · 55 kg × 10". Segments without weight read "8, 6 reps".
String patternText(List<Segment> segments) {
  final groups = <(double?, List<int>)>[];
  for (final seg in segments) {
    if (groups.isNotEmpty && groups.last.$1 == seg.weight) {
      groups.last.$2.add(seg.reps);
    } else {
      groups.add((seg.weight, [seg.reps]));
    }
  }
  return groups.map((g) {
    final reps = g.$2.join(', ');
    final w = formatWeight(g.$1);
    return w == null ? '$reps reps' : '$w kg × $reps';
  }).join(' · ');
}

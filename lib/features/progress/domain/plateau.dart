import '../../../core/database/app_database.dart';
import 'progress.dart';

/// How long an exercise has been done at the same top weight.
class Plateau {
  const Plateau({
    required this.weight,
    required this.sessions,
    required this.weeks,
  });

  final double weight;

  /// Consecutive finished sessions at [weight], newest last.
  final int sessions;

  /// Whole weeks from the first of those sessions until now.
  final int weeks;
}

/// Finds a plateau: the latest finished sessions all had the same top weight
/// and it has been at least [minWeeks] weeks and [minSessions] sessions.
///
/// [points] are oldest first. [currentWeight] is the heaviest weight already
/// planned in the workout in progress; if it is higher the weight is being
/// increased right now, so there is nothing to point out. Bodyweight
/// exercises (no weight) never plateau here.
Plateau? detectPlateau(
  List<SessionPoint> points, {
  required DateTime now,
  double? currentWeight,
  int minSessions = 3,
  int minWeeks = 2,
}) {
  if (points.isEmpty) return null;
  final weight = points.last.maxWeight;
  if (weight == null) return null;
  if (currentWeight != null && currentWeight > weight) return null;

  var first = points.length - 1;
  while (first > 0 && points[first - 1].maxWeight == weight) {
    first--;
  }
  final sessions = points.length - first;
  final weeks = now.difference(points[first].date).inDays ~/ 7;
  if (sessions < minSessions || weeks < minWeeks) return null;
  return Plateau(weight: weight, sessions: sessions, weeks: weeks);
}

/// Heaviest weight among [sets], null if none has a weight.
double? heaviestWeight(Iterable<SetLog> sets) {
  double? best;
  for (final s in sets) {
    final w = s.weightKg;
    if (w != null && (best == null || w > best)) best = w;
  }
  return best;
}

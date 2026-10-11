import '../../../core/database/app_database.dart';

/// Totals of one finished session. Only completed sets are expected in the
/// input (finishing a session already drops unfinished sets).
class SessionStats {
  const SessionStats({
    required this.exerciseCount,
    required this.setCount,
    required this.totalReps,
    required this.volumeKg,
  });

  static const empty =
      SessionStats(exerciseCount: 0, setCount: 0, totalReps: 0, volumeKg: 0);

  final int exerciseCount;

  /// Main sets only: a rest-pause main set with mini-sets is still one set.
  final int setCount;

  /// Includes mini-set reps.
  final int totalReps;

  /// Sum of weight × reps in kg. Sets without weight (bodyweight) add 0.
  final double volumeKg;
}

SessionStats computeSessionStats(
    Iterable<SetLog> sets, Iterable<MiniSetLog> miniSets) {
  var setCount = 0;
  var reps = 0;
  var volume = 0.0;
  final exercises = <int>{};
  for (final s in sets) {
    setCount++;
    exercises.add(s.exerciseId);
    reps += s.reps ?? 0;
    volume += (s.weightKg ?? 0) * (s.reps ?? 0);
  }
  for (final m in miniSets) {
    reps += m.reps;
    volume += (m.weightKg ?? 0) * m.reps;
  }
  return SessionStats(
    exerciseCount: exercises.length,
    setCount: setCount,
    totalReps: reps,
    volumeKg: volume,
  );
}

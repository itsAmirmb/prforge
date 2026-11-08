import '../../../core/database/app_database.dart';
import '../../programs/domain/day_entries.dart';
import '../../programs/domain/rep_scheme.dart';
import 'rest_timing.dart';

/// Time under tension plus getting set up, per set. Rough on purpose: about
/// 3 s per rep and 10 s to get into position.
const setupSeconds = 10;
const secondsPerRep = 3;

/// Reps assumed for a set without a rep target.
const assumedReps = 10;

int workSecondsFor(int? reps) => setupSeconds + (reps ?? assumedReps) * secondsPerRep;

/// One planned set, in the order it is performed, with what decides the rest
/// after it (the same inputs as restSecondsAfterSet).
class EstimateSet {
  const EstimateSet({
    required this.exerciseId,
    this.supersetKey,
    this.round = 0,
    this.reps,
    this.setRest,
    this.betweenRest,
    this.afterRoundRest,
  });

  final int exerciseId;
  final String? supersetKey;
  final int round;
  final int? reps;
  final int? setRest;
  final int? betweenRest;
  final int? afterRoundRest;
}

/// Estimated time to do [sets] in order: the work of every set plus the rest
/// after every set but the last, using the same rest rules as the workout
/// itself (plan rest, superset rests, default rest, rest between exercises).
Duration estimateDuration(
  List<EstimateSet> sets, {
  required int defaultRest,
  int exerciseChangeRest = 0,
}) {
  var seconds = 0;
  for (var i = 0; i < sets.length; i++) {
    final s = sets[i];
    seconds += workSecondsFor(s.reps);
    if (i == sets.length - 1) break;

    final later = sets.skip(i + 1);
    final key = s.supersetKey;
    final next = sets[i + 1];
    final sameBlockLeft = later.any((o) => key == null
        ? o.supersetKey == null && o.exerciseId == s.exerciseId
        : o.supersetKey == key);
    seconds += restSecondsAfterSet(
          isSuperset: key != null,
          roundComplete: key == null ||
              next.supersetKey != key ||
              next.round != s.round,
          setRest: s.setRest,
          betweenRest: s.betweenRest,
          afterRoundRest: s.afterRoundRest,
          defaultRest: defaultRest,
          endsExercise: !sameBlockLeft,
          exerciseChangeRest: exerciseChangeRest,
        ) ??
        0;
  }
  return Duration(seconds: seconds);
}

/// The sets of a workout day in performing order, as startSession will
/// create them: a lone exercise set by set, a superset round by round.
/// [prescriptions] must be sorted by plan order.
List<EstimateSet> estimateSetsForPlan(
  List<ExercisePrescription> prescriptions,
  Map<int, SupersetGroup> groups,
) {
  EstimateSet make(ExercisePrescription p, int i, {SupersetGroup? group}) =>
      EstimateSet(
        exerciseId: p.exerciseId,
        supersetKey:
            p.supersetGroupId == null ? null : 's${p.supersetGroupId}',
        round: i,
        reps: repsForSet(i,
            scheme: parseRepScheme(p.repScheme), fallback: p.targetReps),
        setRest: p.restSeconds,
        betweenRest: group?.restBetweenSeconds,
        afterRoundRest: group?.restAfterRoundSeconds,
      );

  final result = <EstimateSet>[];
  for (final entry in toEntries(prescriptions, (p) => p.supersetGroupId)) {
    final groupId = entry.first.supersetGroupId;
    if (groupId == null) {
      for (var i = 0; i < entry.first.targetSets; i++) {
        result.add(make(entry.first, i));
      }
      continue;
    }
    final group = groups[groupId];
    final rounds = entry.map((p) => p.targetSets).fold(0, (a, b) => a > b ? a : b);
    for (var round = 0; round < rounds; round++) {
      for (final member in entry) {
        if (round < member.targetSets) {
          result.add(make(member, round, group: group));
        }
      }
    }
  }
  return result;
}

/// The sets of a running workout that are still to do, [ordered] in
/// performing order. Rests come from the plan the workout was started from
/// ([prescriptions], [groups]); sets added during the workout have none.
List<EstimateSet> estimateSetsForSession(
  List<SetLog> ordered, {
  required Map<int, ExercisePrescription> prescriptions,
  required Map<int, SupersetGroup> groups,
}) {
  return [
    for (final s in ordered)
      if (!s.isCompleted)
        () {
          final key = s.supersetKey;
          final group =
              key == null ? null : groups[int.tryParse(key.substring(1))];
          return EstimateSet(
            exerciseId: s.exerciseId,
            supersetKey: key,
            round: s.roundIndex ?? s.setIndex,
            reps: s.reps,
            setRest: prescriptions[s.prescriptionId]?.restSeconds,
            betweenRest: group?.restBetweenSeconds,
            afterRoundRest: group?.restAfterRoundSeconds,
          );
        }(),
  ];
}

/// "~55 min" or "~1 h 05 min", rounded up to a multiple of [roundToMinutes].
String formatEstimate(Duration d, {int roundToMinutes = 1}) {
  final exact = (d.inSeconds / 60).ceil();
  final minutes = exact <= 0
      ? 1
      : ((exact / roundToMinutes).ceil() * roundToMinutes);
  if (minutes < 60) return '~$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '~$h h' : '~$h h ${m.toString().padLeft(2, '0')} min';
}

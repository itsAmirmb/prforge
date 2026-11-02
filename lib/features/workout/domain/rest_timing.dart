/// Rest used when the plan does not say how long to rest.
const defaultRestSeconds = 90;

/// How long to rest after a set was completed, or null for no rest timer.
///
/// - Single exercise: the plan's rest, else [defaultRest].
/// - Superset member while the round is unfinished: [betweenRest] only.
/// - Last set of a superset round: [afterRoundRest], else the plan's rest,
///   else [defaultRest].
///
/// When [endsExercise] (the last set of an exercise, with another exercise
/// still to come) and [exerciseChangeRest] > 0, that rest is used instead.
///
/// A value of 0 means "no rest".
int? restSecondsAfterSet({
  required bool isSuperset,
  required bool roundComplete,
  int? setRest,
  int? betweenRest,
  int? afterRoundRest,
  int defaultRest = defaultRestSeconds,
  bool endsExercise = false,
  int exerciseChangeRest = 0,
}) {
  int? resolve(List<int?> candidates) {
    for (final c in candidates) {
      if (c != null) return c > 0 ? c : null;
    }
    return defaultRest > 0 ? defaultRest : null;
  }

  if (!isSuperset) {
    if (endsExercise && exerciseChangeRest > 0) return exerciseChangeRest;
    return resolve([setRest]);
  }
  if (!roundComplete) {
    return (betweenRest != null && betweenRest > 0) ? betweenRest : null;
  }
  if (endsExercise && exerciseChangeRest > 0) return exerciseChangeRest;
  return resolve([afterRoundRest, setRest]);
}

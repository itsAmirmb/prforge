import '../../../core/database/app_database.dart';

/// Rest taken before a new mini-set when nothing better is known (seconds).
const defaultMiniSetRestSeconds = 15;

/// Total reps of a rest-pause main set: the main set's own reps plus all of
/// its mini-sets.
int restPauseTotalReps(SetLog main, Iterable<MiniSetLog> minis) =>
    (main.reps ?? 0) + minis.fold<int>(0, (sum, m) => sum + m.reps);

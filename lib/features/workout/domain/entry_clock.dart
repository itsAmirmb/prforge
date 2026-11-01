import '../../../core/database/app_database.dart';
import '../../history/domain/entry_timing.dart';
import 'session_blocks.dart';

/// The small timer shown on an exercise card during a workout.
class EntryClock {
  const EntryClock({required this.elapsed, required this.running});

  final Duration elapsed;

  /// True for the exercise being worked on (the clock is counting).
  final bool running;
}

/// Time spent on [entry]: from the end of the previous exercise's last set
/// (or the session start) to its own last completed set. The exercise that
/// contains the current set keeps counting until its last set is done.
/// Null for exercises not started yet.
EntryClock? entryClock({
  required SessionEntry entry,
  required Iterable<SetLog> allSets,
  required DateTime sessionStart,
  required bool isCurrent,
  required DateTime now,
}) {
  final timing = entryTiming(entry, allSets, sessionStart);
  if (!isCurrent) {
    return timing == null
        ? null
        : EntryClock(elapsed: timing.duration, running: false);
  }
  final start = timing?.start ?? entryStart(entry, allSets, sessionStart, now);
  final elapsed = now.difference(start);
  return EntryClock(
    elapsed: elapsed.isNegative ? Duration.zero : elapsed,
    running: true,
  );
}

/// Time of one [set]: from the end of the previous completed set of the
/// session (or the session start) to its own completion, so the rest before
/// it is included. The current set keeps counting. Null for sets that are
/// neither done nor current.
EntryClock? setClock({
  required SetLog set,
  required Iterable<SetLog> allSets,
  required DateTime sessionStart,
  required bool isCurrent,
  required DateTime now,
}) {
  final doneAt = set.isCompleted ? set.completedAt : null;
  if (isCurrent) {
    final elapsed = now.difference(
      startBefore({set.id}, allSets, sessionStart, now),
    );
    return EntryClock(
      elapsed: elapsed.isNegative ? Duration.zero : elapsed,
      running: true,
    );
  }
  if (doneAt == null) return null;
  return EntryClock(
    elapsed: doneAt.difference(
      startBefore({set.id}, allSets, sessionStart, doneAt),
    ),
    running: false,
  );
}

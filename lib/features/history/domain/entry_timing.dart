import '../../../core/database/app_database.dart';
import '../../workout/domain/session_blocks.dart';

/// When one exercise (or superset) was worked on during a session.
///
/// [start] is the end of whatever came before it (the previous completed set
/// of the session, or the session start), so the first set's own time and the
/// setup are included. [end] is the last completed set of the entry.
class EntryTiming {
  const EntryTiming({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}

/// Start of an entry whose first set was completed at [before] (or that is
/// being worked on right now, [before] = now): the latest completed set of
/// another entry before it, else the session start.
DateTime entryStart(
  SessionEntry entry,
  Iterable<SetLog> allSets,
  DateTime sessionStart,
  DateTime before,
) {
  final own = {
    for (final b in entry.blocks)
      for (final s in b.sets) s.id,
  };
  DateTime? previous;
  for (final s in allSets) {
    final t = s.completedAt;
    if (t == null || !s.isCompleted || own.contains(s.id)) continue;
    if (t.isBefore(before) && (previous == null || t.isAfter(previous))) {
      previous = t;
    }
  }
  if (previous != null) return previous;
  return sessionStart.isBefore(before) ? sessionStart : before;
}

/// Timing of [entry] inside a session, or null when its sets carry no
/// completion times (sessions logged before times were recorded).
EntryTiming? entryTiming(
  SessionEntry entry,
  Iterable<SetLog> allSets,
  DateTime sessionStart,
) {
  final times = [
    for (final b in entry.blocks)
      for (final s in b.sets)
        if (s.isCompleted && s.completedAt != null) s.completedAt!,
  ];
  if (times.isEmpty) return null;
  times.sort();
  return EntryTiming(
    start: entryStart(entry, allSets, sessionStart, times.first),
    end: times.last,
  );
}

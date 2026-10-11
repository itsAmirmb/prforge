import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/session_stats.dart';

/// A finished session with the names it was done under and its totals.
class SessionSummary {
  const SessionSummary({
    required this.session,
    required this.programName,
    required this.dayName,
    required this.stats,
  });

  final WorkoutSession session;

  /// null if the session had no program/day or they no longer exist.
  final String? programName;
  final String? dayName;
  final SessionStats stats;

  Duration? get duration => session.completedAt?.difference(session.startedAt);
}

class HistoryRepository {
  HistoryRepository(this._db);

  final AppDatabase _db;

  /// Completed sessions, newest first.
  Stream<List<SessionSummary>> watchCompleted() {
    final s = _db.workoutSessions;
    final query = _db.select(s).join([
      leftOuterJoin(
          _db.workoutDays, _db.workoutDays.id.equalsExp(s.workoutDayId)),
      leftOuterJoin(_db.programs, _db.programs.id.equalsExp(s.programId)),
    ])
      ..where(s.status.equalsValue(SessionStatus.completed))
      ..orderBy([OrderingTerm.desc(s.startedAt), OrderingTerm.desc(s.id)]);

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return const <SessionSummary>[];
      final sets = await _completedSetsBySession();
      final minis = await _miniSetsBySession();
      return [
        for (final r in rows)
          () {
            final session = r.readTable(s);
            return SessionSummary(
              session: session,
              programName: r.readTableOrNull(_db.programs)?.name,
              dayName: r.readTableOrNull(_db.workoutDays)?.name,
              stats: computeSessionStats(
                sets[session.id] ?? const <SetLog>[],
                minis[session.id] ?? const <MiniSetLog>[],
              ),
            );
          }(),
      ];
    });
  }

  Future<Map<int, List<SetLog>>> _completedSetsBySession() async {
    final l = _db.setLogs;
    final s = _db.workoutSessions;
    final rows = await (_db.select(l).join([
      innerJoin(s, s.id.equalsExp(l.sessionId)),
    ])
          ..where(s.status.equalsValue(SessionStatus.completed) &
              l.isCompleted.equals(true)))
        .get();
    final map = <int, List<SetLog>>{};
    for (final r in rows) {
      final log = r.readTable(l);
      map.putIfAbsent(log.sessionId, () => <SetLog>[]).add(log);
    }
    return map;
  }

  Future<Map<int, List<MiniSetLog>>> _miniSetsBySession() async {
    final m = _db.miniSetLogs;
    final l = _db.setLogs;
    final s = _db.workoutSessions;
    final rows = await (_db.select(m).join([
      innerJoin(l, l.id.equalsExp(m.setLogId)),
      innerJoin(s, s.id.equalsExp(l.sessionId)),
    ])
          ..where(s.status.equalsValue(SessionStatus.completed) &
              l.isCompleted.equals(true)))
        .get();
    final map = <int, List<MiniSetLog>>{};
    for (final r in rows) {
      final sessionId = r.readTable(l).sessionId;
      map.putIfAbsent(sessionId, () => <MiniSetLog>[]).add(r.readTable(m));
    }
    return map;
  }

  /// Deletes a finished session with its sets and mini-sets (cascade).
  /// Returns false if the session does not exist or is not completed (an
  /// in-progress session is discarded from the workout screen instead).
  Future<bool> deleteCompleted(int sessionId) async {
    final deleted = await (_db.delete(_db.workoutSessions)
          ..where((s) =>
              s.id.equals(sessionId) &
              s.status.equalsValue(SessionStatus.completed)))
        .go();
    return deleted > 0;
  }
}

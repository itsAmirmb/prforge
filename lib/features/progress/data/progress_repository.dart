import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/progress.dart';

class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  /// Progress of one exercise from completed sets of completed sessions.
  Stream<ExerciseProgress> watchExercise(int exerciseId) {
    final l = _db.setLogs;
    final s = _db.workoutSessions;
    final query = _db.select(l).join([
      innerJoin(s, s.id.equalsExp(l.sessionId)),
    ])
      ..where(l.exerciseId.equals(exerciseId) &
          l.isCompleted.equals(true) &
          s.status.equalsValue(SessionStatus.completed));

    return query.watch().asyncMap((rows) async {
      if (rows.isEmpty) return ExerciseProgress.empty;
      final minis = await _miniSets(exerciseId);
      return buildExerciseProgress([
        for (final r in rows)
          LoggedSet(
            sessionId: r.readTable(s).id,
            startedAt: r.readTable(s).startedAt,
            log: r.readTable(l),
            miniSets: minis[r.readTable(l).id] ?? const <MiniSetLog>[],
          ),
      ]);
    });
  }

  Future<Map<int, List<MiniSetLog>>> _miniSets(int exerciseId) async {
    final m = _db.miniSetLogs;
    final l = _db.setLogs;
    final s = _db.workoutSessions;
    final rows = await (_db.select(m).join([
      innerJoin(l, l.id.equalsExp(m.setLogId)),
      innerJoin(s, s.id.equalsExp(l.sessionId)),
    ])
          ..where(l.exerciseId.equals(exerciseId) &
              l.isCompleted.equals(true) &
              s.status.equalsValue(SessionStatus.completed))
          ..orderBy([OrderingTerm.asc(m.miniSetIndex), OrderingTerm.asc(m.id)]))
        .get();
    final map = <int, List<MiniSetLog>>{};
    for (final r in rows) {
      map.putIfAbsent(r.readTable(m).setLogId, () => <MiniSetLog>[]).add(
            r.readTable(m),
          );
    }
    return map;
  }
}

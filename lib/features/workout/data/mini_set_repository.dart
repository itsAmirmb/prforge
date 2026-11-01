import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/rest_pause.dart';

/// Mini-sets of rest-pause main sets. A main set is a SetLog of kind
/// restPause (its own weight/reps are the first segment); each MiniSetLog is
/// a further segment after a short rest. The number of mini-sets is variable.
class MiniSetRepository {
  MiniSetRepository(this._db);

  final AppDatabase _db;

  /// All mini-sets of a session, ordered by index (group by setLogId in UI).
  Stream<List<MiniSetLog>> watchForSession(int sessionId) {
    final m = _db.miniSetLogs;
    final l = _db.setLogs;
    final query = _db.select(m).join([
      innerJoin(l, l.id.equalsExp(m.setLogId)),
    ])
      ..where(l.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(m.miniSetIndex), OrderingTerm.asc(m.id)]);
    return query.watch().map((rows) => [for (final r in rows) r.readTable(m)]);
  }

  /// Appends a mini-set to a rest-pause main set, copying weight, reps and
  /// rest from the previous segment for fast entry.
  Future<int> add(int setLogId) {
    return _db.transaction(() async {
      final main = await (_db.select(_db.setLogs)
            ..where((l) => l.id.equals(setLogId)))
          .getSingle();
      if (main.setKind != SetKind.restPause) {
        throw StateError('Mini-sets belong to rest-pause sets only.');
      }
      final lastRows = await (_db.select(_db.miniSetLogs)
            ..where((m) => m.setLogId.equals(setLogId))
            ..orderBy([
              (m) => OrderingTerm.desc(m.miniSetIndex),
              (m) => OrderingTerm.desc(m.id),
            ])
            ..limit(1))
          .get();
      final last = lastRows.isEmpty ? null : lastRows.first;
      return _db.into(_db.miniSetLogs).insert(
            MiniSetLogsCompanion.insert(
              setLogId: setLogId,
              miniSetIndex: (last?.miniSetIndex ?? -1) + 1,
              reps: last?.reps ?? main.reps ?? 0,
              weightKg: Value(last != null ? last.weightKg : main.weightKg),
              restSeconds:
                  Value(last?.restSeconds ?? defaultMiniSetRestSeconds),
            ),
          );
    });
  }

  Future<void> setWeight(int id, double? weightKg) async {
    await (_db.update(_db.miniSetLogs)..where((m) => m.id.equals(id)))
        .write(MiniSetLogsCompanion(weightKg: Value(weightKg)));
  }

  Future<void> setReps(int id, int reps) async {
    if (reps < 0) throw ArgumentError.value(reps, 'reps', 'must be >= 0');
    await (_db.update(_db.miniSetLogs)..where((m) => m.id.equals(id)))
        .write(MiniSetLogsCompanion(reps: Value(reps)));
  }

  Future<void> setRest(int id, int? restSeconds) async {
    if (restSeconds != null && restSeconds < 0) {
      throw ArgumentError.value(restSeconds, 'restSeconds', 'must be >= 0');
    }
    await (_db.update(_db.miniSetLogs)..where((m) => m.id.equals(id)))
        .write(MiniSetLogsCompanion(restSeconds: Value(restSeconds)));
  }

  /// Deletes a mini-set and returns it so the caller can offer Undo.
  Future<MiniSetLog> delete(int id) async {
    final mini = await (_db.select(_db.miniSetLogs)
          ..where((m) => m.id.equals(id)))
        .getSingle();
    await (_db.delete(_db.miniSetLogs)..where((m) => m.id.equals(id))).go();
    return mini;
  }

  Future<void> restore(MiniSetLog mini) async {
    await _db.into(_db.miniSetLogs).insert(mini);
  }
}

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/session_blocks.dart';

/// Workout session persistence. Every change is written immediately, so an
/// app crash or restart never loses logged data.
class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  // ───────── Session lifecycle ─────────

  Stream<WorkoutSession?> watchActiveSession() {
    return (_db.select(_db.workoutSessions)
          ..where((s) => s.status.equalsValue(SessionStatus.inProgress))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<WorkoutSession?> findActiveSession() {
    return (_db.select(_db.workoutSessions)
          ..where((s) => s.status.equalsValue(SessionStatus.inProgress))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Starts a session for [dayId] and creates one SetLog per planned set.
  ///
  /// Weights are prefilled from the last completed session of the same
  /// exercise (set by set; the last weight is reused if the plan has more
  /// sets), otherwise from the prescription's target weight. Reps are
  /// prefilled with the target reps. Nothing counts as done until the user
  /// marks the set completed.
  Future<int> startSession(int dayId) {
    return _db.transaction(() async {
      if (await findActiveSession() != null) {
        throw StateError('A workout is already in progress.');
      }
      final day = await (_db.select(_db.workoutDays)
            ..where((d) => d.id.equals(dayId)))
          .getSingle();
      final sessionId = await _db.into(_db.workoutSessions).insert(
            WorkoutSessionsCompanion.insert(
              startedAt: DateTime.now(),
              programId: Value(day.programId),
              workoutDayId: Value(dayId),
            ),
          );
      final prescriptions = await (_db.select(_db.exercisePrescriptions)
            ..where((p) => p.workoutDayId.equals(dayId))
            ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
          .get();
      for (final p in prescriptions) {
        final last = await lastPerformance(p.exerciseId);
        for (var i = 0; i < p.targetSets; i++) {
          final double? weight = last.isEmpty
              ? p.targetWeightKg
              : (i < last.length ? last[i] : last.last).weightKg;
          await _db.into(_db.setLogs).insert(
                SetLogsCompanion.insert(
                  sessionId: sessionId,
                  exerciseId: p.exerciseId,
                  setIndex: i,
                  prescriptionId: Value(p.id),
                  setKind: Value(p.setType),
                  weightKg: Value(weight),
                  reps: Value(p.targetReps),
                ),
              );
        }
      }
      return sessionId;
    });
  }

  /// Completes the session. Sets that were never marked done are discarded.
  Future<void> finishSession(int sessionId) {
    return _db.transaction(() async {
      await (_db.delete(_db.setLogs)
            ..where((l) =>
                l.sessionId.equals(sessionId) & l.isCompleted.equals(false)))
          .go();
      await (_db.update(_db.workoutSessions)
            ..where((s) => s.id.equals(sessionId)))
          .write(WorkoutSessionsCompanion(
        status: const Value(SessionStatus.completed),
        completedAt: Value(DateTime.now()),
      ));
    });
  }

  /// Deletes the session and all of its sets (cascade).
  Future<void> discardSession(int sessionId) async {
    await (_db.delete(_db.workoutSessions)..where((s) => s.id.equals(sessionId)))
        .go();
  }

  // ───────── Sets ─────────

  Stream<List<SetLogWithExercise>> watchSessionSets(int sessionId) {
    final l = _db.setLogs;
    final query = _db.select(l).join([
      innerJoin(_db.exercises, _db.exercises.id.equalsExp(l.exerciseId)),
    ])
      ..where(l.sessionId.equals(sessionId))
      ..orderBy([OrderingTerm.asc(l.id)]);
    return query.watch().map((rows) => [
          for (final r in rows)
            SetLogWithExercise(r.readTable(l), r.readTable(_db.exercises)),
        ]);
  }

  Future<void> setWeight(int setId, double? weightKg) async {
    await (_db.update(_db.setLogs)..where((l) => l.id.equals(setId)))
        .write(SetLogsCompanion(weightKg: Value(weightKg)));
  }

  Future<void> setReps(int setId, int? reps) async {
    await (_db.update(_db.setLogs)..where((l) => l.id.equals(setId)))
        .write(SetLogsCompanion(reps: Value(reps)));
  }

  /// Marks a set done / not done. A set needs reps to be marked done.
  Future<void> setCompleted(int setId, bool completed) async {
    final log = await (_db.select(_db.setLogs)..where((l) => l.id.equals(setId)))
        .getSingle();
    if (completed && log.reps == null) {
      throw StateError('Enter reps before completing the set.');
    }
    await (_db.update(_db.setLogs)..where((l) => l.id.equals(setId)))
        .write(SetLogsCompanion(isCompleted: Value(completed)));
  }

  /// Adds a set at the end of a block, copying weight and reps of the
  /// block's last set for fast entry.
  Future<int> addSet(int sessionId, int exerciseId, int? prescriptionId) async {
    final l = _db.setLogs;
    final block = await (_db.select(l)
          ..where((s) =>
              s.sessionId.equals(sessionId) &
              s.exerciseId.equals(exerciseId) &
              (prescriptionId == null
                  ? s.prescriptionId.isNull()
                  : s.prescriptionId.equals(prescriptionId)))
          ..orderBy([
            (s) => OrderingTerm.desc(s.setIndex),
            (s) => OrderingTerm.desc(s.id),
          ])
          ..limit(1))
        .get();
    final last = block.isEmpty ? null : block.first;
    return _db.into(l).insert(
          SetLogsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            setIndex: (last?.setIndex ?? -1) + 1,
            prescriptionId: Value(prescriptionId),
            setKind: Value(last?.setKind ?? SetKind.normal),
            weightKg: Value(last?.weightKg),
            reps: Value(last?.reps),
          ),
        );
  }

  /// Deletes a set and returns it so the caller can offer Undo.
  Future<SetLog> deleteSet(int setId) async {
    final log = await (_db.select(_db.setLogs)..where((l) => l.id.equals(setId)))
        .getSingle();
    await (_db.delete(_db.setLogs)..where((l) => l.id.equals(setId))).go();
    return log;
  }

  /// Re-inserts a set returned by [deleteSet] (same id, same position).
  Future<void> restoreSet(SetLog log) async {
    await _db.into(_db.setLogs).insert(log);
  }

  // ───────── History lookup ─────────

  /// Completed sets of the most recent completed session that contains the
  /// exercise, ordered by set index. Empty if there is no history.
  Future<List<SetLog>> lastPerformance(int exerciseId) async {
    final l = _db.setLogs;
    final s = _db.workoutSessions;
    final latest = await (_db.select(l).join([
      innerJoin(s, s.id.equalsExp(l.sessionId)),
    ])
          ..where(l.exerciseId.equals(exerciseId) &
              l.isCompleted.equals(true) &
              s.status.equalsValue(SessionStatus.completed))
          ..orderBy([OrderingTerm.desc(s.startedAt), OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
    if (latest == null) return const [];
    return (_db.select(l)
          ..where((x) =>
              x.sessionId.equals(latest.read(s.id)!) &
              x.exerciseId.equals(exerciseId) &
              x.isCompleted.equals(true))
          ..orderBy([
            (x) => OrderingTerm.asc(x.setIndex),
            (x) => OrderingTerm.asc(x.id),
          ]))
        .get();
  }
}

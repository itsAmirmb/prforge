import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// Thrown when a day cannot be deleted because workout sessions reference it.
class DayHasHistoryException implements Exception {
  const DayHasHistoryException();

  @override
  String toString() => 'This day has logged workouts and cannot be deleted.';
}

class WorkoutDayRepository {
  WorkoutDayRepository(this._db);

  final AppDatabase _db;

  Stream<List<WorkoutDay>> watchDays(int programId) {
    final query = _db.select(_db.workoutDays)
      ..where((d) => d.programId.equals(programId))
      ..orderBy([(d) => OrderingTerm.asc(d.orderIndex)]);
    return query.watch();
  }

  /// Appends a day at the end of the program.
  Future<int> add(int programId, String name) async {
    final maxIndex = _db.workoutDays.orderIndex.max();
    final row = await (_db.selectOnly(_db.workoutDays)
          ..addColumns([maxIndex])
          ..where(_db.workoutDays.programId.equals(programId)))
        .getSingle();
    final next = (row.read(maxIndex) ?? -1) + 1;
    return _db.into(_db.workoutDays).insert(
          WorkoutDaysCompanion.insert(
            programId: programId,
            name: _requireName(name),
            orderIndex: next,
          ),
        );
  }

  Future<void> rename(int id, String name) async {
    await (_db.update(_db.workoutDays)..where((d) => d.id.equals(id)))
        .write(WorkoutDaysCompanion(name: Value(_requireName(name))));
  }

  /// Persists the given order (first id gets index 0, and so on).
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.workoutDays)
              ..where((d) => d.id.equals(orderedIds[i])))
            .write(WorkoutDaysCompanion(orderIndex: Value(i)));
      }
    });
  }

  /// Deletes a day with its planned content. Refuses if any session used it,
  /// so history is never broken.
  Future<void> delete(int id) {
    return _db.transaction(() async {
      final used = await (_db.select(_db.workoutSessions)
            ..where((s) => s.workoutDayId.equals(id))
            ..limit(1))
          .get();
      if (used.isNotEmpty) throw const DayHasHistoryException();

      await (_db.delete(_db.exercisePrescriptions)
            ..where((p) => p.workoutDayId.equals(id)))
          .go();
      await (_db.delete(_db.supersetGroups)
            ..where((g) => g.workoutDayId.equals(id)))
          .go();
      await (_db.delete(_db.workoutDays)..where((d) => d.id.equals(id))).go();
    });
  }

  static String _requireName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be blank');
    }
    return trimmed;
  }
}

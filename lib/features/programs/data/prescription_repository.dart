import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import 'day_structure.dart';

/// Planned values for one exercise inside a workout day.
class PrescriptionDraft {
  const PrescriptionDraft({
    required this.exerciseId,
    this.targetSets = 3,
    this.targetReps,
    this.targetWeightKg,
    this.setType = SetKind.normal,
    this.restSeconds,
    this.notes,
  });

  final int exerciseId;
  final int targetSets;
  final int? targetReps;

  /// Always kg; null = no target (weight is decided per session).
  final double? targetWeightKg;
  final SetKind setType;
  final int? restSeconds;
  final String? notes;

  void validate() {
    if (targetSets < 1) {
      throw ArgumentError.value(targetSets, 'targetSets', 'must be >= 1');
    }
    if (targetReps != null && targetReps! < 1) {
      throw ArgumentError.value(targetReps, 'targetReps', 'must be >= 1');
    }
    if (targetWeightKg != null && targetWeightKg! < 0) {
      throw ArgumentError.value(targetWeightKg, 'targetWeightKg', 'must be >= 0');
    }
    if (restSeconds != null && restSeconds! < 0) {
      throw ArgumentError.value(restSeconds, 'restSeconds', 'must be >= 0');
    }
  }
}

class PrescriptionWithExercise {
  const PrescriptionWithExercise(this.prescription, this.exercise);

  final ExercisePrescription prescription;
  final Exercise exercise;
}

class PrescriptionRepository {
  PrescriptionRepository(this._db);

  final AppDatabase _db;

  Stream<List<PrescriptionWithExercise>> watchForDay(int dayId) {
    final p = _db.exercisePrescriptions;
    final query = _db.select(p).join([
      innerJoin(_db.exercises, _db.exercises.id.equalsExp(p.exerciseId)),
    ])
      ..where(p.workoutDayId.equals(dayId))
      ..orderBy([OrderingTerm.asc(p.orderIndex)]);
    return query.watch().map((rows) => [
          for (final r in rows)
            PrescriptionWithExercise(
              r.readTable(p),
              r.readTable(_db.exercises),
            ),
        ]);
  }

  /// Appends the exercise at the end of the day.
  Future<int> add(int dayId, PrescriptionDraft draft) async {
    draft.validate();
    final p = _db.exercisePrescriptions;
    final maxIndex = p.orderIndex.max();
    final row = await (_db.selectOnly(p)
          ..addColumns([maxIndex])
          ..where(p.workoutDayId.equals(dayId)))
        .getSingle();
    final next = (row.read(maxIndex) ?? -1) + 1;
    return _db.into(p).insert(
          ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: draft.exerciseId,
            orderIndex: next,
            targetSets: Value(draft.targetSets),
            targetReps: Value(draft.targetReps),
            targetWeightKg: Value(draft.targetWeightKg),
            setType: Value(draft.setType),
            restSeconds: Value(draft.restSeconds),
            notes: Value(_clean(draft.notes)),
          ),
        );
  }

  Future<void> update(int id, PrescriptionDraft draft) async {
    draft.validate();
    await (_db.update(_db.exercisePrescriptions)..where((p) => p.id.equals(id)))
        .write(
      ExercisePrescriptionsCompanion(
        exerciseId: Value(draft.exerciseId),
        targetSets: Value(draft.targetSets),
        targetReps: Value(draft.targetReps),
        targetWeightKg: Value(draft.targetWeightKg),
        setType: Value(draft.setType),
        restSeconds: Value(draft.restSeconds),
        notes: Value(_clean(draft.notes)),
      ),
    );
  }

  /// Persists the given order (first id gets index 0, and so on).
  ///
  /// Only for days without supersets; the day screen uses
  /// SupersetRepository.reorderEntries, which moves a superset as one unit.
  Future<void> reorder(List<int> orderedIds) {
    return _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.exercisePrescriptions)
              ..where((p) => p.id.equals(orderedIds[i])))
            .write(ExercisePrescriptionsCompanion(orderIndex: Value(i)));
      }
    });
  }

  /// Removes the exercise from the plan. Logged sets keep their exerciseId and
  /// only lose the link to the removed prescription, so history is untouched.
  /// If it was a superset member, the group is repaired (dissolved when fewer
  /// than 2 members remain).
  Future<void> remove(int id) {
    return _db.transaction(() async {
      final row = await (_db.select(_db.exercisePrescriptions)
            ..where((p) => p.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return;
      await (_db.update(_db.setLogs)..where((l) => l.prescriptionId.equals(id)))
          .write(const SetLogsCompanion(prescriptionId: Value(null)));
      await (_db.delete(_db.exercisePrescriptions)
            ..where((p) => p.id.equals(id)))
          .go();
      await DayStructure(_db).normalize(row.workoutDayId);
    });
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

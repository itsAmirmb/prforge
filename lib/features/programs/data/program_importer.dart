import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/program_template.dart';

class ProgramImportResult {
  const ProgramImportResult({
    required this.programName,
    required this.days,
    required this.prescriptions,
    required this.exercisesCreated,
    required this.exercisesReused,
  });

  final String programName;
  final int days;
  final int prescriptions;
  final int exercisesCreated;
  final int exercisesReused;
}

/// Adds a program from a template. Nothing existing is changed or removed:
/// the program is new, and exercises are matched by name (ignoring case and
/// extra spaces) so history of existing exercises keeps working. Everything
/// is saved in one transaction.
class ProgramImporter {
  ProgramImporter(this._db);

  final AppDatabase _db;

  static String _key(String name) => name
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  Future<ProgramImportResult> importJson(String text) async {
    final template = parseProgramTemplate(text);
    return _db.transaction(() async {
      final existing = await _db.select(_db.exercises).get();
      final ids = {for (final e in existing) _key(e.name): e.id};
      final archived = {
        for (final e in existing)
          if (e.isArchived) e.id,
      };
      final created = <int>{};
      final reused = <int>{};

      Future<int> exerciseId(String name) async {
        final key = _key(name);
        final found = ids[key];
        if (found != null) {
          if (!created.contains(found)) reused.add(found);
          if (archived.remove(found)) {
            await (_db.update(_db.exercises)..where((e) => e.id.equals(found)))
                .write(const ExercisesCompanion(isArchived: Value(false)));
          }
          return found;
        }
        final id = await _db
            .into(_db.exercises)
            .insert(ExercisesCompanion.insert(name: name.trim()));
        created.add(id);
        ids[key] = id;
        return id;
      }

      final programId = await _db
          .into(_db.programs)
          .insert(ProgramsCompanion.insert(name: template.name));
      var prescriptions = 0;

      for (var d = 0; d < template.days.length; d++) {
        final day = template.days[d];
        final dayId = await _db.into(_db.workoutDays).insert(
              WorkoutDaysCompanion.insert(
                programId: programId,
                name: day.name,
                orderIndex: d,
              ),
            );
        var index = 0; // prescription order
        var entry = 0; // entry order (a superset counts once)

        Future<void> add(TemplateExercise e,
            {int? groupId, int? groupOrder}) async {
          await _db.into(_db.exercisePrescriptions).insert(
                ExercisePrescriptionsCompanion.insert(
                  workoutDayId: dayId,
                  exerciseId: await exerciseId(e.name),
                  orderIndex: index++,
                  targetSets: Value(e.sets),
                  targetReps: Value(e.reps),
                  targetWeightKg: Value(e.weightKg),
                  setType: Value(e.type),
                  supersetGroupId: Value(groupId),
                  supersetOrder: Value(groupOrder),
                  restSeconds: Value(e.restSeconds),
                  notes: Value(e.notes),
                ),
              );
          prescriptions++;
        }

        for (final e in day.entries) {
          switch (e) {
            case TemplateExercise():
              await add(e);
              entry++;
            case TemplateSuperset():
              final groupId = await _db.into(_db.supersetGroups).insert(
                    SupersetGroupsCompanion.insert(
                      workoutDayId: dayId,
                      orderIndex: entry++,
                      rounds: Value(e.rounds),
                    ),
                  );
              for (var j = 0; j < e.members.length; j++) {
                await add(e.members[j], groupId: groupId, groupOrder: j);
              }
          }
        }
      }

      return ProgramImportResult(
        programName: template.name,
        days: template.days.length,
        prescriptions: prescriptions,
        exercisesCreated: created.length,
        exercisesReused: reused.length,
      );
    });
  }
}

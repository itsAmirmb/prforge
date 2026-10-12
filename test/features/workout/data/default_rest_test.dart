import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late int setId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    final dayId = await db.into(db.workoutDays).insert(
        WorkoutDaysCompanion.insert(
            programId: programId, name: 'D', orderIndex: 0));
    final ex = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Bench'));
    // No restSeconds in the plan: the default applies.
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: ex,
            orderIndex: 0,
            targetSets: const Value(1),
            targetReps: const Value(8)));
    final sessionId = await sessions.startSession(dayId);
    setId = (await (db.select(db.setLogs)
              ..where((l) => l.sessionId.equals(sessionId)))
            .getSingle())
        .id;
    await sessions.setCompleted(setId, true);
  });

  tearDown(() => db.close());

  test('without a setting the built-in default is used', () async {
    expect(await sessions.restAfterCompleting(setId), 90);
  });

  test('the configured default rest is used when the plan has none', () async {
    expect(await sessions.restAfterCompleting(setId, defaultRest: 45), 45);
  });

  test('a default of 0 means no timer', () async {
    expect(await sessions.restAfterCompleting(setId, defaultRest: 0), isNull);
  });
}

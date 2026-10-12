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
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: ex,
            orderIndex: 0,
            targetSets: const Value(2),
            targetReps: const Value(8)));
    final sessionId = await sessions.startSession(dayId);
    setId = (await (db.select(db.setLogs)
              ..where((l) => l.sessionId.equals(sessionId))
              ..limit(1))
            .getSingle())
        .id;
  });

  tearDown(() => db.close());

  Future<SetLog> row() =>
      (db.select(db.setLogs)..where((l) => l.id.equals(setId))).getSingle();

  test('completing stamps the time, uncompleting clears it', () async {
    expect((await row()).completedAt, isNull);
    await sessions.setCompleted(setId, true);
    final done = await row();
    expect(done.isCompleted, isTrue);
    expect(done.completedAt, isNotNull);
    await sessions.setCompleted(setId, false);
    final undone = await row();
    expect(undone.isCompleted, isFalse);
    expect(undone.completedAt, isNull);
  });

  test('completing an already completed set keeps the first time', () async {
    await sessions.setCompleted(setId, true);
    final first = (await row()).completedAt;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await sessions.setCompleted(setId, true);
    expect((await row()).completedAt, first);
  });
}

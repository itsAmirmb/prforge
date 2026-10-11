import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late int sessionId;
  late int curl;
  late int squat;
  late int curlPrescription;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    final dayId = await db.into(db.workoutDays).insert(
        WorkoutDaysCompanion.insert(
            programId: programId, name: 'D', orderIndex: 0));
    curl = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Curl'));
    squat = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Squat'));
    curlPrescription = await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: curl,
            orderIndex: 0,
            targetSets: const Value(3),
            targetReps: const Value(10),
            targetWeightKg: const Value(5)));
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: squat,
            orderIndex: 1,
            targetSets: const Value(2),
            targetWeightKg: const Value(40)));
    sessionId = await repo.startSession(dayId);
  });

  tearDown(() => db.close());

  Future<List<SetLog>> block(int exerciseId) => (db.select(db.setLogs)
        ..where((l) =>
            l.sessionId.equals(sessionId) & l.exerciseId.equals(exerciseId))
        ..orderBy([
          (l) => OrderingTerm.asc(l.setIndex),
          (l) => OrderingTerm.asc(l.id),
        ]))
      .get();

  Future<void> apply(int atNew, {int? reps, double prev = 5, double next = 7.5}) =>
      repo.applyProgressiveLoading(
        sessionId: sessionId,
        exerciseId: curl,
        prescriptionId: curlPrescription,
        previousWeight: prev,
        newWeight: next,
        setsAtNewWeight: atNew,
        reps: reps,
      );

  test('1 of 3 sets at the new weight: 7.5, 5, 5', () async {
    await apply(1);
    expect((await block(curl)).map((l) => l.weightKg), [7.5, 5, 5]);
  });

  test('stepping 1/3 -> 2/3 -> 3/3 and back to 2/3 -> 1/3', () async {
    final expected = {
      1: [7.5, 5.0, 5.0],
      2: [7.5, 7.5, 5.0],
      3: [7.5, 7.5, 7.5],
    };
    for (final n in [1, 2, 3, 2, 1]) {
      await apply(n);
      expect((await block(curl)).map((l) => l.weightKg), expected[n]);
    }
  });

  test('each set stays an independent SetLog with its own reps', () async {
    await apply(2);
    final sets = await block(curl);
    await repo.setReps(sets[0].id, 8);
    await repo.setReps(sets[2].id, 12);
    final after = await block(curl);
    expect(after.map((l) => l.reps), [8, 10, 12]);
    expect(after.map((l) => l.weightKg), [7.5, 7.5, 5]);
  });

  test('reps are updated only when given', () async {
    await apply(1);
    expect((await block(curl)).every((l) => l.reps == 10), isTrue);
    await apply(1, reps: 8);
    expect((await block(curl)).every((l) => l.reps == 8), isTrue);
  });

  test('completed sets are not touched; plan covers the unfinished ones',
      () async {
    final first = (await block(curl)).first;
    await repo.setCompleted(first.id, true);

    await apply(1);

    final sets = await block(curl);
    expect(sets.map((l) => l.weightKg), [5, 7.5, 5]);
    expect(sets.first.isCompleted, isTrue);
  });

  test('other exercises are not affected', () async {
    await apply(3);
    expect((await block(squat)).map((l) => l.weightKg), [40, 40]);
  });

  test('fails when every set is already completed', () async {
    for (final s in await block(curl)) {
      await repo.setCompleted(s.id, true);
    }
    expect(() => apply(1), throwsStateError);
  });

  test('invalid set count is rejected and nothing changes', () async {
    expect(() => apply(4), throwsArgumentError);
    expect((await block(curl)).map((l) => l.weightKg), [5, 5, 5]);
  });
}

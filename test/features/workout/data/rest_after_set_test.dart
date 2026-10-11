import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/data/session_repository.dart';
import 'package:prforge/features/workout/domain/rest_timing.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late int dayId;
  late int sessionId;
  late int benchId;
  late int curlId;
  late int flyId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
        programId: programId, name: 'D', orderIndex: 0));
    Future<int> exercise(String n) =>
        db.into(db.exercises).insert(ExercisesCompanion.insert(name: n));
    benchId = await exercise('Bench');
    curlId = await exercise('Curl');
    flyId = await exercise('Fly');

    // Bench: 2 sets, 60s rest. Curl + Fly: superset of 2 rounds.
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: benchId,
            orderIndex: 0,
            targetSets: const Value(2),
            targetReps: const Value(8),
            restSeconds: const Value(60)));
    final groupId = await db.into(db.supersetGroups).insert(
        SupersetGroupsCompanion.insert(
            workoutDayId: dayId,
            orderIndex: 1,
            rounds: const Value(2),
            restBetweenSeconds: const Value(10),
            restAfterRoundSeconds: const Value(120)));
    for (final (i, ex) in [curlId, flyId].indexed) {
      await db.into(db.exercisePrescriptions).insert(
          ExercisePrescriptionsCompanion.insert(
              workoutDayId: dayId,
              exerciseId: ex,
              orderIndex: 1 + i,
              targetSets: const Value(2),
              targetReps: const Value(10),
              supersetGroupId: Value(groupId),
              supersetOrder: Value(i)));
    }
    sessionId = await sessions.startSession(dayId);
  });

  tearDown(() => db.close());

  Future<SetLog> setOf(int exerciseId, int index) =>
      (db.select(db.setLogs)
            ..where((l) =>
                l.sessionId.equals(sessionId) &
                l.exerciseId.equals(exerciseId) &
                l.setIndex.equals(index)))
          .getSingle();

  Future<int?> complete(SetLog s) async {
    await sessions.setCompleted(s.id, true);
    return sessions.restAfterCompleting(s.id);
  }

  test('a set that is not completed gives no rest', () async {
    final s = await setOf(benchId, 0);
    expect(await sessions.restAfterCompleting(s.id), isNull);
  });

  test('single exercise: the planned rest', () async {
    expect(await complete(await setOf(benchId, 0)), 60);
  });

  test('single exercise without planned rest: the default', () async {
    await (db.update(db.exercisePrescriptions)
          ..where((p) => p.exerciseId.equals(benchId)))
        .write(const ExercisePrescriptionsCompanion(restSeconds: Value(null)));
    expect(await complete(await setOf(benchId, 0)), defaultRestSeconds);
  });

  test('superset: short rest between members, group rest after the round',
      () async {
    expect(await complete(await setOf(curlId, 0)), 10);
    expect(await complete(await setOf(flyId, 0)), 120);
  });

  test('superset rounds are independent', () async {
    await complete(await setOf(curlId, 0));
    await complete(await setOf(flyId, 0));
    // First set of round 2: its partner is still open.
    expect(await complete(await setOf(curlId, 1)), 10);
    expect(await complete(await setOf(flyId, 1)), 120);
  });

  test('superset without group rest values: none between, plan/default after',
      () async {
    await db.update(db.supersetGroups).write(const SupersetGroupsCompanion(
        restBetweenSeconds: Value(null), restAfterRoundSeconds: Value(null)));
    expect(await complete(await setOf(curlId, 0)), isNull);
    expect(await complete(await setOf(flyId, 0)), defaultRestSeconds);
  });
}

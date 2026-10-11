import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/progress/data/progress_repository.dart';
import 'package:prforge/features/workout/data/mini_set_repository.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late MiniSetRepository minis;
  late ProgressRepository progress;
  late int dayId;
  late int pressId;
  late int curlId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    minis = MiniSetRepository(db);
    progress = ProgressRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
        programId: programId, name: 'D', orderIndex: 0));
    pressId = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Press'));
    curlId = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Curl'));
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: pressId,
            orderIndex: 0,
            targetSets: const Value(2),
            targetReps: const Value(10),
            targetWeightKg: const Value(20)));
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: curlId,
            orderIndex: 1,
            targetSets: const Value(1),
            targetReps: const Value(8),
            targetWeightKg: const Value(10)));
  });

  tearDown(() => db.close());

  Future<List<SetLog>> setsOf(int sessionId, int exerciseId) =>
      (db.select(db.setLogs)
            ..where((l) =>
                l.sessionId.equals(sessionId) &
                l.exerciseId.equals(exerciseId))
            ..orderBy([(l) => OrderingTerm.asc(l.setIndex)]))
          .get();

  /// Finishes a session where the press sets are done at [weights] x 10.
  Future<int> pressSession(List<double> weights) async {
    final id = await sessions.startSession(dayId);
    final sets = await setsOf(id, pressId);
    for (var i = 0; i < weights.length; i++) {
      await sessions.setWeight(sets[i].id, weights[i]);
      await sessions.setCompleted(sets[i].id, true);
    }
    await sessions.finishSession(id);
    return id;
  }

  test('no history -> empty', () async {
    expect((await progress.watchExercise(pressId).first).isEmpty, isTrue);
  });

  test('only counts the requested exercise from completed sessions',
      () async {
    await pressSession([20, 20]);
    await sessions.startSession(dayId); // in progress, must be ignored

    final press = await progress.watchExercise(pressId).first;
    expect(press.points, hasLength(1));
    expect(press.points.single.sets, 2);
    // Curl sets were not completed, so there is nothing for it.
    expect((await progress.watchExercise(curlId).first).isEmpty, isTrue);
  });

  test('tracks weight increase across sessions', () async {
    final a = await pressSession([20, 20]);
    await (db.update(db.workoutSessions)..where((s) => s.id.equals(a)))
        .write(WorkoutSessionsCompanion(startedAt: Value(DateTime(2020, 1, 1))));
    await pressSession([22.5, 20]); // stepped loading in one session

    final p = await progress.watchExercise(pressId).first;
    expect(p.points.map((x) => x.maxWeight), [20, 22.5]);
    expect(p.points.last.segments.map((s) => s.weight), [22.5, 20]);
    expect(p.maxWeight, 22.5);
    expect(p.records.map((r) => r.weight), [22.5, 20]);
    expect(p.records.last.sets, 3);
  });

  test('includes rest-pause mini-sets', () async {
    final id = await sessions.startSession(dayId);
    final press = (await setsOf(id, pressId)).first;
    await db.update(db.setLogs).replace(press.copyWith(setKind: SetKind.restPause));
    await sessions.setCompleted(press.id, true);
    await minis.add(press.id);
    await minis.setReps((await minis.watchForSession(id).first).single.id, 4);
    await sessions.finishSession(id);

    final p = await progress.watchExercise(pressId).first;
    expect(p.points.single.totalReps, 14);
    expect(p.points.single.sets, 1);
  });
}

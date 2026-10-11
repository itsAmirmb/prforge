import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/history/data/history_repository.dart';
import 'package:prforge/features/workout/data/mini_set_repository.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late MiniSetRepository minis;
  late HistoryRepository history;
  late int programId;
  late int dayId;
  late int pressId;
  late int curlId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    minis = MiniSetRepository(db);
    history = HistoryRepository(db);
    programId = await db
        .into(db.programs)
        .insert(ProgramsCompanion.insert(name: 'PPL'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
        programId: programId, name: 'Push', orderIndex: 0));
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
            targetWeightKg: const Value(20),
            setType: const Value(SetKind.restPause)));
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: curlId,
            orderIndex: 1,
            targetSets: const Value(2),
            targetReps: const Value(8),
            targetWeightKg: const Value(10)));
  });

  tearDown(() => db.close());

  Future<List<SetLog>> setsOf(int sessionId) => (db.select(db.setLogs)
        ..where((l) => l.sessionId.equals(sessionId))
        ..orderBy([(l) => OrderingTerm.asc(l.id)]))
      .get();

  /// Starts a session, completes the first press set (+1 mini) and the first
  /// curl set, then finishes it.
  Future<int> doWorkout() async {
    final id = await sessions.startSession(dayId);
    final sets = await setsOf(id);
    final press = sets.firstWhere((s) => s.exerciseId == pressId);
    final curl = sets.firstWhere((s) => s.exerciseId == curlId);
    await sessions.setCompleted(press.id, true);
    await minis.add(press.id);
    await minis.setReps((await minis.watchForSession(id).first).single.id, 4);
    await sessions.setCompleted(curl.id, true);
    await sessions.finishSession(id);
    return id;
  }

  test('empty history', () async {
    expect(await history.watchCompleted().first, isEmpty);
  });

  test('lists only completed sessions, with names and totals', () async {
    await doWorkout();
    await sessions.startSession(dayId); // still in progress

    final list = await history.watchCompleted().first;
    expect(list, hasLength(1));
    final s = list.single;
    expect(s.programName, 'PPL');
    expect(s.dayName, 'Push');
    expect(s.stats.setCount, 2); // unfinished sets were dropped
    expect(s.stats.exerciseCount, 2);
    expect(s.stats.totalReps, 10 + 4 + 8);
    expect(s.stats.volumeKg, 20 * 10 + 20 * 4 + 10 * 8);
    expect(s.duration, isNotNull);
  });

  test('newest session comes first', () async {
    final first = await doWorkout();
    await (db.update(db.workoutSessions)..where((s) => s.id.equals(first)))
        .write(WorkoutSessionsCompanion(
            startedAt: Value(DateTime(2020, 1, 1))));
    final second = await doWorkout();

    final list = await history.watchCompleted().first;
    expect(list.map((s) => s.session.id), [second, first]);
  });

  test('history survives deleting the program day (names become null)',
      () async {
    final id = await doWorkout();
    // The app refuses to delete days with history; simulate a plan that was
    // detached to prove the history query itself does not depend on it.
    await (db.update(db.workoutSessions)..where((s) => s.id.equals(id)))
        .write(const WorkoutSessionsCompanion(
            workoutDayId: Value(null), programId: Value(null)));

    final s = (await history.watchCompleted().first).single;
    expect(s.programName, isNull);
    expect(s.dayName, isNull);
    expect(s.stats.setCount, 2);
  });

  test('deleteCompleted removes sets and mini-sets with the session',
      () async {
    final id = await doWorkout();
    expect(await history.deleteCompleted(id), isTrue);

    expect(await history.watchCompleted().first, isEmpty);
    expect(await setsOf(id), isEmpty);
    expect(await db.select(db.miniSetLogs).get(), isEmpty);
  });

  test('deleteCompleted refuses an in-progress session', () async {
    final id = await sessions.startSession(dayId);
    expect(await history.deleteCompleted(id), isFalse);
    expect(await sessions.findActiveSession(), isNotNull);
  });
}

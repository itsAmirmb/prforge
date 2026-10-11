import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/data/mini_set_repository.dart';
import 'package:prforge/features/workout/data/session_repository.dart';
import 'package:prforge/features/workout/domain/rest_pause.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late MiniSetRepository minis;
  late int sessionId;
  late int pressId; // exercise with rest-pause prescription (2 sets)
  late int curlId; // exercise with a normal prescription

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    minis = MiniSetRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    final dayId = await db.into(db.workoutDays).insert(
        WorkoutDaysCompanion.insert(
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
            targetWeightKg: const Value(20),
            setType: const Value(SetKind.restPause)));
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: curlId,
            orderIndex: 1,
            targetSets: const Value(1)));
    sessionId = await sessions.startSession(dayId);
  });

  tearDown(() => db.close());

  Future<List<SetLog>> mainSets() => (db.select(db.setLogs)
        ..where((l) =>
            l.sessionId.equals(sessionId) & l.exerciseId.equals(pressId))
        ..orderBy([(l) => OrderingTerm.asc(l.setIndex)]))
      .get();
  Future<SetLog> curlSet() => (db.select(db.setLogs)
        ..where((l) => l.exerciseId.equals(curlId)))
      .getSingle();
  Future<List<MiniSetLog>> allMinis() => minis.watchForSession(sessionId).first;

  test('rest-pause sets start as main sets without mini-sets', () async {
    final sets = await mainSets();
    expect(sets.every((s) => s.setKind == SetKind.restPause), isTrue);
    expect(await allMinis(), isEmpty);
  });

  test('first mini-set copies the main set; later ones copy the previous',
      () async {
    final main = (await mainSets()).first;
    await minis.add(main.id);
    var list = await allMinis();
    expect(list.single.miniSetIndex, 0);
    expect(list.single.weightKg, 20);
    expect(list.single.reps, 10);
    expect(list.single.restSeconds, defaultMiniSetRestSeconds);

    await minis.setReps(list.single.id, 4);
    await minis.setRest(list.single.id, 10);
    await minis.setWeight(list.single.id, 17.5);
    await minis.add(main.id);
    list = await allMinis();
    expect(list.map((m) => m.miniSetIndex), [0, 1]);
    expect(list[1].reps, 4);
    expect(list[1].restSeconds, 10);
    expect(list[1].weightKg, 17.5);
  });

  test('mini-sets are only allowed on rest-pause sets', () async {
    expect(() => minis.add((await curlSet()).id), throwsStateError);
  });

  test('the number of mini-sets can differ per main set', () async {
    final sets = await mainSets();
    await minis.add(sets[0].id);
    await minis.add(sets[0].id);
    await minis.add(sets[1].id);
    await minis.add(sets[1].id);
    await minis.add(sets[1].id);
    final list = await allMinis();
    expect(list.where((m) => m.setLogId == sets[0].id), hasLength(2));
    expect(list.where((m) => m.setLogId == sets[1].id), hasLength(3));
  });

  test('weight and rest can be cleared; invalid values are rejected',
      () async {
    final main = (await mainSets()).first;
    final id = await minis.add(main.id);
    await minis.setWeight(id, null);
    await minis.setRest(id, null);
    final m = (await allMinis()).single;
    expect(m.weightKg, isNull);
    expect(m.restSeconds, isNull);
    expect(() => minis.setReps(id, -1), throwsArgumentError);
    expect(() => minis.setRest(id, -5), throwsArgumentError);
  });

  test('delete returns the mini-set and restore brings it back unchanged',
      () async {
    final main = (await mainSets()).first;
    final id = await minis.add(main.id);
    final before = (await allMinis()).single;
    final deleted = await minis.delete(id);
    expect(await allMinis(), isEmpty);
    await minis.restore(deleted);
    expect((await allMinis()).single, before);
  });

  test('total reps adds the main set and its mini-sets', () async {
    final main = (await mainSets()).first;
    final id = await minis.add(main.id);
    await minis.setReps(id, 4);
    await minis.add(main.id); // copies 4
    expect(restPauseTotalReps(main, await allMinis()), 10 + 4 + 4);
  });

  test('deleting a main set removes its mini-sets; undo restores them',
      () async {
    final main = (await mainSets()).first;
    await minis.add(main.id);
    await minis.add(main.id);
    final before = await allMinis();

    final deleted = await sessions.deleteSet(main.id);
    expect(deleted.miniSets, hasLength(2));
    expect(await allMinis(), isEmpty);

    await sessions.restoreSet(deleted);
    expect(await allMinis(), before);
    expect((await mainSets()).first, main);
  });

  test('finishing keeps mini-sets of completed sets and drops the rest',
      () async {
    final sets = await mainSets();
    await minis.add(sets[0].id);
    await minis.add(sets[1].id);
    await sessions.setCompleted(sets[0].id, true);

    await sessions.finishSession(sessionId);

    final left = await allMinis();
    expect(left, hasLength(1));
    expect(left.single.setLogId, sets[0].id);
  });

  test('discarding the session removes mini-sets too', () async {
    await minis.add((await mainSets()).first.id);
    await sessions.discardSession(sessionId);
    expect(await db.select(db.miniSetLogs).get(), isEmpty);
  });

  test('mini-sets of another session are not listed', () async {
    await minis.add((await mainSets()).first.id);
    final otherSession = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(startedAt: DateTime(2026, 1, 1)));
    expect(await minis.watchForSession(otherSession).first, isEmpty);
    expect(await allMinis(), hasLength(1));
  });
}

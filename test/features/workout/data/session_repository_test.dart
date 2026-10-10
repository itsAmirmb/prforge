import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository repo;
  late int dayId;
  late int curl;
  late int squat;
  late int curlPrescription;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SessionRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
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
            setType: const Value(SetKind.amrap)));
  });

  tearDown(() => db.close());

  Future<List<SetLog>> sets(int sessionId) => (db.select(db.setLogs)
        ..where((l) => l.sessionId.equals(sessionId))
        ..orderBy([(l) => OrderingTerm.asc(l.id)]))
      .get();

  /// A finished session in the past with the given completed curl sets.
  Future<void> seedHistory(List<double?> weights,
      {DateTime? at, SessionStatus status = SessionStatus.completed}) async {
    final sid = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
            startedAt: at ?? DateTime(2026, 1, 1), status: Value(status)));
    for (var i = 0; i < weights.length; i++) {
      await db.into(db.setLogs).insert(SetLogsCompanion.insert(
          sessionId: sid,
          exerciseId: curl,
          setIndex: i,
          weightKg: Value(weights[i]),
          reps: const Value(10),
          isCompleted: const Value(true)));
    }
  }

  test('startSession creates sets from the plan with target values', () async {
    final id = await repo.startSession(dayId);
    final list = await sets(id);
    expect(list, hasLength(5));
    final curls = list.where((l) => l.exerciseId == curl).toList();
    expect(curls.map((l) => l.setIndex), [0, 1, 2]);
    expect(curls.every((l) => l.prescriptionId == curlPrescription), isTrue);
    expect(curls.every((l) => l.weightKg == 5 && l.reps == 10), isTrue);
    expect(curls.every((l) => !l.isCompleted), isTrue);
    final squats = list.where((l) => l.exerciseId == squat);
    expect(squats.every((l) => l.setKind == SetKind.amrap), isTrue);
    expect(squats.every((l) => l.weightKg == null), isTrue);
    expect((await repo.findActiveSession())!.id, id);
  });

  test('only one session can be in progress', () async {
    await repo.startSession(dayId);
    expect(() => repo.startSession(dayId), throwsStateError);
  });

  test('weights are prefilled from the last completed session, set by set',
      () async {
    await seedHistory([7.5, 5, 5]);
    final id = await repo.startSession(dayId);
    final curls = (await sets(id)).where((l) => l.exerciseId == curl);
    expect(curls.map((l) => l.weightKg), [7.5, 5, 5]);
  });

  test('last weight is reused when the plan has more sets than history',
      () async {
    await seedHistory([7.5, 6]);
    final id = await repo.startSession(dayId);
    final curls = (await sets(id)).where((l) => l.exerciseId == curl);
    expect(curls.map((l) => l.weightKg), [7.5, 6, 6]);
  });

  test('the most recent completed session wins; cancelled/unfinished ignored',
      () async {
    await seedHistory([5, 5, 5], at: DateTime(2026, 1, 1));
    await seedHistory([7.5, 7.5, 5], at: DateTime(2026, 2, 1));
    await seedHistory([100, 100, 100],
        at: DateTime(2026, 3, 1), status: SessionStatus.cancelled);
    final id = await repo.startSession(dayId);
    final curls = (await sets(id)).where((l) => l.exerciseId == curl);
    expect(curls.map((l) => l.weightKg), [7.5, 7.5, 5]);
  });

  test('uncompleted sets in history are not used for prefill', () async {
    final sid = await db.into(db.workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
            startedAt: DateTime(2026, 1, 1),
            status: const Value(SessionStatus.completed)));
    await db.into(db.setLogs).insert(SetLogsCompanion.insert(
        sessionId: sid,
        exerciseId: curl,
        setIndex: 0,
        weightKg: const Value(99),
        reps: const Value(10)));
    expect(await repo.lastPerformance(curl), isEmpty);
  });

  test('setCompleted needs reps and toggles', () async {
    final id = await repo.startSession(dayId);
    final set = (await sets(id)).first;
    await repo.setReps(set.id, null);
    expect(() => repo.setCompleted(set.id, true), throwsStateError);
    await repo.setReps(set.id, 8);
    await repo.setCompleted(set.id, true);
    expect((await sets(id)).first.isCompleted, isTrue);
    await repo.setCompleted(set.id, false);
    expect((await sets(id)).first.isCompleted, isFalse);
  });

  test('sets keep independent decimal weights', () async {
    final id = await repo.startSession(dayId);
    final curls = (await sets(id)).where((l) => l.exerciseId == curl).toList();
    await repo.setWeight(curls[0].id, 7.5);
    await repo.setWeight(curls[1].id, 5);
    await repo.setWeight(curls[2].id, null);
    final after = (await sets(id)).where((l) => l.exerciseId == curl).toList();
    expect(after.map((l) => l.weightKg), [7.5, 5, null]);
  });

  test('addSet appends and copies the last set of the block', () async {
    final id = await repo.startSession(dayId);
    final curls = (await sets(id)).where((l) => l.exerciseId == curl).toList();
    await repo.setWeight(curls.last.id, 7.5);
    await repo.setReps(curls.last.id, 9);
    final newId = await repo.addSet(id, curl, curlPrescription);
    final added = (await sets(id)).firstWhere((l) => l.id == newId);
    expect(added.setIndex, 3);
    expect(added.weightKg, 7.5);
    expect(added.reps, 9);
    expect(added.isCompleted, isFalse);
    expect(added.prescriptionId, curlPrescription);
  });

  test('deleteSet returns the set and restoreSet brings it back unchanged',
      () async {
    final id = await repo.startSession(dayId);
    final target = (await sets(id)).first;
    final deleted = await repo.deleteSet(target.id);
    expect(await sets(id), hasLength(4));
    await repo.restoreSet(deleted);
    final restored = (await sets(id)).firstWhere((l) => l.id == target.id);
    expect(restored, target);
  });

  test('finishSession keeps completed sets and discards the rest', () async {
    final id = await repo.startSession(dayId);
    final first = (await sets(id)).first;
    await repo.setCompleted(first.id, true);

    await repo.finishSession(id);

    final left = await sets(id);
    expect(left.map((l) => l.id), [first.id]);
    final session = await (db.select(db.workoutSessions)
          ..where((s) => s.id.equals(id)))
        .getSingle();
    expect(session.status, SessionStatus.completed);
    expect(session.completedAt, isNotNull);
    expect(await repo.findActiveSession(), isNull);
  });

  test('discardSession deletes the session and its sets', () async {
    final id = await repo.startSession(dayId);
    await repo.discardSession(id);
    expect(await db.select(db.workoutSessions).get(), isEmpty);
    expect(await db.select(db.setLogs).get(), isEmpty);
  });

  test('history survives deleting the plan (day content removed)', () async {
    final id = await repo.startSession(dayId);
    final first = (await sets(id)).first;
    await repo.setCompleted(first.id, true);
    await repo.finishSession(id);

    // Remove the prescription the way the app does: unlink logs, then delete.
    await (db.update(db.setLogs)
          ..where((l) => l.prescriptionId.equals(curlPrescription)))
        .write(const SetLogsCompanion(prescriptionId: Value(null)));
    await (db.delete(db.exercisePrescriptions)
          ..where((p) => p.id.equals(curlPrescription)))
        .go();

    final kept = (await sets(id)).single;
    expect(kept.exerciseId, curl);
    expect(kept.isCompleted, isTrue);
  });
}

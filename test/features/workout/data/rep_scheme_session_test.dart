import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/prescription_repository.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late PrescriptionRepository plan;
  late int dayId;
  late int exerciseId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    plan = PrescriptionRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
        programId: programId, name: 'D', orderIndex: 0));
    exerciseId = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Incline'));
  });

  tearDown(() => db.close());

  Future<List<int?>> startAndReadReps() async {
    final id = await sessions.startSession(dayId);
    final sets = await (db.select(db.setLogs)
          ..where((l) => l.sessionId.equals(id))
          ..orderBy([(l) => OrderingTerm.asc(l.setIndex)]))
        .get();
    return [for (final s in sets) s.reps];
  }

  test('each set starts with its own reps from the scheme', () async {
    await plan.add(
        dayId,
        PrescriptionDraft(
            exerciseId: exerciseId,
            targetSets: 4,
            targetReps: 12,
            repScheme: const [12, 10, 8, 8]));
    expect(await startAndReadReps(), [12, 10, 8, 8]);
  });

  test('more sets than the scheme repeat its last value', () async {
    await plan.add(
        dayId,
        PrescriptionDraft(
            exerciseId: exerciseId,
            targetSets: 5,
            targetReps: 12,
            repScheme: const [12, 10, 8]));
    expect(await startAndReadReps(), [12, 10, 8, 8, 8]);
  });

  test('without a scheme every set uses the target reps', () async {
    await plan.add(dayId,
        PrescriptionDraft(exerciseId: exerciseId, targetSets: 3, targetReps: 10));
    expect(await startAndReadReps(), [10, 10, 10]);
  });

  test('update can set and clear the scheme', () async {
    final id = await plan.add(dayId,
        PrescriptionDraft(exerciseId: exerciseId, targetSets: 3, targetReps: 10));

    await plan.update(
        id,
        PrescriptionDraft(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: 12,
            repScheme: const [12, 10, 8]));
    expect((await db.select(db.exercisePrescriptions).getSingle()).repScheme,
        '12,10,8');

    await plan.update(id,
        PrescriptionDraft(exerciseId: exerciseId, targetSets: 3, targetReps: 10));
    expect((await db.select(db.exercisePrescriptions).getSingle()).repScheme,
        isNull);
  });

  test('an invalid scheme is rejected', () async {
    expect(
        () => plan.add(
            dayId,
            PrescriptionDraft(
                exerciseId: exerciseId, repScheme: const [12, 0])),
        throwsArgumentError);
  });

  test('logged sets stay independent of the plan afterwards', () async {
    await plan.add(
        dayId,
        PrescriptionDraft(
            exerciseId: exerciseId,
            targetSets: 3,
            targetReps: 12,
            repScheme: const [12, 10, 8]));
    final id = await sessions.startSession(dayId);
    final first = (await db.select(db.setLogs).get()).first;
    await sessions.setReps(first.id, 15);
    await sessions.setCompleted(first.id, true);
    await sessions.finishSession(id);

    await db.update(db.exercisePrescriptions).write(
        const ExercisePrescriptionsCompanion(repScheme: Value('5,5,5')));

    final logged = await db.select(db.setLogs).get();
    expect(logged.map((s) => s.reps), [15]);
  });
}

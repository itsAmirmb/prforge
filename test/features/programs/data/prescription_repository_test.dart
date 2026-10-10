import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/prescription_repository.dart';

void main() {
  late AppDatabase db;
  late PrescriptionRepository repo;
  late int dayId;
  late int curl;
  late int squat;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = PrescriptionRepository(db);
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
  });

  tearDown(() => db.close());

  Future<List<PrescriptionWithExercise>> items() => repo.watchForDay(dayId).first;

  test('add appends in order and joins the exercise', () async {
    await repo.add(dayId, PrescriptionDraft(exerciseId: curl, targetReps: 10));
    await repo.add(dayId, PrescriptionDraft(exerciseId: squat));
    final list = await items();
    expect(list.map((i) => i.exercise.name), ['Curl', 'Squat']);
    expect(list.first.prescription.targetSets, 3);
    expect(list.first.prescription.targetReps, 10);
  });

  test('target weight is optional and decimals are kept', () async {
    await repo.add(dayId, PrescriptionDraft(exerciseId: curl));
    await repo.add(
        dayId, PrescriptionDraft(exerciseId: squat, targetWeightKg: 7.5));
    final list = await items();
    expect(list[0].prescription.targetWeightKg, isNull);
    expect(list[1].prescription.targetWeightKg, 7.5);
  });

  test('same exercise can appear twice in a day', () async {
    await repo.add(dayId, PrescriptionDraft(exerciseId: curl));
    await repo.add(dayId, PrescriptionDraft(exerciseId: curl));
    expect(await items(), hasLength(2));
  });

  test('update changes values and trims blank notes to null', () async {
    final id = await repo.add(dayId, PrescriptionDraft(exerciseId: curl));
    await repo.update(
        id,
        PrescriptionDraft(
            exerciseId: curl,
            targetSets: 4,
            setType: SetKind.restPause,
            restSeconds: 90,
            notes: '  '));
    final p = (await items()).single.prescription;
    expect(p.targetSets, 4);
    expect(p.setType, SetKind.restPause);
    expect(p.restSeconds, 90);
    expect(p.notes, isNull);
  });

  test('reorder persists the new order', () async {
    final a = await repo.add(dayId, PrescriptionDraft(exerciseId: curl));
    final b = await repo.add(dayId, PrescriptionDraft(exerciseId: squat));
    await repo.reorder([b, a]);
    expect((await items()).map((i) => i.exercise.name), ['Squat', 'Curl']);
  });

  test('invalid values are rejected', () {
    expect(() => repo.add(dayId, PrescriptionDraft(exerciseId: curl, targetSets: 0)),
        throwsArgumentError);
    expect(
        () => repo.add(
            dayId, PrescriptionDraft(exerciseId: curl, targetWeightKg: -1)),
        throwsArgumentError);
    expect(() => repo.add(dayId, PrescriptionDraft(exerciseId: curl, restSeconds: -5)),
        throwsArgumentError);
  });

  test('remove keeps logged sets and only clears their prescription link',
      () async {
    final pid = await repo.add(dayId, PrescriptionDraft(exerciseId: curl));
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(WorkoutSessionsCompanion.insert(startedAt: DateTime.now()));
    await db.into(db.setLogs).insert(SetLogsCompanion.insert(
        sessionId: sessionId,
        exerciseId: curl,
        setIndex: 0,
        prescriptionId: Value(pid),
        weightKg: const Value(7.5),
        reps: const Value(10)));

    await repo.remove(pid);

    expect(await items(), isEmpty);
    final log = (await db.select(db.setLogs).get()).single;
    expect(log.prescriptionId, isNull);
    expect(log.exerciseId, curl);
    expect(log.weightKg, 7.5);
  });
}

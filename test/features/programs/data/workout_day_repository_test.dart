import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/program_repository.dart';
import 'package:prforge/features/programs/data/workout_day_repository.dart';

void main() {
  late AppDatabase db;
  late ProgramRepository programs;
  late WorkoutDayRepository days;
  late int programId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    programs = ProgramRepository(db);
    days = WorkoutDayRepository(db);
    programId = await programs.add('PPL');
  });

  tearDown(() => db.close());

  Future<List<String>> names([int? id]) async =>
      (await days.watchDays(id ?? programId).first).map((d) => d.name).toList();

  test('days are appended in order and scoped per program', () async {
    final other = await programs.add('Other');
    await days.add(programId, 'Push');
    await days.add(programId, 'Pull');
    await days.add(other, 'Solo');
    expect(await names(), ['Push', 'Pull']);
    expect(await names(other), ['Solo']);
  });

  test('rename changes only the name', () async {
    final id = await days.add(programId, 'Push');
    await days.rename(id, 'Chest');
    final d = (await days.watchDays(programId).first).single;
    expect(d.id, id);
    expect(d.name, 'Chest');
  });

  test('reorder persists the new order', () async {
    final a = await days.add(programId, 'A');
    final b = await days.add(programId, 'B');
    final c = await days.add(programId, 'C');
    await days.reorder([c, a, b]);
    expect(await names(), ['C', 'A', 'B']);
  });

  test('adding after a delete keeps order stable', () async {
    await days.add(programId, 'A');
    final b = await days.add(programId, 'B');
    await days.add(programId, 'C');
    await days.delete(b);
    await days.add(programId, 'D');
    expect(await names(), ['A', 'C', 'D']);
  });

  test('delete removes the day and its prescriptions and groups', () async {
    final dayId = await days.add(programId, 'A');
    final ex = await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Curl'));
    final group = await db.into(db.supersetGroups).insert(
        SupersetGroupsCompanion.insert(workoutDayId: dayId, orderIndex: 0));
    await db.into(db.exercisePrescriptions).insert(
        ExercisePrescriptionsCompanion.insert(
            workoutDayId: dayId,
            exerciseId: ex,
            orderIndex: 0,
            supersetGroupId: Value(group)));

    await days.delete(dayId);

    expect(await names(), isEmpty);
    expect(await db.select(db.exercisePrescriptions).get(), isEmpty);
    expect(await db.select(db.supersetGroups).get(), isEmpty);
    // The exercise itself stays.
    expect(await db.select(db.exercises).get(), hasLength(1));
  });

  test('delete is refused when a session used the day', () async {
    final dayId = await days.add(programId, 'A');
    await db.into(db.workoutSessions).insert(WorkoutSessionsCompanion.insert(
        startedAt: DateTime.now(), workoutDayId: Value(dayId)));

    expect(() => days.delete(dayId), throwsA(isA<DayHasHistoryException>()));
    expect(await names(), ['A']);
  });
}

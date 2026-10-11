import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/day_structure.dart';
import 'package:prforge/features/programs/data/program_importer.dart';
import 'package:prforge/features/programs/domain/day_entries.dart';

String template({List<Map<String, dynamic>>? entries}) => jsonEncode({
      'format': 'prforge-program',
      'version': 1,
      'name': 'P',
      'days': [
        {
          'name': 'D',
          'entries': entries ??
              [
                {'exercise': 'Bench', 'sets': 3, 'reps': 8},
                {
                  'rounds': 2,
                  'superset': [
                    {'exercise': 'Curl', 'reps': 12},
                    {'exercise': 'Fly', 'reps': 12},
                  ],
                },
                {
                  'exercise': 'Press',
                  'sets': 2,
                  'reps': 10,
                  'type': 'restPause',
                  'notes': 'rp'
                },
              ],
        },
      ],
    });

void main() {
  late AppDatabase db;
  late ProgramImporter importer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    importer = ProgramImporter(db);
  });

  tearDown(() => db.close());

  Future<List<ExercisePrescription>> prescriptions() =>
      (db.select(db.exercisePrescriptions)
            ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
          .get();

  test('creates program, day, exercises, prescriptions and superset', () async {
    final result = await importer.importJson(template());

    expect(result.days, 1);
    expect(result.prescriptions, 4);
    expect(result.exercisesCreated, 4);
    expect(result.exercisesReused, 0);

    final program = await db.select(db.programs).getSingle();
    expect(program.name, 'P');
    final day = await db.select(db.workoutDays).getSingle();
    expect(day.programId, program.id);

    final list = await prescriptions();
    expect(list.map((p) => p.orderIndex), [0, 1, 2, 3]);
    final group = await db.select(db.supersetGroups).getSingle();
    expect(group.rounds, 2);
    expect(group.orderIndex, 1); // second entry of the day
    final members = list.where((p) => p.supersetGroupId == group.id).toList();
    expect(members.map((m) => m.supersetOrder), [0, 1]);
    expect(members.map((m) => m.targetSets), [2, 2]);
    expect(members.map((m) => m.orderIndex), [1, 2]); // consecutive

    final press = list.last;
    expect(press.setType, SetKind.restPause);
    expect(press.notes, 'rp');
    expect(press.supersetGroupId, isNull);
    expect(toEntries(list, (p) => p.supersetGroupId).map((e) => e.length),
        [1, 2, 1]);
  });

  test('plan structure is already normalized', () async {
    await importer.importJson(template());
    final before = await prescriptions();
    final groupBefore = await db.select(db.supersetGroups).getSingle();

    await DayStructure(db)
        .normalize((await db.select(db.workoutDays).getSingle()).id);

    expect(await prescriptions(), before);
    expect(await db.select(db.supersetGroups).getSingle(), groupBefore);
  });

  test('reuses existing exercises by name (case, spaces) and unarchives',
      () async {
    final bench = await db.into(db.exercises).insert(ExercisesCompanion.insert(
        name: 'Bench', category: const Value('chest')));
    final curl = await db.into(db.exercises).insert(
        ExercisesCompanion.insert(name: 'curl', isArchived: const Value(true)));

    final result = await importer.importJson(template(entries: [
      {'exercise': '  BENCH ', 'sets': 3},
      {'exercise': 'Curl', 'sets': 3},
      {'exercise': 'Bench', 'sets': 3}, // same exercise twice in one day
    ]));

    expect(result.exercisesCreated, 0);
    expect(result.exercisesReused, 2);
    final all = await db.select(db.exercises).get();
    expect(all, hasLength(2));
    expect(all.firstWhere((e) => e.id == bench).category, 'chest');
    expect(all.firstWhere((e) => e.id == curl).isArchived, isFalse);
    expect((await prescriptions()).map((p) => p.exerciseId),
        [bench, curl, bench]);
  });

  test('an exercise shared by two days is created once', () async {
    final text = jsonEncode({
      'format': 'prforge-program',
      'version': 1,
      'name': 'P',
      'days': [
        for (final d in ['A', 'B'])
          {
            'name': d,
            'entries': [
              {'exercise': 'Fly', 'sets': 3},
            ],
          },
      ],
    });
    final result = await importer.importJson(text);
    expect(result.exercisesCreated, 1);
    expect(await db.select(db.exercises).get(), hasLength(1));
    expect(await db.select(db.workoutDays).get(), hasLength(2));
  });

  test('importing twice adds a second program and keeps the first', () async {
    await importer.importJson(template());
    await importer.importJson(template());
    expect(await db.select(db.programs).get(), hasLength(2));
    expect(await db.select(db.exercises).get(), hasLength(4));
  });

  test('an invalid file changes nothing', () async {
    await expectLater(importer.importJson('{"format":"x"}'), throwsA(anything));
    expect(await db.select(db.programs).get(), isEmpty);
    expect(await db.select(db.exercises).get(), isEmpty);
  });

  test('the bundled 3-day program imports as planned', () async {
    final text = File('test/fixtures/program_3day.json').readAsStringSync();
    final result = await importer.importJson(text);

    expect(result.days, 3);
    expect(result.prescriptions, 42);
    expect(result.exercisesCreated, 41); // one exercise is shared by two days
    final days = await (db.select(db.workoutDays)
          ..orderBy([(d) => OrderingTerm.asc(d.orderIndex)]))
        .get();
    final entryCounts = <int>[];
    for (final d in days) {
      final rows = await (db.select(db.exercisePrescriptions)
            ..where((p) => p.workoutDayId.equals(d.id))
            ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
          .get();
      entryCounts.add(toEntries(rows, (p) => p.supersetGroupId).length);
    }
    expect(entryCounts, [11, 14, 11]);
    expect(await db.select(db.supersetGroups).get(), hasLength(6));
    expect(
        (await prescriptions()).where((p) => p.setType == SetKind.restPause),
        hasLength(3));
  });
}

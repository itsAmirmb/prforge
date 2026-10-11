import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/backup/data/backup_repository.dart';
import 'package:prforge/features/backup/domain/backup_format.dart';
import 'package:prforge/features/workout/data/mini_set_repository.dart';
import 'package:prforge/features/workout/data/session_repository.dart';

/// Seeds: a program with a day holding one superset (2 members) and one
/// rest-pause exercise, plus one finished session with a mini-set.
Future<void> seed(AppDatabase db) async {
  final sessions = SessionRepository(db);
  final minis = MiniSetRepository(db);
  final programId = await db
      .into(db.programs)
      .insert(ProgramsCompanion.insert(name: 'PPL'));
  final dayId = await db.into(db.workoutDays).insert(
      WorkoutDaysCompanion.insert(
          programId: programId, name: 'Push', orderIndex: 0));
  final bench = await db
      .into(db.exercises)
      .insert(ExercisesCompanion.insert(name: 'Bench'));
  final fly = await db
      .into(db.exercises)
      .insert(ExercisesCompanion.insert(name: 'Fly'));
  final press = await db
      .into(db.exercises)
      .insert(ExercisesCompanion.insert(name: 'Press'));
  final groupId = await db.into(db.supersetGroups).insert(
      SupersetGroupsCompanion.insert(workoutDayId: dayId, orderIndex: 0));
  await db.into(db.exercisePrescriptions).insert(
      ExercisePrescriptionsCompanion.insert(
          workoutDayId: dayId,
          exerciseId: bench,
          orderIndex: 0,
          supersetGroupId: Value(groupId),
          supersetOrder: const Value(0),
          targetSets: const Value(2),
          targetReps: const Value(8),
          targetWeightKg: const Value(60)));
  await db.into(db.exercisePrescriptions).insert(
      ExercisePrescriptionsCompanion.insert(
          workoutDayId: dayId,
          exerciseId: fly,
          orderIndex: 1,
          supersetGroupId: Value(groupId),
          supersetOrder: const Value(1),
          targetSets: const Value(2),
          targetReps: const Value(12),
          targetWeightKg: const Value(10)));
  await db.into(db.exercisePrescriptions).insert(
      ExercisePrescriptionsCompanion.insert(
          workoutDayId: dayId,
          exerciseId: press,
          orderIndex: 2,
          targetSets: const Value(1),
          targetReps: const Value(10),
          targetWeightKg: const Value(20),
          setType: const Value(SetKind.restPause)));

  final id = await sessions.startSession(dayId);
  final sets = await (db.select(db.setLogs)
        ..where((l) => l.sessionId.equals(id)))
      .get();
  for (final s in sets) {
    await sessions.setCompleted(s.id, true);
  }
  final main = sets.firstWhere((s) => s.exerciseId == press);
  await minis.add(main.id);
  await sessions.finishSession(id);
}

Map<String, dynamic> tablesOf(String json) =>
    (jsonDecode(json) as Map<String, dynamic>)['tables'] as Map<String, dynamic>;

void main() {
  late AppDatabase db;
  late BackupRepository backup;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    backup = BackupRepository(db);
  });

  tearDown(() => db.close());

  test('export contains every table and the format header', () async {
    await seed(db);
    final root = jsonDecode(await backup.exportJson()) as Map<String, dynamic>;
    expect(root['format'], backupFormatName);
    expect(root['version'], backupFormatVersion);
    expect(root['schemaVersion'], db.schemaVersion);
    final tables = root['tables'] as Map<String, dynamic>;
    expect((tables['exercises'] as List), hasLength(3));
    expect((tables['workoutSessions'] as List), hasLength(1));
    expect((tables['miniSetLogs'] as List), hasLength(1));
  });

  test('round trip into an empty database gives identical data', () async {
    await seed(db);
    final json = await backup.exportJson();

    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    final summary = await BackupRepository(other).restoreJson(json);

    expect(summary.exercises, 3);
    expect(summary.programs, 1);
    expect(summary.sessions, 1);
    expect(tablesOf(await BackupRepository(other).exportJson()),
        tablesOf(json));
  });

  test('restore replaces existing data', () async {
    await seed(db);
    final json = await backup.exportJson();

    await db
        .into(db.exercises)
        .insert(ExercisesCompanion.insert(name: 'Extra'));
    await backup.restoreJson(json);

    final names = (await db.select(db.exercises).get()).map((e) => e.name);
    expect(names, unorderedEquals(['Bench', 'Fly', 'Press']));
  });

  test('restored data keeps relations (superset, rest-pause, enums)',
      () async {
    await seed(db);
    final json = await backup.exportJson();
    final other = AppDatabase(NativeDatabase.memory());
    addTearDown(other.close);
    await BackupRepository(other).restoreJson(json);

    final sets = await other.select(other.setLogs).get();
    expect(sets.where((s) => s.supersetKey != null), hasLength(4));
    final restPause = sets.singleWhere((s) => s.setKind == SetKind.restPause);
    final minis = await other.select(other.miniSetLogs).get();
    expect(minis.single.setLogId, restPause.id);
    final session = await other.select(other.workoutSessions).getSingle();
    expect(session.status, SessionStatus.completed);
    expect(session.completedAt, isNotNull);
  });

  group('invalid files leave the data untouched', () {
    late String before;

    setUp(() async {
      await seed(db);
      before = await backup.exportJson();
    });

    Future<void> expectRejected(String text) async {
      await expectLater(
          backup.restoreJson(text), throwsA(isA<BackupFormatException>()));
      expect(tablesOf(await backup.exportJson()), tablesOf(before));
    }

    test('not JSON', () => expectRejected('hello'));

    test('not a PRForge file', () => expectRejected('{"a": 1}'));

    test('newer format version', () async {
      final root = jsonDecode(before) as Map<String, dynamic>;
      root['version'] = backupFormatVersion + 1;
      await expectRejected(jsonEncode(root));
    });

    test('newer schema version', () async {
      final root = jsonDecode(before) as Map<String, dynamic>;
      root['schemaVersion'] = db.schemaVersion + 1;
      await expectRejected(jsonEncode(root));
    });

    test('missing table', () async {
      final root = jsonDecode(before) as Map<String, dynamic>;
      (root['tables'] as Map<String, dynamic>).remove('setLogs');
      await expectRejected(jsonEncode(root));
    });

    test('damaged row', () async {
      final root = jsonDecode(before) as Map<String, dynamic>;
      ((root['tables'] as Map<String, dynamic>)['exercises'] as List)
          .first['name'] = 123;
      await expectRejected(jsonEncode(root));
    });

    test('broken relation rolls the whole restore back', () async {
      final root = jsonDecode(before) as Map<String, dynamic>;
      // A set that points to a session that is not in the file.
      ((root['tables'] as Map<String, dynamic>)['setLogs'] as List)
          .first['sessionId'] = 9999;
      await expectLater(backup.restoreJson(jsonEncode(root)), throwsA(anything));
      expect(tablesOf(await backup.exportJson()), tablesOf(before));
    });
  });
}

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/prescription_repository.dart';
import 'package:prforge/features/programs/data/superset_repository.dart';

void main() {
  late AppDatabase db;
  late PrescriptionRepository prescriptions;
  late SupersetRepository supersets;
  late int dayId;
  final ex = <String, int>{};
  final rx = <int, String>{}; // exercise id -> name
  final pid = <String, int>{}; // name -> prescription id

  Future<void> addPrescription(String name, {int sets = 3}) async {
    pid[name] = await prescriptions.add(
        dayId, PrescriptionDraft(exerciseId: ex[name]!, targetSets: sets));
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prescriptions = PrescriptionRepository(db);
    supersets = SupersetRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
        programId: programId, name: 'D', orderIndex: 0));
    ex.clear();
    rx.clear();
    pid.clear();
    for (final n in ['A', 'B', 'C', 'D', 'E']) {
      ex[n] = await db
          .into(db.exercises)
          .insert(ExercisesCompanion.insert(name: n));
      rx[ex[n]!] = n;
    }
  });

  tearDown(() => db.close());

  Future<List<ExercisePrescription>> rows() => (db.select(db.exercisePrescriptions)
        ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
      .get();
  Future<List<String>> order() async =>
      (await rows()).map((p) => rx[p.exerciseId]!).toList();
  Future<List<SupersetGroup>> groups() => db.select(db.supersetGroups).get();

  group('createGroup', () {
    test('groups adjacent exercises; rounds come from the first', () async {
      await addPrescription('A', sets: 4);
      await addPrescription('B', sets: 3);
      await addPrescription('C');

      final gid = await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

      final g = (await groups()).single;
      expect(g.id, gid);
      expect(g.rounds, 4);
      final r = await rows();
      expect(r.map((p) => rx[p.exerciseId]), ['A', 'B', 'C']);
      expect(r.map((p) => p.supersetGroupId), [gid, gid, null]);
      expect(r.map((p) => p.supersetOrder), [0, 1, null]);
      expect(r.map((p) => p.targetSets), [4, 4, 3]);
      expect(r.map((p) => p.orderIndex), [0, 1, 2]);
    });

    test('members are ordered by their position, not by argument order',
        () async {
      await addPrescription('A');
      await addPrescription('B');
      await supersets.createGroup(dayId, [pid['B']!, pid['A']!]);
      final r = await rows();
      expect(r.map((p) => rx[p.exerciseId]), ['A', 'B']);
      expect(r.map((p) => p.supersetOrder), [0, 1]);
    });

    test('three exercises can form one superset', () async {
      await addPrescription('A');
      await addPrescription('B');
      await addPrescription('C');
      await supersets
          .createGroup(dayId, [pid['A']!, pid['B']!, pid['C']!]);
      expect((await rows()).map((p) => p.supersetOrder), [0, 1, 2]);
    });

    test('rejects non-adjacent, single, duplicate and already grouped',
        () async {
      await addPrescription('A');
      await addPrescription('B');
      await addPrescription('C');
      await addPrescription('D');
      expect(() => supersets.createGroup(dayId, [pid['A']!, pid['C']!]),
          throwsArgumentError);
      expect(() => supersets.createGroup(dayId, [pid['A']!]),
          throwsArgumentError);
      expect(() => supersets.createGroup(dayId, [pid['A']!, pid['A']!]),
          throwsArgumentError);
      await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);
      expect(() => supersets.createGroup(dayId, [pid['B']!, pid['C']!]),
          throwsArgumentError);
      expect(await groups(), hasLength(1));
    });
  });

  test('addMember appends next to the group and uses the group rounds',
      () async {
    await addPrescription('A', sets: 4);
    await addPrescription('B');
    await addPrescription('C');
    await addPrescription('D');
    final gid = await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

    await supersets.addMember(
        gid, PrescriptionDraft(exerciseId: ex['E']!, targetSets: 9));

    expect(await order(), ['A', 'B', 'E', 'C', 'D']);
    final e = (await rows()).firstWhere((p) => p.exerciseId == ex['E']);
    expect(e.supersetGroupId, gid);
    expect(e.supersetOrder, 2);
    expect(e.targetSets, 4);
  });

  test('removeMember keeps the rest grouped; leaver becomes a single',
      () async {
    await addPrescription('A');
    await addPrescription('B');
    await addPrescription('C');
    final gid = await supersets
        .createGroup(dayId, [pid['A']!, pid['B']!, pid['C']!]);

    await supersets.removeMember(pid['B']!);

    final r = await rows();
    expect(r.map((p) => rx[p.exerciseId]), ['A', 'C', 'B']);
    expect(r.map((p) => p.supersetGroupId), [gid, gid, null]);
    expect(r.map((p) => p.supersetOrder), [0, 1, null]);
  });

  test('a group with fewer than 2 members is dissolved', () async {
    await addPrescription('A');
    await addPrescription('B');
    await addPrescription('C');
    await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

    await supersets.removeMember(pid['A']!);

    expect(await groups(), isEmpty);
    final r = await rows();
    expect(r.every((p) => p.supersetGroupId == null), isTrue);
    expect(r.map((p) => p.orderIndex), [0, 1, 2]);
  });

  test('ungroup keeps all exercises as singles in order', () async {
    await addPrescription('A');
    await addPrescription('B');
    final gid = await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

    await supersets.ungroup(gid);

    expect(await groups(), isEmpty);
    expect(await order(), ['A', 'B']);
    expect((await rows()).every((p) => p.supersetOrder == null), isTrue);
  });

  test('removing a member from the plan repairs the group', () async {
    await addPrescription('A');
    await addPrescription('B');
    await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

    await prescriptions.remove(pid['A']!);

    expect(await groups(), isEmpty);
    final r = (await rows()).single;
    expect(rx[r.exerciseId], 'B');
    expect(r.supersetGroupId, isNull);
  });

  test('moveMember swaps order inside the group and stops at the ends',
      () async {
    await addPrescription('A');
    await addPrescription('B');
    await addPrescription('C');
    await supersets.createGroup(dayId, [pid['A']!, pid['B']!, pid['C']!]);

    await supersets.moveMember(pid['C']!, -1);
    expect(await order(), ['A', 'C', 'B']);
    await supersets.moveMember(pid['A']!, -1); // already first
    expect(await order(), ['A', 'C', 'B']);
    await supersets.moveMember(pid['A']!, 1);
    expect(await order(), ['C', 'A', 'B']);
    expect((await rows()).map((p) => p.supersetOrder), [0, 1, 2]);
  });

  group('updateGroup', () {
    test('rounds are applied to every member; name is trimmed', () async {
      await addPrescription('A');
      await addPrescription('B');
      await addPrescription('C');
      final gid = await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

      await supersets.updateGroup(gid,
          name: '  Arms ',
          rounds: 5,
          restBetweenSeconds: 10,
          restAfterRoundSeconds: 90);

      final g = (await groups()).single;
      expect(g.name, 'Arms');
      expect(g.rounds, 5);
      expect(g.restBetweenSeconds, 10);
      expect(g.restAfterRoundSeconds, 90);
      expect((await rows()).map((p) => p.targetSets), [5, 5, 3]);
    });

    test('blank name becomes null; invalid values are rejected', () async {
      await addPrescription('A');
      await addPrescription('B');
      final gid = await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);
      await supersets.updateGroup(gid, name: '  ', rounds: 3);
      expect((await groups()).single.name, isNull);
      expect(() => supersets.updateGroup(gid, rounds: 0), throwsArgumentError);
      expect(() => supersets.updateGroup(gid, rounds: 3, restBetweenSeconds: -1),
          throwsArgumentError);
    });
  });

  group('reorderEntries', () {
    test('a superset moves as one unit and stays adjacent', () async {
      await addPrescription('A');
      await addPrescription('B');
      await addPrescription('C');
      await addPrescription('D');
      final gid = await supersets.createGroup(dayId, [pid['A']!, pid['B']!]);

      await supersets
          .reorderEntries(dayId, ['p${pid['C']}', 'p${pid['D']}', 'g$gid']);

      expect(await order(), ['C', 'D', 'A', 'B']);
      expect((await rows()).map((p) => p.orderIndex), [0, 1, 2, 3]);
      expect((await groups()).single.orderIndex, 2);
    });

    test('keys must list every entry exactly once', () async {
      await addPrescription('A');
      await addPrescription('B');
      expect(() => supersets.reorderEntries(dayId, ['p${pid['A']}']),
          throwsArgumentError);
      expect(
          () => supersets.reorderEntries(
              dayId, ['p${pid['A']}', 'p${pid['A']}']),
          throwsArgumentError);
    });
  });
}

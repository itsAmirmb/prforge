import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/programs/data/prescription_repository.dart';
import 'package:prforge/features/programs/data/superset_repository.dart';
import 'package:prforge/features/workout/data/session_repository.dart';
import 'package:prforge/features/workout/domain/session_blocks.dart';

void main() {
  late AppDatabase db;
  late SessionRepository sessions;
  late SupersetRepository supersets;
  late int dayId;
  late int groupId;
  late int a;
  late int b;
  late int c;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    sessions = SessionRepository(db);
    supersets = SupersetRepository(db);
    final prescriptions = PrescriptionRepository(db);
    final programId =
        await db.into(db.programs).insert(ProgramsCompanion.insert(name: 'P'));
    dayId = await db.into(db.workoutDays).insert(WorkoutDaysCompanion.insert(
        programId: programId, name: 'D', orderIndex: 0));
    Future<int> exercise(String n) =>
        db.into(db.exercises).insert(ExercisesCompanion.insert(name: n));
    a = await exercise('A');
    b = await exercise('B');
    c = await exercise('C');
    final pa = await prescriptions.add(
        dayId, PrescriptionDraft(exerciseId: a, targetSets: 3, targetReps: 10));
    final pb = await prescriptions.add(
        dayId, PrescriptionDraft(exerciseId: b, targetSets: 3, targetReps: 12));
    await prescriptions.add(dayId, PrescriptionDraft(exerciseId: c, targetSets: 2));
    groupId = await supersets.createGroup(dayId, [pa, pb]);
  });

  tearDown(() => db.close());

  Future<List<SetLog>> sets(int sessionId) => (db.select(db.setLogs)
        ..where((l) => l.sessionId.equals(sessionId))
        ..orderBy([(l) => OrderingTerm.asc(l.id)]))
      .get();

  test('startSession snapshots superset key and round on each set', () async {
    final id = await sessions.startSession(dayId);
    final list = await sets(id);

    final aSets = list.where((l) => l.exerciseId == a).toList();
    final bSets = list.where((l) => l.exerciseId == b).toList();
    expect(aSets.map((l) => l.roundIndex), [0, 1, 2]);
    expect(bSets.map((l) => l.roundIndex), [0, 1, 2]);
    expect([...aSets, ...bSets].every((l) => l.supersetKey == 's$groupId'),
        isTrue);
    final cSets = list.where((l) => l.exerciseId == c);
    expect(cSets.every((l) => l.supersetKey == null && l.roundIndex == null),
        isTrue);
  });

  test('the session screen entries show one superset followed by C', () async {
    final id = await sessions.startSession(dayId);
    final entries =
        groupIntoEntries(await sessions.watchSessionSets(id).first);

    expect(entries, hasLength(2));
    final superset = entries[0] as SupersetEntry;
    expect(superset.members.map((m) => m.exercise.name), ['A', 'B']);
    expect(superset.rounds, [0, 1, 2]);
    expect((entries[1] as SingleEntry).block.exercise.name, 'C');
  });

  test('addSet inside a superset continues the round numbering', () async {
    final id = await sessions.startSession(dayId);
    final aBlock = (await sets(id)).where((l) => l.exerciseId == a).toList();
    final newId = await sessions.addSet(id, a, aBlock.first.prescriptionId);
    final added = (await sets(id)).firstWhere((l) => l.id == newId);
    expect(added.supersetKey, 's$groupId');
    expect(added.roundIndex, 3);
    expect(added.setIndex, 3);
  });

  test('addRound adds one set to every member', () async {
    final id = await sessions.startSession(dayId);
    final entries =
        groupIntoEntries(await sessions.watchSessionSets(id).first);
    final superset = entries.first as SupersetEntry;

    await sessions.addRound(id, superset.members);

    final after = groupIntoEntries(await sessions.watchSessionSets(id).first)
        .first as SupersetEntry;
    expect(after.rounds, [0, 1, 2, 3]);
    for (final m in after.members) {
      expect(m.sets, hasLength(4));
    }
  });

  test('history keeps the superset after the plan is ungrouped', () async {
    final id = await sessions.startSession(dayId);
    for (final s in await sets(id)) {
      await sessions.setReps(s.id, 10);
      await sessions.setCompleted(s.id, true);
    }
    await sessions.finishSession(id);

    await supersets.ungroup(groupId);

    final kept = (await sets(id)).where((l) => l.exerciseId == a);
    expect(kept.every((l) => l.supersetKey == 's$groupId'), isTrue);
  });

  test('progressive loading on one member leaves the other untouched',
      () async {
    final id = await sessions.startSession(dayId);
    final aSet = (await sets(id)).firstWhere((l) => l.exerciseId == a);
    await sessions.applyProgressiveLoading(
      sessionId: id,
      exerciseId: a,
      prescriptionId: aSet.prescriptionId,
      previousWeight: 5,
      newWeight: 7.5,
      setsAtNewWeight: 2,
    );
    final list = await sets(id);
    expect(list.where((l) => l.exerciseId == a).map((l) => l.weightKg),
        [7.5, 7.5, 5]);
    expect(list.where((l) => l.exerciseId == b).every((l) => l.weightKg == null),
        isTrue);
  });
}

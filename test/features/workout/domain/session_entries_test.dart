import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/domain/session_blocks.dart';

Exercise ex(int id, String name) => Exercise(
    id: id,
    name: name,
    category: null,
    equipment: null,
    notes: null,
    isBodyweight: false,
    isArchived: false);

SetLog log(int id, int exerciseId, int prescriptionId, int setIndex,
        {String? superset, int? round}) =>
    SetLog(
        id: id,
        sessionId: 1,
        exerciseId: exerciseId,
        prescriptionId: prescriptionId,
        setIndex: setIndex,
        setKind: SetKind.normal,
        weightKg: null,
        reps: null,
        isCompleted: false,
        supersetKey: superset,
        roundIndex: round,
        mainSetId: null,
        note: null);

void main() {
  final a = ex(1, 'A');
  final b = ex(2, 'B');
  final c = ex(3, 'C');

  test('superset sets collapse into one entry; order is first-seen', () {
    final entries = groupIntoEntries([
      SetLogWithExercise(log(1, 1, 10, 0, superset: 's1', round: 0), a),
      SetLogWithExercise(log(2, 1, 10, 1, superset: 's1', round: 1), a),
      SetLogWithExercise(log(3, 2, 11, 0, superset: 's1', round: 0), b),
      SetLogWithExercise(log(4, 2, 11, 1, superset: 's1', round: 1), b),
      SetLogWithExercise(log(5, 3, 12, 0), c),
    ]);
    expect(entries, hasLength(2));
    final superset = entries[0] as SupersetEntry;
    expect(superset.key, 's1');
    expect(superset.members.map((m) => m.exercise.name), ['A', 'B']);
    expect((entries[1] as SingleEntry).block.exercise.name, 'C');
  });

  test('rounds align the members sets by roundIndex', () {
    final entry = groupIntoEntries([
      SetLogWithExercise(log(1, 1, 10, 0, superset: 's1', round: 0), a),
      SetLogWithExercise(log(2, 1, 10, 1, superset: 's1', round: 1), a),
      SetLogWithExercise(log(3, 2, 11, 0, superset: 's1', round: 0), b),
      // B's round 1 set was deleted, B has an extra round 2 instead.
      SetLogWithExercise(log(4, 2, 11, 2, superset: 's1', round: 2), b),
    ]).single as SupersetEntry;

    expect(entry.rounds, [0, 1, 2]);
    final memberB = entry.members[1];
    expect(entry.setInRound(memberB, 0)!.id, 3);
    expect(entry.setInRound(memberB, 1), isNull);
    expect(entry.setInRound(memberB, 2)!.id, 4);
  });

  test('a single exercise before and after a superset keeps its place', () {
    final entries = groupIntoEntries([
      SetLogWithExercise(log(1, 3, 12, 0), c),
      SetLogWithExercise(log(2, 1, 10, 0, superset: 's1', round: 0), a),
      SetLogWithExercise(log(3, 2, 11, 0, superset: 's1', round: 0), b),
      SetLogWithExercise(log(4, 3, 13, 0), c),
    ]);
    expect(entries.map((e) => e.runtimeType),
        [SingleEntry, SupersetEntry, SingleEntry]);
  });

  test('two supersets in one session stay separate', () {
    final entries = groupIntoEntries([
      SetLogWithExercise(log(1, 1, 10, 0, superset: 's1', round: 0), a),
      SetLogWithExercise(log(2, 2, 11, 0, superset: 's1', round: 0), b),
      SetLogWithExercise(log(3, 3, 12, 0, superset: 's2', round: 0), c),
      SetLogWithExercise(log(4, 1, 13, 0, superset: 's2', round: 0), a),
    ]);
    expect(entries.map((e) => (e as SupersetEntry).key), ['s1', 's2']);
  });
}

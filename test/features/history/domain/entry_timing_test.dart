import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/history/domain/entry_timing.dart';
import 'package:prforge/features/workout/domain/session_blocks.dart';

final t0 = DateTime(2026, 1, 1, 9, 0);
DateTime at(int minutes) => t0.add(Duration(minutes: minutes));

Exercise ex(int id) => Exercise(
    id: id,
    name: 'E$id',
    category: null,
    equipment: null,
    notes: null,
    isBodyweight: false,
    isArchived: false);

SetLog set(int id, int exerciseId, int? doneAtMin, {String? key}) => SetLog(
    id: id,
    sessionId: 1,
    exerciseId: exerciseId,
    prescriptionId: exerciseId,
    setIndex: id,
    setKind: SetKind.normal,
    weightKg: 10,
    reps: 10,
    isCompleted: doneAtMin != null,
    completedAt: doneAtMin == null ? null : at(doneAtMin),
    supersetKey: key,
    roundIndex: null,
    mainSetId: null,
    note: null);

SingleEntry single(int exerciseId, List<SetLog> sets) => SingleEntry(
    ExerciseBlock(exercise: ex(exerciseId), prescriptionId: exerciseId, sets: sets));

void main() {
  test('first exercise starts at the session start', () {
    final a = single(1, [set(1, 1, 3), set(2, 1, 8)]);
    final b = single(2, [set(3, 2, 14)]);
    final all = [...a.block.sets, ...b.block.sets];
    final t = entryTiming(a, all, t0)!;
    expect(t.start, t0);
    expect(t.end, at(8));
    expect(t.duration, const Duration(minutes: 8));
  });

  test('next exercise starts where the previous completed set ended', () {
    final a = single(1, [set(1, 1, 3), set(2, 1, 8)]);
    final b = single(2, [set(3, 2, 14), set(4, 2, 18)]);
    final all = [...a.block.sets, ...b.block.sets];
    final t = entryTiming(b, all, t0)!;
    expect(t.start, at(8));
    expect(t.end, at(18));
    expect(t.duration, const Duration(minutes: 10));
  });

  test('superset is timed as one entry', () {
    final m1 = ExerciseBlock(
        exercise: ex(1),
        prescriptionId: 1,
        sets: [set(1, 1, 2, key: 's1'), set(3, 1, 6, key: 's1')]);
    final m2 = ExerciseBlock(
        exercise: ex(2),
        prescriptionId: 2,
        sets: [set(2, 2, 4, key: 's1'), set(4, 2, 8, key: 's1')]);
    final entry = SupersetEntry(key: 's1', members: [m1, m2]);
    final t = entryTiming(entry, [...m1.sets, ...m2.sets], t0)!;
    expect(t.start, t0);
    expect(t.end, at(8));
  });

  test('sets without times give no timing', () {
    final a = single(1, [set(1, 1, null)]);
    expect(entryTiming(a, a.block.sets, t0), isNull);
  });

  test('old sessions: completed sets with null time give no timing', () {
    final s = set(1, 1, 5);
    final old = SetLog(
        id: s.id,
        sessionId: 1,
        exerciseId: 1,
        prescriptionId: 1,
        setIndex: 0,
        setKind: SetKind.normal,
        weightKg: 10,
        reps: 10,
        isCompleted: true,
        supersetKey: null,
        roundIndex: null,
        mainSetId: null,
        note: null);
    expect(entryTiming(single(1, [old]), [old], t0), isNull);
  });

  test('out-of-order work: start is the latest earlier completion', () {
    final a = single(1, [set(1, 1, 20)]);
    final b = single(2, [set(2, 2, 5), set(3, 2, 9)]);
    final all = [...a.block.sets, ...b.block.sets];
    final t = entryTiming(a, all, t0)!;
    expect(t.start, at(9));
    expect(t.end, at(20));
  });
}

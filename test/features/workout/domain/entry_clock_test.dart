import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/domain/entry_clock.dart';
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

SetLog set(int id, int exerciseId, int? doneAtMin) => SetLog(
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
    supersetKey: null,
    roundIndex: null,
    mainSetId: null,
    note: null);

SingleEntry single(int exerciseId, List<SetLog> sets) => SingleEntry(
    ExerciseBlock(exercise: ex(exerciseId), prescriptionId: exerciseId, sets: sets));

void main() {
  test('current first exercise counts from the session start', () {
    final a = single(1, [set(1, 1, null), set(2, 1, null)]);
    final c = entryClock(
        entry: a,
        allSets: a.block.sets,
        sessionStart: t0,
        isCurrent: true,
        now: at(3))!;
    expect(c.running, isTrue);
    expect(c.elapsed, const Duration(minutes: 3));
  });

  test('current exercise with a done set counts from its start', () {
    final a = single(1, [set(1, 1, 4), set(2, 1, null)]);
    final c = entryClock(
        entry: a,
        allSets: a.block.sets,
        sessionStart: t0,
        isCurrent: true,
        now: at(6))!;
    expect(c.running, isTrue);
    expect(c.elapsed, const Duration(minutes: 6));
  });

  test('next exercise starts counting at the previous last set', () {
    final a = single(1, [set(1, 1, 5), set(2, 1, 9)]);
    final b = single(2, [set(3, 2, null)]);
    final c = entryClock(
        entry: b,
        allSets: [...a.block.sets, ...b.block.sets],
        sessionStart: t0,
        isCurrent: true,
        now: at(12))!;
    expect(c.elapsed, const Duration(minutes: 3));
  });

  test('finished exercise shows its fixed duration, not running', () {
    final a = single(1, [set(1, 1, 5), set(2, 1, 9)]);
    final c = entryClock(
        entry: a,
        allSets: a.block.sets,
        sessionStart: t0,
        isCurrent: false,
        now: at(60))!;
    expect(c.running, isFalse);
    expect(c.elapsed, const Duration(minutes: 9));
  });

  test('exercise not reached yet has no clock', () {
    final b = single(2, [set(3, 2, null)]);
    expect(
        entryClock(
            entry: b,
            allSets: b.block.sets,
            sessionStart: t0,
            isCurrent: false,
            now: at(5)),
        isNull);
  });
}

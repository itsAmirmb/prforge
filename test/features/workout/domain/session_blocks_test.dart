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

SetLog log(int id, int exerciseId, int? prescriptionId, int setIndex) => SetLog(
    id: id,
    sessionId: 1,
    exerciseId: exerciseId,
    prescriptionId: prescriptionId,
    setIndex: setIndex,
    setKind: SetKind.normal,
    weightKg: null,
    reps: null,
    isCompleted: false,
    supersetKey: null,
    roundIndex: null,
    mainSetId: null,
    note: null);

void main() {
  final curl = ex(1, 'Curl');
  final squat = ex(2, 'Squat');

  test('blocks keep first-seen order and sets are sorted by index', () {
    final blocks = groupIntoBlocks([
      SetLogWithExercise(log(1, 1, 10, 0), curl),
      SetLogWithExercise(log(2, 1, 10, 1), curl),
      SetLogWithExercise(log(3, 2, 20, 0), squat),
      SetLogWithExercise(log(4, 1, 10, 2), curl), // set added later
    ]);
    expect(blocks.map((b) => b.exercise.name), ['Curl', 'Squat']);
    expect(blocks.first.sets.map((s) => s.setIndex), [0, 1, 2]);
  });

  test('same exercise planned twice stays two blocks', () {
    final blocks = groupIntoBlocks([
      SetLogWithExercise(log(1, 1, 10, 0), curl),
      SetLogWithExercise(log(2, 1, 11, 0), curl),
    ]);
    expect(blocks, hasLength(2));
  });

  test('sets without a prescription group by exercise', () {
    final blocks = groupIntoBlocks([
      SetLogWithExercise(log(1, 1, null, 0), curl),
      SetLogWithExercise(log(2, 1, null, 1), curl),
      SetLogWithExercise(log(3, 2, null, 0), squat),
    ]);
    expect(blocks, hasLength(2));
    expect(blocks.first.sets, hasLength(2));
    expect(blocks.first.prescriptionId, isNull);
  });
}

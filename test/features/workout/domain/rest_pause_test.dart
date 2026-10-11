import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/domain/rest_pause.dart';

SetLog main(int? reps) => SetLog(
    id: 1,
    sessionId: 1,
    exerciseId: 1,
    prescriptionId: null,
    setIndex: 0,
    setKind: SetKind.restPause,
    weightKg: 20,
    reps: reps,
    isCompleted: true,
    supersetKey: null,
    roundIndex: null,
    mainSetId: null,
    note: null);

MiniSetLog mini(int id, int reps) => MiniSetLog(
    id: id,
    setLogId: 1,
    miniSetIndex: id,
    weightKg: 20,
    reps: reps,
    restSeconds: 15);

void main() {
  test('total reps = main set reps + every mini-set', () {
    expect(restPauseTotalReps(main(10), [mini(1, 4), mini(2, 3)]), 17);
  });

  test('no mini-sets: total is the main set; missing reps count as 0', () {
    expect(restPauseTotalReps(main(10), const []), 10);
    expect(restPauseTotalReps(main(null), [mini(1, 5)]), 5);
  });

  test('default mini-set rest is a positive number of seconds', () {
    expect(defaultMiniSetRestSeconds, greaterThan(0));
  });
}

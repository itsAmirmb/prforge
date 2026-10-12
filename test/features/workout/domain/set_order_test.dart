import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/domain/set_order.dart';

SetLog set(int id, {bool done = false}) => SetLog(
    id: id,
    sessionId: 1,
    exerciseId: 1,
    prescriptionId: null,
    setIndex: id,
    setKind: SetKind.normal,
    weightKg: 10,
    reps: 10,
    isCompleted: done,
    supersetKey: null,
    roundIndex: null,
    mainSetId: null,
    note: null);

void main() {
  test('nothing done: first set is current', () {
    expect(currentSetIdOf([set(1), set(2), set(3)]), 1);
  });

  test('after finished sets, the next one is current', () {
    expect(currentSetIdOf([set(1, done: true), set(2), set(3)]), 2);
    expect(currentSetIdOf([set(1, done: true), set(2, done: true), set(3)]), 3);
  });

  test('skipped set before the furthest finished one is not revisited', () {
    expect(currentSetIdOf([set(1), set(2, done: true), set(3)]), 3);
  });

  test('falls back to the first unfinished set when the tail is done', () {
    expect(currentSetIdOf([set(1), set(2, done: true), set(3, done: true)]), 1);
  });

  test('all done or empty gives null', () {
    expect(currentSetIdOf([set(1, done: true), set(2, done: true)]), isNull);
    expect(currentSetIdOf(const []), isNull);
  });

  test('performingOrder of no entries is empty', () {
    expect(performingOrder(const []), isEmpty);
  });
}

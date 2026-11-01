import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/domain/session_blocks.dart';

SetLog set(int id, int prescription, {int? order, String? superset}) => SetLog(
  id: id,
  sessionId: 1,
  exerciseId: prescription,
  prescriptionId: prescription,
  setIndex: 0,
  setKind: SetKind.normal,
  weightKg: null,
  reps: 10,
  isCompleted: false,
  completedAt: null,
  supersetKey: superset,
  roundIndex: null,
  entryOrder: order,
  mainSetId: null,
  note: null,
);

void main() {
  test('without saved positions the creation order is used', () {
    expect(orderedTokens([set(1, 10), set(2, 11), set(3, 10)]), [
      'p:10',
      'p:11',
    ]);
  });

  test('saved positions win, the rest follow in creation order', () {
    expect(
      orderedTokens([set(1, 10, order: 1), set(2, 11, order: 0), set(3, 12)]),
      ['p:11', 'p:10', 'p:12'],
    );
  });

  test('a superset is one entry', () {
    expect(
      orderedTokens([
        set(1, 10, superset: 's1', order: 1),
        set(2, 11, superset: 's1', order: 1),
        set(3, 12, order: 0),
      ]),
      ['p:12', 's:s1'],
    );
  });
}

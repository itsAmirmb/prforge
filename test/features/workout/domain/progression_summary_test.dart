import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/workout/domain/progression_summary.dart';

SetLog log(int id, double? weight) => SetLog(
    id: id,
    sessionId: 1,
    exerciseId: 1,
    prescriptionId: null,
    setIndex: id,
    setKind: SetKind.normal,
    weightKg: weight,
    reps: 10,
    isCompleted: true,
    supersetKey: null,
    roundIndex: null,
    mainSetId: null,
    note: null);

void main() {
  test('counts last time sets at a weight (1/3 pattern)', () {
    final last = [log(0, 7.5), log(1, 5), log(2, 5)];
    final usage = lastTimeUsage(last, 7.5);
    expect(usage.atWeight, 1);
    expect(usage.total, 3);
  });

  test('weight not used last time gives zero; empty history is safe', () {
    expect(lastTimeUsage([log(0, 5)], 7.5).atWeight, 0);
    final empty = lastTimeUsage(const [], 7.5);
    expect(empty.atWeight, 0);
    expect(empty.total, 0);
  });
}

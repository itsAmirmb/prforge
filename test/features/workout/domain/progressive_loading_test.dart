import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/workout/domain/progressive_loading.dart';

List<PlannedSet> plan(int newSets, {int total = 3}) => planProgressiveLoading(
      totalSets: total,
      previousWeight: 5,
      newWeight: 7.5,
      setsAtNewWeight: newSets,
    );

int newCount(List<PlannedSet> s) => s.where((e) => e.isNewWeight).length;

void main() {
  test('1/3 -> 2 sets at 5kg + 1 set at 7.5kg', () {
    final s = plan(1);
    expect(newCount(s), 1);
    expect(s.map((e) => e.weight), [7.5, 5, 5]);
  });

  test('progression 1/3 -> 2/3 -> 3/3 and back to 2/3 and 1/3', () {
    for (final n in [1, 2, 3, 2, 1]) {
      final s = plan(n);
      expect(s.length, 3);
      expect(newCount(s), n);
    }
  });

  test('0/3 keeps previous weight, 3/3 uses only new weight', () {
    expect(plan(0).every((e) => e.weight == 5), isTrue);
    expect(plan(3).every((e) => e.weight == 7.5), isTrue);
  });

  test('decimal weights are kept exactly', () {
    expect(plan(2).first.weight, 7.5);
  });

  test('invalid input throws', () {
    expect(() => plan(4), throwsArgumentError);
    expect(() => plan(-1), throwsArgumentError);
    expect(() => plan(0, total: 0), throwsArgumentError);
  });
}

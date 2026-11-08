import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/workout/domain/duration_estimate.dart';

void main() {
  EstimateSet single(int exercise, {int? reps = 10, int? rest}) =>
      EstimateSet(exerciseId: exercise, reps: reps, setRest: rest);

  test('work of every set plus rest after all but the last', () {
    // 3 sets of 10 reps: 3 x (10 + 30) work, 2 x 60 rest.
    final sets = [for (var i = 0; i < 3; i++) single(1, rest: 60)];
    expect(estimateDuration(sets, defaultRest: 90), const Duration(seconds: 240));
  });

  test('uses the default rest when the plan has none', () {
    final sets = [single(1), single(1)];
    expect(estimateDuration(sets, defaultRest: 90),
        const Duration(seconds: 40 + 90 + 40));
  });

  test('rest between exercises replaces the rest after the last set', () {
    final sets = [single(1, rest: 60), single(2, rest: 60)];
    expect(estimateDuration(sets, defaultRest: 90, exerciseChangeRest: 120),
        const Duration(seconds: 40 + 120 + 40));
  });

  test('no rest after the final set, and an empty workout takes no time', () {
    expect(estimateDuration([single(1)], defaultRest: 90),
        const Duration(seconds: 40));
    expect(estimateDuration(const [], defaultRest: 90), Duration.zero);
  });

  test('superset: between-rest inside a round, round rest after it', () {
    EstimateSet member(int exercise, int round) => EstimateSet(
        exerciseId: exercise,
        supersetKey: 's1',
        round: round,
        reps: 10,
        betweenRest: 10,
        afterRoundRest: 100);
    final sets = [member(1, 0), member(2, 0), member(1, 1), member(2, 1)];
    // 4 x 40 work + between 10 + round 100 + between 10.
    expect(estimateDuration(sets, defaultRest: 90),
        const Duration(seconds: 160 + 10 + 100 + 10));
  });

  test('formats the estimate', () {
    expect(formatEstimate(const Duration(minutes: 52), roundToMinutes: 5),
        '~55 min');
    expect(formatEstimate(const Duration(minutes: 25, seconds: 10)), '~26 min');
    expect(formatEstimate(const Duration(minutes: 65)), '~1 h 05 min');
    expect(formatEstimate(const Duration(minutes: 60)), '~1 h');
  });
}

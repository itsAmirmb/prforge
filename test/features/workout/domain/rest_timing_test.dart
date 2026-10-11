import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/workout/domain/rest_timing.dart';

void main() {
  group('single exercise', () {
    int? rest({int? setRest}) => restSecondsAfterSet(
        isSuperset: false, roundComplete: true, setRest: setRest);

    test('uses the plan, else the default', () {
      expect(rest(setRest: 60), 60);
      expect(rest(), defaultRestSeconds);
    });

    test('0 means no rest', () => expect(rest(setRest: 0), isNull));
  });

  group('superset', () {
    int? rest({
      required bool roundComplete,
      int? setRest,
      int? between,
      int? after,
    }) =>
        restSecondsAfterSet(
          isSuperset: true,
          roundComplete: roundComplete,
          setRest: setRest,
          betweenRest: between,
          afterRoundRest: after,
        );

    test('no timer between members unless a rest is planned', () {
      expect(rest(roundComplete: false), isNull);
      expect(rest(roundComplete: false, setRest: 60, after: 90), isNull);
      expect(rest(roundComplete: false, between: 10), 10);
      expect(rest(roundComplete: false, between: 0), isNull);
    });

    test('after the round: group rest, then plan rest, then default', () {
      expect(rest(roundComplete: true, after: 120, setRest: 60), 120);
      expect(rest(roundComplete: true, setRest: 60), 60);
      expect(rest(roundComplete: true), defaultRestSeconds);
      expect(rest(roundComplete: true, after: 0), isNull);
    });
  });

  test('custom default', () {
    expect(
        restSecondsAfterSet(
            isSuperset: false, roundComplete: true, defaultRest: 45),
        45);
  });
}

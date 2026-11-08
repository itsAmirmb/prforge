import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/workout/domain/rest_countdown.dart';

void main() {
  List<double> secondsOf(CountdownStyle style, int total, {int n = 5}) => [
        for (final d in countdownTicks(
            style: style, seconds: n, totalSeconds: total))
          d.inMilliseconds / 1000,
      ];

  test('off gives no beeps', () {
    expect(secondsOf(CountdownStyle.off, 90), isEmpty);
  });

  test('seconds: one beep per second, skipping what is longer than the rest',
      () {
    expect(secondsOf(CountdownStyle.seconds, 90), [5, 4, 3, 2, 1]);
    expect(secondsOf(CountdownStyle.seconds, 3), [2, 1]);
  });

  test('halving: half, then half of what is left, until under a second', () {
    expect(secondsOf(CountdownStyle.halving, 90),
        [45, 22.5, 11.25, 5.625, 2.8125, 1.40625]);
    expect(secondsOf(CountdownStyle.halving, 30), [15, 7.5, 3.75, 1.875]);
    expect(secondsOf(CountdownStyle.halving, 1), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/progress/domain/plateau.dart';
import 'package:prforge/features/progress/domain/progress.dart';

final start = DateTime(2026, 1, 1);

SessionPoint point(int session, int dayOffset, double? weight) => SessionPoint(
      sessionId: session,
      date: start.add(Duration(days: dayOffset)),
      maxWeight: weight,
      bestRepsAtMax: 8,
      totalReps: 24,
      volumeKg: 0,
      sets: 3,
      segments: const [],
    );

DateTime day(int offset) => start.add(Duration(days: offset));

void main() {
  test('same top weight for 3 sessions over 3 weeks is a plateau', () {
    final p = detectPlateau(
      [point(1, 0, 60), point(2, 7, 62.5), point(3, 14, 62.5), point(4, 21, 62.5)],
      now: day(22),
    )!;
    expect(p.weight, 62.5);
    expect(p.sessions, 3);
    expect(p.weeks, 2); // day 7 to day 22 = 15 days
  });

  test('a recent increase resets it', () {
    expect(
        detectPlateau(
            [point(1, 0, 60), point(2, 7, 60), point(3, 14, 62.5)],
            now: day(21)),
        isNull);
  });

  test('too few sessions or too short a time is not a plateau', () {
    expect(detectPlateau([point(1, 0, 60), point(2, 7, 60)], now: day(30)),
        isNull);
    expect(
        detectPlateau(
            [point(1, 0, 60), point(2, 2, 60), point(3, 4, 60)], now: day(6)),
        isNull);
  });

  test('already planning a heavier weight today hides it', () {
    final points = [point(1, 0, 60), point(2, 7, 60), point(3, 14, 60)];
    expect(detectPlateau(points, now: day(21)), isNotNull);
    expect(detectPlateau(points, now: day(21), currentWeight: 62.5), isNull);
    expect(detectPlateau(points, now: day(21), currentWeight: 60), isNotNull);
  });

  test('bodyweight and empty history never plateau', () {
    expect(detectPlateau(const [], now: day(30)), isNull);
    expect(
        detectPlateau(
            [point(1, 0, null), point(2, 7, null), point(3, 14, null)],
            now: day(30)),
        isNull);
  });
}

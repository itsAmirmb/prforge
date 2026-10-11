import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/history/domain/session_stats.dart';
import 'package:prforge/features/history/domain/set_text.dart';

SetLog set(int id, int exerciseId, double? weight, int? reps,
        {SetKind kind = SetKind.normal}) =>
    SetLog(
        id: id,
        sessionId: 1,
        exerciseId: exerciseId,
        prescriptionId: null,
        setIndex: id,
        setKind: kind,
        weightKg: weight,
        reps: reps,
        isCompleted: true,
        supersetKey: null,
        roundIndex: null,
        mainSetId: null,
        note: null);

MiniSetLog mini(int id, double? weight, int reps, {int? rest = 15}) =>
    MiniSetLog(
        id: id,
        setLogId: 1,
        miniSetIndex: id,
        weightKg: weight,
        reps: reps,
        restSeconds: rest);

void main() {
  group('computeSessionStats', () {
    test('empty input gives zeros', () {
      final s = computeSessionStats(const [], const []);
      expect(s.setCount, 0);
      expect(s.exerciseCount, 0);
      expect(s.totalReps, 0);
      expect(s.volumeKg, 0);
    });

    test('counts sets, distinct exercises, reps and volume', () {
      final s = computeSessionStats([
        set(1, 10, 60, 8),
        set(2, 10, 60, 6),
        set(3, 11, 20, 10),
      ], const []);
      expect(s.setCount, 3);
      expect(s.exerciseCount, 2);
      expect(s.totalReps, 24);
      expect(s.volumeKg, 60 * 8 + 60 * 6 + 20 * 10);
    });

    test('bodyweight sets add reps but no volume', () {
      final s = computeSessionStats([set(1, 10, null, 12)], const []);
      expect(s.totalReps, 12);
      expect(s.volumeKg, 0);
    });

    test('mini-sets add reps and volume but not set count', () {
      final s = computeSessionStats(
        [set(1, 10, 20, 10, kind: SetKind.restPause)],
        [mini(1, 20, 4), mini(2, 15, 3)],
      );
      expect(s.setCount, 1);
      expect(s.totalReps, 17);
      expect(s.volumeKg, 20 * 10 + 20 * 4 + 15 * 3);
    });
  });

  group('set text', () {
    test('weight and reps', () {
      expect(setText(set(1, 1, 60, 8)), '60 kg × 8');
      expect(setText(set(1, 1, 7.5, 12)), '7.5 kg × 12');
    });

    test('zero weight is shown, null weight is bodyweight', () {
      expect(setText(set(1, 1, 0, 5)), '0 kg × 5');
      expect(setText(set(1, 1, null, 12)), '12 reps');
    });

    test('mini-set with and without rest', () {
      expect(miniSetText(mini(1, 17.5, 4)), '+ 17.5 kg × 4 · rest 15s');
      expect(miniSetText(mini(1, 20, 3, rest: null)), '+ 20 kg × 3');
    });
  });
}

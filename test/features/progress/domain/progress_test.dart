import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/database/app_database.dart';
import 'package:prforge/features/progress/domain/progress.dart';

int _id = 0;

LoggedSet logged(int session, int index, double? weight, int reps,
    {DateTime? at, List<MiniSetLog> minis = const []}) {
  final id = ++_id;
  return LoggedSet(
    sessionId: session,
    startedAt: at ?? DateTime(2026, 1, session),
    log: SetLog(
        id: id,
        sessionId: session,
        exerciseId: 1,
        prescriptionId: null,
        setIndex: index,
        setKind: minis.isEmpty ? SetKind.normal : SetKind.restPause,
        weightKg: weight,
        reps: reps,
        isCompleted: true,
        supersetKey: null,
        roundIndex: null,
        mainSetId: null,
        note: null),
    miniSets: minis,
  );
}

MiniSetLog mini(int setLogId, int i, double? weight, int reps) => MiniSetLog(
    id: ++_id,
    setLogId: setLogId,
    miniSetIndex: i,
    weightKg: weight,
    reps: reps,
    restSeconds: 15);

void main() {
  test('no sets gives empty progress', () {
    final p = buildExerciseProgress(const []);
    expect(p.isEmpty, isTrue);
    expect(p.maxWeight, isNull);
    expect(p.totalVolumeKg, 0);
  });

  test('one point per session, oldest first', () {
    final p = buildExerciseProgress([
      logged(2, 0, 62.5, 8),
      logged(1, 0, 60, 8),
      logged(1, 1, 60, 6),
    ]);
    expect(p.points.map((x) => x.sessionId), [1, 2]);
    final first = p.points.first;
    expect(first.maxWeight, 60);
    expect(first.bestRepsAtMax, 8);
    expect(first.totalReps, 14);
    expect(first.volumeKg, 60 * 8 + 60 * 6);
    expect(first.sets, 2);
  });

  test('different weights per set are kept in order (stepped loading)', () {
    final p = buildExerciseProgress([
      logged(1, 1, 55, 10),
      logged(1, 0, 60, 8),
      logged(1, 2, 55, 9),
    ]);
    final point = p.points.single;
    expect(point.maxWeight, 60);
    expect(point.bestRepsAtMax, 8);
    expect(point.segments.map((s) => s.weight), [60, 55, 55]);
  });

  test('records: best reps and set count per weight, heaviest first', () {
    final p = buildExerciseProgress([
      logged(1, 0, 60, 8),
      logged(1, 1, 60, 6),
      logged(2, 0, 60, 9),
      logged(2, 1, 55, 12),
      logged(3, 0, null, 15),
    ]);
    expect(p.records.map((r) => r.weight), [60, 55, null]);
    expect(p.records[0].bestReps, 9);
    expect(p.records[0].sets, 3);
    expect(p.records[1].bestReps, 12);
    expect(p.records[1].sets, 1);
    expect(p.records[2].bestReps, 15); // bodyweight
    expect(p.maxWeight, 60);
  });

  test('rest-pause: mini-sets add reps and volume, not sets', () {
    final main = logged(1, 0, 20, 10);
    final withMinis = LoggedSet(
      sessionId: 1,
      startedAt: main.startedAt,
      log: main.log,
      miniSets: [mini(main.log.id, 0, 20, 4), mini(main.log.id, 1, 17.5, 3)],
    );
    final p = buildExerciseProgress([withMinis]);
    final point = p.points.single;
    expect(point.sets, 1);
    expect(point.totalReps, 17);
    expect(point.volumeKg, 20 * 10 + 20 * 4 + 17.5 * 3);
    expect(point.maxWeight, 20);
    expect(point.bestRepsAtMax, 10);
    expect(p.records.firstWhere((r) => r.weight == 17.5).bestReps, 3);
    expect(p.records.firstWhere((r) => r.weight == 20).sets, 1);
  });

  test('bodyweight-only session has no max weight and zero volume', () {
    final p = buildExerciseProgress([logged(1, 0, null, 12)]);
    final point = p.points.single;
    expect(point.maxWeight, isNull);
    expect(point.bestRepsAtMax, 12);
    expect(point.volumeKg, 0);
    expect(p.maxWeight, isNull);
  });

  group('patternText', () {
    test('groups consecutive equal weights', () {
      expect(
        patternText([
          (weight: 60.0, reps: 8),
          (weight: 60.0, reps: 6),
          (weight: 55.0, reps: 10),
        ]),
        '60 kg × 8, 6 · 55 kg × 10',
      );
    });

    test('does not merge a weight that returns later', () {
      expect(
        patternText([
          (weight: 60.0, reps: 8),
          (weight: 55.0, reps: 8),
          (weight: 60.0, reps: 6),
        ]),
        '60 kg × 8 · 55 kg × 8 · 60 kg × 6',
      );
    });

    test('no weight reads as reps and decimals are kept', () {
      expect(patternText([(weight: null, reps: 12), (weight: null, reps: 10)]),
          '12, 10 reps');
      expect(patternText([(weight: 7.5, reps: 12)]), '7.5 kg × 12');
    });
  });
}

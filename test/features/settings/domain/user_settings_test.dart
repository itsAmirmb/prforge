import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/features/settings/domain/user_settings.dart';

void main() {
  test('workout timers default to on', () {
    final s = UserSettings.fromMap(const {});
    expect(s.showWorkoutClock, isTrue);
    expect(s.showExerciseClock, isTrue);
    expect(s.showSetClock, isTrue);
  });

  test('workout timers can be switched off one by one', () {
    final s = UserSettings.fromMap({
      SettingKeys.showWorkoutClock: 'false',
      SettingKeys.showSetClock: 'false',
    });
    expect(s.showWorkoutClock, isFalse);
    expect(s.showExerciseClock, isTrue);
    expect(s.showSetClock, isFalse);
  });

  test('plateau reminder defaults and range checks', () {
    final d = UserSettings.fromMap(const {});
    expect(d.plateauHint, isTrue);
    expect(d.plateauWeeks, 2);
    expect(d.plateauSessions, 3);

    final custom = UserSettings.fromMap({
      SettingKeys.plateauHint: 'false',
      SettingKeys.plateauWeeks: '4',
      SettingKeys.plateauSessions: '5',
    });
    expect(custom.plateauHint, isFalse);
    expect(custom.plateauWeeks, 4);
    expect(custom.plateauSessions, 5);

    final bad = UserSettings.fromMap({
      SettingKeys.plateauWeeks: '99',
      SettingKeys.plateauSessions: 'x',
    });
    expect(bad.plateauWeeks, 2);
    expect(bad.plateauSessions, 3);
  });

  test('voice announcements: reps and name on, weight off by default', () {
    final d = UserSettings.fromMap(const {});
    expect(d.speakReps, isTrue);
    expect(d.speakWeight, isFalse);
    expect(d.speakExerciseName, isTrue);
    final custom = UserSettings.fromMap({
      SettingKeys.speakReps: 'false',
      SettingKeys.speakWeight: 'true',
    });
    expect(custom.speakReps, isFalse);
    expect(custom.speakWeight, isTrue);
  });
}

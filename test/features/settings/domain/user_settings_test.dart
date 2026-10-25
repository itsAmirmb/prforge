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
}

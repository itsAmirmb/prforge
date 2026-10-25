import 'package:flutter/material.dart' show ThemeMode;

import '../../workout/domain/rest_timing.dart';

/// Keys of the settings rows.
abstract final class SettingKeys {
  static const restSeconds = 'restSeconds';
  static const sound = 'sound';
  static const vibration = 'vibration';
  static const keepScreenOn = 'keepScreenOn';
  static const themeMode = 'themeMode';
  static const showWorkoutClock = 'showWorkoutClock';
  static const showExerciseClock = 'showExerciseClock';
  static const showSetClock = 'showSetClock';
  static const plateauHint = 'plateauHint';
  static const plateauWeeks = 'plateauWeeks';
  static const plateauSessions = 'plateauSessions';
}

/// Limits of the plateau reminder conditions.
const minPlateauWeeks = 1, maxPlateauWeeks = 12;
const minPlateauSessions = 2, maxPlateauSessions = 10;

/// Longest default rest that can be set (10 minutes).
const maxDefaultRestSeconds = 600;

/// App-wide user settings. Missing or damaged values fall back to defaults.
class UserSettings {
  const UserSettings({
    this.restSeconds = defaultRestSeconds,
    this.sound = true,
    this.vibration = true,
    this.keepScreenOn = true,
    this.themeMode = ThemeMode.system,
    this.showWorkoutClock = true,
    this.showExerciseClock = true,
    this.showSetClock = true,
    this.plateauHint = true,
    this.plateauWeeks = 2,
    this.plateauSessions = 3,
  });

  static const defaults = UserSettings();

  /// Rest after a set when the plan gives none. 0 = no rest timer.
  final int restSeconds;
  final bool sound;
  final bool vibration;

  /// Keep the screen on while a workout is open.
  final bool keepScreenOn;
  final ThemeMode themeMode;

  /// Which stopwatches the workout screen shows: whole workout, each
  /// exercise, each set.
  final bool showWorkoutClock;
  final bool showExerciseClock;
  final bool showSetClock;

  /// "Same weight for N weeks" note under an exercise, shown once the top
  /// weight was unchanged for at least [plateauWeeks] weeks and
  /// [plateauSessions] sessions.
  final bool plateauHint;
  final int plateauWeeks;
  final int plateauSessions;

  factory UserSettings.fromMap(Map<String, String> map) {
    bool flag(String key, bool fallback) => switch (map[key]) {
          'true' => true,
          'false' => false,
          _ => fallback,
        };
    int inRange(String key, int min, int max, int fallback) {
      final v = int.tryParse(map[key] ?? '');
      return v == null || v < min || v > max ? fallback : v;
    }

    final rest = int.tryParse(map[SettingKeys.restSeconds] ?? '');
    return UserSettings(
      restSeconds: rest == null || rest < 0 || rest > maxDefaultRestSeconds
          ? defaultRestSeconds
          : rest,
      sound: flag(SettingKeys.sound, true),
      vibration: flag(SettingKeys.vibration, true),
      keepScreenOn: flag(SettingKeys.keepScreenOn, true),
      themeMode: ThemeMode.values.asNameMap()[map[SettingKeys.themeMode]] ??
          ThemeMode.system,
      showWorkoutClock: flag(SettingKeys.showWorkoutClock, true),
      showExerciseClock: flag(SettingKeys.showExerciseClock, true),
      showSetClock: flag(SettingKeys.showSetClock, true),
      plateauHint: flag(SettingKeys.plateauHint, true),
      plateauWeeks: inRange(SettingKeys.plateauWeeks, minPlateauWeeks,
          maxPlateauWeeks, 2),
      plateauSessions: inRange(SettingKeys.plateauSessions,
          minPlateauSessions, maxPlateauSessions, 3),
    );
  }
}

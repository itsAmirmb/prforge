import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/feedback/speech_service.dart' show SpeechLanguage;
import '../../workout/domain/rest_countdown.dart';
import '../../workout/domain/rest_timing.dart';

/// Keys of the settings rows.
abstract final class SettingKeys {
  static const restSeconds = 'restSeconds';
  static const restBetweenExercises = 'restBetweenExercises';
  static const restWarnSeconds = 'restWarnSeconds';
  static const countdownStyle = 'countdownStyle';
  static const speechLanguage = 'speechLanguage';
  static const sound = 'sound';
  static const vibration = 'vibration';
  static const keepScreenOn = 'keepScreenOn';
  static const themeMode = 'themeMode';
  static const showWorkoutClock = 'showWorkoutClock';
  static const showExerciseClock = 'showExerciseClock';
  static const showSetClock = 'showSetClock';
  static const plateauHint = 'plateauHint';
  static const speakReps = 'speakReps';
  static const speakWeight = 'speakWeight';
  static const speakExerciseName = 'speakExerciseName';
  static const plateauWeeks = 'plateauWeeks';
  static const plateauSessions = 'plateauSessions';
}

/// Limits of the plateau reminder conditions.
const minPlateauWeeks = 1, maxPlateauWeeks = 12;
const minPlateauSessions = 2, maxPlateauSessions = 10;

/// Countdown length in seconds for [CountdownStyle.seconds].
const minRestWarnSeconds = 1, maxRestWarnSeconds = 8;

/// Longest default rest that can be set (10 minutes).
const maxDefaultRestSeconds = 600;

/// App-wide user settings. Missing or damaged values fall back to defaults.
class UserSettings {
  const UserSettings({
    this.restSeconds = defaultRestSeconds,
    this.restBetweenExercises = 0,
    this.restWarnSeconds = 5,
    this.countdownStyle = CountdownStyle.seconds,
    this.speechLanguage = SpeechLanguage.english,
    this.sound = true,
    this.vibration = true,
    this.keepScreenOn = true,
    this.themeMode = ThemeMode.system,
    this.showWorkoutClock = true,
    this.showExerciseClock = true,
    this.showSetClock = true,
    this.plateauHint = true,
    this.speakReps = true,
    this.speakWeight = false,
    this.speakExerciseName = true,
    this.plateauWeeks = 2,
    this.plateauSessions = 3,
  });

  static const defaults = UserSettings();

  /// Rest after a set when the plan gives none. 0 = no rest timer.
  final int restSeconds;

  /// Rest after the last set of an exercise when another exercise follows.
  /// 0 = off: the usual rest applies.
  final int restBetweenExercises;

  /// Countdown before a rest ends: how, and (for one beep per second) for how
  /// many seconds.
  final int restWarnSeconds;
  final CountdownStyle countdownStyle;

  /// Language of the numbers and units when the next set is spoken.
  final SpeechLanguage speechLanguage;
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

  /// What is spoken when a rest is over: the next set's reps and weight, and
  /// the exercise name when the next set is a different exercise.
  final bool speakReps;
  final bool speakWeight;
  final bool speakExerciseName;
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
    final between = int.tryParse(map[SettingKeys.restBetweenExercises] ?? '');
    return UserSettings(
      restWarnSeconds: inRange(SettingKeys.restWarnSeconds, minRestWarnSeconds,
          maxRestWarnSeconds, 5),
      // Before the style existed, 0 seconds meant "off".
      countdownStyle:
          CountdownStyle.values.asNameMap()[map[SettingKeys.countdownStyle]] ??
              (map[SettingKeys.restWarnSeconds] == '0'
                  ? CountdownStyle.off
                  : CountdownStyle.seconds),
      restBetweenExercises:
          between == null || between < 0 || between > maxDefaultRestSeconds
              ? 0
              : between,
      speechLanguage:
          SpeechLanguage.values.asNameMap()[map[SettingKeys.speechLanguage]] ??
              SpeechLanguage.english,
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
      speakReps: flag(SettingKeys.speakReps, true),
      speakWeight: flag(SettingKeys.speakWeight, false),
      speakExerciseName: flag(SettingKeys.speakExerciseName, true),
      plateauWeeks: inRange(SettingKeys.plateauWeeks, minPlateauWeeks,
          maxPlateauWeeks, 2),
      plateauSessions: inRange(SettingKeys.plateauSessions,
          minPlateauSessions, maxPlateauSessions, 3),
    );
  }
}

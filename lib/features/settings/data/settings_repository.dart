import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/database/app_database.dart';
import '../../../core/feedback/speech_service.dart' show SpeechLanguage;
import '../domain/user_settings.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Stream<UserSettings> watch() => _db.select(_db.settingEntries).watch().map(
        (rows) => UserSettings.fromMap({for (final r in rows) r.key: r.value}),
      );

  Future<void> _put(String key, String value) => _db
      .into(_db.settingEntries)
      .insertOnConflictUpdate(SettingEntriesCompanion.insert(key: key, value: value));

  /// Clamped to 0..[maxDefaultRestSeconds].
  Future<void> setRestSeconds(int seconds) => _put(SettingKeys.restSeconds,
      seconds.clamp(0, maxDefaultRestSeconds).toString());

  /// Clamped to 0..[maxDefaultRestSeconds]; 0 = off.
  Future<void> setRestBetweenExercises(int seconds) => _put(
      SettingKeys.restBetweenExercises,
      seconds.clamp(0, maxDefaultRestSeconds).toString());

  Future<void> setSpeechLanguage(SpeechLanguage language) =>
      _put(SettingKeys.speechLanguage, language.name);

  Future<void> setSound(bool on) => _put(SettingKeys.sound, on.toString());

  Future<void> setVibration(bool on) =>
      _put(SettingKeys.vibration, on.toString());

  Future<void> setKeepScreenOn(bool on) =>
      _put(SettingKeys.keepScreenOn, on.toString());

  Future<void> setShowWorkoutClock(bool on) =>
      _put(SettingKeys.showWorkoutClock, on.toString());

  Future<void> setShowExerciseClock(bool on) =>
      _put(SettingKeys.showExerciseClock, on.toString());

  Future<void> setShowSetClock(bool on) =>
      _put(SettingKeys.showSetClock, on.toString());

  Future<void> setPlateauHint(bool on) =>
      _put(SettingKeys.plateauHint, on.toString());

  Future<void> setPlateauWeeks(int weeks) => _put(SettingKeys.plateauWeeks,
      weeks.clamp(minPlateauWeeks, maxPlateauWeeks).toString());

  Future<void> setPlateauSessions(int sessions) => _put(
      SettingKeys.plateauSessions,
      sessions.clamp(minPlateauSessions, maxPlateauSessions).toString());

  Future<void> setSpeakReps(bool on) =>
      _put(SettingKeys.speakReps, on.toString());

  Future<void> setSpeakWeight(bool on) =>
      _put(SettingKeys.speakWeight, on.toString());

  Future<void> setSpeakExerciseName(bool on) =>
      _put(SettingKeys.speakExerciseName, on.toString());

  Future<void> setThemeMode(ThemeMode mode) =>
      _put(SettingKeys.themeMode, mode.name);
}

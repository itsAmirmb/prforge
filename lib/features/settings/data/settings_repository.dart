import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/database/app_database.dart';
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

  Future<void> setSound(bool on) => _put(SettingKeys.sound, on.toString());

  Future<void> setVibration(bool on) =>
      _put(SettingKeys.vibration, on.toString());

  Future<void> setKeepScreenOn(bool on) =>
      _put(SettingKeys.keepScreenOn, on.toString());

  Future<void> setThemeMode(ThemeMode mode) =>
      _put(SettingKeys.themeMode, mode.name);
}

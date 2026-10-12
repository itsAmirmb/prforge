import 'package:flutter/material.dart' show ThemeMode;

import '../../workout/domain/rest_timing.dart';

/// Keys of the settings rows.
abstract final class SettingKeys {
  static const restSeconds = 'restSeconds';
  static const sound = 'sound';
  static const vibration = 'vibration';
  static const keepScreenOn = 'keepScreenOn';
  static const themeMode = 'themeMode';
}

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
  });

  static const defaults = UserSettings();

  /// Rest after a set when the plan gives none. 0 = no rest timer.
  final int restSeconds;
  final bool sound;
  final bool vibration;

  /// Keep the screen on while a workout is open.
  final bool keepScreenOn;
  final ThemeMode themeMode;

  factory UserSettings.fromMap(Map<String, String> map) {
    bool flag(String key, bool fallback) => switch (map[key]) {
          'true' => true,
          'false' => false,
          _ => fallback,
        };
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
    );
  }
}

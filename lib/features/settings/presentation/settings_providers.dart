import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/settings_repository.dart';
import '../domain/user_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final _settingsStreamProvider = StreamProvider<UserSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);

/// Current settings (defaults until the first database read arrives).
final userSettingsProvider = Provider<UserSettings>(
  (ref) => ref.watch(_settingsStreamProvider).value ?? UserSettings.defaults,
);

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../backup/domain/backup_format.dart';
import '../../backup/presentation/backup_providers.dart';
import '../../programs/data/program_importer.dart';
import '../../programs/domain/program_template.dart';
import '../../../app/providers.dart';
import '../../../core/feedback/feedback_service.dart';
import '../domain/user_settings.dart';
import 'settings_providers.dart';
import '../../workout/presentation/rest_timer_bar.dart' show formatRest;
import '../../workout/presentation/workout_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await ref.read(backupRepositoryProvider).exportJson();
      final file =
          File('${Directory.systemTemp.path}/prforge_backup_${_stamp()}.json');
      await file.writeAsString(json, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'PRForge backup',
      ));
    } catch (e) {
      _say('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (await ref.read(sessionRepositoryProvider).findActiveSession() != null) {
      _say('Finish or discard the workout in progress before restoring.');
      return;
    }
    final List<int>? bytes;
    try {
      final picked = await FilePicker.platform.pickFiles(withData: true);
      bytes = picked?.files.single.bytes;
    } catch (e) {
      _say('Could not open the file picker: $e');
      return;
    }
    if (bytes == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
            'All current data (programs, exercises and history) will be '
            'replaced by the contents of this backup.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Restore')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final summary = await ref
          .read(backupRepositoryProvider)
          .restoreJson(utf8.decode(bytes));
      _say('Restored ${summary.programs} programs, ${summary.exercises} '
          'exercises and ${summary.sessions} workouts.');
    } on BackupFormatException catch (e) {
      _say(e.message);
    } catch (e) {
      _say('Restore failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importProgram() async {
    setState(() => _busy = true);
    try {
      // FileType.any: Android does not know a "json" filter and rejects it.
      final picked = await FilePicker.platform.pickFiles(withData: true);
      final bytes = picked?.files.single.bytes;
      if (bytes == null) return; // cancelled

      final result = await ProgramImporter(ref.read(databaseProvider))
          .importJson(utf8.decode(bytes));
      _say('Imported "${result.programName}": ${result.days} days, '
          '${result.prescriptions} exercises '
          '(${result.exercisesCreated} new, ${result.exercisesReused} existing).');
    } on ProgramTemplateException catch (e) {
      _say(e.message);
    } catch (e) {
      _say('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(userSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          const _SectionTitle('Workout'),
          const _RestTile(),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Sound'),
            subtitle: const Text('Beep when the rest is over'),
            value: settings.sound,
            onChanged: ref.read(settingsRepositoryProvider).setSound,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibration'),
            subtitle: const Text('When a set is done and the rest is over'),
            value: settings.vibration,
            onChanged: ref.read(settingsRepositoryProvider).setVibration,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: const Text('Test alert'),
            subtitle: const Text('Plays the rest-over sound and vibration'),
            onTap: () => ref.read(feedbackServiceProvider).restOver(
                sound: settings.sound, vibration: settings.vibration),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screen_lock_portrait_outlined),
            title: const Text('Keep screen on'),
            subtitle: const Text('While a workout is open'),
            value: settings.keepScreenOn,
            onChanged: ref.read(settingsRepositoryProvider).setKeepScreenOn,
          ),
          const _SectionTitle('Appearance'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) =>
                  ref.read(settingsRepositoryProvider).setThemeMode(v.first),
            ),
          ),
          const _SectionTitle('Programs'),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Import program'),
            subtitle: const Text('Add a program from a JSON file (keeps your data)'),
            enabled: !_busy,
            onTap: _importProgram,
          ),
          const _SectionTitle('Backup'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export backup'),
            subtitle: const Text('Save all data as a JSON file'),
            enabled: !_busy,
            onTap: _export,
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replace all data with a backup file'),
            enabled: !_busy,
            onTap: _restore,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text,
          style: theme.textTheme.titleSmall
              ?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

/// Default rest: used when the plan gives none. Steps of 15 s, 0 = off.
class _RestTile extends ConsumerWidget {
  const _RestTile();

  static const _step = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(userSettingsProvider).restSeconds;
    final repo = ref.read(settingsRepositoryProvider);
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Default rest'),
      subtitle: const Text('When the plan does not set a rest'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less rest',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed:
                seconds > 0 ? () => repo.setRestSeconds(seconds - _step) : null,
          ),
          SizedBox(
            width: 48,
            child: Text(
              seconds == 0 ? 'Off' : formatRest(Duration(seconds: seconds)),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'More rest',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: seconds < maxDefaultRestSeconds
                ? () => repo.setRestSeconds(seconds + _step)
                : null,
          ),
        ],
      ),
    );
  }
}

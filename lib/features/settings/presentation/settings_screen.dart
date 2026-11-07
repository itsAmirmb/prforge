import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../backup/domain/backup_format.dart';
import '../../backup/presentation/backup_providers.dart';
import '../../programs/data/program_importer.dart';
import '../../programs/domain/program_template.dart';
import '../../programs/domain/program_template_guide.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/feedback/speech_service.dart';
import '../../workout/domain/rest_announcement.dart';
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

  Future<void> _testVoice() async {
    final speech = ref.read(speechServiceProvider);
    final persian = await speech.persianAvailable;
    if (!persian) {
      _say('No Persian voice on this phone: Persian exercise names will not '
          'be read. Install one in the phone\'s text-to-speech settings.');
    }
    await speech.speakAll(buildAnnouncement(
      exerciseName: 'پرس سینه',
      exerciseChanged: true,
      weightKg: 12.5,
      reps: 10,
      language: ref.read(userSettingsProvider).speechLanguage,
      sayName: true,
      sayWeight: true,
      sayReps: true,
      persianAvailable: persian,
    ));
  }

  Future<void> _copyFormat() async {
    await Clipboard.setData(const ClipboardData(text: programTemplateGuide));
    _say('File format and sample copied.');
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
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          if (_busy) const LinearProgressIndicator(),
          _Section('Workout', [
              _RestTile(
                title: 'Default rest',
                subtitle: 'When the plan does not set a rest',
                seconds: settings.restSeconds,
                onChanged: ref.read(settingsRepositoryProvider).setRestSeconds,
              ),
              _StepperTile(
                icon: Icons.notifications_active_outlined,
                title: 'Countdown before rest ends (0 = off)',
                unit: 'seconds',
                value: settings.restWarnSeconds,
                min: 0,
                max: maxRestWarnSeconds,
                onChanged:
                    ref.read(settingsRepositoryProvider).setRestWarnSeconds,
              ),
              _RestTile(
                title: 'Rest between exercises',
                subtitle: 'After the last set of an exercise. Off = usual rest',
                seconds: settings.restBetweenExercises,
                onChanged:
                    ref.read(settingsRepositoryProvider).setRestBetweenExercises,
              ),
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
          ]),
          _Section('Voice', [
              ListTile(
                leading: const Icon(Icons.translate),
                title: const Text('Voice language'),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SegmentedButton<SpeechLanguage>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: SpeechLanguage.english, label: Text('English')),
                      ButtonSegment(
                          value: SpeechLanguage.persian, label: Text('فارسی')),
                    ],
                    selected: {settings.speechLanguage},
                    onSelectionChanged: (s) => ref
                        .read(settingsRepositoryProvider)
                        .setSpeechLanguage(s.first),
                  ),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.record_voice_over_outlined),
                title: const Text('Say reps'),
                subtitle: const Text('When the rest is over, e.g. "10 reps" / «ده تکرار»'),
                value: settings.speakReps,
                onChanged: ref.read(settingsRepositoryProvider).setSpeakReps,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.fitness_center),
                title: const Text('Say weight'),
                subtitle: const Text('e.g. "12.5 kilos" / «دوازده و نیم کیلوگرم»'),
                value: settings.speakWeight,
                onChanged: ref.read(settingsRepositoryProvider).setSpeakWeight,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.badge_outlined),
                title: const Text('Say exercise name'),
                subtitle: const Text('When the next set is a different exercise'),
                value: settings.speakExerciseName,
                onChanged:
                    ref.read(settingsRepositoryProvider).setSpeakExerciseName,
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Test voice'),
                subtitle:
                    const Text('Checks whether this phone can speak Persian'),
                onTap: _testVoice,
              ),
          ]),
          _Section('Workout timers', [
              SwitchListTile(
                secondary: const Icon(Icons.hourglass_bottom),
                title: const Text('Workout time'),
                subtitle: const Text('Total time since the workout started'),
                value: settings.showWorkoutClock,
                onChanged: ref.read(settingsRepositoryProvider).setShowWorkoutClock,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.timer_outlined),
                title: const Text('Exercise time'),
                subtitle: const Text('Time spent on each exercise'),
                value: settings.showExerciseClock,
                onChanged:
                    ref.read(settingsRepositoryProvider).setShowExerciseClock,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.looks_one_outlined),
                title: const Text('Set time'),
                subtitle: const Text('Time of each set (from the previous set)'),
                value: settings.showSetClock,
                onChanged: ref.read(settingsRepositoryProvider).setShowSetClock,
              ),
          ]),
          _Section('Progress', [
              SwitchListTile(
                secondary: const Icon(Icons.trending_flat),
                title: const Text('Plateau reminder'),
                subtitle: const Text('Note when the weight has not gone up'),
                value: settings.plateauHint,
                onChanged: ref.read(settingsRepositoryProvider).setPlateauHint,
              ),
              if (settings.plateauHint) ...[
                _StepperTile(
                  icon: Icons.date_range_outlined,
                  title: 'Show after',
                  unit: 'weeks',
                  value: settings.plateauWeeks,
                  min: minPlateauWeeks,
                  max: maxPlateauWeeks,
                  onChanged: ref.read(settingsRepositoryProvider).setPlateauWeeks,
                ),
                _StepperTile(
                  icon: Icons.fitness_center,
                  title: 'At least',
                  unit: 'sessions',
                  value: settings.plateauSessions,
                  min: minPlateauSessions,
                  max: maxPlateauSessions,
                  onChanged:
                      ref.read(settingsRepositoryProvider).setPlateauSessions,
                ),
              ],
          ]),
          _Section('Appearance', [
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
          ]),
          _Section('Programs', [
              ListTile(
                leading: const Icon(Icons.playlist_add),
                title: const Text('Import program'),
                subtitle: const Text('Add a program from a JSON file (keeps your data)'),
                enabled: !_busy,
                onTap: _importProgram,
              ),
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('Copy file format'),
                subtitle: const Text(
                    'Copies the JSON structure and a sample, to prepare a program file'),
                onTap: _copyFormat,
              ),
          ]),
          _Section('Backup', [
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
          ]),
        ],
      ),
    );
  }
}

/// A titled group of settings in one card.
class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        Card(child: Column(children: children)),
      ],
    );
  }
}

/// A rest length in steps of 15 s, 0 = off.
class _RestTile extends StatelessWidget {
  const _RestTile({
    required this.title,
    required this.subtitle,
    required this.seconds,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final int seconds;
  final Future<void> Function(int seconds) onChanged;

  static const _step = 15;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less rest',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed:
                seconds > 0 ? () => onChanged(seconds - _step) : null,
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
                ? () => onChanged(seconds + _step)
                : null,
          ),
        ],
      ),
    );
  }
}

/// A whole number with minus / plus buttons.
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.icon,
    required this.title,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String unit;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(unit),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Less $unit',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 32,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: 'More $unit',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

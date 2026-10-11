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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Programs'),
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Import program'),
            subtitle: const Text('Add a program from a JSON file (keeps your data)'),
            enabled: !_busy,
            onTap: _importProgram,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Backup'),
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../workout/presentation/workout_providers.dart';
import '../../workout/presentation/workout_session_screen.dart';
import '../data/prescription_repository.dart';
import '../domain/day_entries.dart';
import 'plan_entry_tiles.dart';
import 'prescription_form_sheet.dart';
import 'prescription_providers.dart';

class WorkoutDayScreen extends ConsumerWidget {
  const WorkoutDayScreen({super.key, required this.day});

  final WorkoutDay day;

  void _openSession(BuildContext context, int sessionId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => WorkoutSessionScreen(sessionId: sessionId),
    ));
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sessionRepositoryProvider);
    final active = await repo.findActiveSession();
    if (!context.mounted) return;
    if (active != null) {
      final resume = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Workout in progress'),
          content: const Text(
              'Finish or discard the current workout before starting a new one.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Resume'),
            ),
          ],
        ),
      );
      if (resume == true && context.mounted) _openSession(context, active.id);
      return;
    }
    final id = await repo.startSession(day.id);
    if (context.mounted) _openSession(context, id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(dayPrescriptionsProvider(day.id));
    final groups = {
      for (final g in ref.watch(daySupersetGroupsProvider(day.id)).value ??
          const <SupersetGroup>[])
        g.id: g,
    };

    return Scaffold(
      appBar: AppBar(title: Text(day.name)),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
                child: Text('No exercises yet. Tap + to add one.'));
          }
          final entries =
              toEntries(list, (i) => i.prescription.supersetGroupId);
          String keyOf(List<PrescriptionWithExercise> e) =>
              e.first.prescription.supersetGroupId != null
                  ? 'g${e.first.prescription.supersetGroupId}'
                  : 'p${e.first.prescription.id}';

          return ReorderableListView.builder(
            itemCount: entries.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final keys = [for (final e in entries) keyOf(e)];
              keys.insert(newIndex, keys.removeAt(oldIndex));
              ref
                  .read(supersetRepositoryProvider)
                  .reorderEntries(day.id, keys);
            },
            itemBuilder: (context, i) {
              final entry = entries[i];
              final groupId = entry.first.prescription.supersetGroupId;
              final group = groupId == null ? null : groups[groupId];
              if (group != null) {
                return SupersetGroupCard(
                  key: ValueKey(keyOf(entry)),
                  dayId: day.id,
                  group: group,
                  members: entry,
                  dragIndex: i,
                );
              }
              final next = i + 1 < entries.length ? entries[i + 1] : null;
              final nextIsSingle = next != null &&
                  next.length == 1 &&
                  next.first.prescription.supersetGroupId == null;
              return SinglePrescriptionTile(
                key: ValueKey(keyOf(entry)),
                dayId: day.id,
                item: entry.first,
                dragIndex: i,
                nextSingle: nextIsSingle ? next.first : null,
              );
            },
          );
        },
      ),
      bottomNavigationBar: (items.value ?? const []).isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start workout'),
                  onPressed: () => _start(context, ref),
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add exercise',
        onPressed: () => showPrescriptionForm(context, dayId: day.id),
        child: const Icon(Icons.add),
      ),
    );
  }
}

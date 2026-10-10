import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../data/prescription_repository.dart';
import '../../workout/presentation/workout_providers.dart';
import '../../workout/presentation/workout_session_screen.dart';
import 'prescription_form_sheet.dart';
import 'prescription_providers.dart';

const _setTypeLabels = {
  SetKind.restPause: 'Rest-Pause',
  SetKind.drop: 'Drop set',
  SetKind.amrap: 'AMRAP',
};

String _summary(ExercisePrescription p) {
  String num(double w) =>
      w == w.roundToDouble() ? w.toInt().toString() : w.toString();
  return [
    p.targetReps != null ? '${p.targetSets} × ${p.targetReps}' : '${p.targetSets} sets',
    if (p.targetWeightKg != null) '${num(p.targetWeightKg!)} kg',
    if (p.restSeconds != null) 'rest ${p.restSeconds}s',
    if (_setTypeLabels[p.setType] != null) _setTypeLabels[p.setType]!,
  ].join(' · ');
}

class WorkoutDayScreen extends ConsumerWidget {
  const WorkoutDayScreen({super.key, required this.day});

  final WorkoutDay day;

  Future<void> _remove(
      BuildContext context, WidgetRef ref, PrescriptionWithExercise item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from plan?'),
        content: Text(
            '"${item.exercise.name}" will be removed from this day. Logged workouts are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(prescriptionRepositoryProvider).remove(item.prescription.id);
    }
  }

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
          return ReorderableListView.builder(
            itemCount: list.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final ids = [for (final i in list) i.prescription.id];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              ref.read(prescriptionRepositoryProvider).reorder(ids);
            },
            itemBuilder: (context, i) {
              final item = list[i];
              return ListTile(
                key: ValueKey(item.prescription.id),
                title: Text(item.exercise.name),
                subtitle: Text(_summary(item.prescription)),
                onTap: () => showPrescriptionForm(context,
                    dayId: day.id, existing: item),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _remove(context, ref, item),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                  ],
                ),
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

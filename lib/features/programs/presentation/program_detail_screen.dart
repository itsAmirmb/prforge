import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/widgets/name_dialog.dart';
import '../data/workout_day_repository.dart';
import 'program_providers.dart';

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final int programId;

  Future<void> _renameProgram(
      BuildContext context, WidgetRef ref, Program program) async {
    final name = await showNameDialog(context,
        title: 'Rename program', initial: program.name);
    if (name != null) {
      await ref.read(programRepositoryProvider).rename(program.id, name);
    }
  }

  Future<void> _addDay(BuildContext context, WidgetRef ref) async {
    final name = await showNameDialog(context,
        title: 'New day', label: 'Day name (e.g. Push)');
    if (name != null) {
      await ref.read(workoutDayRepositoryProvider).add(programId, name);
    }
  }

  Future<void> _renameDay(
      BuildContext context, WidgetRef ref, WorkoutDay day) async {
    final name = await showNameDialog(context,
        title: 'Rename day', initial: day.name, label: 'Day name');
    if (name != null) {
      await ref.read(workoutDayRepositoryProvider).rename(day.id, name);
    }
  }

  Future<void> _deleteDay(
      BuildContext context, WidgetRef ref, WorkoutDay day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete day?'),
        content: Text(
            '"${day.name}" and its planned exercises will be deleted. Logged workouts are not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(workoutDayRepositoryProvider).delete(day.id);
    } on DayHasHistoryException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider(programId)).value;
    final days = ref.watch(workoutDaysProvider(programId));

    return Scaffold(
      appBar: AppBar(
        title: Text(program?.name ?? ''),
        actions: [
          if (program != null)
            IconButton(
              tooltip: 'Rename program',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _renameProgram(context, ref, program),
            ),
        ],
      ),
      body: days.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
                child: Text('No days yet. Tap + to add one (e.g. Push, Pull, Legs).'));
          }
          return ReorderableListView.builder(
            itemCount: list.length,
            onReorder: (oldIndex, newIndex) {
              if (oldIndex < newIndex) newIndex -= 1;
              final ids = [for (final d in list) d.id];
              ids.insert(newIndex, ids.removeAt(oldIndex));
              ref.read(workoutDayRepositoryProvider).reorder(ids);
            },
            itemBuilder: (context, i) {
              final day = list[i];
              return ListTile(
                key: ValueKey(day.id),
                title: Text(day.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'rename'
                          ? _renameDay(context, ref, day)
                          : _deleteDay(context, ref, day),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add day',
        onPressed: () => _addDay(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

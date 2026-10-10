import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'exercise_form_sheet.dart';
import 'exercise_providers.dart';

class ExerciseListScreen extends ConsumerStatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  ConsumerState<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends ConsumerState<ExerciseListScreen> {
  bool _showArchived = false;

  Future<void> _setArchived(Exercise e, bool archived) async {
    final repo = ref.read(exerciseRepositoryProvider);
    await repo.setArchived(e.id, archived);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(archived ? '"${e.name}" archived' : '"${e.name}" restored'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.setArchived(e.id, !archived),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = ref.watch(exerciseListProvider(_showArchived));

    return Scaffold(
      appBar: AppBar(
        title: Text(_showArchived ? 'Archived exercises' : 'Exercises'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Show active' : 'Show archived',
            icon: Icon(_showArchived
                ? Icons.fitness_center
                : Icons.inventory_2_outlined),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: exercises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(_showArchived
                  ? 'No archived exercises'
                  : 'No exercises yet. Tap + to add one.'),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              final subtitle = [
                if (e.category != null) e.category!,
                if (e.equipment != null) e.equipment!,
                if (e.isBodyweight) 'Bodyweight',
              ].join(' · ');
              return ListTile(
                title: Text(e.name),
                subtitle: subtitle.isEmpty ? null : Text(subtitle),
                onTap: () => showExerciseForm(context, exercise: e),
                trailing: IconButton(
                  tooltip: _showArchived ? 'Restore' : 'Archive',
                  icon: Icon(_showArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined),
                  onPressed: () => _setArchived(e, !_showArchived),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _showArchived
          ? null
          : FloatingActionButton(
              tooltip: 'Add exercise',
              onPressed: () => showExerciseForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

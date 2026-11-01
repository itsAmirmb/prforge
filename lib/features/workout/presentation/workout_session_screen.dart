import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../domain/session_blocks.dart';
import 'exercise_block_card.dart';
import 'exercise_picker_sheet.dart';
import 'keep_screen_on.dart';
import 'rest_timer_bar.dart';
import 'rest_timer_state.dart';
import 'superset_card.dart';
import 'workout_clock_chip.dart';
import 'workout_providers.dart';

class WorkoutSessionScreen extends ConsumerWidget {
  const WorkoutSessionScreen({super.key, required this.sessionId});

  final int sessionId;

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    List<SessionEntry> entries,
  ) async {
    final sets = [
      for (final e in entries)
        for (final b in e.blocks) ...b.sets,
    ];
    final done = sets.where((s) => s.isCompleted).length;
    final pending = sets.length - done;
    if (done == 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text('Complete at least one set, or discard the workout.'),
          ),
        );
      return;
    }
    final ok = await _confirm(
      context,
      title: 'Finish workout?',
      message: pending > 0
          ? '$pending unfinished set${pending == 1 ? '' : 's'} will be discarded.'
          : 'All sets are done.',
      action: 'Finish',
    );
    if (!ok) return;
    await ref.read(sessionRepositoryProvider).finishSession(sessionId);
    ref.read(restTimerProvider.notifier).stop();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await showExercisePicker(context);
    if (exercise == null) return;
    await ref
        .read(sessionRepositoryProvider)
        .addExercise(sessionId, exercise.id);
  }

  Future<void> _discard(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Discard workout?',
      message: 'All sets logged in this workout will be deleted.',
      action: 'Discard',
    );
    if (!ok) return;
    await ref.read(sessionRepositoryProvider).discardSession(sessionId);
    ref.read(restTimerProvider.notifier).stop();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(sessionEntriesProvider(sessionId));
    final entries = entriesAsync.value ?? const <SessionEntry>[];
    final sets = [
      for (final e in entries)
        for (final b in e.blocks) ...b.sets,
    ];
    final done = sets.where((s) => s.isCompleted).length;

    return KeepScreenOn(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Workout · $done/${sets.length} sets'),
              WorkoutClockChip(sessionId: sessionId),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: sets.isEmpty ? 0 : done / sets.length,
              minHeight: 4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: entriesAsync.hasValue
                  ? () => _finish(context, ref, entries)
                  : null,
              child: const Text('Finish'),
            ),
            PopupMenuButton<String>(
              onSelected: (_) => _discard(context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'discard', child: Text('Discard workout')),
              ],
            ),
          ],
        ),
        bottomNavigationBar: const RestTimerBar(),
        body: entriesAsync.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(e),
          data: (list) => ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            buildDefaultDragHandles: false,
            itemCount: list.length,
            onReorderItem: (oldIndex, newIndex) {
              final tokens = [for (final e in list) e.token];
              tokens.insert(newIndex, tokens.removeAt(oldIndex));
              ref
                  .read(sessionRepositoryProvider)
                  .reorderEntries(sessionId, tokens);
            },
            itemBuilder: (context, i) => switch (list[i]) {
              SingleEntry(:final block) => ExerciseBlockCard(
                key: ValueKey(list[i].token),
                sessionId: sessionId,
                block: block,
                dragIndex: i,
              ),
              SupersetEntry e => SupersetCard(
                key: ValueKey(list[i].token),
                sessionId: sessionId,
                entry: e,
                dragIndex: i,
              ),
            },
            footer: Column(
              children: [
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('This workout has no sets.'),
                  ),
                if (sets.isNotEmpty && done == sets.length)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.flag),
                      label: const Text('All sets done · Finish workout'),
                      onPressed: () => _finish(context, ref, list),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add exercise'),
                      onPressed: () => _addExercise(context, ref),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

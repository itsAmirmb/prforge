import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session_blocks.dart';
import 'exercise_block_card.dart';
import 'workout_providers.dart';

class WorkoutSessionScreen extends ConsumerWidget {
  const WorkoutSessionScreen({super.key, required this.sessionId});

  final int sessionId;

  Future<bool> _confirm(BuildContext context,
      {required String title, required String message, required String action}) async {
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
      BuildContext context, WidgetRef ref, List<ExerciseBlock> blocks) async {
    final sets = [for (final b in blocks) ...b.sets];
    final done = sets.where((s) => s.isCompleted).length;
    final pending = sets.length - done;
    if (done == 0) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
            content: Text('Complete at least one set, or discard the workout.')));
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
    if (context.mounted) Navigator.of(context).pop();
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
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocksAsync = ref.watch(sessionBlocksProvider(sessionId));
    final blocks = blocksAsync.value ?? const <ExerciseBlock>[];
    final sets = [for (final b in blocks) ...b.sets];
    final done = sets.where((s) => s.isCompleted).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Workout · $done/${sets.length} sets'),
        actions: [
          TextButton(
            onPressed: blocksAsync.hasValue
                ? () => _finish(context, ref, blocks)
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
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? const Center(child: Text('This workout has no sets.'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: list.length,
                itemBuilder: (_, i) => ExerciseBlockCard(
                  key: ValueKey(list[i].prescriptionId ?? -list[i].exercise.id),
                  sessionId: sessionId,
                  block: list[i],
                ),
              ),
      ),
    );
  }
}

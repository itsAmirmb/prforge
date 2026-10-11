import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/session_blocks.dart';
import 'progressive_loading_sheet.dart';
import 'set_actions.dart';
import 'set_row.dart';
import 'workout_providers.dart';

const _kindLabels = {
  SetKind.restPause: 'Rest-Pause',
  SetKind.drop: 'Drop set',
  SetKind.amrap: 'AMRAP',
  SetKind.warmup: 'Warm-up',
};

class ExerciseBlockCard extends ConsumerWidget {
  const ExerciseBlockCard({
    super.key,
    required this.sessionId,
    required this.block,
  });

  final int sessionId;
  final ExerciseBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastPerformanceProvider(block.exercise.id)).value;
    final kind = block.sets.isEmpty ? null : _kindLabels[block.sets.first.setKind];
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind == null
                  ? block.exercise.name
                  : '${block.exercise.name} · $kind',
              style: theme.textTheme.titleMedium,
            ),
            if (last != null && last.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 6),
                child: Text(
                  'Last: ${lastPerformanceText(last)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (var i = 0; i < block.sets.length; i++)
              SetRow(
                key: ValueKey(block.sets[i].id),
                log: block.sets[i],
                number: i + 1,
                onDelete: () => deleteSetWithUndo(context, ref, block.sets[i]),
              ),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add set'),
                  onPressed: () => ref.read(sessionRepositoryProvider).addSet(
                      sessionId, block.exercise.id, block.prescriptionId),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Increase weight'),
                  onPressed: () async {
                    if (block.sets.every((s) => s.isCompleted)) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(const SnackBar(
                            content: Text('All sets of this exercise are done.')));
                      return;
                    }
                    await showProgressiveLoadingSheet(
                      context,
                      sessionId: sessionId,
                      block: block,
                      last: last ?? const [],
                    );
                    // Make sure no set field keeps stale focus, so the new
                    // values are always shown.
                    FocusManager.instance.primaryFocus?.unfocus();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

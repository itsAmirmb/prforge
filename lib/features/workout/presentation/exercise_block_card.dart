import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../domain/session_blocks.dart';
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

  Future<void> _delete(BuildContext context, WidgetRef ref, SetLog log) async {
    final repo = ref.read(sessionRepositoryProvider);
    final deleted = await repo.deleteSet(log.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('Set deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.restoreSet(deleted),
        ),
      ));
  }

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
                  'Last: ${last.map((s) => '${formatWeight(s.weightKg) ?? 'BW'}×${s.reps ?? '-'}').join('  ·  ')}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (var i = 0; i < block.sets.length; i++)
              SetRow(
                key: ValueKey(block.sets[i].id),
                log: block.sets[i],
                number: i + 1,
                onDelete: () => _delete(context, ref, block.sets[i]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add set'),
                onPressed: () => ref.read(sessionRepositoryProvider).addSet(
                    sessionId, block.exercise.id, block.prescriptionId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

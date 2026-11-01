import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/domain/plateau.dart';
import '../domain/session_blocks.dart';
import 'entry_clock_chip.dart';
import 'exercise_notes.dart';
import 'last_sessions_hint.dart';
import 'progressive_loading_sheet.dart';
import 'set_actions.dart';
import 'set_with_minis.dart';
import 'workout_providers.dart';

/// A superset in a session: one card, sets grouped by round, every member's
/// set of the round listed in the planned order.
class SupersetCard extends ConsumerWidget {
  const SupersetCard({
    super.key,
    required this.sessionId,
    required this.entry,
    this.dragIndex,
  });

  final int sessionId;
  final SupersetEntry entry;

  /// Position in the reorderable workout list (shows the drag handle).
  final int? dragIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rounds = entry.rounds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Superset · ${entry.members.map((m) => m.exercise.name).join(' + ')}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: EntryClockChip(sessionId: sessionId, entry: entry),
                ),
                if (dragIndex != null)
                  ReorderableDragStartListener(
                    index: dragIndex!,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            for (final m in entry.members) ...[
              LastSessionsHint(
                exercise: m.exercise,
                showName: true,
                currentWeight: heaviestWeight(m.sets),
              ),
              ExerciseNotes(
                exercise: m.exercise,
                prescriptionId: m.prescriptionId,
                showName: true,
              ),
            ],
            for (var r = 0; r < rounds.length; r++) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text(
                  'Round ${r + 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final m in entry.members)
                if (entry.setInRound(m, rounds[r]) case final set?)
                  SetWithMinis(
                    key: ValueKey(set.id),
                    log: set,
                    label: m.exercise.name,
                    onDelete: () => deleteSetWithUndo(context, ref, set),
                  ),
            ],
            Wrap(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add round'),
                  onPressed: () => ref
                      .read(sessionRepositoryProvider)
                      .addRound(sessionId, entry.members),
                ),
                for (final m in entry.members)
                  TextButton.icon(
                    icon: const Icon(Icons.trending_up),
                    label: Text('Increase weight · ${m.exercise.name}'),
                    onPressed: () async {
                      if (m.sets.every((s) => s.isCompleted)) {
                        ScaffoldMessenger.of(context)
                          ..clearSnackBars()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'All sets of this exercise are done.',
                              ),
                            ),
                          );
                        return;
                      }
                      await showProgressiveLoadingSheet(
                        context,
                        sessionId: sessionId,
                        block: m,
                        last:
                            ref
                                .read(lastPerformanceProvider(m.exercise.id))
                                .value ??
                            const [],
                      );
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

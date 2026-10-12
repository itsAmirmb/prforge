import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/session_blocks.dart';
import 'exercise_notes.dart';
import 'last_sessions_hint.dart';
import 'progressive_loading_sheet.dart';
import 'set_actions.dart';
import 'set_with_minis.dart';
import 'workout_providers.dart';

/// A superset in a session: one card, sets grouped by round, every member's
/// set of the round listed in the planned order.
class SupersetCard extends ConsumerWidget {
  const SupersetCard({super.key, required this.sessionId, required this.entry});

  final int sessionId;
  final SupersetEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rounds = entry.rounds;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Superset · ${entry.members.map((m) => m.exercise.name).join(' + ')}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            for (final m in entry.members) ...[
              LastSessionsHint(exercise: m.exercise, showName: true),
              ExerciseNotes(
                  exercise: m.exercise,
                  prescriptionId: m.prescriptionId,
                  showName: true),
            ],
            for (var r = 0; r < rounds.length; r++) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: Text('Round ${r + 1}', style: theme.textTheme.labelLarge),
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
                          ..showSnackBar(const SnackBar(
                              content:
                                  Text('All sets of this exercise are done.')));
                        return;
                      }
                      await showProgressiveLoadingSheet(
                        context,
                        sessionId: sessionId,
                        block: m,
                        last: ref
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

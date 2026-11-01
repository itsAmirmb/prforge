import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/format.dart';
import '../../progress/domain/progress.dart';
import '../../progress/presentation/exercise_progress_screen.dart';
import '../../progress/presentation/progress_providers.dart';

/// How many past sessions the quick sheet lists.
const historySheetSessions = 8;

Future<void> showExerciseHistorySheet(BuildContext context, Exercise exercise) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ExerciseHistorySheet(exercise: exercise),
  );
}

/// Quick look at what was lifted in the previous sessions of an exercise,
/// newest first, without leaving the workout.
class ExerciseHistorySheet extends ConsumerWidget {
  const ExerciseHistorySheet({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(exerciseProgressProvider(exercise.id));

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: async.when(
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(24), child: Text('Error: $e')),
          data: (progress) {
            final recent =
                progress.points.reversed.take(historySheetSessions).toList();
            final max = progress.maxWeight;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(exercise.name, style: theme.textTheme.titleLarge),
                ),
                if (recent.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No finished sets for this exercise yet.'),
                  )
                else ...[
                  if (max != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Max weight: ${formatWeight(max)} kg',
                          style: theme.textTheme.bodyMedium),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p in recent) _SessionTile(point: p),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.show_chart),
                        label: const Text('Full progress'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) =>
                                ExerciseProgressScreen(exercise: exercise),
                          ));
                        },
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.point});

  final SessionPoint point;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(patternText(point.segments)),
      subtitle: Text('${formatDate(point.date)} · ${point.sets} sets · '
          '${point.totalReps} reps'),
    );
  }
}

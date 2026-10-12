import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../progress/domain/progress.dart';
import '../../progress/presentation/progress_providers.dart';
import 'exercise_history_sheet.dart';

/// "Last: 60 kg × 8, 6 · 55 kg × 10" for the most recent finished session of
/// the exercise (weights per set, rest-pause parts included). Tap for the
/// previous sessions.
class LastSessionsHint extends ConsumerWidget {
  const LastSessionsHint(
      {super.key, required this.exercise, this.showName = false});

  final Exercise exercise;

  /// Prefix with the exercise name (inside a superset).
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(exerciseProgressProvider(exercise.id)).value;
    if (progress == null || progress.isEmpty) return const SizedBox.shrink();

    final text = '${showName ? '${exercise.name} last' : 'Last'}: '
        '${patternText(progress.points.last.segments)}';
    return InkWell(
      onTap: () => showExerciseHistorySheet(context, exercise),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.history, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}

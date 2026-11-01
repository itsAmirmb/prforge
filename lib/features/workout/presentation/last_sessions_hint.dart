import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import '../../progress/domain/plateau.dart';
import '../../progress/domain/progress.dart';
import '../../progress/presentation/progress_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import 'exercise_history_sheet.dart';

/// "Last: 60 kg × 8, 6 · 55 kg × 10" for the most recent finished session of
/// the exercise (weights per set, rest-pause parts included). Tap for the
/// previous sessions.
class LastSessionsHint extends ConsumerWidget {
  const LastSessionsHint({
    super.key,
    required this.exercise,
    this.showName = false,
    this.currentWeight,
  });

  final Exercise exercise;

  /// Prefix with the exercise name (inside a superset).
  final bool showName;

  /// Heaviest weight planned in the workout in progress. When it is above the
  /// last top weight the plateau note is not shown.
  final double? currentWeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(exerciseProgressProvider(exercise.id)).value;
    if (progress == null || progress.isEmpty) return const SizedBox.shrink();

    final text =
        '${showName ? '${exercise.name} last' : 'Last'}: '
        '${patternText(progress.points.last.segments)}';
    final settings = ref.watch(userSettingsProvider);
    final plateau = settings.plateauHint
        ? detectPlateau(
            progress.points,
            now: DateTime.now(),
            currentWeight: currentWeight,
            minWeeks: settings.plateauWeeks,
            minSessions: settings.plateauSessions,
          )
        : null;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => showExerciseHistorySheet(context, exercise),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
              ],
            ),
            if (plateau != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_flat,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Same weight (${formatWeight(plateau.weight)} kg) for '
                        '${plateau.weeks} weeks · ${plateau.sessions} sessions',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

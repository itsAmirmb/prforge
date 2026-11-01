import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../app/theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/state_views.dart';
import '../data/history_repository.dart';
import 'history_providers.dart';
import 'session_detail_screen.dart';

String summaryTitle(SessionSummary s) => s.dayName ?? 'Workout';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(completedSessionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: async.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(e),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.history, message: 'No finished workouts yet.');
          }
          return ListView.builder(
            padding: const EdgeInsets.only(
                top: AppSpacing.sm, bottom: AppSpacing.xl),
            itemCount: list.length,
            itemBuilder: (context, i) => _SessionTile(summary: list[i]),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final stats = summary.stats;
    final duration = summary.duration;
    final title = summary.programName == null
        ? summaryTitle(summary)
        : '${summaryTitle(summary)} · ${summary.programName}';
    final volume = formatWeight(stats.volumeKg.roundToDouble());
    final theme = Theme.of(context);
    final when = '${formatDateTime(summary.session.startedAt)}'
        '${duration == null ? '' : ' · ${formatDuration(duration)}'}';
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(summary: summary),
        )),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium),
                  ),
                  Icon(Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 2),
              Text(when,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  StatPill(
                      icon: Icons.fitness_center,
                      text: '${stats.exerciseCount} exercises'),
                  StatPill(
                      icon: Icons.layers_outlined,
                      text: '${stats.setCount} sets'),
                  StatPill(
                      icon: Icons.repeat, text: '${stats.totalReps} reps'),
                  StatPill(
                      icon: Icons.scale_outlined, text: '$volume kg'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

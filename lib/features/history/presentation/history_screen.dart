import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../core/utils/format.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No finished workouts yet.'));
          }
          return ListView.builder(
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
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          '${formatDateTime(summary.session.startedAt)}'
          '${duration == null ? '' : ' · ${formatDuration(duration)}'}\n'
          '${stats.exerciseCount} exercises · ${stats.setCount} sets · '
          '${stats.totalReps} reps · $volume kg',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SessionDetailScreen(summary: summary),
        )),
      ),
    );
  }
}

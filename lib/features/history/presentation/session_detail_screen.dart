import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../workout/domain/rest_pause.dart';
import '../../workout/domain/session_blocks.dart';
import '../../workout/presentation/workout_providers.dart';
import '../data/history_repository.dart';
import '../domain/entry_timing.dart';
import '../domain/set_text.dart';
import 'history_providers.dart';
import 'history_screen.dart';

const _kindLabels = {
  SetKind.restPause: 'Rest-Pause',
  SetKind.drop: 'Drop set',
  SetKind.amrap: 'AMRAP',
  SetKind.warmup: 'Warm-up',
};

/// Read-only view of a finished session, built only from what was logged
/// (so it stays correct after the plan changes).
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({super.key, required this.summary});

  final SessionSummary summary;

  int get _sessionId => summary.session.id;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text(
            'This permanently removes the workout and all its sets.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(historyRepositoryProvider).deleteCompleted(_sessionId);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(sessionEntriesProvider(_sessionId));
    final minis = ref.watch(miniSetsBySetProvider(_sessionId)).value ??
        const <int, List<MiniSetLog>>{};
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(summaryTitle(summary)),
        actions: [
          IconButton(
            tooltip: 'Delete workout',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          final allSets = [
            for (final e in list)
              for (final b in e.blocks) ...b.sets,
          ];
          return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                formatDateTime(summary.session.startedAt),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            for (final e in list)
              switch (e) {
                SingleEntry() => _BlockCard(
                    block: e.block,
                    minis: minis,
                    timing: entryTiming(e, allSets, summary.session.startedAt)),
                SupersetEntry() => _SupersetCard(
                    entry: e,
                    minis: minis,
                    timing: entryTiming(e, allSets, summary.session.startedAt)),
              },
          ],
          );
        },
      ),
    );
  }
}

/// Timing line: "09:12 – 09:21 · 9m".
class _TimingLine extends StatelessWidget {
  const _TimingLine(this.timing);

  final EntryTiming? timing;

  @override
  Widget build(BuildContext context) {
    final t = timing;
    if (t == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '${formatTime(t.start)} – ${formatTime(t.end)} · ${formatDuration(t.duration)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Lines for one set: the set itself, then its mini-sets and total reps.
List<Widget> _setLines(
  BuildContext context,
  SetLog set,
  Map<int, List<MiniSetLog>> minis, {
  required String prefix,
}) {
  final theme = Theme.of(context);
  final parts = minis[set.id] ?? const <MiniSetLog>[];
  return [
    Text('$prefix${setText(set)}', style: theme.textTheme.bodyLarge),
    if (set.setKind == SetKind.restPause && parts.isNotEmpty) ...[
      for (final m in parts)
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(miniSetText(m), style: theme.textTheme.bodyMedium),
        ),
      Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Text('= ${restPauseTotalReps(set, parts)} reps',
            style: theme.textTheme.bodySmall),
      ),
    ],
  ];
}

class _BlockCard extends StatelessWidget {
  const _BlockCard(
      {required this.block, required this.minis, required this.timing});

  final ExerciseBlock block;
  final Map<int, List<MiniSetLog>> minis;
  final EntryTiming? timing;

  @override
  Widget build(BuildContext context) {
    final kind = block.sets.isEmpty ? null : _kindLabels[block.sets.first.setKind];
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kind == null ? block.exercise.name : '${block.exercise.name} · $kind',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            _TimingLine(timing),
            const SizedBox(height: 6),
            for (var i = 0; i < block.sets.length; i++)
              ..._setLines(context, block.sets[i], minis,
                  prefix: '${i + 1}.  '),
          ],
        ),
      ),
    );
  }
}

class _SupersetCard extends StatelessWidget {
  const _SupersetCard(
      {required this.entry, required this.minis, required this.timing});

  final SupersetEntry entry;
  final Map<int, List<MiniSetLog>> minis;
  final EntryTiming? timing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Superset · ${entry.members.map((m) => m.exercise.name).join(' + ')}',
              style: theme.textTheme.titleMedium,
            ),
            _TimingLine(timing),
            for (var r = 0; r < entry.rounds.length; r++) ...[
              const SizedBox(height: 8),
              Text('Round ${r + 1}', style: theme.textTheme.labelLarge),
              for (final member in entry.members)
                if (entry.setInRound(member, entry.rounds[r]) case final set?)
                  ..._setLines(context, set, minis,
                      prefix: '${member.exercise.name}: '),
            ],
          ],
        ),
      ),
    );
  }
}

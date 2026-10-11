import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/format.dart';
import '../domain/progress.dart';
import 'line_chart.dart';
import 'progress_providers.dart';

enum _Metric { maxWeight, volume, totalReps }

String _kg(double v) => '${formatWeight(v)} kg';

class ExerciseProgressScreen extends ConsumerStatefulWidget {
  const ExerciseProgressScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  ConsumerState<ExerciseProgressScreen> createState() =>
      _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState
    extends ConsumerState<ExerciseProgressScreen> {
  _Metric _metric = _Metric.maxWeight;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exerciseProgressProvider(widget.exercise.id));
    return Scaffold(
      appBar: AppBar(title: Text(widget.exercise.name)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (progress) {
          if (progress.isEmpty) {
            return const Center(
                child: Text('No finished sets for this exercise yet.'));
          }
          return _Content(
            progress: progress,
            metric: _metric,
            onMetric: (m) => setState(() => _metric = m),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content(
      {required this.progress, required this.metric, required this.onMetric});

  final ExerciseProgress progress;
  final _Metric metric;
  final ValueChanged<_Metric> onMetric;

  double? _value(SessionPoint p) => switch (metric) {
        _Metric.maxWeight => p.maxWeight,
        _Metric.volume => p.volumeKg,
        _Metric.totalReps => p.totalReps.toDouble(),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = progress.points;
    final maxWeight = progress.maxWeight;
    final recent = points.reversed.toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            _Stat(
                label: 'Max weight',
                value: maxWeight == null ? '—' : _kg(maxWeight)),
            _Stat(label: 'Sessions', value: '${points.length}'),
            _Stat(
                label: 'Total volume',
                value: _kg(progress.totalVolumeKg.roundToDouble())),
          ],
        ),
        const SizedBox(height: 16),
        SegmentedButton<_Metric>(
          segments: const [
            ButtonSegment(value: _Metric.maxWeight, label: Text('Max weight')),
            ButtonSegment(value: _Metric.volume, label: Text('Volume')),
            ButtonSegment(value: _Metric.totalReps, label: Text('Reps')),
          ],
          selected: {metric},
          onSelectionChanged: (s) => onMetric(s.first),
        ),
        const SizedBox(height: 12),
        LineChart(values: [for (final p in points) _value(p)]),
        Padding(
          padding: const EdgeInsets.only(left: 44, top: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDateTime(points.first.date).split(' · ').first,
                  style: theme.textTheme.labelSmall),
              if (points.length > 1)
                Text(formatDateTime(points.last.date).split(' · ').first,
                    style: theme.textTheme.labelSmall),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Best reps at each weight', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(1),
          },
          children: [
            TableRow(children: [
              Text('Weight', style: theme.textTheme.labelMedium),
              Text('Best reps', style: theme.textTheme.labelMedium),
              Text('Sets', style: theme.textTheme.labelMedium),
            ]),
            for (final r in progress.records)
              TableRow(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                      r.weight == null ? 'Bodyweight' : _kg(r.weight!)),
                ),
                Text('${r.bestReps}'),
                Text('${r.sets}'),
              ]),
          ],
        ),
        const SizedBox(height: 24),
        Text('Sessions', style: theme.textTheme.titleMedium),
        for (var i = 0; i < recent.length; i++)
          _SessionRow(
            point: recent[i],
            previous: i + 1 < recent.length ? recent[i + 1] : null,
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.point, required this.previous});

  final SessionPoint point;
  final SessionPoint? previous;

  String? _delta() {
    final now = point.maxWeight;
    final before = previous?.maxWeight;
    if (now == null || before == null || now == before) return null;
    final d = now - before;
    return '${d > 0 ? '+' : '−'}${formatWeight(d.abs())} kg';
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(patternText(point.segments)),
      subtitle: Text(
          '${formatDateTime(point.date).split(' · ').first} · '
          '${point.sets} sets · ${point.totalReps} reps'),
      trailing: delta == null ? null : Text(delta),
    );
  }
}

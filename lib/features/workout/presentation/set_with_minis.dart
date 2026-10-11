import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../domain/rest_pause.dart';
import 'mini_set_row.dart';
import 'set_row.dart';
import 'workout_providers.dart';

/// A set row; rest-pause sets also show their mini-sets underneath.
class SetWithMinis extends ConsumerWidget {
  const SetWithMinis({
    super.key,
    required this.log,
    this.number,
    this.label,
    required this.onDelete,
  });

  final SetLog log;
  final int? number;
  final String? label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final row = SetRow(
      key: ValueKey('set${log.id}'),
      log: log,
      number: number,
      label: label,
      onDelete: onDelete,
    );
    if (log.setKind != SetKind.restPause) return row;

    final minis =
        ref.watch(miniSetsBySetProvider(log.sessionId)).value?[log.id] ??
            const <MiniSetLog>[];
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < minis.length; i++)
                MiniSetRow(
                    key: ValueKey('mini${minis[i].id}'),
                    mini: minis[i],
                    number: i + 1),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add mini set'),
                    onPressed: () =>
                        ref.read(miniSetRepositoryProvider).add(log.id),
                  ),
                  if (minis.isNotEmpty)
                    Text('Total: ${restPauseTotalReps(log, minis)} reps',
                        style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

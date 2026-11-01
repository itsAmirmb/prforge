import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'synced_number_field.dart';
import 'workout_providers.dart';

/// One mini-set of a rest-pause main set: kg, reps and the rest taken before
/// it. Every edit is saved at once.
class MiniSetRow extends ConsumerWidget {
  const MiniSetRow({super.key, required this.mini, required this.number});

  final MiniSetLog mini;
  final int number;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(miniSetRepositoryProvider);
    final deleted = await repo.delete(mini.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: const Text('Mini-set deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repo.restore(deleted),
        ),
      ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(miniSetRepositoryProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('+$number', style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: SyncedNumberField(
              label: 'kg',
              decimal: true,
              value: mini.weightKg,
              onChanged: (v) => repo.setWeight(mini.id, v),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SyncedNumberField(
              label: 'reps',
              value: mini.reps.toDouble(),
              // Reps cannot be empty in the database; an empty field simply
              // keeps the stored value and is restored on blur.
              onChanged: (v) {
                if (v != null) repo.setReps(mini.id, v.toInt());
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SyncedNumberField(
              label: 'rest s',
              value: mini.restSeconds?.toDouble(),
              onChanged: (v) => repo.setRest(mini.id, v?.toInt()),
            ),
          ),
          IconButton(
            tooltip: 'Delete mini-set',
            icon: const Icon(Icons.close),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

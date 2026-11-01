import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';

/// The plan's note for a prescription (e.g. "2 × (2×10, 10s rest)").
final planNoteProvider = FutureProvider.autoDispose.family<String?, int>(
  (ref, prescriptionId) async {
    final db = ref.watch(databaseProvider);
    final row = await (db.select(db.exercisePrescriptions)
          ..where((p) => p.id.equals(prescriptionId)))
        .getSingleOrNull();
    return row?.notes;
  },
);

/// Notes to read while training: the plan's note for this exercise and the
/// exercise's own note. Both are edited in their usual screens.
class ExerciseNotes extends ConsumerWidget {
  const ExerciseNotes({
    super.key,
    required this.exercise,
    required this.prescriptionId,
    this.showName = false,
  });

  final Exercise exercise;
  final int? prescriptionId;
  final bool showName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = prescriptionId == null
        ? null
        : ref.watch(planNoteProvider(prescriptionId!)).value;
    final notes = [
      for (final n in [plan, exercise.notes])
        if (n != null && n.trim().isNotEmpty) n.trim(),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();

    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in notes)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.notes, size: 16),
                ),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(showName ? '${exercise.name}: $n' : n,
                        style: style)),
              ],
            ),
        ],
      ),
    );
  }
}

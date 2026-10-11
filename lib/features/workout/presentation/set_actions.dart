import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';
import 'workout_providers.dart';

/// Deletes a set and offers Undo in a snackbar.
Future<void> deleteSetWithUndo(
    BuildContext context, WidgetRef ref, SetLog log) async {
  final repo = ref.read(sessionRepositoryProvider);
  final deleted = await repo.deleteSet(log.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: const Text('Set deleted'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => repo.restoreSet(deleted),
      ),
    ));
}

/// "7.5×10  ·  5×10  ·  5×9" (BW = no weight).
String lastPerformanceText(List<SetLog> sets) => sets
    .map((s) => '${formatWeight(s.weightKg) ?? 'BW'}×${s.reps ?? '-'}')
    .join('  ·  ');

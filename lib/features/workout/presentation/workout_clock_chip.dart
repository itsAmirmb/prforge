import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../settings/presentation/settings_providers.dart';
import 'workout_providers.dart';

/// Total time since the workout started (see Settings > Workout timers).
/// Derived from the session's start time, so it survives restarts.
class WorkoutClockChip extends ConsumerStatefulWidget {
  const WorkoutClockChip({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<WorkoutClockChip> createState() => _WorkoutClockChipState();
}

class _WorkoutClockChipState extends ConsumerState<WorkoutClockChip> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(userSettingsProvider.select((s) => s.showWorkoutClock));
    final session = ref.watch(activeSessionProvider).value;
    if (!enabled || session == null || session.id != widget.sessionId) {
      return const SizedBox.shrink();
    }
    final text = formatStopwatch(DateTime.now().difference(session.startedAt));
    return Semantics(
      label: 'Workout time $text',
      child: ExcludeSemantics(
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

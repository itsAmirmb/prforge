import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../programs/data/prescription_repository.dart';
import '../../programs/presentation/prescription_providers.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/duration_estimate.dart';
import '../domain/set_order.dart';
import 'rest_timer_state.dart';
import 'workout_providers.dart';

/// "Estimated time ~55 min" for a workout day, before it is started.
class DayEstimateLabel extends ConsumerWidget {
  const DayEstimateLabel({super.key, required this.dayId});

  final int dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(userSettingsProvider);
    final items = ref.watch(dayPrescriptionsProvider(dayId)).value;
    if (!settings.showEstimate || items == null || items.isEmpty) {
      return const SizedBox.shrink();
    }
    final groups = {
      for (final g in ref.watch(daySupersetGroupsProvider(dayId)).value ??
          const <SupersetGroup>[])
        g.id: g,
    };
    final sets =
        estimateSetsForPlan([for (final i in items) i.prescription], groups);
    final estimate = estimateDuration(sets,
        defaultRest: settings.restSeconds,
        exerciseChangeRest: settings.restBetweenExercises);
    return Text(
      'Estimated time ${formatEstimate(estimate, roundToMinutes: 5)}',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

/// "~25 min left" in a running workout: the sets still to do plus the rest
/// that is running now. It follows the workout, so skipped or added
/// exercises are taken into account.
class RemainingEstimateChip extends ConsumerStatefulWidget {
  const RemainingEstimateChip({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<RemainingEstimateChip> createState() =>
      _RemainingEstimateChipState();
}

class _RemainingEstimateChipState extends ConsumerState<RemainingEstimateChip> {
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    // The running rest counts down, so refresh now and then.
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
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
    final settings = ref.watch(userSettingsProvider);
    final session = ref.watch(activeSessionProvider).value;
    final entries = ref.watch(sessionEntriesProvider(widget.sessionId)).value;
    if (!settings.showEstimate ||
        session == null ||
        session.id != widget.sessionId ||
        entries == null) {
      return const SizedBox.shrink();
    }
    final dayId = session.workoutDayId;
    final prescriptions = <int, ExercisePrescription>{};
    final groups = <int, SupersetGroup>{};
    if (dayId != null) {
      for (final i in ref.watch(dayPrescriptionsProvider(dayId)).value ??
          const <PrescriptionWithExercise>[]) {
        prescriptions[i.prescription.id] = i.prescription;
      }
      for (final g in ref.watch(daySupersetGroupsProvider(dayId)).value ??
          const <SupersetGroup>[]) {
        groups[g.id] = g;
      }
    }

    final todo = estimateSetsForSession(performingOrder(entries),
        prescriptions: prescriptions, groups: groups);
    if (todo.isEmpty) return const SizedBox.shrink();
    final rest = ref.watch(restTimerProvider)?.remaining();
    final left = estimateDuration(todo,
            defaultRest: settings.restSeconds,
            exerciseChangeRest: settings.restBetweenExercises) +
        (rest != null && rest > Duration.zero ? rest : Duration.zero);
    return Text(
      '${formatEstimate(left)} left',
      style: Theme.of(context).textTheme.labelMedium,
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/set_order.dart';
import 'rest_timer_state.dart';
import 'workout_providers.dart';

/// Workout actions shared by the UI and the headset button.
class WorkoutActions {
  WorkoutActions(this._ref);

  final Ref _ref;

  /// Marks [log] done, gives feedback and starts the rest timer.
  Future<void> completeSet(SetLog log) async {
    final repo = _ref.read(sessionRepositoryProvider);
    await repo.setCompleted(log.id, true);
    final settings = _ref.read(userSettingsProvider);
    _ref.read(feedbackServiceProvider).setDone(vibration: settings.vibration);
    final rest = await repo.restAfterCompleting(log.id,
        defaultRest: settings.restSeconds);
    if (rest != null) _ref.read(restTimerProvider.notifier).start(rest);
  }

  /// Completes the set to do next in the active workout (the highlighted
  /// one). Does nothing without a workout, or if that set has no reps.
  Future<void> completeCurrentSet() async {
    final session =
        await _ref.read(sessionRepositoryProvider).findActiveSession();
    if (session == null) return;
    final entries =
        await _ref.read(sessionEntriesProvider(session.id).future);
    final ordered = performingOrder(entries);
    final currentId = currentSetIdOf(ordered);
    if (currentId == null) return;
    final current = ordered.firstWhere((s) => s.id == currentId);
    if (current.reps == null) return;
    await completeSet(current);
  }
}

final workoutActionsProvider =
    Provider<WorkoutActions>((ref) => WorkoutActions(ref));

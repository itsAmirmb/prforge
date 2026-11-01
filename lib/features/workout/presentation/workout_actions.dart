import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/feedback/feedback_service.dart';
import '../../../core/feedback/speech_service.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/rest_announcement.dart';
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
    _ref
        .read(feedbackServiceProvider)
        .setDoneAudible(sound: _ref.read(userSettingsProvider).sound);
  }

  /// Speaks the next set when a rest is over (see Settings > Voice).
  Future<void> announceNext() async {
    final settings = _ref.read(userSettingsProvider);
    if (!(settings.speakReps ||
        settings.speakWeight ||
        settings.speakExerciseName)) {
      return;
    }
    final session =
        await _ref.read(sessionRepositoryProvider).findActiveSession();
    if (session == null) return;
    final entries =
        await _ref.read(sessionEntriesProvider(session.id).future);
    final ordered = performingOrder(entries);
    final nextId = currentSetIdOf(ordered);
    if (nextId == null) return;
    final next = ordered.firstWhere((s) => s.id == nextId);

    SetLog? previous;
    for (final s in ordered) {
      final t = s.completedAt;
      if (!s.isCompleted || t == null) continue;
      final p = previous?.completedAt;
      if (p == null || t.isAfter(p)) previous = s;
    }
    final name = [
      for (final e in entries)
        for (final b in e.blocks)
          if (b.exercise.id == next.exerciseId) b.exercise.name,
    ].firstOrNull;
    if (name == null) return;

    final speech = _ref.read(speechServiceProvider);
    final utterances = buildAnnouncement(
      exerciseName: name,
      exerciseChanged: previous == null || previous.exerciseId != next.exerciseId,
      weightKg: next.weightKg,
      reps: next.reps,
      sayName: settings.speakExerciseName,
      sayWeight: settings.speakWeight,
      sayReps: settings.speakReps,
      persianAvailable:
          settings.speakExerciseName ? await speech.persianAvailable : false,
    );
    // Let the rest-over beep finish first.
    if (settings.sound) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }
    await speech.speakAll(utterances);
  }
}

final workoutActionsProvider =
    Provider<WorkoutActions>((ref) => WorkoutActions(ref));

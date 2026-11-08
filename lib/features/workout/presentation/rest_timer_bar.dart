import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../settings/presentation/settings_providers.dart';
import '../domain/rest_countdown.dart';
import 'rest_alarm.dart';
import 'rest_timer_state.dart';
import 'workout_actions.dart';

String formatRest(Duration d) {
  final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Bar at the top of the workout screen: counts down the rest after a set, with
/// -15s / +15s / skip. Vibrates, beeps and speaks the next set when the rest
/// is over.
class RestTimerBar extends ConsumerStatefulWidget {
  const RestTimerBar({super.key});

  @override
  ConsumerState<RestTimerBar> createState() => _RestTimerBarState();
}

class _RestTimerBarState extends ConsumerState<RestTimerBar> {
  Timer? _ticker;

  /// Time left at the previous tick, to notice crossing a countdown beep.
  Duration? _prevRemaining;

  @override
  void initState() {
    super.initState();
    // Tick only while a timer is running.
    ref.listenManual<RestTimerState?>(restTimerProvider, (_, next) {
      _ticker?.cancel();
      _prevRemaining = null;
      _ticker = next == null
          ? null
          : Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    }, fireImmediately: true);
  }

  void _tick() {
    final timer = ref.read(restTimerProvider);
    if (timer == null) return;
    if (timer.remaining() <= Duration.zero) {
      // The OS alarm already beeped if the app was in the background.
      final alarmed = ref.read(restAlarmControllerProvider).takeArmed();
      if (!alarmed) {
        final settings = ref.read(userSettingsProvider);
        ref.read(feedbackServiceProvider).restOver(
            sound: settings.sound, vibration: settings.vibration);
      }
      ref.read(restTimerProvider.notifier).stop();
      ref.read(workoutActionsProvider).announceNext();
    } else {
      _countdownIfDue(timer);
      if (mounted) setState(() {});
    }
  }

  /// Plays a countdown beep when the time left drops below one of the beep
  /// points (see countdownTicks); the long final beep is the rest-over beep.
  /// Only beeps seen here are played: if the app was in the background the
  /// OS alarms played them.
  void _countdownIfDue(RestTimerState timer) {
    final remaining = timer.remaining();
    final previous = _prevRemaining;
    _prevRemaining = remaining;
    if (previous == null) return;
    final settings = ref.read(userSettingsProvider);
    final due = countdownTicks(
      style: settings.countdownStyle,
      seconds: settings.restWarnSeconds,
      totalSeconds: timer.totalSeconds,
    ).any((t) => previous > t && remaining <= t);
    if (due) {
      ref.read(feedbackServiceProvider).restCountdownTick(
          sound: settings.sound, vibration: settings.vibration);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(restTimerProvider);
    if (timer == null) return const SizedBox.shrink();

    final notifier = ref.read(restTimerProvider.notifier);
    final remaining = timer.remaining();
    final progress =
        (remaining.inMilliseconds / (timer.totalSeconds * 1000)).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final onBar = TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onPrimaryContainer);

    return Material(
      color: theme.colorScheme.primaryContainer,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Text('Rest ${formatRest(remaining + const Duration(milliseconds: 999))}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
              const SizedBox(width: 12),
              Expanded(
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              TextButton(
                  style: onBar,
                  onPressed: () => notifier.adjust(-15),
                  child: const Text('−15s')),
              TextButton(
                  style: onBar,
                  onPressed: () => notifier.adjust(15),
                  child: const Text('+15s')),
              IconButton(
                tooltip: 'Skip rest',
                color: theme.colorScheme.onPrimaryContainer,
                icon: const Icon(Icons.close),
                onPressed: notifier.stop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

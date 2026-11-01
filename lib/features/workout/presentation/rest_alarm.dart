import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/feedback_service.dart';
import '../../settings/presentation/settings_providers.dart';
import 'rest_timer_state.dart';

/// Makes the rest-over beep work with the screen off.
///
/// While the app is in the foreground the Dart timer in RestTimerBar does the
/// job. When the app goes to the background Dart timers stop, so the end time
/// is handed to the OS (an exact alarm). Back in the foreground the alarm is
/// cancelled again. [takeArmed] lets the foreground timer know the OS already
/// played the beep, so it is not played twice.
class RestAlarmController with WidgetsBindingObserver {
  RestAlarmController(this._ref) {
    WidgetsBinding.instance.addObserver(this);
    _ref.listen<RestTimerState?>(restTimerProvider, _onTimerChanged);
  }

  final Ref _ref;
  bool _armed = false;

  FeedbackService get _feedback => _ref.read(feedbackServiceProvider);

  bool get _inBackground {
    final state = WidgetsBinding.instance.lifecycleState;
    return state != null && state != AppLifecycleState.resumed;
  }

  /// True once if the OS alarm was set for the rest that just ended.
  bool takeArmed() {
    final armed = _armed;
    _armed = false;
    return armed;
  }

  void _schedule(RestTimerState timer) {
    final settings = _ref.read(userSettingsProvider);
    _armed = true;
    _feedback.scheduleRestEnd(
      endsAt: timer.endsAt,
      sound: settings.sound,
      vibration: settings.vibration,
      title: 'Rest is over',
      body: 'Time for your next set',
    );
  }

  void _onTimerChanged(RestTimerState? previous, RestTimerState? next) {
    if (next == null) {
      _armed = false;
      _feedback.cancelRestEnd();
    } else if (_inBackground) {
      _schedule(next);
    } else if (previous == null) {
      _feedback.requestNotificationPermission();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final timer = _ref.read(restTimerProvider);
    if (state == AppLifecycleState.resumed) {
      _feedback.cancelRestEnd();
      // If the rest already ended, the OS played the beep: stay armed so the
      // foreground timer only announces the next set.
      if (timer == null || timer.remaining() > Duration.zero) _armed = false;
    } else if (timer != null && timer.remaining() > Duration.zero) {
      _schedule(timer);
    }
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);
}

final restAlarmControllerProvider = Provider<RestAlarmController>((ref) {
  final controller = RestAlarmController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

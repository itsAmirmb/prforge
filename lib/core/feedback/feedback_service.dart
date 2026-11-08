import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real vibration, beep and keep-screen-on through a small native channel
/// (MainActivity.kt). Flutter's own HapticFeedback depends on the phone's
/// "touch vibration" setting and SystemSound.alert makes no sound on Android.
///
/// If the channel is missing (tests, other platforms) it falls back to
/// HapticFeedback and never throws: feedback must not break a workout.
class FeedbackService {
  FeedbackService([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'prforge/feedback';

  /// Vibration patterns in ms: off, on, off, on ...
  static const tickPattern = [0, 40];
  static const restOverPattern = [0, 300, 150, 300];
  static const warningPattern = [0, 40];

  final MethodChannel _channel;

  /// Fallbacks must never throw either (no platform handler in tests).
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }

  Future<void> _vibrate(List<int> pattern) async {
    try {
      await _channel.invokeMethod<void>('vibrate', pattern);
    } on MissingPluginException {
      await _safely(HapticFeedback.heavyImpact);
    } on PlatformException {
      // Ignore: no vibrator or no permission.
    }
  }

  /// [kind]: 'tick' (short, low), 'final' (long, high) or the default beep.
  Future<void> _beep([String kind = 'default']) async {
    try {
      await _channel.invokeMethod<void>('beep', kind);
    } on MissingPluginException {
      await _safely(() => SystemSound.play(SystemSoundType.click));
    } on PlatformException {
      // Ignore.
    }
  }

  /// A short tick when a set is marked done.
  Future<void> setDone({required bool vibration}) async {
    if (vibration) await _vibrate(tickPattern);
  }

  /// A beep for a set completed without looking at the screen (headset).
  Future<void> setDoneAudible({required bool sound}) async {
    if (sound) await _beep();
  }

  /// The rest is over: double buzz and beep, as enabled.
  Future<void> restOver({required bool sound, required bool vibration}) async {
    if (vibration) await _vibrate(restOverPattern);
    if (sound) await _beep('final');
  }

  /// Asks the OS to play the rest-over beep/vibration and show a notification
  /// at [endsAt] (and a short countdown beep at each of [tickAts]), even with the screen off (a Dart timer does not run then).
  /// Scheduling again replaces the previous alarm.
  Future<void> scheduleRestEnd({
    required DateTime endsAt,
    List<DateTime> tickAts = const [],
    required bool sound,
    required bool vibration,
    required String title,
    required String body,
  }) =>
      _invokeQuietly('scheduleRestEnd', {
        'atMillis': endsAt.millisecondsSinceEpoch,
        'tickAtMillis': [for (final t in tickAts) t.millisecondsSinceEpoch],
        'sound': sound,
        'vibration': vibration,
        'title': title,
        'body': body,
      });

  Future<void> cancelRestEnd() => _invokeQuietly('cancelRestEnd');

  /// Android 13+ asks before showing notifications; sound works without it.
  Future<void> requestNotificationPermission() =>
      _invokeQuietly('requestNotificationPermission');

  Future<void> _invokeQuietly(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Not supported here (tests, other platforms).
    } on PlatformException {
      // Ignore: feedback must never break a workout.
    }
  }

  /// One count of the countdown in the last seconds of a rest.
  Future<void> restCountdownTick(
      {required bool sound, required bool vibration}) async {
    if (vibration) await _vibrate(warningPattern);
    if (sound) await _beep('tick');
  }

  Future<void> keepScreenOn(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepScreenOn', on);
    } on MissingPluginException {
      // Not supported here.
    } on PlatformException {
      // Ignore.
    }
  }
}

final feedbackServiceProvider = Provider<FeedbackService>((ref) => FeedbackService());

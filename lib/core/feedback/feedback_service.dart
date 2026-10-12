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

  Future<void> _beep() async {
    try {
      await _channel.invokeMethod<void>('beep');
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

  /// The rest is over: double buzz and beep, as enabled.
  Future<void> restOver({required bool sound, required bool vibration}) async {
    if (vibration) await _vibrate(restOverPattern);
    if (sound) await _beep();
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

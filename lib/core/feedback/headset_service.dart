import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Headset button long-press, delivered by MainActivity.kt.
///
/// PRForge is registered as a system voice assistant (VOICE_COMMAND), so
/// holding the headset button launches it instead of the phone's assistant.
/// Each press arrives here as one event on [triggers].
class HeadsetService {
  HeadsetService([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trigger') _triggers.add(null);
    });
  }

  static const channelName = 'prforge/headset';

  final MethodChannel _channel;
  final _triggers = StreamController<void>.broadcast();

  Stream<void> get triggers => _triggers.stream;
}

final headsetServiceProvider = Provider<HeadsetService>(
  (ref) => HeadsetService(),
);

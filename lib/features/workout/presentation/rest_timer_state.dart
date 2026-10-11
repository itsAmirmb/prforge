import 'package:flutter_riverpod/flutter_riverpod.dart';

class RestTimerState {
  const RestTimerState({required this.endsAt, required this.totalSeconds});

  final DateTime endsAt;

  /// Length of the whole rest (for the progress bar).
  final int totalSeconds;

  Duration remaining([DateTime? now]) => endsAt.difference(now ?? DateTime.now());
}

/// The running rest timer, or null. It is based on an end time, so it stays
/// correct if the app was in the background.
class RestTimerNotifier extends Notifier<RestTimerState?> {
  @override
  RestTimerState? build() => null;

  void start(int seconds) {
    if (seconds <= 0) return;
    state = RestTimerState(
      endsAt: DateTime.now().add(Duration(seconds: seconds)),
      totalSeconds: seconds,
    );
  }

  /// Adds or removes time; if nothing is left the timer stops.
  void adjust(int deltaSeconds) {
    final current = state;
    if (current == null) return;
    final end = current.endsAt.add(Duration(seconds: deltaSeconds));
    if (!end.isAfter(DateTime.now())) {
      state = null;
      return;
    }
    final total = current.totalSeconds + deltaSeconds;
    state = RestTimerState(endsAt: end, totalSeconds: total < 1 ? 1 : total);
  }

  void stop() => state = null;
}

final restTimerProvider =
    NotifierProvider<RestTimerNotifier, RestTimerState?>(RestTimerNotifier.new);

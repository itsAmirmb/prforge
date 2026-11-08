/// How the end of a rest is announced.
enum CountdownStyle {
  /// No countdown, only the beep when the rest is over.
  off,

  /// One beep per second for the last N seconds ("ding ding ding").
  seconds,

  /// A beep at half of the rest, then at half of what is left, and so on:
  /// the beeps get faster until the rest is over.
  halving,
}

/// Shortest gap worth beeping for in [CountdownStyle.halving]; beeps closer
/// to the end than this would just blur into the final beep.
const _minHalvingLeft = Duration(seconds: 1);

/// How long before the end of a rest of [totalSeconds] each countdown beep
/// plays, longest first. The long final beep at 0 is not part of the list.
List<Duration> countdownTicks({
  required CountdownStyle style,
  required int seconds,
  required int totalSeconds,
}) {
  switch (style) {
    case CountdownStyle.off:
      return const [];
    case CountdownStyle.seconds:
      return [
        for (var s = seconds; s >= 1; s--)
          if (s < totalSeconds) Duration(seconds: s),
      ];
    case CountdownStyle.halving:
      final result = <Duration>[];
      var left = Duration(milliseconds: totalSeconds * 1000 ~/ 2);
      while (left >= _minHalvingLeft) {
        result.add(left);
        left = Duration(microseconds: left.inMicroseconds ~/ 2);
      }
      return result;
  }
}

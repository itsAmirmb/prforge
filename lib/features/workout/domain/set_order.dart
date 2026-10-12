import '../../../core/database/app_database.dart';
import 'session_blocks.dart';

/// Sets in the order they are performed: a single exercise top to bottom, a
/// superset round by round (every member's set of round 1, then round 2 ...).
List<SetLog> performingOrder(List<SessionEntry> entries) {
  final result = <SetLog>[];
  for (final entry in entries) {
    switch (entry) {
      case SingleEntry(:final block):
        result.addAll(block.sets);
      case SupersetEntry():
        for (final round in entry.rounds) {
          for (final member in entry.members) {
            final set = entry.setInRound(member, round);
            if (set != null) result.add(set);
          }
        }
    }
  }
  return result;
}

/// The set to do next: the first unfinished set after the furthest finished
/// one (so doing exercises out of order does not jump the screen back), else
/// the first unfinished set. Null when everything is done.
int? currentSetIdOf(List<SetLog> ordered) {
  final lastDone = ordered.lastIndexWhere((s) => s.isCompleted);
  for (var i = lastDone + 1; i < ordered.length; i++) {
    if (!ordered[i].isCompleted) return ordered[i].id;
  }
  for (final s in ordered) {
    if (!s.isCompleted) return s.id;
  }
  return null;
}

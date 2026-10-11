import '../../../core/database/app_database.dart';

/// A logged set together with its exercise.
class SetLogWithExercise {
  const SetLogWithExercise(this.log, this.exercise);

  final SetLog log;
  final Exercise exercise;
}

/// All sets of one planned exercise within a session (one card in the UI).
class ExerciseBlock {
  const ExerciseBlock({
    required this.exercise,
    required this.prescriptionId,
    required this.sets,
  });

  final Exercise exercise;
  final int? prescriptionId;
  final List<SetLog> sets;
}

/// Groups session sets into blocks.
///
/// Blocks keep the order in which they first appear in [rows] (rows are
/// expected sorted by SetLog id, i.e. creation order); sets inside a block are
/// sorted by setIndex. The same exercise planned twice stays two blocks
/// because blocks are keyed by prescription, not by exercise.
List<ExerciseBlock> groupIntoBlocks(List<SetLogWithExercise> rows) {
  final order = <int>[];
  final groups = <int, List<SetLogWithExercise>>{};
  for (final row in rows) {
    final key = row.log.prescriptionId ?? -row.log.exerciseId;
    groups.putIfAbsent(key, () {
      order.add(key);
      return <SetLogWithExercise>[];
    }).add(row);
  }
  return [
    for (final key in order)
      ExerciseBlock(
        exercise: groups[key]!.first.exercise,
        prescriptionId: groups[key]!.first.log.prescriptionId,
        sets: [for (final r in groups[key]!) r.log]..sort((a, b) {
            final byIndex = a.setIndex.compareTo(b.setIndex);
            return byIndex != 0 ? byIndex : a.id.compareTo(b.id);
          }),
      ),
  ];
}

/// One item of the session screen: a single exercise or a whole superset.
sealed class SessionEntry {
  const SessionEntry();

  /// All exercise blocks inside this entry.
  List<ExerciseBlock> get blocks;
}

class SingleEntry extends SessionEntry {
  const SingleEntry(this.block);

  final ExerciseBlock block;

  @override
  List<ExerciseBlock> get blocks => [block];
}

/// Sets that share a supersetKey: one block per member exercise, aligned by
/// round (roundIndex).
class SupersetEntry extends SessionEntry {
  const SupersetEntry({required this.key, required this.members});

  final String key;
  final List<ExerciseBlock> members;

  @override
  List<ExerciseBlock> get blocks => members;

  static int roundOf(SetLog set) => set.roundIndex ?? set.setIndex;

  /// Distinct round numbers present, ascending.
  List<int> get rounds {
    final all = {
      for (final m in members)
        for (final s in m.sets) roundOf(s),
    };
    return all.toList()..sort();
  }

  /// The member's set in [round], or null if it has none (e.g. deleted).
  SetLog? setInRound(ExerciseBlock member, int round) {
    for (final s in member.sets) {
      if (roundOf(s) == round) return s;
    }
    return null;
  }
}

/// Groups session sets into screen entries in first-seen order. Sets with a
/// supersetKey collapse into one [SupersetEntry]; everything else becomes a
/// [SingleEntry] per prescription (see [groupIntoBlocks]).
List<SessionEntry> groupIntoEntries(List<SetLogWithExercise> rows) {
  final order = <String>[];
  final groups = <String, List<SetLogWithExercise>>{};
  for (final row in rows) {
    final superset = row.log.supersetKey;
    final token = superset != null
        ? 's:$superset'
        : 'p:${row.log.prescriptionId ?? -row.log.exerciseId}';
    groups.putIfAbsent(token, () {
      order.add(token);
      return <SetLogWithExercise>[];
    }).add(row);
  }
  return [
    for (final token in order)
      if (token.startsWith('s:'))
        SupersetEntry(
          key: token.substring(2),
          members: groupIntoBlocks(groups[token]!),
        )
      else
        SingleEntry(groupIntoBlocks(groups[token]!).single),
  ];
}

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
    groups
        .putIfAbsent(key, () {
          order.add(key);
          return <SetLogWithExercise>[];
        })
        .add(row);
  }
  return [
    for (final key in order)
      ExerciseBlock(
        exercise: groups[key]!.first.exercise,
        prescriptionId: groups[key]!.first.log.prescriptionId,
        sets: [for (final r in groups[key]!) r.log]
          ..sort((a, b) {
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

  /// Identifies the entry (see [entryToken]).
  String get token;
}

class SingleEntry extends SessionEntry {
  const SingleEntry(this.block);

  final ExerciseBlock block;

  @override
  List<ExerciseBlock> get blocks => [block];

  @override
  String get token => 'p:${block.prescriptionId ?? -block.exercise.id}';
}

/// Sets that share a supersetKey: one block per member exercise, aligned by
/// round (roundIndex).
class SupersetEntry extends SessionEntry {
  const SupersetEntry({required this.key, required this.members});

  final String key;
  final List<ExerciseBlock> members;

  @override
  List<ExerciseBlock> get blocks => members;

  @override
  String get token => 's:$key';

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

/// Key of the screen entry a set belongs to: its superset, else its
/// prescription (or, for an exercise added during the workout, the exercise).
String entryToken(SetLog log) {
  final superset = log.supersetKey;
  return superset != null
      ? 's:$superset'
      : 'p:${log.prescriptionId ?? -log.exerciseId}';
}

/// Entry tokens in screen order. [sets] must be sorted by id. Entries with a
/// saved position come first in that order, the others follow in the order
/// they were created.
List<String> orderedTokens(Iterable<SetLog> sets) {
  final first = <String, int>{};
  final position = <String, int>{};
  for (final s in sets) {
    final token = entryToken(s);
    first.putIfAbsent(token, () => first.length);
    final p = s.entryOrder;
    final known = position[token];
    if (p != null && (known == null || p < known)) position[token] = p;
  }
  const unplaced = 1 << 30;
  return first.keys.toList()..sort((a, b) {
    final byPosition = (position[a] ?? unplaced).compareTo(
      position[b] ?? unplaced,
    );
    return byPosition != 0 ? byPosition : first[a]!.compareTo(first[b]!);
  });
}

/// Groups session sets into screen entries in screen order (see
/// [orderedTokens]). Sets with a supersetKey collapse into one
/// [SupersetEntry]; everything else becomes a [SingleEntry] per prescription
/// (see [groupIntoBlocks]).
List<SessionEntry> groupIntoEntries(List<SetLogWithExercise> rows) {
  final groups = <String, List<SetLogWithExercise>>{};
  for (final row in rows) {
    groups
        .putIfAbsent(entryToken(row.log), () => <SetLogWithExercise>[])
        .add(row);
  }
  return [
    for (final token in orderedTokens([for (final r in rows) r.log]))
      if (token.startsWith('s:'))
        SupersetEntry(
          key: token.substring(2),
          members: groupIntoBlocks(groups[token]!),
        )
      else
        SingleEntry(groupIntoBlocks(groups[token]!).single),
  ];
}

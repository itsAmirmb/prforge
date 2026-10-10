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

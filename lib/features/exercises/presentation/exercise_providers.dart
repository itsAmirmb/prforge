import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/exercise_repository.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);

/// Family key: true = archived exercises, false = active ones.
final exerciseListProvider =
    StreamProvider.autoDispose.family<List<Exercise>, bool>(
  (ref, archived) =>
      ref.watch(exerciseRepositoryProvider).watchExercises(archived: archived),
);

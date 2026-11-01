import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/progress_repository.dart';
import '../domain/progress.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ProgressRepository(ref.watch(databaseProvider)),
);

final exerciseProgressProvider =
    StreamProvider.autoDispose.family<ExerciseProgress, int>(
  (ref, exerciseId) =>
      ref.watch(progressRepositoryProvider).watchExercise(exerciseId),
);

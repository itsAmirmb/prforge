import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/program_repository.dart';
import '../data/workout_day_repository.dart';

final programRepositoryProvider = Provider<ProgramRepository>(
  (ref) => ProgramRepository(ref.watch(databaseProvider)),
);

final workoutDayRepositoryProvider = Provider<WorkoutDayRepository>(
  (ref) => WorkoutDayRepository(ref.watch(databaseProvider)),
);

/// Family key: true = archived programs, false = active ones.
final programListProvider =
    StreamProvider.autoDispose.family<List<Program>, bool>(
  (ref, archived) =>
      ref.watch(programRepositoryProvider).watchPrograms(archived: archived),
);

final programProvider = StreamProvider.autoDispose.family<Program?, int>(
  (ref, id) => ref.watch(programRepositoryProvider).watchProgram(id),
);

final workoutDaysProvider =
    StreamProvider.autoDispose.family<List<WorkoutDay>, int>(
  (ref, programId) =>
      ref.watch(workoutDayRepositoryProvider).watchDays(programId),
);

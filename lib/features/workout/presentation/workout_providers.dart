import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/session_repository.dart';
import '../domain/session_blocks.dart';

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

/// The in-progress session, if any (drives the "Resume workout" bar).
final activeSessionProvider = StreamProvider<WorkoutSession?>(
  (ref) => ref.watch(sessionRepositoryProvider).watchActiveSession(),
);

final sessionEntriesProvider =
    StreamProvider.autoDispose.family<List<SessionEntry>, int>(
  (ref, sessionId) => ref
      .watch(sessionRepositoryProvider)
      .watchSessionSets(sessionId)
      .map(groupIntoEntries),
);

/// Last completed performance of an exercise (for the "Last:" line).
final lastPerformanceProvider =
    FutureProvider.autoDispose.family<List<SetLog>, int>(
  (ref, exerciseId) =>
      ref.watch(sessionRepositoryProvider).lastPerformance(exerciseId),
);

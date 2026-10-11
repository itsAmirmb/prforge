import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(databaseProvider)),
);

final completedSessionsProvider =
    StreamProvider.autoDispose<List<SessionSummary>>(
  (ref) => ref.watch(historyRepositoryProvider).watchCompleted(),
);

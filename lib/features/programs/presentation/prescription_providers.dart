import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/prescription_repository.dart';
import '../data/superset_repository.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => PrescriptionRepository(ref.watch(databaseProvider)),
);

final dayPrescriptionsProvider = StreamProvider.autoDispose
    .family<List<PrescriptionWithExercise>, int>(
  (ref, dayId) => ref.watch(prescriptionRepositoryProvider).watchForDay(dayId),
);

final supersetRepositoryProvider = Provider<SupersetRepository>(
  (ref) => SupersetRepository(ref.watch(databaseProvider)),
);

final daySupersetGroupsProvider =
    StreamProvider.autoDispose.family<List<SupersetGroup>, int>(
  (ref, dayId) => ref.watch(supersetRepositoryProvider).watchGroups(dayId),
);

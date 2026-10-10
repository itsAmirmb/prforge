import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/prescription_repository.dart';

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>(
  (ref) => PrescriptionRepository(ref.watch(databaseProvider)),
);

final dayPrescriptionsProvider = StreamProvider.autoDispose
    .family<List<PrescriptionWithExercise>, int>(
  (ref, dayId) => ref.watch(prescriptionRepositoryProvider).watchForDay(dayId),
);

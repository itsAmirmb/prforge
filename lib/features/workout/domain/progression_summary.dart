import '../../../core/database/app_database.dart';

/// How many of last time's sets were done at [weight], e.g. 1 of 3.
///
/// Used only as an informational hint ("Last time: 1 of 3 sets at 7.5 kg");
/// the app never decides the next step for the user.
({int atWeight, int total}) lastTimeUsage(List<SetLog> last, double weight) {
  return (
    atWeight: last.where((s) => s.weightKg == weight).length,
    total: last.length,
  );
}

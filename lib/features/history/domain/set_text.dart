import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';

String _part(double? weightKg, int? reps) {
  final w = formatWeight(weightKg);
  final r = reps?.toString() ?? '?';
  return w == null ? '$r reps' : '$w kg × $r';
}

/// "60 kg × 8", or "8 reps" when the set has no weight.
String setText(SetLog set) => _part(set.weightKg, set.reps);

/// "+ 17.5 kg × 4 · rest 15s".
String miniSetText(MiniSetLog mini) {
  final rest = mini.restSeconds == null ? '' : ' · rest ${mini.restSeconds}s';
  return '+ ${_part(mini.weightKg, mini.reps)}$rest';
}

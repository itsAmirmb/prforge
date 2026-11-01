import '../../../core/feedback/speech_service.dart';
import '../../../core/utils/format.dart';

final _arabicScript = RegExp(r'[\u0600-\u06FF]');

/// What to say when a rest is over, for the next set.
///
/// The exercise name comes first, only when [exerciseChanged]; it is read in
/// Persian if it is written in Persian script and [persianAvailable],
/// skipped if the phone has no Persian voice, and read in English otherwise.
/// Then "60 kilos, 10 reps" in English, as chosen in the settings.
List<Utterance> buildAnnouncement({
  required String exerciseName,
  required bool exerciseChanged,
  required double? weightKg,
  required int? reps,
  required bool sayName,
  required bool sayWeight,
  required bool sayReps,
  required bool persianAvailable,
}) {
  final result = <Utterance>[];
  if (sayName && exerciseChanged && exerciseName.trim().isNotEmpty) {
    if (!_arabicScript.hasMatch(exerciseName)) {
      result.add(Utterance(exerciseName.trim(), 'en-US'));
    } else if (persianAvailable) {
      result.add(Utterance(exerciseName.trim(), 'fa-IR'));
    }
  }
  final weight = formatWeight(weightKg);
  final parts = [
    if (sayWeight && weight != null) '$weight kilos',
    if (sayReps && reps != null) reps == 1 ? '1 rep' : '$reps reps',
  ];
  if (parts.isNotEmpty) result.add(Utterance(parts.join(', '), 'en-US'));
  return result;
}

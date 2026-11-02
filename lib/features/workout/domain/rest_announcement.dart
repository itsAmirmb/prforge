import '../../../core/feedback/speech_service.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/spoken_numbers.dart';

final _arabicScript = RegExp(r'[\u0600-\u06FF]');

/// What to say when a rest is over, for the next set.
///
/// The exercise name comes first, only when [exerciseChanged]; it is read in
/// Persian if it is written in Persian script and [persianAvailable],
/// skipped if the phone has no Persian voice, and read in English otherwise.
/// Then the weight and reps, as chosen in the settings: in English ("12 point
/// 5 kilos, 10 reps") or, when [language] is Persian and the phone has a
/// Persian voice, entirely in Persian words ("دوازده و نیم کیلوگرم، ده
/// تکرار"). Without a Persian voice it falls back to English.
List<Utterance> buildAnnouncement({
  required String exerciseName,
  required bool exerciseChanged,
  required double? weightKg,
  required int? reps,
  required bool sayName,
  required bool sayWeight,
  required bool sayReps,
  required bool persianAvailable,
  SpeechLanguage language = SpeechLanguage.english,
}) {
  final result = <Utterance>[];
  if (sayName && exerciseChanged && exerciseName.trim().isNotEmpty) {
    if (!_arabicScript.hasMatch(exerciseName)) {
      result.add(Utterance(exerciseName.trim(), 'en-US'));
    } else if (persianAvailable) {
      result.add(Utterance(exerciseName.trim(), 'fa-IR'));
    }
  }
  final inPersian = language == SpeechLanguage.persian && persianAvailable;
  final hasWeight = sayWeight && formatWeight(weightKg) != null;
  final hasReps = sayReps && reps != null;
  final parts = inPersian
      ? [
          if (hasWeight) '${persianWeight(weightKg!)} کیلوگرم',
          if (hasReps) '${persianInt(reps)} تکرار',
        ]
      : [
          if (hasWeight) '${englishWeight(weightKg!)} kilos',
          if (hasReps) reps == 1 ? '1 rep' : '$reps reps',
        ];
  if (parts.isNotEmpty) {
    result.add(
        Utterance(parts.join(inPersian ? '، ' : ', '), inPersian ? 'fa-IR' : 'en-US'));
  }
  return result;
}

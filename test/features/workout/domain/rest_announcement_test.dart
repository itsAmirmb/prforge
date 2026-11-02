import 'package:flutter_test/flutter_test.dart';
import 'package:prforge/core/feedback/speech_service.dart';
import 'package:prforge/features/workout/domain/rest_announcement.dart';

List<Utterance> say({
  String name = 'پرس سینه',
  bool changed = true,
  double? weight = 60,
  int? reps = 10,
  bool sayName = true,
  bool sayWeight = true,
  bool sayReps = true,
  bool persian = true,
  SpeechLanguage language = SpeechLanguage.english,
}) =>
    buildAnnouncement(
      exerciseName: name,
      exerciseChanged: changed,
      weightKg: weight,
      reps: reps,
      sayName: sayName,
      sayWeight: sayWeight,
      sayReps: sayReps,
      persianAvailable: persian,
      language: language,
    );

void main() {
  test('Persian name first, then weight and reps in English', () {
    expect(say(), const [
      Utterance('پرس سینه', 'fa-IR'),
      Utterance('60 kilos, 10 reps', 'en-US'),
    ]);
  });

  test('no Persian voice: the name is skipped, reps are still said', () {
    expect(say(persian: false), const [Utterance('60 kilos, 10 reps', 'en-US')]);
  });

  test('English names are read in English even without a Persian voice', () {
    expect(say(name: 'Bench Press', persian: false), const [
      Utterance('Bench Press', 'en-US'),
      Utterance('60 kilos, 10 reps', 'en-US'),
    ]);
  });

  test('the name is only said when the exercise changed', () {
    expect(say(changed: false), const [Utterance('60 kilos, 10 reps', 'en-US')]);
  });

  test('each part can be switched off, even all of them', () {
    expect(say(sayWeight: false), const [
      Utterance('پرس سینه', 'fa-IR'),
      Utterance('10 reps', 'en-US'),
    ]);
    expect(say(sayName: false, sayReps: false),
        const [Utterance('60 kilos', 'en-US')]);
    expect(say(sayName: false, sayWeight: false, sayReps: false), isEmpty);
  });

  test('missing weight or reps are left out; one rep is singular', () {
    expect(say(weight: null, reps: 1, sayName: false),
        const [Utterance('1 rep', 'en-US')]);
    expect(say(weight: 7.5, reps: null, sayName: false),
        const [Utterance('7.5 kilos', 'en-US')]);
  });

  test('Persian voice language says units and numbers in Persian', () {
    expect(
        say(weight: 12.5, language: SpeechLanguage.persian, changed: false),
        const [Utterance('دوازده و نیم کیلوگرم، ده تکرار', 'fa-IR')]);
  });

  test('Persian language without a Persian voice falls back to English', () {
    expect(
        say(language: SpeechLanguage.persian, persian: false, changed: false),
        const [Utterance('60 kilos, 10 reps', 'en-US')]);
  });

  test('English reads 12.5 as "12 point 5"', () {
    expect(say(weight: 12.5, changed: false),
        const [Utterance('12 point 5 kilos, 10 reps', 'en-US')]);
  });
}

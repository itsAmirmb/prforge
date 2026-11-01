import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// One piece of speech and the language it is spoken in (e.g. "en-US").
class Utterance {
  const Utterance(this.text, this.language);

  final String text;
  final String language;

  @override
  bool operator ==(Object other) =>
      other is Utterance && other.text == text && other.language == language;

  @override
  int get hashCode => Object.hash(text, language);

  @override
  String toString() => 'Utterance($language: $text)';
}

/// Speaks through the phone's own text-to-speech engine. Which languages
/// work depends on the voices installed on the phone, so [persianAvailable]
/// is checked before Persian is used. Never throws: speech must not break a
/// workout.
class SpeechService {
  SpeechService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool? _persian;

  Future<bool> get persianAvailable async =>
      _persian ??= await _isAvailable('fa-IR');

  Future<bool> _isAvailable(String language) async {
    try {
      final result = await _tts.isLanguageAvailable(language);
      return result == true || result == 1;
    } catch (_) {
      return false;
    }
  }

  /// Speaks the pieces one after another, replacing anything still playing.
  Future<void> speakAll(List<Utterance> utterances) async {
    if (utterances.isEmpty) return;
    try {
      if (!_ready) {
        // Makes speak() finish when the speech is over, so the pieces (and
        // their languages) really follow each other.
        await _tts.awaitSpeakCompletion(true);
        _ready = true;
      }
      await _tts.stop();
      for (final u in utterances) {
        await _tts.setLanguage(u.language);
        await _tts.speak(u.text);
      }
    } catch (_) {}
  }
}

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());

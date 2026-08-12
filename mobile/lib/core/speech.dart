import 'package:flutter_tts/flutter_tts.dart';

/// Manual TTS only. Never call from stream completion or auto-play.
class SpeechService {
  SpeechService._();
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> _ensure() async {
    if (_ready) return;
    await _tts.setLanguage('fa-IR');
    await _tts.setSpeechRate(0.45);
    _ready = true;
  }

  static Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _ensure();
    await _tts.stop();
    await _tts.speak(t);
  }

  static Future<void> stop() => _tts.stop();
}

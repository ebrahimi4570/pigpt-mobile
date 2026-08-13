import 'package:flutter_tts/flutter_tts.dart';

/// Manual TTS only. Never call from stream completion or auto-play.
class SpeechService {
  SpeechService._();
  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;
  static bool _hasPersian = false;
  static bool speaking = false;
  static String? speakingText;
  static Map<String, String>? _voice;

  static const noPersianVoiceFa =
      'صدای فارسی روی این دستگاه نصب نیست. یک موتور/صدای فارسی (fa-IR) اضافه کنید؛ در غیر این صورت متن به‌صورت نامفهوم خوانده می‌شود.';

  static Future<void> _ensure() async {
    if (_ready) return;
    try {
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      final available = await _tts.isLanguageAvailable('fa-IR');
      final langOk = available == true ||
          available == 1 ||
          '$available'.toLowerCase() == 'true';
      final raw = await _tts.getVoices;
      var listedAny = false;
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          listedAny = true;
          final locale =
              '${item['locale'] ?? item['localeId'] ?? ''}'.toLowerCase();
          final name = '${item['name'] ?? ''}'.toLowerCase();
          final fa = locale.startsWith('fa') ||
              name.contains('persian') ||
              name.contains('farsi') ||
              name.contains('iran');
          if (!fa) continue;
          final voiceName = '${item['name'] ?? ''}';
          final voiceLocale = '${item['locale'] ?? 'fa-IR'}';
          if (voiceName.isEmpty) continue;
          _voice = {'name': voiceName, 'locale': voiceLocale};
          _hasPersian = true;
          final lang = voiceLocale.replaceAll('_', '-');
          await _tts.setLanguage(lang.toLowerCase().startsWith('fa') ? lang : 'fa-IR');
          await _tts.setVoice(_voice!);
          break;
        }
      }
      if (!_hasPersian && !listedAny && langOk) {
        _hasPersian = true;
        await _tts.setLanguage('fa-IR');
      }
    } catch (_) {
      _hasPersian = false;
    }
    _ready = true;
  }

  /// Plain text for speech: no markdown, URLs, or powered-by footers.
  static String plainText(String text) {
    var t = text;
    t = t.replaceAll(
      RegExp(
        r'(?:\n|^)\s*(?:[-–—*•]\s*)?(?:PiGPT\s*[·•|\-–—]?\s*)?(?:قدرت[\u200c\s\-]*گرفته\s*از|powered\s+by)\s+[^\n]+?\s*$',
        caseSensitive: false,
        multiLine: true,
      ),
      '',
    );
    t = t.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
    t = t.replaceAll(RegExp(r'`[^`]*`'), ' ');
    t = t.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), ' ');
    t = t.replaceAll(RegExp(r'\[[^\]]*\]\([^)]+\)'), ' ');
    t = t.replaceAll(RegExp(r'https?://\S+', caseSensitive: false), ' ');
    t = t.replaceAll(RegExp(r'[*_~>#]+'), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t;
  }

  /// Speaks [text] in Persian. Same button stops if already speaking this text.
  static Future<String?> speak(String text) async {
    final t = plainText(text);
    if (t.isEmpty) return 'متنی برای خواندن نیست';
    await _ensure();
    if (!_hasPersian) return noPersianVoiceFa;
    if (speaking && speakingText == t) {
      await stop();
      return null;
    }
    await stop();
    final lang = (_voice?['locale'] ?? 'fa-IR').replaceAll('_', '-');
    await _tts.setLanguage(lang.toLowerCase().startsWith('fa') ? lang : 'fa-IR');
    if (_voice != null) {
      try {
        await _tts.setVoice(_voice!);
      } catch (_) {}
    }
    speaking = true;
    speakingText = t;
    _tts.setCompletionHandler(() {
      speaking = false;
      speakingText = null;
    });
    _tts.setCancelHandler(() {
      speaking = false;
      speakingText = null;
    });
    await _tts.speak(t);
    return null;
  }

  static Future<void> stop() async {
    speaking = false;
    speakingText = null;
    await _tts.stop();
  }
}

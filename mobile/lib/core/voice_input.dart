import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'api_client.dart';
import 'api_paths.dart';

/// Web pattern: on-device SpeechRecognition analog, else record + Whisper.
class VoiceInputService {
  VoiceInputService(this._api);

  final ApiClient _api;
  final SpeechToText _stt = SpeechToText();
  final AudioRecorder _recorder = AudioRecorder();

  bool listening = false;
  bool busy = false;
  bool _sttReady = false;
  String _base = '';

  Future<bool> _micPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> toggle({
    required String currentText,
    required void Function(String text) onText,
    required void Function(String error) onError,
  }) async {
    if (busy) return;
    if (listening) {
      await stop();
      return;
    }
    if (!await _micPermission()) {
      onError('اجازهٔ میکروفون داده نشد');
      return;
    }
    _base = currentText.trimRight();
    final usedStt = await _startSpeech(onText: onText, onError: onError);
    if (!usedStt) {
      await _startRecord(onText: onText, onError: onError);
    }
  }

  Future<bool> _startSpeech({
    required void Function(String text) onText,
    required void Function(String error) onError,
  }) async {
    try {
      _sttReady = await _stt.initialize(
        onError: (e) {
          final code = e.errorMsg;
          if (code == 'error_speech_timeout' || code == 'error_no_match') {
            onError('گفتاری شنیده نشد');
            listening = false;
            return;
          }
          // Network / service failures (common in Iran) → Whisper fallback.
          if (listening) {
            listening = false;
            _stt.stop();
            _startRecord(onText: onText, onError: onError);
          }
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            listening = false;
          }
        },
      );
      if (!_sttReady) return false;
      final locales = await _stt.locales();
      final fa = locales.where((l) {
        final id = l.localeId.toLowerCase();
        return id.startsWith('fa');
      });
      final localeId = fa.isNotEmpty ? fa.first.localeId : 'fa_IR';
      listening = true;
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          localeId: localeId,
        ),
        onResult: (r) {
          final piece = r.recognizedWords.trim();
          if (piece.isEmpty) return;
          final shown = _base.isEmpty ? piece : '$_base $piece';
          onText(shown);
          if (r.finalResult) {
            _base = shown;
          }
        },
      );
      return true;
    } catch (_) {
      listening = false;
      return false;
    }
  }

  Future<void> _startRecord({
    required void Function(String text) onText,
    required void Function(String error) onError,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'pigpt-dictate-${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 16000,
        ),
        path: path,
      );
      listening = true;
    } catch (_) {
      listening = false;
      onError('ضبط صدا شروع نشد');
    }
  }

  Future<void> stop({
    void Function(String text)? onText,
    void Function(String error)? onError,
  }) async {
    if (_stt.isListening) {
      await _stt.stop();
      listening = false;
      return;
    }
    if (await _recorder.isRecording()) {
      final path = await _recorder.stop();
      listening = false;
      if (path == null || path.isEmpty) {
        onError?.call('گفتاری شنیده نشد');
        return;
      }
      await _transcribe(path, onText: onText, onError: onError);
    } else {
      listening = false;
    }
  }

  Future<void> _transcribe(
    String filePath, {
    void Function(String text)? onText,
    void Function(String error)? onError,
  }) async {
    busy = true;
    try {
      final file = File(filePath);
      if (!file.existsSync() || file.lengthSync() == 0) {
        onError?.call('گفتاری شنیده نشد');
        return;
      }
      final data = await _api.postMultipart(
        ApiPaths.chatTranscribe,
        filePath: filePath,
        filename: p.basename(filePath),
      );
      final text = '${data['text'] ?? data['transcript'] ?? ''}'.trim();
      if (text.isEmpty) {
        onError?.call('گفتاری شنیده نشد');
        return;
      }
      final shown = _base.isEmpty ? text : '$_base $text';
      onText?.call(shown);
    } on ApiException catch (e) {
      onError?.call(e.message);
    } catch (_) {
      onError?.call('تبدیل گفتار ناموفق بود');
    } finally {
      busy = false;
      try {
        File(filePath).deleteSync();
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }
}

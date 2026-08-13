import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Local composer drafts so killing the app does not lose typed text.
class ComposerDrafts {
  ComposerDrafts._();

  static const _prefix = 'pigpt_composer_draft_';
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _store() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static String _key(String? conversationId) {
    final id = (conversationId == null || conversationId.isEmpty)
        ? 'home'
        : conversationId;
    return '$_prefix$id';
  }

  static Future<String> load(String? conversationId) async {
    try {
      final p = await _store();
      return p.getString(_key(conversationId)) ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> save(String? conversationId, String text) async {
    try {
      final p = await _store();
      final t = text.trimRight();
      if (t.isEmpty) {
        await p.remove(_key(conversationId));
      } else {
        await p.setString(_key(conversationId), t);
      }
    } catch (_) {}
  }

  static Future<void> clear(String? conversationId) async {
    try {
      final p = await _store();
      await p.remove(_key(conversationId));
    } catch (_) {}
  }
}

/// Debounced saver for the composer TextField.
class DraftSaver {
  DraftSaver({this.delay = const Duration(milliseconds: 450)});
  final Duration delay;
  Timer? _timer;

  void schedule(String? conversationId, String text) {
    _timer?.cancel();
    _timer = Timer(delay, () => ComposerDrafts.save(conversationId, text));
  }

  void flush(String? conversationId, String text) {
    _timer?.cancel();
    unawaited(ComposerDrafts.save(conversationId, text));
  }

  void dispose() => _timer?.cancel();
}

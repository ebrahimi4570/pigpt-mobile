import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'api_paths.dart';

/// Local composer drafts so killing the app does not lose typed text.
/// Also mirrors to `/message-drafts` when an [ApiClient] is provided.
class ComposerDrafts {
  ComposerDrafts._();

  static const _prefix = 'pigpt_composer_draft_';
  static SharedPreferences? _prefs;
  static ApiClient? _api;

  static void bindApi(ApiClient? api) => _api = api;

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
      final local = p.getString(_key(conversationId)) ?? '';
      if (local.isNotEmpty) return local;
      final api = _api;
      if (api == null) return '';
      final data = await api.get<dynamic>(ApiPaths.messageDrafts);
      final list = data is List
          ? data
          : (data is Map ? (data['items'] ?? data['drafts'] ?? []) as List : []);
      for (final raw in list) {
        if (raw is! Map) continue;
        final m = Map<String, dynamic>.from(raw);
        final cid = '${m['conversation_id'] ?? ''}';
        final match = (conversationId == null || conversationId.isEmpty)
            ? cid.isEmpty
            : cid == conversationId;
        if (match) {
          final content = '${m['content'] ?? ''}';
          if (content.isNotEmpty) {
            await p.setString(_key(conversationId), content);
            return content;
          }
        }
      }
    } catch (_) {}
    return '';
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
      final api = _api;
      if (api != null && t.isNotEmpty) {
        unawaited((() async {
          try {
            await api.post(
              ApiPaths.messageDrafts,
              data: {
                'content': t,
                if (conversationId != null && conversationId.isNotEmpty)
                  'conversation_id': conversationId,
              },
            );
          } catch (_) {}
        })());
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

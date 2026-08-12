import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

final modelsProvider = FutureProvider<List<AiModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<dynamic>(ApiPaths.models);
  final list = _asList(data, keys: ['models', 'items', 'data']);
  return list
      .whereType<Map>()
      .map((e) => AiModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

final conversationsProvider =
    FutureProvider.family<List<Conversation>, bool>((ref, archivedOnly) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get<dynamic>(
    ApiPaths.conversations,
    query: {'archived_only': archivedOnly},
  );
  final list = _asList(data, keys: ['conversations', 'items', 'data']);
  return list
      .whereType<Map>()
      .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e)))
      .toList();
});

class ChatSessionState {
  const ChatSessionState({
    this.conversationId,
    this.messages = const [],
    this.streaming = false,
    this.error,
    this.modelId,
    this.mode = 'chat',
  });

  final String? conversationId;
  final List<ChatMessage> messages;
  final bool streaming;
  final String? error;
  final String? modelId;
  final String mode; // chat | agent

  ChatSessionState copyWith({
    String? conversationId,
    List<ChatMessage>? messages,
    bool? streaming,
    String? error,
    String? modelId,
    String? mode,
    bool clearError = false,
  }) =>
      ChatSessionState(
        conversationId: conversationId ?? this.conversationId,
        messages: messages ?? this.messages,
        streaming: streaming ?? this.streaming,
        error: clearError ? null : (error ?? this.error),
        modelId: modelId ?? this.modelId,
        mode: mode ?? this.mode,
      );
}

class ChatSessionController extends StateNotifier<ChatSessionState> {
  ChatSessionController(this._ref, this.initialId)
      : super(ChatSessionState(conversationId: initialId)) {
    if (initialId != null) {
      load(initialId!);
    }
  }

  final Ref _ref;
  final String? initialId;
  CancelToken? _cancel;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> load(String id) async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiPaths.conversation(id),
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final msgs = _asList(data, keys: ['messages', 'items'])
          .whereType<Map>()
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = state.copyWith(
        conversationId: id,
        messages: msgs,
        modelId: data['model_id']?.toString() ?? state.modelId,
        clearError: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  void setMode(String mode) => state = state.copyWith(mode: mode);

  void setModel(String modelId) => state = state.copyWith(modelId: modelId);

  void stop() {
    _cancel?.cancel('user');
    _cancel = null;
    if (state.streaming) {
      final msgs = [...state.messages];
      if (msgs.isNotEmpty && msgs.last.streaming) {
        msgs[msgs.length - 1] = msgs.last.copyWith(streaming: false);
      }
      state = state.copyWith(streaming: false, messages: msgs);
    }
  }

  Future<void> ensureConversation() async {
    if (state.conversationId != null) return;
    final modelId = state.modelId;
    final created = await _api.post<Map<String, dynamic>>(
      ApiPaths.conversations,
      data: {
        if (modelId != null && modelId.isNotEmpty) 'model_id': modelId,
        'title': 'گفتگوی جدید',
      },
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );
    state = state.copyWith(
      conversationId: '${created['id']}',
      modelId: created['model_id']?.toString() ?? modelId,
    );
  }

  Future<void> send(String content) async {
    final text = content.trim();
    if (text.isEmpty || state.streaming) return;
    await ensureConversation();
    final convId = state.conversationId!;
    final userMsg = ChatMessage(
      id: 'local-u-${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      content: text,
    );
    final assistantId = 'local-a-${DateTime.now().microsecondsSinceEpoch}';
    final assistant = ChatMessage(
      id: assistantId,
      role: 'assistant',
      content: '',
      streaming: true,
      modelId: state.modelId,
    );
    state = state.copyWith(
      messages: [...state.messages, userMsg, assistant],
      streaming: true,
      clearError: true,
    );

    _cancel = CancelToken();
    var buffer = '';
    try {
      await for (final event in _api.postSse(
        ApiPaths.conversationMessages(convId),
        data: {
          'content': text,
          'mode': state.mode,
          if (state.modelId != null) 'model_id': state.modelId,
        },
        cancelToken: _cancel,
      )) {
        if (event.event == 'token') {
          buffer += '${event.data['text'] ?? ''}';
          _patchAssistant(assistantId, buffer, streaming: true);
        } else if (event.event == 'error') {
          final err = '${event.data['error_message_fa'] ?? event.data['message_fa'] ?? event.data['detail'] ?? 'خطا در تولید پاسخ'}';
          _patchAssistant(assistantId, buffer, streaming: false, error: err);
          state = state.copyWith(streaming: false, error: err);
          return;
        }
      }
      _patchAssistant(assistantId, buffer, streaming: false);
      state = state.copyWith(streaming: false);
      await _ref.read(authControllerProvider.notifier).refreshMe();
      _ref.invalidate(conversationsProvider(false));
    } on ApiException catch (e) {
      _patchAssistant(assistantId, buffer, streaming: false, error: e.message);
      state = state.copyWith(streaming: false, error: e.message);
    }
  }

  Future<void> regenerate() async {
    final convId = state.conversationId;
    if (convId == null || state.streaming) return;
    // replace last assistant
    final msgs = [...state.messages];
    while (msgs.isNotEmpty && msgs.last.role == 'assistant') {
      msgs.removeLast();
    }
    final assistantId = 'local-a-${DateTime.now().microsecondsSinceEpoch}';
    msgs.add(ChatMessage(
      id: assistantId,
      role: 'assistant',
      content: '',
      streaming: true,
      modelId: state.modelId,
    ));
    state = state.copyWith(messages: msgs, streaming: true, clearError: true);
    _cancel = CancelToken();
    var buffer = '';
    try {
      await for (final event in _api.postSse(
        ApiPaths.conversationRegenerate(convId),
        data: {'mode': state.mode},
        cancelToken: _cancel,
      )) {
        if (event.event == 'token') {
          buffer += '${event.data['text'] ?? ''}';
          _patchAssistant(assistantId, buffer, streaming: true);
        } else if (event.event == 'error') {
          final err = '${event.data['error_message_fa'] ?? 'خطا'}';
          _patchAssistant(assistantId, buffer, streaming: false, error: err);
          state = state.copyWith(streaming: false);
          return;
        }
      }
      _patchAssistant(assistantId, buffer, streaming: false);
      state = state.copyWith(streaming: false);
      await _ref.read(authControllerProvider.notifier).refreshMe();
    } on ApiException catch (e) {
      state = state.copyWith(streaming: false, error: e.message);
    }
  }

  void _patchAssistant(
    String id,
    String content, {
    required bool streaming,
    String? error,
  }) {
    final msgs = [...state.messages];
    final idx = msgs.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    msgs[idx] = msgs[idx].copyWith(
      content: content,
      streaming: streaming,
      errorFa: error,
    );
    state = state.copyWith(messages: msgs);
  }
}

final chatSessionProvider = StateNotifierProvider.autoDispose
    .family<ChatSessionController, ChatSessionState, String?>((ref, id) {
  return ChatSessionController(ref, id);
});

List<dynamic> _asList(dynamic data, {List<String> keys = const []}) {
  if (data is List) return data;
  if (data is Map) {
    for (final k in keys) {
      final v = data[k];
      if (v is List) return v;
    }
  }
  return const [];
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api_client.dart';
import '../../core/api_paths.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

const _lastPathKey = 'pigpt_agent_last_path';

class AgentWorkspaceState {
  const AgentWorkspaceState({
    this.items = const [],
    this.current,
    this.loading = true,
    this.error,
  });

  final List<AgentWorkspace> items;
  final AgentWorkspace? current;
  final bool loading;
  final String? error;

  AgentWorkspaceState copyWith({
    List<AgentWorkspace>? items,
    AgentWorkspace? current,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearCurrent = false,
  }) =>
      AgentWorkspaceState(
        items: items ?? this.items,
        current: clearCurrent ? null : (current ?? this.current),
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AgentWorkspaceController extends StateNotifier<AgentWorkspaceState> {
  AgentWorkspaceController(this._ref) : super(const AgentWorkspaceState()) {
    load();
  }

  final Ref _ref;
  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final data = await _api.get<Map<String, dynamic>>(
        ApiPaths.agentWorkspaces,
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final raw = data['items'] ?? data['workspaces'] ?? data['data'];
      final items = <AgentWorkspace>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) {
            items.add(AgentWorkspace.fromJson(Map<String, dynamic>.from(e)));
          }
        }
      }
      AgentWorkspace? current;
      final cur = data['current'];
      if (cur is Map) {
        current = AgentWorkspace.fromJson(Map<String, dynamic>.from(cur));
      }
      current ??= items.isNotEmpty ? items.first : null;
      if (current == null) {
        final prefs = await SharedPreferences.getInstance();
        final last = prefs.getString(_lastPathKey);
        if (last != null && last.isNotEmpty) {
          for (final w in items) {
            if (w.slug == last || w.path == last || w.id == last) {
              current = w;
              break;
            }
          }
        }
      }
      if (current != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_lastPathKey, current.slug.isNotEmpty ? current.slug : current.path);
      }
      state = state.copyWith(
        items: items,
        current: current,
        loading: false,
        clearCurrent: current == null,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<AgentWorkspace?> create(String name) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiPaths.agentWorkspaces,
        data: {'name': n},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final w = AgentWorkspace.fromJson(data);
      final items = [w, ...state.items.where((x) => x.slug != w.slug)];
      state = state.copyWith(items: items, current: w, loading: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastPathKey, w.slug);
      return w;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    }
  }

  Future<void> select(AgentWorkspace w) async {
    state = state.copyWith(current: w);
    try {
      await _api.post(ApiPaths.agentWorkspaceSelect(w.id.isNotEmpty ? w.id : w.slug));
    } on ApiException {
      /* keep local */
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPathKey, w.slug.isNotEmpty ? w.slug : w.path);
  }
}

final agentWorkspaceProvider =
    StateNotifierProvider<AgentWorkspaceController, AgentWorkspaceState>(
  (ref) => AgentWorkspaceController(ref),
);

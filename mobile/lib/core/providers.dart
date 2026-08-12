import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'api_paths.dart';
import 'models.dart';
import 'token_store.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final authRefreshProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return ApiClient(
    tokenStore: store,
    onUnauthorized: () {
      ref.read(authRefreshProvider.notifier).state++;
    },
  );
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

/// UI locale from Settings (`ui_locale`). Defaults to Persian.
final localeProvider = StateProvider<Locale>((ref) => const Locale('fa'));

/// Whether TTS output is enabled (from settings.speech.voice_output).
final speechOutputEnabledProvider = StateProvider<bool>((ref) => true);

enum AuthStatus { unknown, signedOut, signedIn, needsVerification }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
  });
  final AuthStatus status;
  final UserMe? user;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserMe? user,
    String? error,
    bool clearUser = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        error: error,
      );
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState(status: AuthStatus.unknown)) {
    bootstrap();
  }

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);
  TokenStore get _store => _ref.read(tokenStoreProvider);

  Future<void> bootstrap() async {
    final token = await _store.read();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.signedOut);
      return;
    }
    try {
      final me = await _api.get<UserMe>(
        ApiPaths.me,
        parser: (d) => UserMe.fromJson(Map<String, dynamic>.from(d as Map)),
      );
      if (!me.emailVerified) {
        state = AuthState(status: AuthStatus.needsVerification, user: me);
      } else {
        state = AuthState(status: AuthStatus.signedIn, user: me);
      }
    } catch (_) {
      await _store.clear();
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<void> refreshMe() async {
    try {
      final me = await _api.get<UserMe>(
        ApiPaths.me,
        parser: (d) => UserMe.fromJson(Map<String, dynamic>.from(d as Map)),
      );
      state = AuthState(
        status: me.emailVerified
            ? AuthStatus.signedIn
            : AuthStatus.needsVerification,
        user: me,
      );
    } catch (e) {
      // keep prior state on soft refresh failure
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiPaths.login,
        data: {'email': email.trim(), 'password': password},
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final token = '${data['access_token'] ?? data['token'] ?? ''}';
      if (token.isEmpty) throw ApiException('توکن دریافت نشد');
      await _store.write(token);
      await bootstrap();
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.signedOut, error: e.message);
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
    String? phone,
  }) async {
    try {
      final data = await _api.post<Map<String, dynamic>>(
        ApiPaths.register,
        data: {
          'email': email.trim(),
          'password': password,
          if (displayName != null && displayName.trim().isNotEmpty)
            'display_name': displayName.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        },
        parser: (d) => Map<String, dynamic>.from(d as Map),
      );
      final token = '${data['access_token'] ?? data['token'] ?? ''}';
      if (token.isNotEmpty) {
        await _store.write(token);
        await bootstrap();
      } else {
        // registration may require email verify without immediate token
        state = const AuthState(status: AuthStatus.needsVerification);
      }
    } on ApiException {
      rethrow;
    }
  }

  Future<void> resendVerification() async {
    final email = state.user?.email;
    if (email == null) return;
    await _api.post(ApiPaths.resendVerification, data: {'email': email});
  }

  Future<void> verifyEmail(String token) async {
    await _api.post(ApiPaths.verifyEmail, data: {'token': token});
    await bootstrap();
  }

  Future<void> logout() async {
    await _store.clear();
    state = const AuthState(status: AuthStatus.signedOut);
  }

  /// Apply JWT from Google OAuth deep-link return (custom scheme / App Link).
  Future<void> applyOAuthToken(String token) async {
    final t = token.trim();
    if (t.isEmpty) return;
    await _store.write(t);
    await bootstrap();
  }

  Future<AuthMethods> fetchMethods() async {
    return _api.get(
      ApiPaths.authMethods,
      parser: (d) => AuthMethods.fromJson(Map<String, dynamic>.from(d as Map)),
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  ref.watch(authRefreshProvider);
  return AuthController(ref);
});

final meProvider = Provider<UserMe?>((ref) => ref.watch(authControllerProvider).user);

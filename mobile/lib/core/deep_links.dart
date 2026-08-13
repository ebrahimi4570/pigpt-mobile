import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand.dart';
import 'providers.dart';
import 'router.dart';

/// Listens for OAuth / verify / chat / CLI / payment App Links and routes in-app.
class DeepLinkBootstrap extends ConsumerStatefulWidget {
  const DeepLinkBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkBootstrap> createState() => _DeepLinkBootstrapState();
}

class _DeepLinkBootstrapState extends ConsumerState<DeepLinkBootstrap> {
  StreamSubscription<Uri>? _sub;
  final _appLinks = AppLinks();
  String? _lastHandled;

  @override
  void initState() {
    super.initState();
    _appLinks.getInitialLink().then(_handle);
    _sub = _appLinks.uriLinkStream.listen(_handle);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _handle(Uri? uri) async {
    if (uri == null) return;
    final key = uri.toString();
    if (_lastHandled == key) return;
    _lastHandled = key;

    // 1) OAuth access token (or error= from Google)
    final oauthErr = _extractOAuthError(uri);
    if (oauthErr != null) {
      ref.read(authControllerProvider.notifier);
      return;
    }
    final token = _extractAccessToken(uri);
    if (token != null && token.isNotEmpty) {
      await ref.read(authControllerProvider.notifier).applyOAuthToken(token);
      return;
    }

    final router = ref.read(goRouterProvider);

    // 2) Email verify — pigpt://auth/verify?token= / https://pigpt.ir/auth/verify
    final verifyToken = _extractVerifyToken(uri);
    if (verifyToken != null && verifyToken.isNotEmpty) {
      router.go('/auth/verify?token=${Uri.encodeComponent(verifyToken)}');
      return;
    }

    // 3) CLI authorize
    final cliCode = _extractCliCode(uri);
    if (cliCode != null) {
      router.go(
        '/app/cli/authorize?user_code=${Uri.encodeComponent(cliCode)}',
      );
      return;
    }

    // 4) Open chat /app/c/:id
    final chatId = _extractChatId(uri);
    if (chatId != null && chatId.isNotEmpty) {
      router.go('/chat/$chatId');
      return;
    }

    // 5) Public share /share/:token
    final shareToken = _extractShareToken(uri);
    if (shareToken != null && shareToken.isNotEmpty) {
      router.go('/share/$shareToken');
      return;
    }

    // 6) Payment return — backend redirects to /app?billing=ok|failed|missing
    final billing = _extractBillingStatus(uri);
    if (billing != null) {
      await ref.read(authControllerProvider.notifier).refreshMe();
      router.go('/account/plans?billing=$billing');
      return;
    }

    // 7) Quick Start /app/quick-start/:cardId
    final qs = _extractQuickStart(uri);
    if (qs != null) {
      router.go(qs == 'hub' ? '/quick-start' : '/quick-start/$qs');
      return;
    }
  }

  static bool _isOAuthCallback(Uri uri) {
    final isCustom = uri.scheme == 'pigpt' &&
        (uri.host == 'auth' || uri.pathSegments.contains('auth')) &&
        (uri.path == '/callback' ||
            uri.path.startsWith('/callback') ||
            uri.path.endsWith('/callback'));
    final isAppLink = uri.scheme == 'https' &&
        uri.host == 'pigpt.ir' &&
        (uri.path == '/app/auth/callback' ||
            uri.path.startsWith('/app/auth/callback'));
    return isCustom || isAppLink;
  }

  static String? _extractOAuthError(Uri uri) {
    if (!_isOAuthCallback(uri)) return null;
    final e = uri.queryParameters['error'] ?? uri.queryParameters['error_description'];
    return (e != null && e.isNotEmpty) ? e : null;
  }

  /// Accepts `pigpt://auth/callback` and `https://pigpt.ir/app/auth/callback`
  /// with `access_token` in query or fragment.
  static String? _extractAccessToken(Uri uri) {
    if (!_isOAuthCallback(uri)) return null;

    final q = uri.queryParameters['access_token'];
    if (q != null && q.isNotEmpty) return q;
    if (uri.fragment.isNotEmpty) {
      final frag = Uri.splitQueryString(uri.fragment);
      final t = frag['access_token'];
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  static String? _extractVerifyToken(Uri uri) {
    final pathOk = uri.path.contains('verify') ||
        (uri.host == 'auth' && uri.path.contains('verify'));
    final schemeOk = uri.scheme == 'pigpt' ||
        (uri.scheme == 'https' && uri.host == 'pigpt.ir');
    if (!schemeOk || !pathOk) return null;
    final t = uri.queryParameters['token'] ?? uri.queryParameters['t'];
    return (t != null && t.isNotEmpty) ? t : null;
  }

  static String? _extractCliCode(Uri uri) {
    final isCli = (uri.scheme == 'pigpt' &&
            (uri.host == 'cli' || uri.path.contains('cli'))) ||
        (uri.scheme == 'https' &&
            uri.host == 'pigpt.ir' &&
            uri.path.contains('/app/cli/authorize'));
    if (!isCli) return null;
    return uri.queryParameters['user_code'] ??
        uri.queryParameters['code'] ??
        uri.queryParameters['userCode'];
  }

  static String? _extractChatId(Uri uri) {
    // /app/c/:id or pigpt://c/:id or pigpt://app/c/:id
    final segs = uri.pathSegments;
    if (uri.scheme == 'https' && uri.host == 'pigpt.ir') {
      // /app/c/:id
      final i = segs.indexOf('c');
      if (i >= 0 && i + 1 < segs.length && segs.contains('app')) {
        return segs[i + 1];
      }
    }
    if (uri.scheme == 'pigpt') {
      final i = segs.indexOf('c');
      if (i >= 0 && i + 1 < segs.length) return segs[i + 1];
      if (uri.host == 'c' && segs.isNotEmpty) return segs.first;
    }
    return null;
  }

  static String? _extractShareToken(Uri uri) {
    final segs = uri.pathSegments;
    final i = segs.indexOf('share');
    if (i >= 0 && i + 1 < segs.length) {
      if (uri.scheme == 'https' && uri.host == 'pigpt.ir') return segs[i + 1];
      if (uri.scheme == 'pigpt') return segs[i + 1];
    }
    return null;
  }

  static String? _extractQuickStart(Uri uri) {
    final segs = uri.pathSegments;
    final okHost = (uri.scheme == 'https' && uri.host == 'pigpt.ir') ||
        uri.scheme == 'pigpt';
    if (!okHost) return null;
    final i = segs.indexOf('quick-start');
    if (i < 0) return null;
    if (i + 1 < segs.length && segs[i + 1].isNotEmpty) return segs[i + 1];
    return 'hub';
  }

  /// Backend payment callback redirects to `{web}/app?billing=ok|failed|missing`.
  static String? _extractBillingStatus(Uri uri) {
    final billing = uri.queryParameters['billing'];
    if (billing == null || billing.isEmpty) return null;
    final isAppRoot = (uri.scheme == 'https' &&
            uri.host == 'pigpt.ir' &&
            (uri.path == '/app' ||
                uri.path == '/app/' ||
                uri.path == PigptBrand.paymentReturnPath)) ||
        (uri.scheme == 'pigpt' &&
            (uri.host == 'app' || uri.path.startsWith('/app')));
    if (!isAppRoot) return null;
    return billing;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Builds the Google OAuth start URL with a mobile-safe `next` redirect.
String googleOAuthStartUrl({String? next}) {
  final n = next ?? PigptBrand.oauthCallback;
  return Uri.parse('${PigptBrand.apiBase}/api/v1/auth/google/start').replace(
    queryParameters: {'next': n},
  ).toString();
}

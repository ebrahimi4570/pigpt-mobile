import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand.dart';
import 'providers.dart';

/// Listens for OAuth / App Link returns and applies the session in-app.
class DeepLinkBootstrap extends ConsumerStatefulWidget {
  const DeepLinkBootstrap({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DeepLinkBootstrap> createState() => _DeepLinkBootstrapState();
}

class _DeepLinkBootstrapState extends ConsumerState<DeepLinkBootstrap> {
  StreamSubscription<Uri>? _sub;
  final _appLinks = AppLinks();

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
    final token = _extractAccessToken(uri);
    if (token == null || token.isEmpty) return;
    await ref.read(authControllerProvider.notifier).applyOAuthToken(token);
  }

  static String? _extractAccessToken(Uri uri) {
    final isCustom = uri.scheme == 'pigpt' &&
        uri.host == 'auth' &&
        (uri.path == '/callback' || uri.path.startsWith('/callback'));
    final isAppLink = uri.scheme == 'https' &&
        uri.host == 'pigpt.ir' &&
        (uri.path == '/app/auth/callback' ||
            uri.path.startsWith('/app/auth/callback'));
    if (!isCustom && !isAppLink) return null;

    final q = uri.queryParameters['access_token'];
    if (q != null && q.isNotEmpty) return q;
    if (uri.fragment.isNotEmpty) {
      final frag = Uri.splitQueryString(uri.fragment);
      final t = frag['access_token'];
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
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

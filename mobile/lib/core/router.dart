import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screens.dart';
import '../features/account/settings_screen.dart';
import '../features/account/usage_referral_support.dart';
import '../features/agent/agent_screens.dart';
import '../features/auth/auth_screen.dart';
import '../features/chat/chat_screens.dart';
import '../features/picode_guide/picode_screen.dart';
import '../features/quick_start/quick_start_screens.dart';
import '../features/share/share_screen.dart';
import '../features/studios/image_studio_screen.dart';
import '../features/studios/studios_screens.dart';
import '../features/studios/writing_studio_screen.dart';
import '../shared/widgets/shell.dart';
import 'providers.dart';
import 'studio_catalog.dart';

final _rootKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggingIn = loc.startsWith('/auth');
      final splash = loc == '/splash';
      final publicShare = loc.startsWith('/share/');

      if (publicShare) return null;

      if (auth.status == AuthStatus.unknown || splash) {
        if (auth.status == AuthStatus.unknown) return '/splash';
        if (auth.status == AuthStatus.signedIn) return '/chat';
        if (auth.status == AuthStatus.needsVerification) return '/auth/verify';
        if (auth.status == AuthStatus.signedOut) return '/auth';
      }

      if (auth.status == AuthStatus.signedOut && !loggingIn) {
        return '/auth';
      }
      if (auth.status == AuthStatus.needsVerification &&
          loc != '/auth/verify') {
        return '/auth/verify';
      }
      if (auth.status == AuthStatus.signedIn &&
          (loggingIn || loc == '/splash')) {
        return '/chat';
      }
      // Never expose admin routes
      if (loc.startsWith('/admin')) return '/chat';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/share/:token',
        builder: (_, state) => ShareViewerScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, state) => AuthScreen(
          mode: state.uri.queryParameters['mode'] ?? 'login',
        ),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (_, state) => VerifyEmailScreen(
              token: state.uri.queryParameters['token'],
            ),
          ),
          GoRoute(
            path: 'callback',
            builder: (_, __) => const AuthScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                builder: (_, state) {
                  final extra = state.extra;
                  final modelId = extra is String
                      ? extra
                      : (extra is Map
                          ? extra['model_id']?.toString()
                          : null);
                  // Home = new-chat composer (archive/list is secondary).
                  return ChatThreadScreen(
                    conversationId: null,
                    initialModelId: modelId,
                    isHome: true,
                  );
                },
                routes: [
                  GoRoute(
                    path: 'history',
                    builder: (_, __) => const ChatListScreen(),
                  ),
                  GoRoute(
                    path: 'new',
                    builder: (_, state) {
                      final extra = state.extra;
                      final modelId = extra is String
                          ? extra
                          : (extra is Map
                              ? extra['model_id']?.toString()
                              : null);
                      return ChatThreadScreen(
                        conversationId: null,
                        initialModelId: modelId,
                        isHome: true,
                      );
                    },
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => ChatThreadScreen(
                      conversationId: state.pathParameters['id'],
                      initialModelId: state.uri.queryParameters['model'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quick-start',
                builder: (_, __) => const QuickStartHubScreen(),
                routes: [
                  GoRoute(
                    path: ':cardId',
                    builder: (_, state) => QuickStartWizardScreen(
                      cardId: state.pathParameters['cardId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/studios',
                builder: (_, __) => const StudiosHubScreen(),
                routes: [
                  GoRoute(
                    path: 'gallery',
                    builder: (_, __) => const GalleryScreen(),
                  ),
                  ...StudioCatalog.allTools.map(
                    (t) => GoRoute(
                      path: t.routeName ?? 'studio-${t.id}',
                      builder: (_, __) {
                        if (t.id == 'image') {
                          return const ImageStudioScreen();
                        }
                        if (t.id == 'writing') {
                          return const WritingStudioScreen();
                        }
                        return StudioWorkspaceScreen(
                          toolId: t.id,
                          title: t.label,
                          capability: t.capability,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (_, __) => const AccountHubScreen(),
                routes: [
                  GoRoute(
                    path: 'plans',
                    builder: (_, state) => PlansScreen(
                      billingStatus: state.uri.queryParameters['billing'],
                    ),
                  ),
                  GoRoute(
                    path: 'usage',
                    builder: (_, __) => const UsageScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: 'referral',
                    builder: (_, __) => const ReferralScreen(),
                  ),
                  GoRoute(
                    path: 'support',
                    builder: (_, __) => const SupportScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, state) => SupportTicketDetailScreen(
                          id: state.pathParameters['id']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'picode',
                    builder: (_, __) => const PiCodeGuideScreen(),
                  ),
                  GoRoute(
                    path: 'about',
                    builder: (_, __) => const AboutScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/models',
        builder: (_, __) => const ModelsScreen(),
      ),
      GoRoute(
        path: '/agent',
        builder: (_, __) => const AgentMissionsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => AgentMissionDetailScreen(
              id: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/app/cli/authorize',
        builder: (_, state) => PiCodeGuideScreen(
          initialCode: state.uri.queryParameters['user_code'] ??
              state.uri.queryParameters['code'],
        ),
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}

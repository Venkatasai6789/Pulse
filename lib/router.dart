import 'screens/sensor/sensor_pairing_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth/auth_state.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/community/community_screen.dart';
import 'screens/community/new_post_screen.dart';
import 'screens/community/report_concern_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/locations/location_detail_screen.dart';
import 'screens/locations/locations_screen.dart';
import 'screens/locations/register_location_screen.dart';
import 'screens/main_shell_screen.dart';
import 'screens/monitor/monitor_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/results/results_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter(AuthState authState) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authState,
    redirect: (BuildContext context, GoRouterState state) {
      final loc = state.matchedLocation;
      final status = authState.status;

      // 1. Initializing / waiting for first auth event
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }

      // 2. Signed out: can only be on /sign-in (or /splash during init)
      if (status == AuthStatus.signedOut) {
        if (loc == '/sign-in') return null;
        return '/sign-in';
      }

      // 3. Signed in or Guest
      if (status == AuthStatus.signedIn || status == AuthStatus.guest) {
        // If user needs first-time profile setup
        if (authState.needsProfileSetup) {
          if (loc == '/profile-setup') return null;
          return '/profile-setup';
        }

        // If trying to access auth screens, redirect to home
        if (loc == '/splash' || loc == '/sign-in' || loc == '/profile-setup') {
          return '/';
        }
        return null;
      }

      return null;
    },
    routes: [
      // ------------------------------------------------------------- Auth
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const SignInScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: '/profile-setup',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileSetupScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),

      // ------------------------------------------------ Main Tabs (Shell)
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state, navigationShell) {
          return MainShellScreen(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) => CustomTransitionPage(
                  key: state.pageKey,
                  child: const HomeScreen(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    final curved = CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    );
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(curved),
                      child: FadeTransition(opacity: curved, child: child),
                    );
                  },
                ),
              ),
            ],
          ),
          // Tab 1: Monitor (New Assessment)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/monitor',
                builder: (context, state) => MonitorScreen(
                  preselectedLocationId: state.uri.queryParameters['locationId'],
                ),
              ),
            ],
          ),
          // Tab 2: Locations
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/locations',
                builder: (context, state) => const LocationsScreen(),
              ),
            ],
          ),
          // Tab 3: Community
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
          // Tab 4: Profile
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ------------------------------------------------ Top-level Sub-routes
      GoRoute(
        path: '/results/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ResultsScreen(id: state.pathParameters['id'] ?? 'unknown'),
      ),
      GoRoute(
        path: '/location/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RegisterLocationScreen(),
      ),
      GoRoute(
        path: '/location/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            LocationDetailScreen(id: state.pathParameters['id'] ?? 'unknown'),
      ),
      GoRoute(
        path: '/reports',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/report-concern',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ReportConcernScreen(),
      ),
      GoRoute(
        path: '/sensor/pair',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SensorPairingScreen(),
      ),
      GoRoute(
        path: '/post/new',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NewPostScreen(),
      ),
    ],
  );
}

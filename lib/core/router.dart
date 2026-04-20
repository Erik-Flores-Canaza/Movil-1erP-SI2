import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/vehicles/vehicles_screen.dart';
import '../screens/emergency/report_emergency_screen.dart';
import '../screens/emergency/monitor_screen.dart';
import '../screens/emergency/my_emergencies_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/tecnico/tecnico_home_screen.dart';

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLoggedIn = authProvider.isAuthenticated;
      final rol = authProvider.user?.rol;
      final isOnSplash = location == '/splash';
      final isOnAuth = location == '/login' || location == '/register';

      // Splash manages its own navigation — never redirect away from it
      if (isOnSplash) return null;

      // Not authenticated → force login
      if (!isLoggedIn && !isOnAuth) return '/login';

      // Already authenticated and on auth screens → role-based redirect
      if (isLoggedIn && isOnAuth) {
        return rol == 'tecnico' ? '/tecnico-home' : '/home';
      }

      // Técnico tries to access cliente-only routes → redirect to their home
      // /notifications is shared between roles — NOT blocked here
      if (isLoggedIn && rol == 'tecnico') {
        const clienteOnlyRoutes = {
          '/home',
          '/report-emergency',
          '/my-emergencies',
        };
        if (clienteOnlyRoutes.contains(location)) return '/tecnico-home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionsBuilder: _slideFromRight,
        ),
      ),

      // ── Cliente routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionsBuilder: _slideFromRight,
        ),
      ),
      GoRoute(
        path: '/vehicles',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const VehiclesScreen(),
          transitionsBuilder: _slideFromRight,
        ),
      ),
      GoRoute(
        path: '/report-emergency',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ReportEmergencyScreen(),
          transitionsBuilder: _slideFromBottom,
        ),
      ),
      GoRoute(
        path: '/monitor/:id',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: MonitorScreen(
            incidenteId: state.pathParameters['id']!,
          ),
          transitionsBuilder: _slideFromRight,
        ),
      ),
      GoRoute(
        path: '/my-emergencies',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const MyEmergenciesScreen(),
          transitionsBuilder: _slideFromRight,
        ),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NotificationsScreen(),
          transitionsBuilder: _slideFromRight,
        ),
      ),

      // ── Técnico routes ─────────────────────────────────────────────────
      GoRoute(
        path: '/tecnico-home',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const TecnicoHomeScreen(),
          transitionsBuilder: _fadeTransition,
        ),
      ),
    ],
  );
}

Widget _fadeTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    FadeTransition(opacity: animation, child: child);

Widget _slideFromRight(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    );

Widget _slideFromBottom(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) =>
    SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    );

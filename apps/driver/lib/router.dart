import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import 'features/jobs/jobs_screen.dart';

/// Pure routing decision: only drivers get past the login.
String? driverRedirect(AuthView view, String location) {
  switch (view) {
    case AuthLoading():
      return location == '/splash' ? null : '/splash';
    case AuthSignedOut():
      return location == '/login' ? null : '/login';
    case AuthNoAccess():
      return location == '/no-access' ? null : '/no-access';
    case AuthSignedIn(:final profile):
      if (profile.role != UserRole.driver) return location == '/no-access' ? null : '/no-access';
      if (const {'/login', '/splash', '/no-access', '/'}.contains(location)) return '/jobs';
      return null;
  }
}

final driverRouterProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthView>(ref.read(authViewProvider));
  ref.listen(authViewProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => driverRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => LoginScreen(subtitle: (s) => s.driverAppTitle)),
      GoRoute(
        path: '/no-access',
        builder: (_, _) => NoAccessScreen(allowed: const {UserRole.driver}, wrongAppMessage: (s) => s.useOfficeApp),
      ),
      GoRoute(path: '/jobs', builder: (_, _) => const JobsScreen()),
    ],
  );
});

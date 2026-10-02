import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import 'shell/office_shell.dart';
import 'shell/placeholder_page.dart';

/// Every page in the office app, with who may open it.
enum OfficePage {
  dashboard('/dashboard', Icons.space_dashboard_outlined, {UserRole.admin, UserRole.operator, UserRole.officer}),
  vehicles('/vehicles', Icons.local_shipping_outlined, {UserRole.admin, UserRole.operator, UserRole.officer}),
  newChallan('/challans/new', Icons.add_circle_outline, {UserRole.admin, UserRole.operator}),
  challans('/challans', Icons.receipt_long_outlined, {UserRole.admin, UserRole.operator, UserRole.officer}),
  reports('/reports', Icons.bar_chart_outlined, {UserRole.admin, UserRole.operator, UserRole.officer}),
  map('/map', Icons.map_outlined, {UserRole.admin, UserRole.operator, UserRole.officer}),
  masters('/masters', Icons.tune_outlined, {UserRole.admin}),
  audit('/audit', Icons.history_outlined, {UserRole.admin}),
  paymentSimulator('/payment-simulator', Icons.payments_outlined, {UserRole.admin});

  const OfficePage(this.path, this.icon, this.roles);
  final String path;
  final IconData icon;
  final Set<UserRole> roles;

  String label(S s) => switch (this) {
        dashboard => s.dashboard,
        vehicles => s.vehicleBoard,
        newChallan => s.newChallan,
        challans => s.challans,
        reports => s.reports,
        map => s.map,
        masters => s.masters,
        audit => s.auditLog,
        paymentSimulator => s.paymentSimulator,
      };

  /// Which phase builds the real screen (shown on the placeholder until then).
  int get phase => switch (this) {
        vehicles || masters => 2,
        newChallan || challans => 3,
        paymentSimulator => 5,
        _ => 6,
      };

  static List<OfficePage> forRole(UserRole r) => values.where((p) => p.roles.contains(r)).toList();

  /// The page whose path best matches [location] (longest prefix).
  static OfficePage? match(String location) {
    OfficePage? best;
    for (final p in values) {
      if (location == p.path || location.startsWith('${p.path}/')) {
        if (best == null || p.path.length > best.path.length) best = p;
      }
    }
    return best;
  }
}

/// Pure routing decision, unit-testable without Supabase.
String? officeRedirect(AuthView view, String location) {
  const open = {'/login', '/splash', '/no-access'};
  switch (view) {
    case AuthLoading():
      return location == '/splash' ? null : '/splash';
    case AuthSignedOut():
      return location == '/login' ? null : '/login';
    case AuthNoAccess():
      return location == '/no-access' ? null : '/no-access';
    case AuthSignedIn(:final profile):
      if (!profile.role.isOfficeUser) return location == '/no-access' ? null : '/no-access';
      if (open.contains(location) || location == '/') return OfficePage.dashboard.path;
      final page = OfficePage.match(location);
      if (page != null && !page.roles.contains(profile.role)) return OfficePage.dashboard.path;
      return null;
  }
}

final officeRouterProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthView>(ref.read(authViewProvider));
  ref.listen(authViewProvider, (_, next) => auth.value = next);
  ref.onDispose(auth.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) => officeRedirect(auth.value, state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => LoginScreen(subtitle: (s) => s.officeAppTitle)),
      GoRoute(
        path: '/no-access',
        builder: (_, _) => NoAccessScreen(
          allowed: const {UserRole.admin, UserRole.operator, UserRole.officer},
          wrongAppMessage: (s) => s.useDriverApp,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => OfficeShell(location: state.matchedLocation, child: child),
        routes: [
          for (final p in OfficePage.values)
            GoRoute(
              path: p.path,
              pageBuilder: (_, _) => NoTransitionPage(child: PlaceholderPage(page: p)),
            ),
        ],
      ),
    ],
  );
});

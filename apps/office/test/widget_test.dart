import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasa_core/testing.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_office/router.dart';
import 'package:wasa_ui/wasa_ui.dart';

Profile _profile(UserRole role) => Profile(
      id: 'u1',
      fullName: 'Rabia Noor',
      role: role,
      tehsilId: 't1',
      tehsilCode: 'BKR',
      tehsilName: 'Bhakkar',
    );

void main() {
  group('role-based routing', () {
    test('signed out goes to login', () {
      expect(officeRedirect(const AuthSignedOut(), '/dashboard'), '/login');
      expect(officeRedirect(const AuthSignedOut(), '/login'), isNull);
    });

    test('signed-in staff land on the dashboard', () {
      expect(officeRedirect(AuthSignedIn(_profile(UserRole.operator)), '/login'), '/dashboard');
      expect(officeRedirect(AuthSignedIn(_profile(UserRole.operator)), '/challans/new'), isNull);
    });

    test('officer is read-only: no new challan, no admin pages', () {
      final officer = AuthSignedIn(_profile(UserRole.officer));
      expect(officeRedirect(officer, '/challans/new'), '/dashboard');
      expect(officeRedirect(officer, '/masters'), '/dashboard');
      expect(officeRedirect(officer, '/challans'), isNull);
    });

    test('operator cannot open admin pages', () {
      final op = AuthSignedIn(_profile(UserRole.operator));
      expect(officeRedirect(op, '/payment-simulator'), '/dashboard');
      expect(officeRedirect(op, '/audit'), '/dashboard');
    });

    test('admin can open everything', () {
      final admin = AuthSignedIn(_profile(UserRole.admin));
      for (final p in OfficePage.values) {
        expect(officeRedirect(admin, p.path), isNull, reason: p.path);
      }
    });

    test('drivers are sent away from the office app', () {
      expect(officeRedirect(AuthSignedIn(_profile(UserRole.driver)), '/dashboard'), '/no-access');
    });
  });

  testWidgets('login shows a friendly error for a wrong password', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp(
        theme: WasaTheme.light(),
        home: LoginScreen(subtitle: (s) => s.officeAppTitle),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Service Challan System'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('login-username')), 'operator1');
    await tester.enterText(find.byKey(const Key('login-password')), 'wrong');
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pumpAndSettle();

    expect(auth.signInCalls, 1);
    expect(find.text('Wrong username or password.'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasa_core/testing.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_driver/main.dart';
import 'package:wasa_driver/router.dart';
import 'package:wasa_ui/wasa_ui.dart';

Profile _profile(UserRole role) => Profile(
      id: 'u1',
      fullName: 'Ghulam Abbas',
      role: role,
      tehsilId: 't1',
      tehsilCode: 'BKR',
      tehsilName: 'Bhakkar',
    );

void main() {
  test('only drivers get into the driver app', () {
    expect(driverRedirect(AuthSignedIn(_profile(UserRole.driver)), '/login'), '/jobs');
    expect(driverRedirect(AuthSignedIn(_profile(UserRole.operator)), '/jobs'), '/no-access');
    expect(driverRedirect(const AuthSignedOut(), '/jobs'), '/login');
  });

  testWidgets('login is in Urdu by default and can switch to English', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [...driverOverrides, authRepositoryProvider.overrideWithValue(FakeAuthRepository())],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: WasaTheme.light(touch: true),
          home: Directionality(
            textDirection: ref.watch(langProvider).direction,
            child: LoginScreen(subtitle: (s) => s.driverAppTitle),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('لاگ ان کریں'), findsOneWidget);
    expect(find.text('واسا ڈرائیور'), findsOneWidget);

    await tester.tap(find.byType(LanguageToggle));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
  });
}

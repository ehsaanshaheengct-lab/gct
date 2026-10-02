import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import 'router.dart';

/// Urdu is the default language in the driver app.
final driverOverrides = [defaultLangProvider.overrideWithValue(AppLang.ur)];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // numbers and dates are always formatted the same way, whatever the PC/phone locale
  Intl.defaultLocale = 'en_US';
  if (!AppConfig.isConfigured) {
    runApp(ProviderScope(
      overrides: driverOverrides,
      child: const _Bare(child: NotConfiguredScreen(runCommand: 'flutter run --dart-define-from-file=env.json')),
    ));
    return;
  }
  // the session is kept on the phone, so the driver signs in only once
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
  runApp(ProviderScope(overrides: driverOverrides, child: const DriverApp()));
}

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return MaterialApp.router(
      title: 'WASA Driver',
      debugShowCheckedModeBanner: false,
      theme: WasaTheme.light(touch: true),
      routerConfig: ref.watch(driverRouterProvider),
      locale: lang.locale,
      supportedLocales: const [Locale('ur'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

class _Bare extends ConsumerWidget {
  const _Bare({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: WasaTheme.light(touch: true),
        locale: ref.watch(langProvider).locale,
        supportedLocales: const [Locale('ur'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: child,
      );
}

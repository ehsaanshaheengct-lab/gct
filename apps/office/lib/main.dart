import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // numbers and dates are always formatted the same way, whatever the PC/phone locale
  Intl.defaultLocale = 'en_US';
  if (!AppConfig.isConfigured) {
    runApp(const ProviderScope(child: _Bare(child: NotConfiguredScreen(runCommand: 'flutter run -d windows --dart-define-from-file=env.json'))));
    return;
  }
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
  runApp(const ProviderScope(child: OfficeApp()));
}

class OfficeApp extends ConsumerWidget {
  const OfficeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return MaterialApp.router(
      title: 'WASA Bhakkar – Office',
      debugShowCheckedModeBanner: false,
      theme: WasaTheme.light(),
      routerConfig: ref.watch(officeRouterProvider),
      locale: lang.locale,
      supportedLocales: const [Locale('en'), Locale('ur')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Minimal app wrapper for screens shown before Supabase is available.
class _Bare extends StatelessWidget {
  const _Bare({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: WasaTheme.light(),
        home: child,
      );
}

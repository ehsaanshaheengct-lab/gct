import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';

import '../lang.dart';
import '../strings.dart';
import '../theme.dart';
import 'brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            WasaLogo(size: 80),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ]),
        ),
      );
}

/// Signed in but not allowed here (wrong app for the role, or no active profile).
class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key, required this.allowed, required this.wrongAppMessage});

  /// Roles this app is for.
  final Set<UserRole> allowed;
  final String Function(S s) wrongAppMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final view = ref.watch(authViewProvider);
    final message = switch (view) {
      AuthNoAccess(:final message) => message,
      AuthSignedIn(:final profile) when !allowed.contains(profile.role) => wrongAppMessage(s),
      _ => s.somethingWrong,
    };
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.block, size: 64, color: WasaColors.orange),
            const SizedBox(height: 12),
            Text(s.noAccessTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Wrap(spacing: 12, children: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(profileProvider),
                icon: const Icon(Icons.refresh),
                label: Text(s.retry),
              ),
              FilledButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                icon: const Icon(Icons.logout),
                label: Text(s.signOut),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Shown when the app was built without SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY.
class NotConfiguredScreen extends ConsumerWidget {
  const NotConfiguredScreen({super.key, required this.runCommand});
  final String runCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const WasaLogo(size: 72),
              const SizedBox(height: 16),
              Text(s.notConfiguredTitle, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(s.notConfiguredBody, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              SelectableText(runCommand, style: const TextStyle(fontFamily: 'monospace')),
            ]),
          ),
        ),
      ),
    );
  }
}

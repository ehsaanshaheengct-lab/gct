import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/profile.dart';
import 'repositories/auth_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));

final sessionProvider = StreamProvider<Session?>((ref) => ref.watch(authRepositoryProvider).sessionChanges());

/// Re-loads only when the signed-in user changes (not on every token refresh).
final profileProvider = FutureProvider<Profile?>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.value?.user.id));
  if (userId == null) return null;
  return ref.watch(authRepositoryProvider).loadProfile(userId);
});

/// Where the user stands, for routing.
sealed class AuthView {
  const AuthView();
}

class AuthLoading extends AuthView {
  const AuthLoading();
}

class AuthSignedOut extends AuthView {
  const AuthSignedOut();
}

/// Signed in, but the account has no active profile (or loading it failed).
class AuthNoAccess extends AuthView {
  const AuthNoAccess(this.message);
  final String message;
}

class AuthSignedIn extends AuthView {
  const AuthSignedIn(this.profile);
  final Profile profile;
}

final authViewProvider = Provider<AuthView>((ref) {
  final session = ref.watch(sessionProvider);
  if (session.isLoading && !session.hasValue) return const AuthLoading();
  if (session.value == null) return const AuthSignedOut();
  final profile = ref.watch(profileProvider);
  return switch (profile) {
    AsyncData(value: final p?) when p.isActive => AuthSignedIn(p),
    AsyncData() => const AuthNoAccess('This account has no active role. Ask the WASA admin.'),
    AsyncError() => const AuthNoAccess('Could not load your profile. Check the internet and try again.'),
    _ => const AuthLoading(),
  };
});

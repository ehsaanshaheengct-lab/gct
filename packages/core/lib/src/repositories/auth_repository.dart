import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/profile.dart';

/// A sign-in problem written for the person at the keyboard.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Session? get currentSession => _client.auth.currentSession;

  /// Emits the current session first (supabase_flutter replays it), then every change.
  Stream<Session?> sessionChanges() => _client.auth.onAuthStateChange.map((s) => s.session);

  Future<void> signIn(String usernameOrEmail, String password) async {
    if (usernameOrEmail.trim().isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter your username and password.');
    }
    try {
      await _client.auth.signInWithPassword(email: AppConfig.loginEmail(usernameOrEmail), password: password);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('invalid login') || m.contains('invalid credentials')) {
        throw const AuthFailure('Wrong username or password.');
      }
      throw AuthFailure('Could not sign in: ${e.message}');
    } on Exception {
      throw const AuthFailure('No connection to the server. Check the internet and try again.');
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  /// The profile of the signed-in user, or null if the account has no profile (no role assigned).
  Future<Profile?> loadProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('*, tehsil:tehsils(code, name_en)')
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : Profile.fromJson(row);
  }
}

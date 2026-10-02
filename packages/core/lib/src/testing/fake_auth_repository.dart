import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';
import '../repositories/auth_repository.dart';

/// In-memory [AuthRepository] for widget tests (no network).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.validUser = 'operator1', this.validPassword = 'Wasa@1234'});

  final String validUser;
  final String validPassword;
  final _sessions = StreamController<Session?>.broadcast();
  int signInCalls = 0;

  @override
  Session? get currentSession => null;

  @override
  Stream<Session?> sessionChanges() async* {
    yield null;
    yield* _sessions.stream;
  }

  @override
  Future<void> signIn(String usernameOrEmail, String password) async {
    signInCalls++;
    if (usernameOrEmail.trim().isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter your username and password.');
    }
    if (usernameOrEmail.trim() != validUser || password != validPassword) {
      throw const AuthFailure('Wrong username or password.');
    }
  }

  @override
  Future<void> signOut() async => _sessions.add(null);

  @override
  Future<Profile?> loadProfile(String userId) async => null;
}

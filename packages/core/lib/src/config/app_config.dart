/// Build-time configuration, passed with `--dart-define-from-file=env.json`.
///
/// Only the public key (Supabase "publishable" key, or the legacy "anon" key)
/// ever goes into the apps. The service key and the QR signing secret stay on the server.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// The publishable key, falling back to the legacy anon key.
  static String get supabaseKey => _publishableKey.isNotEmpty ? _publishableKey : _anonKey;

  /// Users type a short username (`operator1`); this domain is appended to make
  /// the Supabase Auth e-mail (`operator1@wasabhakkar.demo`).
  static const loginDomain = String.fromEnvironment('LOGIN_DOMAIN', defaultValue: 'wasabhakkar.demo');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// `operator1` -> `operator1@wasabhakkar.demo`; full e-mails are kept as typed.
  static String loginEmail(String usernameOrEmail) {
    final u = usernameOrEmail.trim().toLowerCase();
    return u.contains('@') ? u : '$u@$loginDomain';
  }
}

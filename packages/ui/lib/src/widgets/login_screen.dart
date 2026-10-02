import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';

import '../lang.dart';
import '../strings.dart';
import '../theme.dart';
import 'brand.dart';

/// Username + password sign-in, shared by both apps.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, required this.subtitle});

  /// The app name under the logo.
  final String Function(S s) subtitle;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(_user.text, _pass.text);
      // the router moves on by itself once the profile has loaded
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [WasaColors.blue, WasaColors.teal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(alignment: AlignmentDirectional.centerEnd, child: const LanguageToggle()),
                        WasaBrand(subtitle: widget.subtitle(s)),
                        const SizedBox(height: 28),
                        TextField(
                          key: const Key('login-username'),
                          controller: _user,
                          autofocus: true,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: s.username,
                            prefixIcon: const Icon(Icons.person_outline),
                            helperText: s.loginHint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const Key('login-password'),
                          controller: _pass,
                          obscureText: _hide,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: s.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hide ? 'Show' : 'Hide',
                              icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _hide = !_hide),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Text(_error!, key: const Key('login-error'), style: const TextStyle(color: WasaColors.red)),
                        ],
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          key: const Key('login-submit'),
                          onPressed: _busy ? null : _submit,
                          icon: _busy
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                              : const Icon(Icons.login),
                          label: Text(_busy ? s.signingIn : s.signIn),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';

enum AppLang {
  ur('ur', TextDirection.rtl),
  en('en', TextDirection.ltr);

  const AppLang(this.code, this.direction);
  final String code;
  final TextDirection direction;
  Locale get locale => Locale(code);
}

/// The chosen language, remembered on the device. Each app sets its default
/// by overriding [defaultLangProvider] (driver: Urdu, office: English).
final defaultLangProvider = Provider<AppLang>((ref) => AppLang.en);

class LangNotifier extends Notifier<AppLang> {
  static const _key = 'app_lang';

  @override
  AppLang build() {
    _load();
    return ref.watch(defaultLangProvider);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      final match = AppLang.values.where((l) => l.code == saved);
      if (match.isNotEmpty) state = match.first;
    } catch (_) {
      // no storage (tests, private web window): keep the default
    }
  }

  Future<void> set(AppLang lang) async {
    state = lang;
    try {
      (await SharedPreferences.getInstance()).setString(_key, lang.code);
    } catch (_) {}
  }

  Future<void> toggle() => set(state == AppLang.ur ? AppLang.en : AppLang.ur);
}

final langProvider = NotifierProvider<LangNotifier, AppLang>(LangNotifier.new);

/// Strings for the current language: `final s = ref.watch(stringsProvider); s.signIn`.
final stringsProvider = Provider<S>((ref) => S(ref.watch(langProvider)));

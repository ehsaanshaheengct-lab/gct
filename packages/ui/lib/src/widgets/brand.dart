import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../lang.dart';
import '../theme.dart';

/// Logo placeholder (packages/ui/assets/brand/wasa_logo.svg; replace with the official logo).
class WasaLogo extends StatelessWidget {
  const WasaLogo({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/brand/wasa_logo.svg', package: 'wasa_ui', width: size, height: size);
}

/// Logo + organisation name, for login screens and headers.
class WasaBrand extends ConsumerWidget {
  const WasaBrand({super.key, this.subtitle, this.logoSize = 72, this.light = false});
  final String? subtitle;
  final double logoSize;
  final bool light;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final color = light ? Colors.white : WasaColors.blueDark;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      WasaLogo(size: logoSize),
      const SizedBox(height: 10),
      Text(s.orgName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
      Text(s.orgFull, textAlign: TextAlign.center, style: TextStyle(color: light ? Colors.white70 : WasaColors.textMuted)),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: light ? Colors.white : WasaColors.teal)),
      ],
    ]);
  }
}

/// A small "اردو / English" switch for app bars and login screens.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return TextButton.icon(
      onPressed: () => ref.read(langProvider.notifier).toggle(),
      icon: Icon(Icons.translate, color: color),
      label: Text(s.language, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

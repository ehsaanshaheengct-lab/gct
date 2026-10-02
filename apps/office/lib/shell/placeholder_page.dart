import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../router.dart';

/// Stand-in for pages built in later phases.
class PlaceholderPage extends ConsumerWidget {
  const PlaceholderPage({super.key, required this.page});
  final OfficePage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return EmptyView(
      icon: page.icon,
      message: '${page.label(s)}\n${s.comingSoon} (phase ${page.phase})',
    );
  }
}

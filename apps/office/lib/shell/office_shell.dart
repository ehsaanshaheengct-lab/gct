import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../router.dart';

/// Left navigation (only the pages this role may open) + top bar with the user.
class OfficeShell extends ConsumerWidget {
  const OfficeShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final view = ref.watch(authViewProvider);
    if (view is! AuthSignedIn) return const Scaffold(body: LoadingView());
    final profile = view.profile;
    final pages = OfficePage.forRole(profile.role);
    final current = OfficePage.match(location);
    final index = current == null ? 0 : pages.indexOf(current).clamp(0, pages.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 1100;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(children: [
          const WasaLogo(size: 34),
          const SizedBox(width: 10),
          Text(s.orgName, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Flexible(
            child: Text('· ${s.officeAppTitle}',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, color: Colors.white70)),
          ),
        ]),
        actions: [
          _TehsilChip(name: profile.tehsilName),
          const SizedBox(width: 8),
          const LanguageToggle(color: Colors.white),
          const SizedBox(width: 4),
          _UserMenu(profile: profile),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(children: [
        NavigationRail(
          extended: wide,
          minExtendedWidth: 210,
          selectedIndex: index,
          labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
          onDestinationSelected: (i) => context.go(pages[i].path),
          destinations: [
            for (final p in pages)
              NavigationRailDestination(icon: Icon(p.icon), label: Text(p.label(s))),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]),
    );
  }
}

class _TehsilChip extends StatelessWidget {
  const _TehsilChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: const Icon(Icons.location_city, size: 18, color: WasaColors.blue),
        label: Text('Tehsil $name'),
        visualDensity: VisualDensity.compact,
      );
}

class _UserMenu extends ConsumerWidget {
  const _UserMenu({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return PopupMenuButton<String>(
      tooltip: profile.fullName,
      onSelected: (v) {
        if (v == 'logout') ref.read(authRepositoryProvider).signOut();
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(profile.fullName),
            subtitle: Text(s.pick(profile.role.en, profile.role.ur)),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'logout', child: ListTile(leading: const Icon(Icons.logout), title: Text(s.signOut))),
      ],
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white,
          child: Text(profile.fullName.isEmpty ? '?' : profile.fullName[0],
              style: const TextStyle(color: WasaColors.blue, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(profile.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            Text(s.pick(profile.role.en, profile.role.ur),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const Icon(Icons.arrow_drop_down, color: Colors.white),
      ]),
    );
  }
}

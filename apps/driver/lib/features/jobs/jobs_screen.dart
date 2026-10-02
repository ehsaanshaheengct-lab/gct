import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

/// Today's jobs. Phase 1: header with the driver's name; the job list arrives in phase 4.
class JobsScreen extends ConsumerWidget {
  const JobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final view = ref.watch(authViewProvider);
    final profile = view is AuthSignedIn ? view.profile : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.todaysJobs),
        actions: [
          const LanguageToggle(color: Colors.white),
          IconButton(
            tooltip: s.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          color: WasaColors.blue,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
          child: Row(children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 34, color: WasaColors.blue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(profile?.fullName ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text('${s.orgName} · ${profile?.tehsilName ?? ''}', style: const TextStyle(color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        Expanded(child: EmptyView(icon: Icons.assignment_outlined, message: '${s.noJobs}\n(${s.comingSoon})')),
      ]),
    );
  }
}

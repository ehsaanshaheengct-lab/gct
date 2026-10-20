import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

/// The signed-in profile (office screens are only shown when signed in).
Profile? currentProfile(WidgetRef ref) {
  final v = ref.watch(authViewProvider);
  return v is AuthSignedIn ? v.profile : null;
}

/// Error text for a failed save: rule messages as they are, others made friendly.
String friendlyError(Object e) => e is RuleException ? e.message : ErrorView.friendly(e);

/// Runs [action], shows a green "Saved" or a red error snackbar. Returns true on success.
Future<bool> runAction(BuildContext context, Future<void> Function() action, {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success), backgroundColor: WasaColors.green));
    }
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: WasaColors.red));
    return false;
  }
}

/// Page title row with optional actions on the right.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: WasaColors.blueDark)),
            if (subtitle != null) Text(subtitle!, style: const TextStyle(color: WasaColors.textMuted)),
          ]),
        ),
        ...actions.expand((a) => [const SizedBox(width: 8), a]),
      ]),
    );
  }
}

/// White rounded section with a title.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, required this.child, this.action, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final Widget child;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Expanded(child: Text(title!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                ?action,
              ]),
            ),
          child,
        ]),
      ),
    );
  }
}

/// "Label: value" row for detail panels.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(color: WasaColors.textMuted))),
          Expanded(
            child: Text((value ?? '').isEmpty ? '–' : value!, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

/// Picks a date with the Karachi "today" as the starting point.
Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final today = Fmt.karachiNow();
  final t = DateTime(today.year, today.month, today.day);
  return showDatePicker(
    context: context,
    initialDate: initial ?? t,
    firstDate: first ?? DateTime(2020),
    lastDate: last ?? DateTime(t.year + 2),
  );
}

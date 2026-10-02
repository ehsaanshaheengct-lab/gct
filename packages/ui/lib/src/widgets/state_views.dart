import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../lang.dart';
import '../theme.dart';

/// Friendly loading / empty / error states, used on every screen.
class LoadingView extends ConsumerWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(message ?? ref.watch(stringsProvider).loading, style: const TextStyle(color: WasaColors.textMuted)),
      ]),
    );
  }
}

class EmptyView extends ConsumerWidget {
  const EmptyView({super.key, this.message, this.icon = Icons.inbox_outlined, this.action});
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MessageView(
      icon: icon,
      color: WasaColors.textMuted,
      message: message ?? ref.watch(stringsProvider).nothingHere,
      action: action,
    );
  }
}

class ErrorView extends ConsumerWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  /// Turns exceptions into a sentence a clerk can act on.
  static String friendly(Object error) {
    final s = error.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('ClientException')) {
      return 'No connection to the server. Check the internet and try again.';
    }
    if (s.contains('JWT') || s.contains('401')) return 'Your session has ended. Please sign in again.';
    if (s.contains('permission denied') || s.contains('42501') || s.contains('row-level security')) {
      return 'You do not have permission to do this.';
    }
    final m = RegExp(r'message: ([^,]+)').firstMatch(s);
    return m?.group(1) ?? s;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return _MessageView(
      icon: Icons.error_outline,
      color: WasaColors.red,
      title: s.somethingWrong,
      message: friendly(error),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(s.retry)),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({required this.icon, required this.color, required this.message, this.title, this.action});
  final IconData icon;
  final Color color;
  final String? title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            if (title != null) ...[
              Text(title!, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 6),
            ],
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: WasaColors.textMuted)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      ),
    );
  }
}

/// `AsyncValueView(value: ref.watch(x), data: (v) => ...)` with the standard states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncData(:final value) => data(value),
      AsyncError(:final error) => ErrorView(error: error, onRetry: onRetry),
      _ => const LoadingView(),
    };
  }
}

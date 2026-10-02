import 'package:flutter/material.dart';

import '../theme.dart';

/// A big tap target with a picture/icon, a title and an optional subtitle.
/// Used for areas, vehicle types and the driver's main actions.
class BigTile extends StatelessWidget {
  const BigTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.autofocus = false,
    this.color = WasaColors.blue,
    this.minHeight = 96,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;
  final bool autofocus;
  final Color color;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final border = selected ? color : WasaColors.border;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: selected ? color.withValues(alpha: 0.08) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border, width: selected ? 2.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: autofocus,
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[leading!, const SizedBox(height: 8)],
                  Text(title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: selected ? color : WasaColors.text)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: WasaColors.textMuted)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

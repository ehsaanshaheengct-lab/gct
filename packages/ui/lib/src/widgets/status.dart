import 'package:flutter/material.dart';

/// A coloured dot: 🟢 available, 🟠 on job, 🔴 maintenance (colours from [WasaColors]).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.size = 12});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 4)],
      ),
    );
  }
}

/// A rounded status label with a dot, e.g. "● On Job".
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.dense = false});
  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusDot(color: color, size: dense ? 8 : 10),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: dense ? 12 : 13)),
      ]),
    );
  }
}

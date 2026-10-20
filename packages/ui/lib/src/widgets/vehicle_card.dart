import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:wasa_core/wasa_core.dart';

import '../lang.dart';
import '../strings.dart';
import '../theme.dart';
import 'status.dart';

/// The flat drawing for a vehicle type (`packages/ui/assets/vehicles/<iconKey>.svg`).
class VehicleIllustration extends StatelessWidget {
  const VehicleIllustration({super.key, required this.iconKey, this.fit = BoxFit.contain});
  final String iconKey;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final key = VehicleType.iconKeys.contains(iconKey) ? iconKey : 'sucker';
    return SvgPicture.asset('assets/vehicles/$key.svg', package: 'wasa_ui', fit: fit);
  }
}

/// A vehicle's main photo, or the type's drawing when there is no photo (or it fails to load).
class VehicleImage extends StatelessWidget {
  const VehicleImage({super.key, required this.iconKey, this.photoUrl, this.fit = BoxFit.cover});
  final String iconKey;
  final String? photoUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final drawing = VehicleIllustration(iconKey: iconKey);
    if (photoUrl == null) return drawing;
    return CachedNetworkImage(
      imageUrl: photoUrl!,
      fit: fit,
      placeholder: (_, _) => const ColoredBox(color: WasaColors.tealLight),
      errorWidget: (_, _, _) => drawing,
    );
  }
}

/// The vehicle card used on the Vehicle Board, in the New Challan flow and in the driver app:
/// big photo, registration, type (English + Urdu), capacity, driver, status and the area rate.
class VehicleCard extends ConsumerWidget {
  const VehicleCard({
    super.key,
    required this.vehicle,
    this.photoUrl,
    this.rate,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.trailing,
  });

  final Vehicle vehicle;
  final String? photoUrl;

  /// Rate for the selected area (shows "PKR 2,000 / trip"); null hides the line.
  final Tariff? rate;
  final VoidCallback? onTap;
  final bool selected;

  /// false = greyed out (busy / in maintenance) and not tappable.
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final v = vehicle;
    final statusColor = WasaColors.vehicleStatus(v.status);
    final driver = v.defaultDriver;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? WasaColors.blue : WasaColors.border, width: selected ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(
                  color: const Color(0xFFEEF5FB),
                  child: VehicleImage(iconKey: v.type.iconKey, photoUrl: photoUrl),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: StatusPill(label: s.pick(v.status.en, v.status.ur), color: statusColor, dense: true),
                  ),
                ),
                if (trailing != null) Positioned(top: 4, right: 4, child: trailing!),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  StatusDot(color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(v.regNo,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(v.type.nameEn, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(v.type.nameUr, maxLines: 1, overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.rtl, style: const TextStyle(color: WasaColors.textMuted)),
                const SizedBox(height: 6),
                if ((v.capacity ?? '').isNotEmpty) _Line(Icons.straighten, v.capacity!),
                _Line(Icons.person_outline,
                    driver == null ? s.noDriver : s.pick(driver.fullName, driver.fullNameUr)),
                if (v.status == VehicleStatus.maintenance && (v.statusReason ?? '').isNotEmpty)
                  _Line(Icons.build_outlined, v.statusReason!, color: WasaColors.red),
                if (rate != null) ...[
                  const SizedBox(height: 6),
                  Text(s.rateText(rate!.rate, rate!.pricingUnit),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: WasaColors.teal)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text, {this.color = WasaColors.textMuted});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(S.auto(text), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color))),
        ]),
      );
}

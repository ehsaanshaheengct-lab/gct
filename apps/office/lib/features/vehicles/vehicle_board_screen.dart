import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';

/// Photos of every vehicle with live status, filters by type/status, and rates for an area.
class VehicleBoardScreen extends ConsumerStatefulWidget {
  const VehicleBoardScreen({super.key});

  @override
  ConsumerState<VehicleBoardScreen> createState() => _VehicleBoardScreenState();
}

class _VehicleBoardScreenState extends ConsumerState<VehicleBoardScreen> {
  String? _typeId;
  VehicleStatus? _status;
  String? _areaId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final types = ref.watch(vehicleTypesProvider).value ?? const <VehicleType>[];
    final areas = (ref.watch(areasProvider).value ?? const <Area>[]).where((a) => a.isActive).toList();
    final tariffs = ref.watch(tariffTableProvider).value;
    final repo = ref.watch(vehicleRepositoryProvider);
    final profile = currentProfile(ref);
    final areaId = _areaId ?? (areas.isEmpty ? null : areas.first.id);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: s.vehicleBoard,
        subtitle: 'Tehsil ${profile?.tehsilName ?? ''}',
        actions: [
          IconButton.outlined(
            tooltip: s.refresh,
            onPressed: () => refreshVehicles(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      Expanded(
        child: AsyncValueView(
          value: vehicles,
          onRetry: () => refreshVehicles(ref),
          data: (all) {
            int count(VehicleStatus st) => all.where((v) => v.status == st).length;
            final shown = all.where((v) {
              if (_typeId != null && v.type.id != _typeId) return false;
              if (_status != null && v.status != _status) return false;
              if (_query.isNotEmpty && !v.regNo.toLowerCase().contains(_query.toLowerCase())) return false;
              return true;
            }).toList();

            return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 24), children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final st in VehicleStatus.values)
                  _CountTile(
                    label: s.pick(st.en, st.ur),
                    count: count(st),
                    color: WasaColors.vehicleStatus(st),
                    selected: _status == st,
                    onTap: () => setState(() => _status = _status == st ? null : st),
                  ),
                _CountTile(
                  label: s.all,
                  count: all.length,
                  color: WasaColors.blue,
                  selected: _status == null,
                  onTap: () => setState(() => _status = null),
                ),
              ]),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _typeId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s.vehicleType, isDense: true),
                    items: [
                      DropdownMenuItem(value: null, child: Text(s.allTypes)),
                      for (final t in types)
                        DropdownMenuItem(value: t.id, child: Text(s.pick(t.nameEn, t.nameUr), overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _typeId = v),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: InputDecoration(labelText: s.regNo, prefixIcon: const Icon(Icons.search), isDense: true),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                if (areas.isNotEmpty)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: areaId,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: s.ratesForArea, isDense: true),
                      items: [for (final a in areas) DropdownMenuItem(value: a.id, child: Text(s.pick(a.nameEn, a.nameUr)))],
                      onChanged: (v) => setState(() => _areaId = v),
                    ),
                  ),
              ]),
              const SizedBox(height: 16),
              if (shown.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 40), child: EmptyView(message: s.noVehicles, icon: Icons.local_shipping_outlined))
              else
                LayoutBuilder(builder: (context, c) {
                  // cards size to their content (fonts differ between PCs), in equal-width columns
                  const gap = 14.0;
                  final cols = (c.maxWidth / 270).floor().clamp(1, 6);
                  final w = (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(spacing: gap, runSpacing: gap, children: [
                    for (final v in shown)
                      SizedBox(
                        key: ValueKey(v.id),
                        width: w,
                        child: VehicleCard(
                          vehicle: v,
                          photoUrl: v.mainPhoto == null ? null : repo.photoUrl(v.mainPhoto!.storagePath),
                          rate: areaId == null ? null : tariffs?.find(areaId, v.type.id),
                          onTap: () => context.go('/vehicles/${v.id}'),
                        ),
                      ),
                  ]);
                }),
            ]);
          },
        ),
      ),
    ]);
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.label, required this.count, required this.color, required this.selected, required this.onTap});
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? color : WasaColors.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusDot(color: color, size: 14),
            const SizedBox(width: 10),
            Text('$count', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

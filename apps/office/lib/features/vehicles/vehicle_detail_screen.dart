import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';
import 'vehicle_status_dialog.dart';

class VehicleDetailScreen extends ConsumerStatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicleId});
  final String vehicleId;

  @override
  ConsumerState<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends ConsumerState<VehicleDetailScreen> {
  int _shown = 0; // photo index in the gallery

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId));
    return AsyncValueView(
      value: vehicle,
      onRetry: () => ref.invalidate(vehicleProvider(widget.vehicleId)),
      data: (v) {
        final profile = currentProfile(ref);
        final canChange = profile != null && profile.role.canWrite;
        return DefaultTabController(
          length: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: v.regNo,
              subtitle: '${v.type.nameEn} · ${S.ur(v.type.nameUr)}',
              actions: [
                OutlinedButton.icon(
                  onPressed: () => context.go('/vehicles'),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(s.vehicleBoard),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 980;
                final left = SizedBox(
                  width: wide ? 440 : double.infinity,
                  child: Column(children: [
                    _Gallery(vehicle: v, index: _shown, onPick: (i) => setState(() => _shown = i)),
                    const SizedBox(height: 14),
                    _StatusPanel(vehicle: v, canChange: canChange),
                  ]),
                );
                final right = Card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [Tab(text: s.info), Tab(text: s.history), Tab(text: s.maintenance)],
                    ),
                    SizedBox(
                      height: wide ? 560 : 520,
                      child: TabBarView(children: [
                        _DetailsTab(vehicle: v),
                        _HistoryTab(vehicleId: v.id),
                        _MaintenanceTab(vehicle: v, isAdmin: profile?.role == UserRole.admin),
                      ]),
                    ),
                  ]),
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          left,
                          const SizedBox(width: 18),
                          Expanded(child: right),
                        ])
                      : Column(children: [left, const SizedBox(height: 18), right]),
                );
              }),
            ),
          ]),
        );
      },
    );
  }
}

class _Gallery extends ConsumerWidget {
  const _Gallery({required this.vehicle, required this.index, required this.onPick});
  final Vehicle vehicle;
  final int index;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final repo = ref.watch(vehicleRepositoryProvider);
    final photos = vehicle.photos;
    final i = photos.isEmpty ? 0 : index.clamp(0, photos.length - 1);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: ColoredBox(
            color: const Color(0xFFEEF5FB),
            child: VehicleImage(
              iconKey: vehicle.type.iconKey,
              photoUrl: photos.isEmpty ? null : repo.photoUrl(photos[i].storagePath),
              fit: BoxFit.contain,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: photos.isEmpty
              ? Text(s.noPhotoYet, style: const TextStyle(color: WasaColors.textMuted))
              : Row(children: [
                  for (var k = 0; k < photos.length; k++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: InkWell(
                        onTap: () => onPick(k),
                        child: Container(
                          width: 84,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: k == i ? WasaColors.blue : WasaColors.border, width: k == i ? 3 : 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: VehicleImage(iconKey: vehicle.type.iconKey, photoUrl: repo.photoUrl(photos[k].storagePath)),
                        ),
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class _StatusPanel extends ConsumerWidget {
  const _StatusPanel({required this.vehicle, required this.canChange});
  final Vehicle vehicle;
  final bool canChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final v = vehicle;
    final color = WasaColors.vehicleStatus(v.status);
    return SectionCard(
      title: s.status,
      action: canChange
          ? FilledButton.tonalIcon(
              onPressed: () => showVehicleStatusDialog(context, v),
              icon: const Icon(Icons.swap_horiz),
              label: Text(s.changeStatus),
            )
          : Text(s.readOnly, style: const TextStyle(color: WasaColors.textMuted)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StatusPill(label: s.pick(v.status.en, v.status.ur), color: color),
        if (v.status == VehicleStatus.maintenance) ...[
          const SizedBox(height: 10),
          InfoRow(s.reason, v.statusReason),
          InfoRow(s.expectedBack, v.expectedBackOn == null ? null : Fmt.date(v.expectedBackOn!, isDateOnly: true)),
        ],
        if (v.status == VehicleStatus.onJob) ...[
          const SizedBox(height: 10),
          Text(s.onJobAuto, style: const TextStyle(color: WasaColors.textMuted)),
        ],
      ]),
    );
  }
}

class _DetailsTab extends ConsumerWidget {
  const _DetailsTab({required this.vehicle});
  final Vehicle vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final v = vehicle;
    final stats = ref.watch(vehicleStatsProvider).value?[v.id];
    final d = v.defaultDriver;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Stat(s.trips, '${stats?.trips ?? 0}'),
        _Stat(s.amountGenerated, Fmt.pkr(stats?.amountGenerated ?? 0)),
        _Stat(s.amountPaid, Fmt.pkr(stats?.amountPaid ?? 0)),
        _Stat(s.daysInMaintenance, '${stats?.daysInMaintenance ?? 0}'),
        _Stat(s.lastTrip, stats?.lastTripAt == null ? '–' : Fmt.date(stats!.lastTripAt!)),
      ]),
      const SizedBox(height: 16),
      InfoRow(s.regNo, v.regNo),
      InfoRow(s.vehicleType, '${v.type.nameEn}  ·  ${S.ur(v.type.nameUr)}'),
      InfoRow(s.category, s.pick(v.type.category.en, v.type.category.ur)),
      InfoRow(s.pricingUnit, s.pick(v.type.pricingUnit.en, v.type.pricingUnit.ur)),
      InfoRow(s.paymentPolicy, s.pick(v.type.paymentPolicy.en, v.type.paymentPolicy.ur)),
      InfoRow(s.makeModel, v.makeModel),
      InfoRow(s.year, v.year?.toString()),
      InfoRow(s.capacity, v.capacity),
      InfoRow(s.colour, v.colour),
      InfoRow(s.defaultDriver, d == null ? null : '${d.fullName} (${d.phone})'),
      InfoRow(s.trackerId, v.trackerDeviceId),
      InfoRow(s.notes, v.notes),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.local_gas_station_outlined, color: WasaColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(s.fuelKmLater, style: const TextStyle(color: WasaColors.textMuted))),
      ]),
    ]);
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Container(
        width: 150,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: WasaColors.background, borderRadius: BorderRadius.circular(10)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: WasaColors.blueDark)),
          Text(label, style: const TextStyle(color: WasaColors.textMuted, fontSize: 12)),
        ]),
      );
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.vehicleId});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncValueView(
      value: ref.watch(vehicleTripsProvider(vehicleId)),
      onRetry: () => ref.invalidate(vehicleTripsProvider(vehicleId)),
      data: (trips) {
        if (trips.isEmpty) return EmptyView(message: s.noHistory, icon: Icons.receipt_long_outlined);
        final done = trips.where((t) => t.isDone);
        final total = done.fold<double>(0, (a, t) => a + t.amount);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('${trips.length} challans · ${s.trips}: ${done.length} · ${s.amountGenerated}: ${Fmt.pkr(total)}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: trips.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final t = trips[i];
                return ListTile(
                  title: Text(t.challanNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${Fmt.date(t.createdAt)} · ${t.customerName} · ${t.areaName}'
                      '${t.driverName == null ? '' : ' · ${t.driverName}'}'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Fmt.pkr(t.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    StatusPill(
                      label: s.pick(t.displayStatus.en, t.displayStatus.ur),
                      color: WasaColors.displayStatus(t.displayStatus),
                      dense: true,
                    ),
                  ]),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

class _MaintenanceTab extends ConsumerWidget {
  const _MaintenanceTab({required this.vehicle, required this.isAdmin});
  final Vehicle vehicle;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncValueView(
      value: ref.watch(vehicleMaintenanceProvider(vehicle.id)),
      onRetry: () => ref.invalidate(vehicleMaintenanceProvider(vehicle.id)),
      data: (entries) => ListView(padding: const EdgeInsets.all(16), children: [
        if (isAdmin)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _addEntry(context, ref),
              icon: const Icon(Icons.add),
              label: Text(s.addMaintenance),
            ),
          ),
        if (entries.isEmpty) Padding(padding: const EdgeInsets.only(top: 24), child: EmptyView(message: s.nothingHere)),
        for (final e in entries)
          ListTile(
            leading: Icon(Icons.build_circle, color: e.isOpen ? WasaColors.red : WasaColors.grey, size: 32),
            title: Text(e.description, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${Fmt.date(e.startedOn, isDateOnly: true)} → '
                '${e.endedOn == null ? s.ongoing : Fmt.date(e.endedOn!, isDateOnly: true)}'),
            trailing: Text(e.cost == null ? '' : Fmt.pkr(e.cost!), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Future<void> _addEntry(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final desc = TextEditingController();
    final cost = TextEditingController();
    DateTime start = Fmt.karachiNow();
    DateTime? end = start;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(s.addMaintenance),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: desc, autofocus: true, decoration: InputDecoration(labelText: s.description)),
              const SizedBox(height: 12),
              TextField(controller: cost, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.cost)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await pickDate(ctx, initial: start);
                      if (d != null) set(() => start = d);
                    },
                    child: Text('${s.from}: ${Fmt.date(start, isDateOnly: true)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final d = await pickDate(ctx, initial: end ?? start, first: start);
                      set(() => end = d);
                    },
                    child: Text('${s.to}: ${end == null ? s.ongoing : Fmt.date(end!, isDateOnly: true)}'),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(s.save)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final saved = await runAction(
      context,
      () => ref.read(vehicleRepositoryProvider).addMaintenance(vehicle.id,
          description: desc.text, startedOn: start, endedOn: end, cost: double.tryParse(cost.text.replaceAll(',', ''))),
      success: s.saved,
    );
    if (saved) refreshVehicles(ref);
  }
}

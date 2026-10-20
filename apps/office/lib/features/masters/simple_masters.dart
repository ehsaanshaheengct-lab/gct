import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';

/// A scrollable table with an "Add" button on top.
class MasterTable extends StatelessWidget {
  const MasterTable({super.key, required this.columns, required this.rows, this.onAdd, this.addLabel, this.help});
  final List<String> columns;
  final List<DataRow> rows;
  final VoidCallback? onAdd;
  final String? addLabel;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [
        if (help != null) Expanded(child: Text(help!, style: const TextStyle(color: WasaColors.textMuted))),
        if (help == null) const Spacer(),
        if (onAdd != null) FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel ?? 'Add')),
      ]),
      const SizedBox(height: 12),
      Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            columnSpacing: 28,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: WasaColors.textMuted),
            columns: [for (final c in columns) DataColumn(label: Text(c))],
            rows: rows,
          ),
        ),
      ),
    ]);
  }
}

DataCell activeCell(S s, bool active) => DataCell(StatusPill(
      label: active ? s.active : s.inactive,
      color: active ? WasaColors.green : WasaColors.grey,
      dense: true,
    ));

/// Standard edit dialog: [fields] + Save/Cancel; [onSave] may throw RuleException.
Future<void> showEditDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required List<Widget> Function(void Function(VoidCallback) setState) fields,
  required Future<void> Function() onSave,
}) {
  final s = ref.read(stringsProvider);
  String? error;
  bool busy = false;
  return showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ...fields(set).expand((f) => [f, const SizedBox(height: 12)]),
              if (error != null) Text(error!, style: const TextStyle(color: WasaColors.red)),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: Text(s.cancel)),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    set(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await onSave();
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      set(() => error = friendlyError(e));
                    } finally {
                      if (ctx.mounted) set(() => busy = false);
                    }
                  },
            child: Text(s.save),
          ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------- vehicle types
class VehicleTypesTab extends ConsumerWidget {
  const VehicleTypesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncValueView(
      value: ref.watch(vehicleTypesProvider),
      onRetry: () => ref.invalidate(vehicleTypesProvider),
      data: (types) => MasterTable(
        addLabel: s.add,
        onAdd: () => _edit(context, ref, null, types.length + 1),
        columns: [s.picture, s.nameEn, s.nameUr, s.category, s.pricingUnit, s.paymentPolicy, s.status],
        rows: [
          for (final t in types)
            DataRow(onSelectChanged: (_) => _edit(context, ref, t, t.sortOrder), cells: [
              DataCell(SizedBox(width: 72, height: 44, child: VehicleIllustration(iconKey: t.iconKey))),
              DataCell(Text(t.nameEn, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(t.nameUr, textDirection: TextDirection.rtl)),
              DataCell(Text(s.pick(t.category.en, t.category.ur))),
              DataCell(Text(s.pick(t.pricingUnit.en, t.pricingUnit.ur))),
              DataCell(Text(s.pick(t.paymentPolicy.en, t.paymentPolicy.ur),
                  style: TextStyle(
                      color: t.paymentPolicy == PaymentPolicy.payBeforeDispatch ? WasaColors.orange : null,
                      fontWeight: FontWeight.w600))),
              activeCell(s, t.isActive),
            ]),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, VehicleType? t, int order) {
    final s = ref.read(stringsProvider);
    final en = TextEditingController(text: t?.nameEn);
    final ur = TextEditingController(text: t?.nameUr);
    var category = t?.category ?? VehicleCategory.sewer;
    var unit = t?.pricingUnit ?? PricingUnit.perTrip;
    var policy = t?.paymentPolicy ?? PaymentPolicy.payAfterService;
    var icon = t?.iconKey ?? 'sucker';
    var active = t?.isActive ?? true;
    return showEditDialog(
      context,
      ref,
      title: t == null ? '${s.add}: ${s.vehicleType}' : '${s.edit}: ${t.nameEn}',
      fields: (set) => [
        TextField(controller: en, decoration: InputDecoration(labelText: s.nameEn)),
        TextField(controller: ur, textDirection: TextDirection.rtl, decoration: InputDecoration(labelText: s.nameUr)),
        DropdownButtonFormField(
          initialValue: category,
          decoration: InputDecoration(labelText: s.category),
          items: [for (final c in VehicleCategory.values) DropdownMenuItem(value: c, child: Text(c.en))],
          onChanged: (v) => set(() => category = v!),
        ),
        DropdownButtonFormField(
          initialValue: unit,
          decoration: InputDecoration(labelText: s.pricingUnit),
          items: [for (final u in PricingUnit.values) DropdownMenuItem(value: u, child: Text(u.en))],
          onChanged: (v) => set(() => unit = v!),
        ),
        DropdownButtonFormField(
          initialValue: policy,
          decoration: InputDecoration(labelText: s.paymentPolicy),
          items: [for (final p in PaymentPolicy.values) DropdownMenuItem(value: p, child: Text(p.en))],
          onChanged: (v) => set(() => policy = v!),
        ),
        Text(s.picture, style: const TextStyle(color: WasaColors.textMuted)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in VehicleType.iconKeys)
            InkWell(
              onTap: () => set(() => icon = k),
              child: Container(
                width: 92,
                height: 58,
                decoration: BoxDecoration(
                  border: Border.all(color: icon == k ? WasaColors.blue : WasaColors.border, width: icon == k ? 3 : 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: VehicleIllustration(iconKey: k),
              ),
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.active),
          value: active,
          onChanged: (v) => set(() => active = v),
        ),
      ],
      onSave: () async {
        final code = t?.code ?? en.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]+'), '_').replaceAll(RegExp(r'^_|_$'), '');
        await ref.read(mastersRepositoryProvider).saveVehicleType(
              VehicleType(
                id: t?.id ?? '',
                code: code.isEmpty ? 'type_$order' : code,
                nameEn: en.text.trim(),
                nameUr: ur.text.trim(),
                category: category,
                pricingUnit: unit,
                paymentPolicy: policy,
                iconKey: icon,
                sortOrder: order,
                isActive: active,
              ),
              isNew: t == null,
            );
        refreshMasters(ref);
      },
    );
  }
}

// ---------------------------------------------------------------- drivers
class DriversTab extends ConsumerWidget {
  const DriversTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncValueView(
      value: ref.watch(driversProvider),
      onRetry: () => ref.invalidate(driversProvider),
      data: (drivers) => MasterTable(
        addLabel: s.add,
        onAdd: () => _edit(context, ref, null),
        columns: [s.nameEn, s.nameUr, s.phone, s.cnic, s.licence, s.appLogin, s.status],
        rows: [
          for (final d in drivers)
            DataRow(onSelectChanged: (_) => _edit(context, ref, d), cells: [
              DataCell(Text(d.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(d.fullNameUr ?? '', textDirection: TextDirection.rtl)),
              DataCell(Text(d.phone)),
              DataCell(Text(d.cnic ?? '–')),
              DataCell(Text(d.licenceNo ?? '–')),
              DataCell(Icon(d.hasAppLogin ? Icons.phone_android : Icons.remove, color: d.hasAppLogin ? WasaColors.green : WasaColors.grey)),
              activeCell(s, d.isActive),
            ]),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Driver? d) {
    final s = ref.read(stringsProvider);
    final name = TextEditingController(text: d?.fullName);
    final nameUr = TextEditingController(text: d?.fullNameUr);
    final phone = TextEditingController(text: d?.phone);
    final cnic = TextEditingController(text: d?.cnic);
    final licence = TextEditingController(text: d?.licenceNo);
    var active = d?.isActive ?? true;
    return showEditDialog(
      context,
      ref,
      title: d == null ? '${s.add}: ${s.drivers}' : '${s.edit}: ${d.fullName}',
      fields: (set) => [
        TextField(controller: name, decoration: InputDecoration(labelText: s.nameEn)),
        TextField(controller: nameUr, textDirection: TextDirection.rtl, decoration: InputDecoration(labelText: s.nameUr)),
        TextField(controller: phone, decoration: InputDecoration(labelText: s.phone, hintText: '0300-1234567')),
        TextField(controller: cnic, decoration: InputDecoration(labelText: s.cnic, hintText: '38101-1234567-1')),
        TextField(controller: licence, decoration: InputDecoration(labelText: s.licence)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.active),
          value: active,
          onChanged: (v) => set(() => active = v),
        ),
      ],
      onSave: () async {
        final profile = currentProfile(ref);
        await ref.read(mastersRepositoryProvider).saveDriver(
              Driver(
                id: d?.id ?? '',
                tehsilId: d?.tehsilId ?? profile!.tehsilId,
                fullName: name.text.trim(),
                fullNameUr: nameUr.text.trim().isEmpty ? null : nameUr.text.trim(),
                phone: Fmt.normalizePhone(phone.text) ?? phone.text.trim(),
                cnic: cnic.text.trim().isEmpty ? null : cnic.text.trim(),
                licenceNo: licence.text.trim().isEmpty ? null : licence.text.trim(),
                isActive: active,
              ),
              isNew: d == null,
            );
        refreshMasters(ref);
      },
    );
  }
}

// ---------------------------------------------------------------- areas
class AreasTab extends ConsumerWidget {
  const AreasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AsyncValueView(
      value: ref.watch(areasProvider),
      onRetry: () => ref.invalidate(areasProvider),
      data: (areas) => MasterTable(
        addLabel: s.add,
        onAdd: () => _edit(context, ref, null, areas.length + 1),
        columns: [s.sortOrder, s.nameEn, s.nameUr, s.status],
        rows: [
          for (final a in areas)
            DataRow(onSelectChanged: (_) => _edit(context, ref, a, a.sortOrder), cells: [
              DataCell(Text('${a.sortOrder}')),
              DataCell(Text(a.nameEn, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(a.nameUr, textDirection: TextDirection.rtl)),
              activeCell(s, a.isActive),
            ]),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Area? a, int order) {
    final s = ref.read(stringsProvider);
    final en = TextEditingController(text: a?.nameEn);
    final ur = TextEditingController(text: a?.nameUr);
    final sort = TextEditingController(text: '$order');
    var active = a?.isActive ?? true;
    return showEditDialog(
      context,
      ref,
      title: a == null ? '${s.add}: ${s.areas}' : '${s.edit}: ${a.nameEn}',
      fields: (set) => [
        TextField(controller: en, decoration: InputDecoration(labelText: s.nameEn)),
        TextField(controller: ur, textDirection: TextDirection.rtl, decoration: InputDecoration(labelText: s.nameUr)),
        TextField(controller: sort, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.sortOrder)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.active),
          value: active,
          onChanged: (v) => set(() => active = v),
        ),
      ],
      onSave: () async {
        await ref.read(mastersRepositoryProvider).saveArea(
              Area(
                id: a?.id ?? '',
                tehsilId: a?.tehsilId ?? currentProfile(ref)!.tehsilId,
                nameEn: en.text.trim(),
                nameUr: ur.text.trim(),
                sortOrder: int.tryParse(sort.text) ?? order,
                isActive: active,
              ),
              isNew: a == null,
            );
        refreshMasters(ref);
      },
    );
  }
}

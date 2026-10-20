import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';

/// Rows = areas, columns = vehicle types. Click a rate to change it (history is kept).
class TariffTab extends ConsumerWidget {
  const TariffTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final types = ref.watch(vehicleTypesProvider);
    final areas = ref.watch(areasProvider);
    final table = ref.watch(tariffTableProvider);
    return AsyncValueView(
      value: table,
      onRetry: () => refreshMasters(ref),
      data: (t) {
        final ts = (types.value ?? const <VehicleType>[]).where((x) => x.isActive).toList();
        final as = (areas.value ?? const <Area>[]).where((x) => x.isActive).toList();
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(s.tariffHelp, style: const TextStyle(color: WasaColors.textMuted)),
          const SizedBox(height: 12),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(8),
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(128),
                columnWidths: const {0: FixedColumnWidth(150)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(children: [
                    const SizedBox.shrink(),
                    for (final vt in ts)
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(children: [
                          SizedBox(height: 40, child: VehicleIllustration(iconKey: vt.iconKey)),
                          Text(vt.nameEn, textAlign: TextAlign.center, maxLines: 2,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          Text(s.pick(vt.pricingUnit.en, vt.pricingUnit.ur),
                              style: const TextStyle(color: WasaColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                  ]),
                  for (final a in as)
                    TableRow(
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: WasaColors.border))),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.nameEn, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(a.nameUr, style: const TextStyle(color: WasaColors.textMuted)),
                          ]),
                        ),
                        for (final vt in ts) _RateCell(area: a, type: vt, tariff: t.find(a.id, vt.id)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _RateCell extends ConsumerWidget {
  const _RateCell({required this.area, required this.type, this.tariff});
  final Area area;
  final VehicleType type;
  final Tariff? tariff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.all(4),
      child: InkWell(
        key: Key('rate-${area.nameEn}-${type.code}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _edit(context, ref),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: tariff == null ? const Color(0xFFFFF3E0) : WasaColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Text(tariff == null ? s.notSet : Fmt.pkr(tariff!.rate, symbol: false),
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: tariff == null ? WasaColors.orange : WasaColors.blueDark)),
            if (tariff?.isPlaceholder ?? false)
              Text(s.placeholderRate, style: const TextStyle(fontSize: 11, color: WasaColors.orange)),
          ]),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final rate = TextEditingController(text: tariff == null ? '' : tariff!.rate.toStringAsFixed(0));
    DateTime from = Fmt.karachiNow();
    String? error;
    final repo = ref.read(mastersRepositoryProvider);
    final history = repo.tariffHistory(area.id, type.id);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        Future<void> save() async {
          final value = double.tryParse(rate.text.replaceAll(',', '').trim());
          if (value == null) {
            set(() => error = 'Enter the rate as a number, e.g. 2000.');
            return;
          }
          try {
            await repo.setTariffRate(area.id, type.id, value, effectiveFrom: from);
            ref.invalidate(tariffTableProvider);
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            set(() => error = friendlyError(e));
          }
        }

        return AlertDialog(
          title: Text('${area.nameEn} × ${type.nameEn}'),
          content: SizedBox(
            width: 440,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                key: const Key('rate-input'),
                controller: rate,
                autofocus: true,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(
                  labelText: s.rate,
                  suffixText: s.pick(type.pricingUnit.en, type.pricingUnit.ur),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await pickDate(ctx, initial: from);
                  if (d != null) set(() => from = d);
                },
                icon: const Icon(Icons.event),
                label: Text('${s.effectiveFrom}: ${Fmt.date(from, isDateOnly: true)}'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: WasaColors.red)),
              ],
              const SizedBox(height: 16),
              Text(s.history, style: const TextStyle(fontWeight: FontWeight.w700)),
              FutureBuilder(
                future: history,
                builder: (_, snap) => Column(children: [
                  for (final h in snap.data ?? const <Tariff>[])
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(h.isActive ? Icons.check_circle : Icons.history,
                          color: h.isActive ? WasaColors.green : WasaColors.grey),
                      title: Text(s.rateText(h.rate, h.pricingUnit)),
                      subtitle: Text('${s.effectiveFrom} ${Fmt.date(h.effectiveFrom, isDateOnly: true)}'
                          '${h.isPlaceholder ? ' · ${s.placeholderRate}' : ''}'),
                    ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.cancel)),
            FilledButton(onPressed: save, child: Text(s.save)),
          ],
        );
      }),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';

/// Operator/Admin: Available <-> Maintenance (reason + expected-back date). On Job is automatic.
Future<void> showVehicleStatusDialog(BuildContext context, Vehicle v) =>
    showDialog(context: context, builder: (_) => _VehicleStatusDialog(vehicle: v));

class _VehicleStatusDialog extends ConsumerStatefulWidget {
  const _VehicleStatusDialog({required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<_VehicleStatusDialog> createState() => _VehicleStatusDialogState();
}

class _VehicleStatusDialogState extends ConsumerState<_VehicleStatusDialog> {
  late VehicleStatus _status =
      widget.vehicle.status == VehicleStatus.maintenance ? VehicleStatus.available : VehicleStatus.maintenance;
  final _reason = TextEditingController();
  DateTime? _back;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(vehicleRepositoryProvider)
          .setStatus(widget.vehicle.id, _status, reason: _reason.text, expectedBack: _back);
      refreshVehicles(ref);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.saved), backgroundColor: WasaColors.green));
      }
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final onJob = widget.vehicle.status == VehicleStatus.onJob;
    return AlertDialog(
      title: Text('${s.changeStatus}: ${widget.vehicle.regNo}'),
      content: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (onJob)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s.onJobAuto, style: const TextStyle(color: WasaColors.orange)),
            ),
          SegmentedButton<VehicleStatus>(
            segments: [
              for (final st in [VehicleStatus.available, VehicleStatus.maintenance])
                ButtonSegment(
                  value: st,
                  label: Text(s.pick(st.en, st.ur)),
                  icon: StatusDot(color: WasaColors.vehicleStatus(st)),
                ),
            ],
            selected: {_status},
            onSelectionChanged: (v) => setState(() => _status = v.first),
          ),
          if (_status == VehicleStatus.maintenance) ...[
            const SizedBox(height: 16),
            TextField(
              key: const Key('status-reason'),
              controller: _reason,
              autofocus: true,
              decoration: InputDecoration(labelText: '${s.reason} *', hintText: 'e.g. Pump seal leaking'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final today = Fmt.karachiNow();
                final d = await pickDate(context, initial: _back, first: DateTime(today.year, today.month, today.day));
                if (d != null) setState(() => _back = d);
              },
              icon: const Icon(Icons.event),
              label: Text('${s.expectedBack}: ${_back == null ? s.notSet : Fmt.date(_back!, isDateOnly: true)}'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: WasaColors.red)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(s.save)),
      ],
    );
  }
}

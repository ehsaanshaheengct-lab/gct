import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';
import 'simple_masters.dart';

class VehiclesTab extends ConsumerWidget {
  const VehiclesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final repo = ref.watch(vehicleRepositoryProvider);
    return AsyncValueView(
      value: ref.watch(allVehiclesProvider),
      onRetry: () => ref.invalidate(allVehiclesProvider),
      data: (vehicles) => MasterTable(
        addLabel: s.add,
        onAdd: () => showVehicleForm(context, null),
        columns: [s.picture, s.regNo, s.vehicleType, s.capacity, s.defaultDriver, s.photos, s.status, ''],
        rows: [
          for (final v in vehicles)
            DataRow(onSelectChanged: (_) => showVehicleForm(context, v.id), cells: [
              DataCell(SizedBox(
                width: 80,
                height: 50,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: VehicleImage(
                    iconKey: v.type.iconKey,
                    photoUrl: v.mainPhoto == null ? null : repo.photoUrl(v.mainPhoto!.storagePath),
                  ),
                ),
              )),
              DataCell(Text(v.regNo, style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text(s.pick(v.type.nameEn, v.type.nameUr))),
              DataCell(Text(v.capacity ?? '–')),
              DataCell(Text(v.defaultDriver?.fullName ?? '–')),
              DataCell(Text('${v.photos.length} / ${VehicleRepository.maxPhotos}')),
              DataCell(StatusPill(label: s.pick(v.status.en, v.status.ur), color: WasaColors.vehicleStatus(v.status), dense: true)),
              activeCell(s, v.isActive),
            ]),
        ],
      ),
    );
  }
}

/// Add (vehicleId == null) or edit a vehicle. After adding, the form stays open so photos can be added.
Future<void> showVehicleForm(BuildContext context, String? vehicleId) =>
    showDialog(context: context, builder: (_) => _VehicleForm(vehicleId: vehicleId));

class _VehicleForm extends ConsumerStatefulWidget {
  const _VehicleForm({this.vehicleId});
  final String? vehicleId;

  @override
  ConsumerState<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends ConsumerState<_VehicleForm> {
  String? _id;
  VehicleDraft? _draft;
  final _c = <String, TextEditingController>{};
  bool _busy = false;
  String? _error;

  TextEditingController _ctl(String key, String? value) => _c.putIfAbsent(key, () => TextEditingController(text: value));

  @override
  void initState() {
    super.initState();
    _id = widget.vehicleId;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final d = _draft!
      ..regNo = _c['reg']!.text
      ..makeModel = _c['make']!.text
      ..year = int.tryParse(_c['year']!.text.trim())
      ..capacity = _c['cap']!.text
      ..colour = _c['colour']!.text
      ..trackerDeviceId = _c['tracker']!.text
      ..notes = _c['notes']!.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final isNew = d.id == null;
      final id = await ref.read(vehicleRepositoryProvider).save(d);
      refreshVehicles(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ref.read(stringsProvider).saved), backgroundColor: WasaColors.green));
      if (isNew) {
        setState(() {
          _id = id;
          _draft!.id = id;
        }); // stay open to add photos
      } else {
        Navigator.pop(context);
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
    final types = ref.watch(vehicleTypesProvider).value ?? const <VehicleType>[];
    final drivers = (ref.watch(driversProvider).value ?? const <Driver>[]).where((d) => d.isActive).toList();
    final existing = _id == null ? null : ref.watch(vehicleProvider(_id!));
    final profile = currentProfile(ref);

    if (_draft == null) {
      if (_id == null) {
        _draft = VehicleDraft(tehsilId: profile?.tehsilId ?? '', vehicleTypeId: types.isEmpty ? null : types.first.id);
      } else if (existing?.value != null) {
        _draft = VehicleDraft.from(existing!.value!);
      } else {
        return const Dialog(child: SizedBox(width: 300, height: 200, child: LoadingView()));
      }
    }
    final d = _draft!;

    return AlertDialog(
      title: Text(_id == null ? '${s.add}: ${s.vehicles}' : '${s.edit}: ${d.regNo}'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _field(220, TextField(controller: _ctl('reg', d.regNo), decoration: InputDecoration(labelText: '${s.regNo} *', hintText: 'BKR-1234'))),
              _field(
                  220,
                  DropdownButtonFormField<String>(
                    initialValue: d.vehicleTypeId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: '${s.vehicleType} *'),
                    items: [for (final t in types) DropdownMenuItem(value: t.id, child: Text(t.nameEn, overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => d.vehicleTypeId = v),
                  )),
              _field(220, TextField(controller: _ctl('make', d.makeModel), decoration: InputDecoration(labelText: s.makeModel))),
              _field(100, TextField(controller: _ctl('year', d.year?.toString()), keyboardType: TextInputType.number, decoration: InputDecoration(labelText: s.year))),
              _field(160, TextField(controller: _ctl('cap', d.capacity), decoration: InputDecoration(labelText: s.capacity, hintText: '6,000 litres'))),
              _field(160, TextField(controller: _ctl('colour', d.colour), decoration: InputDecoration(labelText: s.colour))),
              _field(
                  220,
                  DropdownButtonFormField<String?>(
                    initialValue: d.defaultDriverId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s.defaultDriver),
                    items: [
                      DropdownMenuItem(value: null, child: Text(s.noDriver)),
                      for (final dr in drivers) DropdownMenuItem(value: dr.id, child: Text(dr.fullName)),
                    ],
                    onChanged: (v) => setState(() => d.defaultDriverId = v),
                  )),
              _field(220, TextField(controller: _ctl('tracker', d.trackerDeviceId), decoration: InputDecoration(labelText: s.trackerId))),
              _field(456, TextField(controller: _ctl('notes', d.notes), decoration: InputDecoration(labelText: s.notes))),
              _field(
                  200,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.active),
                    value: d.isActive,
                    onChanged: (v) => setState(() => d.isActive = v),
                  )),
            ]),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: WasaColors.red)),
            ],
            const SizedBox(height: 16),
            const Divider(),
            if (_id == null)
              Text('${s.photos}: ${s.save} first.', style: const TextStyle(color: WasaColors.textMuted))
            else if (existing?.value != null)
              _PhotoManager(vehicle: existing!.value!),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(s.close)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(s.save)),
      ],
    );
  }

  Widget _field(double w, Widget child) => SizedBox(width: w, child: child);
}

/// Up to 4 photos: upload, set the kind, delete, drag to reorder (first = main).
class _PhotoManager extends ConsumerStatefulWidget {
  const _PhotoManager({required this.vehicle});
  final Vehicle vehicle;

  @override
  ConsumerState<_PhotoManager> createState() => _PhotoManagerState();
}

class _PhotoManagerState extends ConsumerState<_PhotoManager> {
  bool _busy = false;

  Future<void> _do(Future<void> Function() action) async {
    setState(() => _busy = true);
    final ok = await runAction(context, action, success: ref.read(stringsProvider).saved);
    if (ok) refreshVehicles(ref);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _upload() async {
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'Photos', extensions: ['jpg', 'jpeg', 'png', 'webp'], uniformTypeIdentifiers: ['public.image']),
    ]);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final kind = VehiclePhoto.kinds[widget.vehicle.photos.length.clamp(0, 3)];
    await _do(() => ref.read(vehicleRepositoryProvider).uploadPhoto(widget.vehicle, bytes, fileName: file.name, kind: kind));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final repo = ref.watch(vehicleRepositoryProvider);
    final v = widget.vehicle;
    final photos = v.photos;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text('${s.photos} (${photos.length}/${VehicleRepository.maxPhotos})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_busy) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          key: const Key('upload-photo'),
          onPressed: _busy || photos.length >= VehicleRepository.maxPhotos ? null : _upload,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(s.uploadPhoto),
        ),
      ]),
      const SizedBox(height: 4),
      Text(photos.isEmpty ? s.noPhotoYet : s.dragToReorder, style: const TextStyle(color: WasaColors.textMuted)),
      const SizedBox(height: 10),
      SizedBox(
        height: 190,
        child: photos.isEmpty
            ? Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(width: 220, child: VehicleIllustration(iconKey: v.type.iconKey)),
              )
            : ReorderableListView(
                scrollDirection: Axis.horizontal,
                buildDefaultDragHandles: false,
                onReorderItem: (from, to) {
                  final ids = photos.map((p) => p.id).toList();
                  ids.insert(to, ids.removeAt(from));
                  _do(() => repo.reorderPhotos(v.id, ids));
                },
                children: [
                  for (var i = 0; i < photos.length; i++)
                    ReorderableDragStartListener(
                      key: ValueKey(photos[i].id),
                      index: i,
                      child: Container(
                        width: 200,
                        margin: const EdgeInsetsDirectional.only(end: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: i == 0 ? WasaColors.blue : WasaColors.border, width: i == 0 ? 3 : 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(children: [
                          Expanded(
                            child: Stack(fit: StackFit.expand, children: [
                              VehicleImage(iconKey: v.type.iconKey, photoUrl: repo.photoUrl(photos[i].storagePath)),
                              if (i == 0)
                                Positioned(
                                  left: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: WasaColors.blue, borderRadius: BorderRadius.circular(10)),
                                    child: Text(s.mainPhoto, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                              const Positioned(right: 6, top: 6, child: Icon(Icons.drag_indicator, color: Colors.white)),
                            ]),
                          ),
                          Row(children: [
                            const SizedBox(width: 6),
                            Expanded(
                              child: DropdownButton<String>(
                                value: photos[i].kind,
                                isDense: true,
                                isExpanded: true,
                                underline: const SizedBox.shrink(),
                                items: [for (final k in VehiclePhoto.kinds) DropdownMenuItem(value: k, child: Text(k))],
                                onChanged: _busy ? null : (k) => _do(() => repo.setPhotoKind(photos[i], k!)),
                              ),
                            ),
                            IconButton(
                              tooltip: s.delete,
                              icon: const Icon(Icons.delete_outline, color: WasaColors.red),
                              onPressed: _busy ? null : () => _do(() => repo.deletePhoto(v, photos[i])),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                ],
              ),
      ),
    ]);
  }
}

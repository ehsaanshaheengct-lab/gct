import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enums.dart';
import '../models/masters.dart';
import '../rules/tariff.dart';

/// Vehicles, their photos, history and status. Writes go through RPCs where a
/// rule applies (status), or straight to tables where RLS allows admin only.
class VehicleRepository {
  VehicleRepository(this._db);
  final SupabaseClient _db;

  static const photoBucket = 'vehicle-photos';
  static const maxPhotos = 4;

  Future<List<Vehicle>> list({bool includeInactive = false}) async {
    var q = _db.from('vehicles').select(Vehicle.select);
    if (!includeInactive) q = q.eq('is_active', true);
    final rows = await q.order('reg_no', ascending: true);
    final list = rows.map(Vehicle.fromJson).toList()
      ..sort((a, b) {
        final t = a.type.sortOrder.compareTo(b.type.sortOrder);
        return t != 0 ? t : a.regNo.compareTo(b.regNo);
      });
    return list;
  }

  Future<Vehicle> get(String id) async =>
      Vehicle.fromJson(await _db.from('vehicles').select(Vehicle.select).eq('id', id).single());

  Future<Map<String, VehicleStats>> stats() async {
    final rows = await _db.from('vehicle_stats').select();
    return {for (final r in rows) r['vehicle_id'] as String: VehicleStats.fromJson(r)};
  }

  Future<List<VehicleTrip>> trips(String vehicleId) async {
    final rows = await _db
        .from('challans')
        .select(VehicleTrip.select)
        .eq('vehicle_id', vehicleId)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map(VehicleTrip.fromJson).toList();
  }

  Future<List<MaintenanceEntry>> maintenance(String vehicleId) async {
    final rows = await _db
        .from('vehicle_maintenance')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('started_on', ascending: false);
    return rows.map(MaintenanceEntry.fromJson).toList();
  }

  /// Available / Maintenance (reason required). On Job is automatic.
  Future<void> setStatus(String vehicleId, VehicleStatus status, {String? reason, DateTime? expectedBack}) async {
    if (status == VehicleStatus.maintenance && (reason ?? '').trim().isEmpty) {
      throw const RuleException('Write the reason for maintenance.');
    }
    await _db.rpc('set_vehicle_status', params: {
      'p_vehicle_id': vehicleId,
      'p_status': status.dbValue,
      'p_reason': reason,
      'p_expected_back': expectedBack == null ? null : _date(expectedBack),
    });
  }

  /// Admin: insert or update; returns the vehicle id.
  Future<String> save(VehicleDraft d) async {
    final problem = d.validate();
    if (problem != null) throw RuleException(problem);
    try {
      if (d.id == null) {
        final row = await _db.from('vehicles').insert(d.toRow()).select('id').single();
        return row['id'] as String;
      }
      await _db.from('vehicles').update(d.toRow()).eq('id', d.id!);
      return d.id!;
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw RuleException('A vehicle with registration ${VehicleDraft.normalizeRegNo(d.regNo)} already exists.');
      }
      rethrow;
    }
  }

  /// Admin: add a maintenance log entry (date, description, cost).
  Future<void> addMaintenance(String vehicleId,
      {required String description, required DateTime startedOn, DateTime? endedOn, double? cost}) async {
    if (description.trim().isEmpty) throw const RuleException('Write what was done.');
    await _db.from('vehicle_maintenance').insert({
      'vehicle_id': vehicleId,
      'description': description.trim(),
      'started_on': _date(startedOn),
      'ended_on': endedOn == null ? null : _date(endedOn),
      'cost': cost,
      'created_by': _db.auth.currentUser?.id,
    });
  }

  String photoUrl(String storagePath) => _db.storage.from(photoBucket).getPublicUrl(storagePath);

  /// Admin: upload a photo (max 4). It goes last; reorder to make it the main photo.
  Future<void> uploadPhoto(Vehicle v, Uint8List bytes, {required String fileName, String kind = 'front'}) async {
    if (v.photos.length >= maxPhotos) throw const RuleException('A vehicle can have up to 4 photos. Delete one first.');
    if (bytes.length > 8 * 1024 * 1024) throw const RuleException('The photo is too large (max 8 MB).');
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final contentType = switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
    final path = '${v.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from(photoBucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    // positions are kept as 0..n-1 (deletePhoto closes gaps), so the new photo goes last
    await _db
        .from('vehicle_photos')
        .insert({'vehicle_id': v.id, 'storage_path': path, 'position': v.photos.length, 'kind': kind});
  }

  Future<void> setPhotoKind(VehiclePhoto p, String kind) =>
      _db.from('vehicle_photos').update({'kind': kind}).eq('id', p.id);

  Future<void> deletePhoto(Vehicle v, VehiclePhoto p) async {
    await _db.from('vehicle_photos').delete().eq('id', p.id);
    await _db.storage.from(photoBucket).remove([p.storagePath]);
    final rest = v.photos.where((x) => x.id != p.id).map((x) => x.id).toList();
    if (rest.isNotEmpty) await reorderPhotos(v.id, rest); // close the gap
  }

  /// The first id becomes the main photo.
  Future<void> reorderPhotos(String vehicleId, List<String> photoIds) =>
      _db.rpc('reorder_vehicle_photos', params: {'p_vehicle_id': vehicleId, 'p_photo_ids': photoIds});

  /// Calls [onChange] when vehicles or challans change (Supabase Realtime).
  /// Returns a function that stops listening. Fails quietly when Realtime is unavailable.
  void Function() listen(void Function() onChange) {
    final channel = _db.channel('vehicles-board-${DateTime.now().microsecondsSinceEpoch}')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'vehicles', callback: (_) => onChange())
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'challans', callback: (_) => onChange())
      ..subscribe();
    return () => _db.removeChannel(channel);
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Vehicle types, areas, drivers and the tariff.
class MastersRepository {
  MastersRepository(this._db);
  final SupabaseClient _db;

  Future<List<VehicleType>> vehicleTypes() async =>
      (await _db.from('vehicle_types').select().order('sort_order', ascending: true)).map(VehicleType.fromJson).toList();

  Future<List<Area>> areas() async =>
      (await _db.from('areas').select().order('sort_order', ascending: true).order('name_en', ascending: true)).map(Area.fromJson).toList();

  Future<List<Driver>> drivers() async =>
      (await _db.from('drivers').select().order('full_name', ascending: true)).map(Driver.fromJson).toList();

  Future<List<Tariff>> tariffs({bool activeOnly = true}) async {
    var q = _db.from('tariffs').select();
    if (activeOnly) q = q.eq('is_active', true);
    return (await q.order('effective_from', ascending: false)).map(Tariff.fromJson).toList();
  }

  Future<List<Tariff>> tariffHistory(String areaId, String vehicleTypeId) async => (await _db
          .from('tariffs')
          .select()
          .eq('area_id', areaId)
          .eq('vehicle_type_id', vehicleTypeId)
          .order('created_at', ascending: false))
      .map(Tariff.fromJson)
      .toList();

  Future<void> setTariffRate(String areaId, String vehicleTypeId, double rate, {DateTime? effectiveFrom}) async {
    if (rate < 0) throw const RuleException('Enter a rate of 0 or more.');
    await _db.rpc('set_tariff_rate', params: {
      'p_area_id': areaId,
      'p_vehicle_type_id': vehicleTypeId,
      'p_rate': rate,
      'p_effective_from': effectiveFrom == null ? null : VehicleRepository._date(effectiveFrom),
    });
  }

  Future<void> saveVehicleType(VehicleType t, {bool isNew = false}) async {
    if (t.nameEn.trim().isEmpty || t.nameUr.trim().isEmpty) {
      throw const RuleException('Enter the name in English and Urdu.');
    }
    await _guardUnique(() => isNew
        ? _db.from('vehicle_types').insert(t.toRow())
        : _db.from('vehicle_types').update(t.toRow()).eq('id', t.id));
  }

  Future<void> saveArea(Area a, {bool isNew = false}) async {
    if (a.nameEn.trim().isEmpty || a.nameUr.trim().isEmpty) {
      throw const RuleException('Enter the area name in English and Urdu.');
    }
    await _guardUnique(() =>
        isNew ? _db.from('areas').insert(a.toRow()) : _db.from('areas').update(a.toRow()).eq('id', a.id));
  }

  Future<void> saveDriver(Driver d, {bool isNew = false}) async {
    if (d.fullName.trim().isEmpty) throw const RuleException("Enter the driver's name.");
    if (!RegExp(r'^03[0-9]{2}-[0-9]{7}$').hasMatch(d.phone)) {
      throw const RuleException('Enter the phone as 03XX-XXXXXXX.');
    }
    if ((d.cnic ?? '').isNotEmpty && !RegExp(r'^[0-9]{5}-[0-9]{7}-[0-9]$').hasMatch(d.cnic!)) {
      throw const RuleException('Enter the CNIC as 12345-1234567-1.');
    }
    await _guardUnique(() =>
        isNew ? _db.from('drivers').insert(d.toRow()) : _db.from('drivers').update(d.toRow()).eq('id', d.id));
  }

  Future<void> _guardUnique(Future<dynamic> Function() op) async {
    try {
      await op();
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const RuleException('This name or code is already used.');
      rethrow;
    }
  }
}

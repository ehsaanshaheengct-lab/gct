import 'enums.dart';

double _num(Object? v) => v == null ? 0 : (v as num).toDouble();
DateTime? _ts(Object? v) => v == null ? null : DateTime.parse(v as String);

class VehicleType {
  const VehicleType({
    required this.id,
    required this.code,
    required this.nameEn,
    required this.nameUr,
    required this.category,
    required this.pricingUnit,
    required this.paymentPolicy,
    required this.iconKey,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id, code, nameEn, nameUr, iconKey;
  final VehicleCategory category;
  final PricingUnit pricingUnit;
  final PaymentPolicy paymentPolicy;
  final int sortOrder;
  final bool isActive;

  factory VehicleType.fromJson(Map<String, dynamic> j) => VehicleType(
        id: j['id'] as String,
        code: j['code'] as String,
        nameEn: j['name_en'] as String,
        nameUr: j['name_ur'] as String,
        category: VehicleCategory.fromDb(j['category'] as String?),
        pricingUnit: PricingUnit.fromDb(j['pricing_unit'] as String?),
        paymentPolicy: PaymentPolicy.fromDb(j['payment_policy'] as String?),
        iconKey: j['icon_key'] as String? ?? 'sucker',
        sortOrder: j['sort_order'] as int? ?? 0,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toRow() => {
        'code': code,
        'name_en': nameEn,
        'name_ur': nameUr,
        'category': category.dbValue,
        'pricing_unit': pricingUnit.dbValue,
        'payment_policy': paymentPolicy.dbValue,
        'icon_key': iconKey,
        'sort_order': sortOrder,
        'is_active': isActive,
      };

  /// Icons that have a drawing in packages/ui/assets/vehicles.
  static const iconKeys = ['sucker', 'jetting', 'desilting', 'tanker', 'dumper', 'crane', 'pump', 'rickshaw'];
}

class Area {
  const Area({
    required this.id,
    required this.tehsilId,
    required this.nameEn,
    required this.nameUr,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String id, tehsilId, nameEn, nameUr;
  final int sortOrder;
  final bool isActive;

  factory Area.fromJson(Map<String, dynamic> j) => Area(
        id: j['id'] as String,
        tehsilId: j['tehsil_id'] as String,
        nameEn: j['name_en'] as String,
        nameUr: j['name_ur'] as String,
        sortOrder: j['sort_order'] as int? ?? 0,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toRow() =>
      {'tehsil_id': tehsilId, 'name_en': nameEn, 'name_ur': nameUr, 'sort_order': sortOrder, 'is_active': isActive};
}

class Driver {
  const Driver({
    required this.id,
    required this.tehsilId,
    required this.fullName,
    required this.phone,
    this.fullNameUr,
    this.cnic,
    this.licenceNo,
    this.profileId,
    this.isActive = true,
  });

  final String id, tehsilId, fullName, phone;
  final String? fullNameUr, cnic, licenceNo, profileId;
  final bool isActive;

  bool get hasAppLogin => profileId != null;

  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
        id: j['id'] as String,
        tehsilId: j['tehsil_id'] as String? ?? '',
        fullName: j['full_name'] as String,
        fullNameUr: j['full_name_ur'] as String?,
        phone: j['phone'] as String? ?? '',
        cnic: j['cnic'] as String?,
        licenceNo: j['licence_no'] as String?,
        profileId: j['profile_id'] as String?,
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toRow() => {
        'tehsil_id': tehsilId,
        'full_name': fullName,
        'full_name_ur': fullNameUr,
        'phone': phone,
        'cnic': cnic,
        'licence_no': licenceNo,
        'is_active': isActive,
      };
}

class Tariff {
  const Tariff({
    required this.id,
    required this.areaId,
    required this.vehicleTypeId,
    required this.rate,
    required this.pricingUnit,
    required this.effectiveFrom,
    this.isActive = true,
    this.isPlaceholder = false,
  });

  final String id, areaId, vehicleTypeId;
  final double rate;
  final PricingUnit pricingUnit;
  final DateTime effectiveFrom;
  final bool isActive, isPlaceholder;

  factory Tariff.fromJson(Map<String, dynamic> j) => Tariff(
        id: j['id'] as String,
        areaId: j['area_id'] as String,
        vehicleTypeId: j['vehicle_type_id'] as String,
        rate: _num(j['rate']),
        pricingUnit: PricingUnit.fromDb(j['pricing_unit'] as String?),
        effectiveFrom: DateTime.parse(j['effective_from'] as String),
        isActive: j['is_active'] as bool? ?? true,
        isPlaceholder: j['is_placeholder'] as bool? ?? false,
      );
}

/// Active tariff lookup: area x vehicle type.
class TariffTable {
  TariffTable(Iterable<Tariff> tariffs) {
    for (final t in tariffs.where((t) => t.isActive)) {
      _byKey['${t.areaId}|${t.vehicleTypeId}'] = t;
    }
  }
  final _byKey = <String, Tariff>{};

  Tariff? find(String areaId, String vehicleTypeId) => _byKey['$areaId|$vehicleTypeId'];
  bool get isEmpty => _byKey.isEmpty;
}

class VehiclePhoto {
  const VehiclePhoto({required this.id, required this.vehicleId, required this.storagePath, required this.position, required this.kind});

  final String id, vehicleId, storagePath, kind;
  final int position;

  static const kinds = ['front', 'side', 'back', 'equipment'];

  factory VehiclePhoto.fromJson(Map<String, dynamic> j) => VehiclePhoto(
        id: j['id'] as String,
        vehicleId: j['vehicle_id'] as String,
        storagePath: j['storage_path'] as String,
        position: j['position'] as int? ?? 0,
        kind: j['kind'] as String? ?? 'front',
      );
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.tehsilId,
    required this.regNo,
    required this.type,
    required this.status,
    this.makeModel,
    this.year,
    this.capacity,
    this.colour,
    this.defaultDriver,
    this.trackerDeviceId,
    this.notes,
    this.statusReason,
    this.expectedBackOn,
    this.photos = const [],
    this.isActive = true,
  });

  final String id, tehsilId, regNo;
  final VehicleType type;
  final VehicleStatus status;
  final String? makeModel, capacity, colour, trackerDeviceId, notes, statusReason;
  final int? year;
  final Driver? defaultDriver;
  final DateTime? expectedBackOn;
  final List<VehiclePhoto> photos; // sorted, first = main
  final bool isActive;

  VehiclePhoto? get mainPhoto => photos.isEmpty ? null : photos.first;

  /// Columns + embedded type, default driver and photos.
  static const select = '*, type:vehicle_types(*), '
      'driver:drivers!default_driver_id(id, tehsil_id, full_name, full_name_ur, phone, profile_id, is_active), '
      'photos:vehicle_photos(*)';

  factory Vehicle.fromJson(Map<String, dynamic> j) {
    final photos = ((j['photos'] as List?) ?? const [])
        .map((p) => VehiclePhoto.fromJson((p as Map).cast<String, dynamic>()))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    final d = j['driver'] as Map?;
    return Vehicle(
      id: j['id'] as String,
      tehsilId: j['tehsil_id'] as String,
      regNo: j['reg_no'] as String,
      type: VehicleType.fromJson((j['type'] as Map).cast<String, dynamic>()),
      status: VehicleStatus.fromDb(j['status'] as String?),
      makeModel: j['make_model'] as String?,
      year: j['year'] as int?,
      capacity: j['capacity'] as String?,
      colour: j['colour'] as String?,
      defaultDriver: d == null ? null : Driver.fromJson(d.cast<String, dynamic>()),
      trackerDeviceId: j['tracker_device_id'] as String?,
      notes: j['notes'] as String?,
      statusReason: j['status_reason'] as String?,
      expectedBackOn: j['expected_back_on'] == null ? null : DateTime.parse(j['expected_back_on'] as String),
      photos: photos,
      isActive: j['is_active'] as bool? ?? true,
    );
  }
}

/// Editable fields of a vehicle (Masters > Vehicles form).
class VehicleDraft {
  VehicleDraft({
    this.id,
    required this.tehsilId,
    this.regNo = '',
    this.vehicleTypeId,
    this.makeModel,
    this.year,
    this.capacity,
    this.colour,
    this.defaultDriverId,
    this.trackerDeviceId,
    this.notes,
    this.isActive = true,
  });

  factory VehicleDraft.from(Vehicle v) => VehicleDraft(
        id: v.id,
        tehsilId: v.tehsilId,
        regNo: v.regNo,
        vehicleTypeId: v.type.id,
        makeModel: v.makeModel,
        year: v.year,
        capacity: v.capacity,
        colour: v.colour,
        defaultDriverId: v.defaultDriver?.id,
        trackerDeviceId: v.trackerDeviceId,
        notes: v.notes,
        isActive: v.isActive,
      );

  String? id;
  String tehsilId;
  String regNo;
  String? vehicleTypeId, makeModel, capacity, colour, defaultDriverId, trackerDeviceId, notes;
  int? year;
  bool isActive;

  /// `bkr 1234` / `BKR1234` -> `BKR-1234`.
  static String normalizeRegNo(String s) {
    final t = s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '-');
    final m = RegExp(r'^([A-Z]{2,4})-?(\d{1,5})$').firstMatch(t);
    return m == null ? t : '${m[1]}-${m[2]}';
  }

  String? validate() {
    if (normalizeRegNo(regNo).isEmpty) return 'Enter the registration number.';
    if (vehicleTypeId == null) return 'Choose the vehicle type.';
    if (year != null && (year! < 1970 || year! > DateTime.now().year + 1)) return 'Check the model year.';
    return null;
  }

  Map<String, dynamic> toRow() {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return {
      'tehsil_id': tehsilId,
      'reg_no': normalizeRegNo(regNo),
      'vehicle_type_id': vehicleTypeId,
      'make_model': clean(makeModel),
      'year': year,
      'capacity': clean(capacity),
      'colour': clean(colour),
      'default_driver_id': defaultDriverId,
      'tracker_device_id': clean(trackerDeviceId),
      'notes': clean(notes),
      'is_active': isActive,
    };
  }
}

class VehicleStats {
  const VehicleStats({
    required this.vehicleId,
    this.trips = 0,
    this.amountGenerated = 0,
    this.amountPaid = 0,
    this.lastTripAt,
    this.daysInMaintenance = 0,
  });

  final String vehicleId;
  final int trips;
  final double amountGenerated, amountPaid;
  final DateTime? lastTripAt;
  final int daysInMaintenance;

  factory VehicleStats.fromJson(Map<String, dynamic> j) => VehicleStats(
        vehicleId: j['vehicle_id'] as String,
        trips: j['trips'] as int? ?? 0,
        amountGenerated: _num(j['amount_generated']),
        amountPaid: _num(j['amount_paid']),
        lastTripAt: _ts(j['last_trip_at']),
        daysInMaintenance: j['days_in_maintenance'] as int? ?? 0,
      );
}

class MaintenanceEntry {
  const MaintenanceEntry({
    required this.id,
    required this.vehicleId,
    required this.startedOn,
    required this.description,
    this.endedOn,
    this.cost,
  });

  final String id, vehicleId, description;
  final DateTime startedOn;
  final DateTime? endedOn;
  final double? cost;

  bool get isOpen => endedOn == null;

  factory MaintenanceEntry.fromJson(Map<String, dynamic> j) => MaintenanceEntry(
        id: j['id'] as String,
        vehicleId: j['vehicle_id'] as String,
        startedOn: DateTime.parse(j['started_on'] as String),
        endedOn: j['ended_on'] == null ? null : DateTime.parse(j['ended_on'] as String),
        description: j['description'] as String,
        cost: j['cost'] == null ? null : _num(j['cost']),
      );
}

/// One challan in a vehicle's history tab.
class VehicleTrip {
  const VehicleTrip({
    required this.challanId,
    required this.challanNo,
    required this.createdAt,
    required this.customerName,
    required this.areaName,
    required this.amount,
    required this.displayStatus,
    required this.status,
    this.driverName,
    this.doneAt,
  });

  final String challanId, challanNo, customerName, areaName;
  final DateTime createdAt;
  final DateTime? doneAt;
  final double amount;
  final DisplayStatus displayStatus;

  /// The work status (a Done challan may still be unpaid or expired).
  final ChallanStatus status;
  final String? driverName;

  bool get isDone => status == ChallanStatus.done;

  static const select = 'id, challan_no, created_at, done_at, customer_name, amount, status, display_status, '
      'area:areas(name_en), driver:drivers(full_name)';

  factory VehicleTrip.fromJson(Map<String, dynamic> j) => VehicleTrip(
        challanId: j['id'] as String,
        challanNo: j['challan_no'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
        doneAt: _ts(j['done_at']),
        customerName: j['customer_name'] as String,
        areaName: (j['area'] as Map?)?['name_en'] as String? ?? '',
        amount: _num(j['amount']),
        displayStatus: DisplayStatus.fromDb(j['display_status'] as String?),
        status: ChallanStatus.fromDb(j['status'] as String?),
        driverName: (j['driver'] as Map?)?['full_name'] as String?,
      );
}

import '../models/enums.dart';
import '../models/masters.dart';
import '../repositories/vehicle_repository.dart';

/// Vehicle repository for widget tests: no network; unknown calls throw.
class FakeVehicleRepository implements VehicleRepository {
  @override
  String photoUrl(String storagePath) => 'https://example.invalid/$storagePath';

  @override
  void Function() listen(void Function() onChange) => () {};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

/// Small demo data set for widget tests.
class TestData {
  static const sucker = VehicleType(
    id: 't-sucker',
    code: 'sucker',
    nameEn: 'Sewer Suction Unit (Sucker)',
    nameUr: 'سیور سکشن یونٹ (سکر)',
    category: VehicleCategory.sewer,
    pricingUnit: PricingUnit.perTrip,
    paymentPolicy: PaymentPolicy.payAfterService,
    iconKey: 'sucker',
    sortOrder: 1,
  );
  static const tanker = VehicleType(
    id: 't-tanker',
    code: 'tanker',
    nameEn: 'Water Bowser (Tanker)',
    nameUr: 'واٹر باؤزر (ٹینکر)',
    category: VehicleCategory.water,
    pricingUnit: PricingUnit.perTrip,
    paymentPolicy: PaymentPolicy.payAfterService,
    iconKey: 'tanker',
    sortOrder: 4,
  );
  static const driver = Driver(id: 'd1', tehsilId: 'bkr', fullName: 'Ghulam Abbas', phone: '0306-2000001');
  static const area = Area(id: 'a1', tehsilId: 'bkr', nameEn: 'Happy Land', nameUr: 'ہیپی لینڈ', sortOrder: 1);

  static final vehicles = [
    const Vehicle(id: 'v1', tehsilId: 'bkr', regNo: 'BKR-1234', type: sucker, status: VehicleStatus.available,
        capacity: '6,000 litres', defaultDriver: driver),
    const Vehicle(id: 'v2', tehsilId: 'bkr', regNo: 'BKR-2741', type: sucker, status: VehicleStatus.onJob),
    const Vehicle(id: 'v3', tehsilId: 'bkr', regNo: 'BKR-6620', type: tanker, status: VehicleStatus.maintenance,
        statusReason: 'Pump seal leaking'),
  ];

  static final tariffs = TariffTable([
    Tariff(id: 'r1', areaId: 'a1', vehicleTypeId: 't-sucker', rate: 2000, pricingUnit: PricingUnit.perTrip,
        effectiveFrom: DateTime(2026)),
    Tariff(id: 'r2', areaId: 'a1', vehicleTypeId: 't-tanker', rate: 1500, pricingUnit: PricingUnit.perTrip,
        effectiveFrom: DateTime(2026)),
  ]);
}

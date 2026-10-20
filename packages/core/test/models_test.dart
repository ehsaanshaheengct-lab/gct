import 'package:flutter_test/flutter_test.dart';
import 'package:wasa_core/wasa_core.dart';

void main() {
  group('Vehicle registration numbers', () {
    test('are normalised', () {
      expect(VehicleDraft.normalizeRegNo(' bkr 1234 '), 'BKR-1234');
      expect(VehicleDraft.normalizeRegNo('BKR1234'), 'BKR-1234');
      expect(VehicleDraft.normalizeRegNo('bkr-77'), 'BKR-77');
    });

    test('a draft needs a registration and a type', () {
      expect(VehicleDraft(tehsilId: 't').validate(), isNotNull);
      expect(VehicleDraft(tehsilId: 't', regNo: 'BKR-1', vehicleTypeId: 'x').validate(), isNull);
      expect(VehicleDraft(tehsilId: 't', regNo: 'BKR-1', vehicleTypeId: 'x', year: 1900).validate(), isNotNull);
    });

    test('blank optional fields are saved as null', () {
      final row = VehicleDraft(tehsilId: 't', regNo: 'bkr 5', vehicleTypeId: 'x', colour: '  ').toRow();
      expect(row['reg_no'], 'BKR-5');
      expect(row['colour'], isNull);
    });
  });

  test('vehicle photos are sorted, first is the main photo', () {
    final v = Vehicle.fromJson({
      'id': 'v1',
      'tehsil_id': 't',
      'reg_no': 'BKR-1234',
      'status': 'maintenance',
      'status_reason': 'Pump',
      'expected_back_on': '2026-10-23',
      'type': {'id': 'ty', 'code': 'sucker', 'name_en': 'Sucker', 'name_ur': 'سکر', 'category': 'sewer',
               'pricing_unit': 'per_trip', 'payment_policy': 'pay_after_service', 'icon_key': 'sucker'},
      'driver': null,
      'photos': [
        {'id': 'p2', 'vehicle_id': 'v1', 'storage_path': 'v1/b.jpg', 'position': 1, 'kind': 'side'},
        {'id': 'p1', 'vehicle_id': 'v1', 'storage_path': 'v1/a.jpg', 'position': 0, 'kind': 'front'},
      ],
    });
    expect(v.mainPhoto!.id, 'p1');
    expect(v.status, VehicleStatus.maintenance);
    expect(v.expectedBackOn, DateTime(2026, 10, 23));
    expect(v.defaultDriver, isNull);
  });

  test('tariff table finds the active rate for area x type', () {
    final table = TariffTable([
      Tariff(id: 'old', areaId: 'a', vehicleTypeId: 't', rate: 2000, pricingUnit: PricingUnit.perTrip,
          effectiveFrom: DateTime(2026), isActive: false),
      Tariff(id: 'new', areaId: 'a', vehicleTypeId: 't', rate: 2200, pricingUnit: PricingUnit.perTrip,
          effectiveFrom: DateTime(2026, 10)),
    ]);
    expect(table.find('a', 't')!.rate, 2200);
    expect(table.find('a', 'other'), isNull);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/masters.dart';
import 'providers.dart';
import 'repositories/vehicle_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) => VehicleRepository(ref.watch(supabaseProvider)));
final mastersRepositoryProvider = Provider<MastersRepository>((ref) => MastersRepository(ref.watch(supabaseProvider)));

/// Ticks whenever vehicles or challans change (Realtime). Watching it makes a
/// provider reload live. If Realtime is unreachable it simply never ticks.
class LiveTick extends Notifier<int> {
  @override
  int build() {
    final stop = ref.watch(vehicleRepositoryProvider).listen(() => state++);
    ref.onDispose(stop);
    return 0;
  }
}

final liveTickProvider = NotifierProvider<LiveTick, int>(LiveTick.new);

final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  ref.watch(liveTickProvider);
  return ref.watch(vehicleRepositoryProvider).list();
});

/// Including inactive vehicles (Masters).
final allVehiclesProvider = FutureProvider<List<Vehicle>>((ref) {
  ref.watch(liveTickProvider);
  return ref.watch(vehicleRepositoryProvider).list(includeInactive: true);
});

final vehicleStatsProvider = FutureProvider<Map<String, VehicleStats>>((ref) {
  ref.watch(liveTickProvider);
  return ref.watch(vehicleRepositoryProvider).stats();
});

final vehicleProvider = FutureProvider.family<Vehicle, String>((ref, id) {
  ref.watch(liveTickProvider);
  return ref.watch(vehicleRepositoryProvider).get(id);
});

final vehicleTripsProvider = FutureProvider.family<List<VehicleTrip>, String>((ref, id) {
  ref.watch(liveTickProvider);
  return ref.watch(vehicleRepositoryProvider).trips(id);
});

final vehicleMaintenanceProvider = FutureProvider.family<List<MaintenanceEntry>, String>(
    (ref, id) => ref.watch(vehicleRepositoryProvider).maintenance(id));

final vehicleTypesProvider = FutureProvider<List<VehicleType>>((ref) => ref.watch(mastersRepositoryProvider).vehicleTypes());
final areasProvider = FutureProvider<List<Area>>((ref) => ref.watch(mastersRepositoryProvider).areas());
final driversProvider = FutureProvider<List<Driver>>((ref) => ref.watch(mastersRepositoryProvider).drivers());
final tariffTableProvider =
    FutureProvider<TariffTable>((ref) async => TariffTable(await ref.watch(mastersRepositoryProvider).tariffs()));

/// After an edit, reload everything that shows vehicles or masters.
void refreshVehicles(WidgetRef ref) {
  ref.invalidate(vehiclesProvider);
  ref.invalidate(allVehiclesProvider);
  ref.invalidate(vehicleStatsProvider);
  ref.invalidate(vehicleProvider);
  ref.invalidate(vehicleTripsProvider);
  ref.invalidate(vehicleMaintenanceProvider);
}

void refreshMasters(WidgetRef ref) {
  ref.invalidate(vehicleTypesProvider);
  ref.invalidate(areasProvider);
  ref.invalidate(driversProvider);
  ref.invalidate(tariffTableProvider);
  refreshVehicles(ref);
}

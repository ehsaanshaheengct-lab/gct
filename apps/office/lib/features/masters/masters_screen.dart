import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wasa_ui/wasa_ui.dart';

import '../../widgets/common.dart';
import 'simple_masters.dart';
import 'tariff_tab.dart';
import 'vehicles_tab.dart';

/// Admin: Vehicle Types, Vehicles (with photos), Drivers, Areas and the Tariff grid.
class MastersScreen extends ConsumerWidget {
  const MastersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return DefaultTabController(
      length: 5,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(title: s.masters, subtitle: 'Admin'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: const Icon(Icons.category_outlined), text: s.vehicleTypes),
              Tab(icon: const Icon(Icons.local_shipping_outlined), text: s.vehicles),
              Tab(icon: const Icon(Icons.badge_outlined), text: s.drivers),
              Tab(icon: const Icon(Icons.place_outlined), text: s.areas),
              Tab(icon: const Icon(Icons.grid_on_outlined), text: s.tariff),
            ],
          ),
        ),
        const Divider(height: 1),
        const Expanded(
          child: TabBarView(children: [
            VehicleTypesTab(),
            VehiclesTab(),
            DriversTab(),
            AreasTab(),
            TariffTab(),
          ]),
        ),
      ]),
    );
  }
}

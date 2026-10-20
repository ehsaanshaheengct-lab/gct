import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasa_core/testing.dart';
import 'package:wasa_core/wasa_core.dart';
import 'package:wasa_office/features/vehicles/vehicle_board_screen.dart';
import 'package:wasa_ui/wasa_ui.dart';

void main() {
  testWidgets('Vehicle Board shows cards with status, rate, and filters by status', (tester) async {
    tester.view.physicalSize = const Size(1366, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authViewProvider.overrideWithValue(const AuthSignedIn(Profile(
            id: 'u', fullName: 'Rabia Noor', role: UserRole.operator, tehsilId: 'bkr', tehsilCode: 'BKR', tehsilName: 'Bhakkar'))),
        vehicleRepositoryProvider.overrideWithValue(FakeVehicleRepository()),
        vehiclesProvider.overrideWith((ref) async => TestData.vehicles),
        vehicleTypesProvider.overrideWith((ref) async => [TestData.sucker, TestData.tanker]),
        areasProvider.overrideWith((ref) async => [TestData.area]),
        tariffTableProvider.overrideWith((ref) async => TestData.tariffs),
      ],
      child: MaterialApp(theme: WasaTheme.light(), home: const Scaffold(body: VehicleBoardScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('BKR-1234'), findsOneWidget);
    expect(find.text('BKR-2741'), findsOneWidget);
    expect(find.text('BKR-6620'), findsOneWidget);
    expect(find.text('PKR 2,000 / trip'), findsNWidgets(2));
    expect(find.textContaining('Ghulam Abbas'), findsOneWidget);
    expect(find.textContaining('Pump seal leaking'), findsOneWidget);

    // tap the "Maintenance" count tile: only the vehicle in maintenance stays
    await tester.tap(find.text('Maintenance').first);
    await tester.pumpAndSettle();
    expect(find.text('BKR-6620'), findsOneWidget);
    expect(find.text('BKR-1234'), findsNothing);

    // search by registration
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2741');
    await tester.pumpAndSettle();
    expect(find.text('BKR-2741'), findsOneWidget);
    expect(find.text('BKR-1234'), findsNothing);
  });
}

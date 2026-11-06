import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/product_region.dart';
import 'package:pickleo/screens/home_screen.dart';
import 'package:pickleo/state/app_state.dart';

void main() {
  testWidgets(
      'HomeScreen selects first region by default when productRegions are available',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    final testRegions = [
      const ProductRegion(
        id: 'r1',
        name: 'Test Region',
        description: 'Traditional dishes',
      ),
      const ProductRegion(
        id: 'r2',
        name: 'Second Region',
        description: 'Spicy curries',
      ),
    ];
    appState.setProductRegionsForTesting(testRegions);
    appState.setBestsellersForTesting([], region: 'Test Region');

    await tester.pumpWidget(
      AppStateProvider(
        appState: appState,
        child: MaterialApp(
          home: HomeScreen(onNavigateTab: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify "Regional Kitchens" header is shown
    expect(find.text('Regional Kitchens'), findsOneWidget);

    // Verify both region chips are shown
    expect(find.text('Test Region'), findsOneWidget);
    expect(find.text('Second Region'), findsOneWidget);

    // Verify the first region container has the selected background color Color(0xFF003820)
    final firstRegionChip = find.ancestor(
      of: find.text('Test Region'),
      matching: find.byType(Container),
    );
    expect(firstRegionChip, findsWidgets);

    final firstBox = tester.widget<Container>(firstRegionChip.first);
    final firstDecor = firstBox.decoration as BoxDecoration;
    expect(firstDecor.color, const Color(0xFF003820));

    // Verify the second region container is NOT selected (white background)
    final secondRegionChip = find.ancestor(
      of: find.text('Second Region'),
      matching: find.byType(Container),
    );
    final secondBox = tester.widget<Container>(secondRegionChip.first);
    final secondDecor = secondBox.decoration as BoxDecoration;
    expect(secondDecor.color, Colors.white);
  });

  testWidgets(
      'HomeScreen does not render Regional Kitchens strip when productRegions is empty',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    appState.setProductRegionsForTesting([]);
    appState.setBestsellersForTesting([]);

    await tester.pumpWidget(
      AppStateProvider(
        appState: appState,
        child: MaterialApp(
          home: HomeScreen(onNavigateTab: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // "Regional Kitchens" should not appear when there are no regions
    expect(find.text('Regional Kitchens'), findsNothing);
  });
}

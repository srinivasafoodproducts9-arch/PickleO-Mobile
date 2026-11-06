import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/product_detail_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProductDetailScreen bottomNavigationBar has compact height and does not cover body', (WidgetTester tester) async {
    final appState = AppState(initialLoggedIn: true);

    tester.view.physicalSize = const Size(390 * 2, 739 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      AppStateProvider(
        appState: appState,
        child: MaterialApp(
          home: ProductDetailScreen(
            product: ProductData.findById('avakaya'),
            productId: 'avakaya',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify product title / body is visible
    final product = ProductData.findById('avakaya');
    expect(find.text(product.name), findsWidgets);

    // Verify Buy Now button exists
    expect(find.text('Buy Now'), findsOneWidget);

    // Verify bottomNavigationBar height is compact (< 120), NOT full screen (739)
    final scaffoldFinder = find.byType(Scaffold);
    final scaffold = tester.widget<Scaffold>(scaffoldFinder);
    expect(scaffold.bottomNavigationBar, isNotNull);

    final bottomNavBox = tester.renderObject(find.byWidget(scaffold.bottomNavigationBar!)) as RenderBox;
    expect(bottomNavBox.size.height, lessThan(120.0));
    expect(bottomNavBox.size.height, greaterThan(50.0));
  });
}

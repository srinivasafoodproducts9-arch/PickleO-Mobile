import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/cart_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CartScreen bottomNavigationBar has compact height and does not cover body/appBar', (WidgetTester tester) async {
    final appState = AppState(initialLoggedIn: true);
    appState.addToCart(ProductData.findById('avakaya'), '250g');

    tester.view.physicalSize = const Size(390 * 2, 739 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      AppStateProvider(
        appState: appState,
        child: const MaterialApp(home: CartScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Verify AppBar is visible
    expect(find.text('Cart & Checkout'), findsOneWidget);


    // Verify Order Items header is visible in body via RichText
    expect(
      find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Order Items')),
      findsOneWidget,
    );

    // Verify TO PAY and Pay Online exist in bottom bar
    expect(find.text('TO PAY'), findsOneWidget);
    expect(find.text('Pay Online'), findsOneWidget);

    // Verify bottomNavigationBar height is compact (< 150), NOT full screen (739)
    final scaffoldFinder = find.byType(Scaffold);
    final scaffold = tester.widget<Scaffold>(scaffoldFinder);
    expect(scaffold.bottomNavigationBar, isNotNull);

    final bottomNavBox = tester.renderObject(find.byWidget(scaffold.bottomNavigationBar!)) as RenderBox;
    expect(bottomNavBox.size.height, lessThan(150.0));
    expect(bottomNavBox.size.height, greaterThan(60.0));
  });
}

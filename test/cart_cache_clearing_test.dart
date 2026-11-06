import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/cart_item.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/cart_screen.dart';
import 'package:pickleo/state/app_state.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return '[]';
  }

  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cart Cache Clearing and Shared-Cart Sync Tests', () {
    test('Clears cached cart when server returns empty items after web checkout', () {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '350g', qty: 2);

      expect(appState.hasCart, isTrue);
      expect(appState.cartCount, 2);
      expect(appState.cartItems.isNotEmpty, isTrue);

      // Backend returns empty cart (items: []) after successful checkout on web
      const emptyServerCart = ConsumerCartResponse(
        items: [],
        itemCount: 0,
        subtotal: 0.0,
      );

      appState.populateCartFromResponseForTesting(emptyServerCart);

      expect(appState.hasCart, isFalse);
      expect(appState.cartCount, 0);
      expect(appState.cartItems.isEmpty, isTrue);
      expect(appState.appliedCoupon, isNull);
    });

    testWidgets('CartScreen updates from populated to empty state when server cart is cleared', (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '350g', qty: 1);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(home: CartScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially cart has items
      expect(find.text('Cart & Checkout'), findsOneWidget);
      expect(find.text('Your cart is empty'), findsNothing);

      // Web order placement succeeds, server cart now empty
      const emptyServerCart = ConsumerCartResponse(
        items: [],
        itemCount: 0,
        subtotal: 0.0,
      );
      appState.populateCartFromResponseForTesting(emptyServerCart);
      await tester.pumpAndSettle();

      // UI immediately updates to empty cart state
      expect(find.text('Your pantry basket is empty'), findsOneWidget);
      expect(find.text('Add a jar or two from the bestsellers'), findsOneWidget);
    });
  });
}

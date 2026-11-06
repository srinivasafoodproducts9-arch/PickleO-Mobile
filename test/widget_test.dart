import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/main.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/models/order.dart';
import 'package:pickleo/models/cart_item.dart';
import 'package:pickleo/screens/main_navigation.dart';
import 'package:pickleo/screens/cart_screen.dart';
import 'package:pickleo/screens/product_detail_screen.dart';
import 'package:pickleo/screens/payment_screen.dart';
import 'package:pickleo/screens/order_tracking_screen.dart';
import 'package:pickleo/screens/rate_delivery_screen.dart';
import 'package:pickleo/screens/tax_invoice_screen.dart';
import 'package:pickleo/screens/address_screen.dart';
import 'package:pickleo/screens/wallet_screen.dart';
import 'package:pickleo/screens/payment_methods_screen.dart';
import 'package:pickleo/screens/help_screen.dart';
import 'package:pickleo/screens/auth_screen.dart';
import 'package:pickleo/screens/home_screen.dart';
import 'package:pickleo/screens/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class TestAssetBundle extends PlatformAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg')) {
      return ByteData.view(kTransparentImage.buffer);
    }
    return super.load(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PickleO app launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: const PickleOApp(),
      ),
    );
    expect(find.byType(PickleOApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('MainNavigation 5 bottom tabs test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(414 * 3, 896 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState(initialLoggedIn: true);
    appState.clearCart();

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: appState,
          child: const MaterialApp(
            home: MainNavigation(),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify 5 bottom navigation destinations
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('Search'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Account'), findsWidgets);

    // Verify Sticky Cart Bar is hidden until Cart API is integrated
    expect(find.text('View Cart'), findsNothing);

    // Switch to Categories tab
    await tester.tap(find.byIcon(Icons.category_outlined), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Shop by Category'), findsOneWidget);

    // Switch to Search tab
    await tester.tap(find.byIcon(Icons.search_rounded), warnIfMissed: false);
    await tester.pump();
    expect(find.text('Search for authentic pickles, powders & snacks'), findsOneWidget);
    expect(find.text('Trending Searches'), findsNothing);

    // Switch to Orders tab
    await tester.tap(find.byIcon(Icons.receipt_long_outlined), warnIfMissed: false);
    await tester.pump();
    expect(find.text('My Orders'), findsOneWidget);

    // Switch to Account tab
    await tester.tap(find.byIcon(Icons.person_outline_rounded), warnIfMissed: false);
    await tester.pump();
    expect(find.text(appState.userName), findsWidgets);
  });

  testWidgets('Cart & Payment screens test', (WidgetTester tester) async {
    final appState = AppState(initialLoggedIn: true);
    appState.addToCart(ProductData.findById('avakaya'), '250g');

    Widget buildTestScreen(Widget child) {
      return DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: appState,
          child: MaterialApp(home: child),
        ),
      );
    }

    // Product Detail Screen
    await tester.pumpWidget(buildTestScreen(ProductDetailScreen(productId: 'avakaya')));
    await tester.pump();
    expect(find.text('Buy Now'), findsOneWidget);

    // Cart Screen
    await tester.pumpWidget(buildTestScreen(const CartScreen()));
    await tester.pump();
    expect(find.text('Cart & Checkout'), findsOneWidget);
    expect(find.text('Cash on Delivery'), findsNothing);
    expect(find.text('Pay Online'), findsOneWidget);

    // Payment Screen
    await tester.pumpWidget(buildTestScreen(const PaymentScreen()));
    await tester.pump();
    expect(find.text('Payment Options'), findsOneWidget);
    expect(find.text('Google Pay'), findsOneWidget);
    expect(find.text('PhonePe'), findsOneWidget);

    // Order Tracking Screen
    final testOrder = UserOrder(
      id: 'PKL-89421',
      orderDate: DateTime.now(),
      dateDisplay: 'Today',
      items: [
        CartItem(
          product: ProductData.findById('avakaya'),
          selectedWeight: '250g',
          quantity: 1,
        ),
      ],
      subtotal: 299,
      total: 299,
      paymentMethod: 'UPI (Google Pay)',
      deliveryAddress: DeliveryAddress.fallback(),
    );
    await tester.pumpWidget(buildTestScreen(OrderTrackingScreen(order: testOrder)));
    await tester.pump();
    expect(find.text('Order Tracking'), findsOneWidget);

    // Rate Delivery Screen
    await tester.pumpWidget(buildTestScreen(RateDeliveryScreen(orderId: testOrder.id)));
    await tester.pump();
    expect(find.text('Rate Delivery'), findsOneWidget);

    // Tax Invoice Screen
    await tester.pumpWidget(buildTestScreen(TaxInvoiceScreen(order: testOrder)));
    await tester.pump();
    expect(find.text('Tax Invoice'), findsWidgets);

    // Saved Addresses Screen
    await tester.pumpWidget(buildTestScreen(const AddressScreen()));
    await tester.pump();
    expect(find.text('Saved Addresses'), findsOneWidget);

    // Wallet Screen
    await tester.pumpWidget(buildTestScreen(const WalletScreen()));
    await tester.pump();
    expect(find.text('PickleO Wallet'), findsOneWidget);

    // Payment Methods Screen
    await tester.pumpWidget(buildTestScreen(const PaymentMethodsScreen()));
    await tester.pump();
    expect(find.text('Payment Methods'), findsOneWidget);

    // Help Screen
    await tester.pumpWidget(buildTestScreen(const HelpScreen()));
    await tester.pump();
    expect(find.text('Help & Support'), findsOneWidget);
  });

  testWidgets('User icon redirects to login screen when not logged in test',
      (WidgetTester tester) async {
    final unauthenticatedState = AppState(initialLoggedIn: false);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: unauthenticatedState,
          child: MaterialApp(
            home: HomeScreen(onNavigateTab: (_) {}),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify User Icon is shown in unauthenticated state
    final userIconFinder = find.byIcon(Icons.person_outline_rounded);
    expect(userIconFinder, findsOneWidget);

    // Tap User Icon
    await tester.tap(userIconFinder);
    await tester.pumpAndSettle();

    // Verify redirected to AuthScreen (Login / OTP screen)
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('1. Phone Number'), findsOneWidget);
  });

  testWidgets('SearchScreen dynamic recent searches based on user typings and trending searches removed',
      (WidgetTester tester) async {
    final appState = AppState();
    await appState.clearRecentSearches();

    // Verify initially empty
    expect(appState.recentSearches, isEmpty);

    // Simulate user typing searches
    await appState.addRecentSearch('Avakaya');
    await appState.addRecentSearch('Gongura');

    expect(appState.recentSearches.first, 'Gongura');
    expect(appState.recentSearches, contains('Avakaya'));

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: appState,
          child: const MaterialApp(
            home: SearchScreen(isTab: false),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify Trending Searches is removed
    expect(find.text('Trending Searches'), findsNothing);
    expect(find.text('Trending in Bengaluru'), findsNothing);

    // Recent searches section should be visible with user's searches
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.text('Gongura'), findsOneWidget);
    expect(find.text('Avakaya'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);

    // Tap 'Clear all' to clear history
    await tester.tap(find.text('Clear all'));
    await tester.pump();

    // Recent searches list should now be empty and prompt returned
    expect(appState.recentSearches, isEmpty);
    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('Search for authentic pickles, powders & snacks'), findsOneWidget);
  });
}


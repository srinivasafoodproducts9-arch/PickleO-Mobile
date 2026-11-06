import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/cart_item.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/cart_screen.dart';
import 'package:pickleo/screens/payment_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    return ByteData(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cart Screen - Online Payment Button', () {
    testWidgets('Renders Pay Online button at bottom of cart without Cash on Delivery option',
        (WidgetTester tester) async {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 2);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: CartScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('TO PAY'), findsOneWidget);
      expect(find.text('Cash on Delivery'), findsNothing);
      expect(find.text('Pay Online'), findsOneWidget);
      expect(find.byIcon(Icons.payments_outlined), findsNothing);
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
    });

    testWidgets('Tapping Pay Online initiates Razorpay directly from Cart without pushing PaymentScreen',
        (WidgetTester tester) async {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 2);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: CartScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      final payOnlineBtn = find.text('Pay Online');
      expect(payOnlineBtn, findsOneWidget);

      await tester.tap(payOnlineBtn);
      await tester.pump();

      // Confirms PaymentScreen was NOT pushed
      expect(find.byType(PaymentScreen), findsNothing);
    });

    testWidgets('Cart button displays Select Delivery Slot when slots available and unselected, and updates to Pay Online once selected',
        (WidgetTester tester) async {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 1);

      final cartResponse = ConsumerCartResponse.fromJson({
        "items": [
          {
            "productId": "avakaya",
            "quantity": 1,
            "unitPrice": 299,
            "lineTotal": 299,
          }
        ],
        "itemCount": 1,
        "subtotal": 299,
        "delivery": {
          "serviceable": true,
          "pinCode": "560001",
          "slots": ["10:00 AM - 1:00 PM", "2:00 PM - 6:00 PM"],
        }
      });
      appState.populateCartFromResponseForTesting(cartResponse);

      expect(appState.hasDeliverySlots, isTrue);
      expect(appState.isDeliverySlotSelected, isFalse);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: CartScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Expect 'Select Delivery Slot' button
      expect(find.text('Select Delivery Slot'), findsOneWidget);
      expect(find.text('Pay Online'), findsNothing);
      expect(find.byIcon(Icons.schedule_rounded), findsWidgets);

      // Now select a slot
      appState.selectDeliverySlot('2:00 PM - 6:00 PM');
      await tester.pump();

      // Expect 'Pay Online' button
      expect(find.text('Select Delivery Slot'), findsNothing);
      expect(find.text('Pay Online'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsWidgets);
    });

    testWidgets('Tapping Select Delivery Slot opens delivery slot bottom sheet',
        (WidgetTester tester) async {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 1);

      final cartResponse = ConsumerCartResponse.fromJson({
        "items": [
          {
            "productId": "avakaya",
            "quantity": 1,
            "unitPrice": 299,
            "lineTotal": 299,
          }
        ],
        "itemCount": 1,
        "subtotal": 299,
        "delivery": {
          "serviceable": true,
          "pinCode": "560001",
          "slots": ["10:00 AM - 1:00 PM", "2:00 PM - 6:00 PM"],
        }
      });
      appState.populateCartFromResponseForTesting(cartResponse);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: CartScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      final selectSlotBtn = find.text('Select Delivery Slot');
      expect(selectSlotBtn, findsOneWidget);

      await tester.tap(selectSlotBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet title is visible
      expect(find.text('Choose your preferred delivery time window for this order'), findsOneWidget);
      expect(find.text('10:00 AM - 1:00 PM'), findsWidgets);
      expect(find.text('2:00 PM - 6:00 PM'), findsWidgets);

      // Tap slot in bottom sheet
      await tester.tap(find.text('2:00 PM - 6:00 PM').last);
      await tester.pumpAndSettle();

      // Bottom sheet popped and button updated to Pay Online
      expect(appState.selectedDeliverySlot, '2:00 PM - 6:00 PM');
      expect(find.text('Pay Online'), findsOneWidget);
    });
  });

  group('Payment Screen - Razorpay Checkout Flow', () {
    testWidgets('Renders PaymentScreen with UPI, Cards, Net Banking & Razorpay options',
        (WidgetTester tester) async {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 1);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: PaymentScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Payment Options'), findsOneWidget);
      expect(find.text('100% RBI Compliant & 256-Bit Encrypted'), findsOneWidget);
      expect(find.text('Razorpay Verified'), findsOneWidget);
      expect(find.text('Google Pay'), findsOneWidget);
      expect(find.text('PhonePe'), findsOneWidget);
      expect(find.text('Paytm UPI'), findsOneWidget);
      expect(find.text('Credit / Debit Cards'), findsOneWidget);
      expect(find.text('Net Banking'), findsOneWidget);
      expect(find.text('Cash on Delivery'), findsNothing);
      expect(find.textContaining('Pay ₹'), findsOneWidget);
    });

    testWidgets('PaymentScreen does not list Cash on Delivery option',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState(initialLoggedIn: true);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: PaymentScreen(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Ensure Cash on Delivery icon and text do not exist
      final codIcon = find.byIcon(Icons.payments_outlined);
      expect(codIcon, findsNothing);
      expect(find.text('Cash on Delivery'), findsNothing);
    });
  });

  group('AppState - Online Payment Methods', () {
    test('completeOnlineOrder finalizes order state, clears cart and updates orders',
        () async {
      final appState = AppState();
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 2);
      expect(appState.cartCount, greaterThan(0));

      final mockOrderData = {
        'id': 'ORD-ONLINE-999',
        'displayId': 'SFPKLO999',
        'amount': 598.0,
        'subtotal': 598.0,
        'paymentMethod': 'Razorpay Online',
        'paymentStatus': 'Pending Payment',
        'status': 'Processing',
        'items': [
          {
            'productId': avakaya.id,
            'name': avakaya.name,
            'price': 299.0,
            'quantity': 2,
            'weight': '250g',
          }
        ],
      };

      final order = await appState.completeOnlineOrder(
        orderData: mockOrderData,
        razorpayPaymentId: 'pay_test_12345678',
        razorpayOrderId: 'order_test_98765432',
        razorpaySignature: 'sig_mock_signature_abc',
      );

      expect(order.id, 'ORD-ONLINE-999');
      expect(order.paymentStatus, 'Paid');
      expect(order.status, 'Confirmed');
      expect(appState.cartCount, 0);
      expect(appState.hasCart, isFalse);
      expect(appState.orders.any((o) => o.id == 'ORD-ONLINE-999'), isTrue);
    });

    test('completeOnlineOrder handles backend response with amount in paise and populates cart items',
        () async {
      final appState = AppState(initialLoggedIn: true);
      final avakaya = ProductData.findById('avakaya');
      appState.addToCart(avakaya, '250g', qty: 2);
      expect(appState.cartCount, greaterThan(0));

      // Backend response from POST /consumer/payments/razorpay/order
      final backendRazorpayResponse = {
        'keyId': 'rzp_test_mock_key_123',
        'orderId': 'order_rzp_mock_555',
        'amount': 59800, // In paise
        'currency': 'INR',
        'requestId': 'req-uuid-test-111',
      };

      final order = await appState.completeOnlineOrder(
        orderData: backendRazorpayResponse,
        razorpayPaymentId: 'pay_rzp_mock_777',
        razorpayOrderId: 'order_rzp_mock_555',
        razorpaySignature: 'sig_rzp_mock_999',
      );

      expect(order.id, 'order_rzp_mock_555');
      expect(order.paymentStatus, 'Paid');
      expect(order.status, 'Confirmed');
      expect(order.total, 598.0);
      expect(order.items.length, 1);
      expect(order.items.first.product.id, avakaya.id);
      expect(appState.cartCount, 0);
      expect(appState.orders.any((o) => o.id == 'order_rzp_mock_555'), isTrue);
    });
  });
}

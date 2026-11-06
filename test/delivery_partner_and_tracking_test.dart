import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/order.dart';
import 'package:pickleo/screens/order_tracking_screen.dart';
import 'package:pickleo/screens/orders_screen.dart';
import 'package:pickleo/state/app_state.dart';

void main() {
  group('Delivery Partner & Tracking Number Model Tests', () {
    test('Parses carrier and trackingNumber from backend payload', () {
      final json = {
        'id': 'ORD-OUT-101',
        'displayId': 'SFPKLO201',
        'status': 'Out for Delivery',
        'carrier': 'Delhivery',
        'trackingNumber': 'PKL-123456',
        'amount': 450,
        'subtotal': 450,
        'items': [],
      };

      final order = UserOrder.fromJson(json);

      expect(order.carrier, equals('Delhivery'));
      expect(order.trackingNumber, equals('PKL-123456'));
      expect(order.deliveryPartner, equals('Delhivery'));
      expect(order.status, equals('Out for Delivery'));
      expect(order.isOutForDelivery, isTrue);
      expect(order.isLiveActive, isTrue);
      expect(order.hasCourierAssigned, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.orderStep, equals(5));

      // Tracking timeline step 5 reflects Out for Delivery and partner
      expect(order.trackingSteps[5].title, equals('Out for Delivery'));
      expect(order.trackingSteps[5].sub, contains('Delhivery'));

      // Serializes carrier and trackingNumber
      final outJson = order.toJson();
      expect(outJson['carrier'], equals('Delhivery'));
      expect(outJson['trackingNumber'], equals('PKL-123456'));
    });

    test('Parses alternative key variations (tracking_number, courierCompany)', () {
      final json = {
        'id': 'ORD-ALT-102',
        'status': 'out_for_delivery',
        'courierCompany': 'Delhivery',
        'tracking_number': 'PKL-998877',
        'items': [],
      };

      final order = UserOrder.fromJson(json);

      expect(order.deliveryPartner, equals('Delhivery'));
      expect(order.trackingNumber, equals('PKL-998877'));
      expect(order.isOutForDelivery, isTrue);
      expect(order.hasCourierAssigned, isTrue);
    });
  });

  group('OrderTrackingScreen Delivery Partner & Tracking Number Widget Tests', () {
    testWidgets('Displays delivery partner and tracking number when Out for Delivery without AWB mentions',
        (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        'id': 'ORD-DELHIVERY-1',
        'displayId': 'PKL-90001',
        'status': 'Out for Delivery',
        'carrier': 'Delhivery',
        'trackingNumber': 'PKL-123456',
        'amount': 399,
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: order),
          ),
        ),
      );
      await tester.pump();

      // Banner shows Out for Delivery!
      expect(find.text('Out for Delivery!'), findsOneWidget);

      // Card displays carrier "Delhivery"
      expect(find.text('Delhivery'), findsWidgets);

      // Card displays tracking number "PKL-123456"
      expect(find.text('PKL-123456'), findsOneWidget);

      // Must say "Tracking Number" and NOT "Tracking Number (AWB)"
      expect(find.text('Tracking Number'), findsOneWidget);
      expect(find.textContaining('(AWB)'), findsNothing);
      expect(find.textContaining('Copy AWB'), findsNothing);

      // Inline Copy button in tracking box is present
      expect(find.text('Copy'), findsOneWidget);

      // Out for Delivery chip / badge
      expect(find.text('Out for Delivery'), findsWidgets);

      // Track direct action button is present (replaces separate WhatsApp button)
      expect(find.text('Track'), findsOneWidget);

      // Share button is present
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('Tapping Copy button displays copy feedback snackbar',
        (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        'id': 'ORD-DELHIVERY-2',
        'displayId': 'PKL-90002',
        'status': 'Out for Delivery',
        'carrier': 'Delhivery',
        'trackingNumber': 'PKL-123456',
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Scaffold(
              body: OrderTrackingScreen(order: order),
            ),
          ),
        ),
      );
      await tester.pump();

      final copyButton = find.text('Copy');
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pump();

      expect(find.text('Tracking # PKL-123456 copied!'), findsOneWidget);
    });

    testWidgets('Tapping Track button triggers tracking action or dispatch notification',
        (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        'id': 'ORD-DELHIVERY-TRK',
        'displayId': 'PKL-90005',
        'status': 'Out for Delivery',
        'carrier': 'Rapido',
        'trackingNumber': 'RAP-778899',
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Scaffold(
              body: OrderTrackingScreen(order: order),
            ),
          ),
        ),
      );
      await tester.pump();

      final trackButton = find.text('Track');
      expect(trackButton, findsOneWidget);

      await tester.tap(trackButton);
      await tester.pump();

      // Feedback snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Live tracking link will be active once dispatched by Rapido'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Share button opens bottom sheet with WhatsApp and Messages (SMS) options',
        (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        'id': 'ORD-DELHIVERY-3',
        'displayId': 'PKL-90003',
        'status': 'Out for Delivery',
        'carrier': 'Delhivery',
        'trackingNumber': 'PKL-123456',
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Scaffold(
              body: OrderTrackingScreen(order: order),
            ),
          ),
        ),
      );
      await tester.pump();

      final shareButton = find.text('Share');
      expect(shareButton, findsOneWidget);

      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      // Share bottom sheet header
      expect(find.text('Share Tracking Details'), findsOneWidget);

      // WhatsApp option in bottom sheet
      expect(find.text('WhatsApp'), findsWidgets);

      // Inbuilt messaging option (SMS)
      expect(find.text('Default Messages (SMS)'), findsOneWidget);

      // Copy option in bottom sheet
      expect(find.text('Copy Details'), findsOneWidget);

      // Tap Default Messages (SMS)
      await tester.tap(find.text('Default Messages (SMS)'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      // Bottom sheet is dismissed and snackbar is triggered
      expect(find.text('Share Tracking Details'), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Displays Call Captain when courierPhone is present',
        (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        'id': 'ORD-DELHIVERY-PHONE',
        'displayId': 'PKL-90004',
        'status': 'Out for Delivery',
        'carrier': 'Rapido',
        'courierName': 'Ramesh',
        'courierPhone': '+91 9876543210',
        'trackingNumber': 'RAP-112233',
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Scaffold(
              body: OrderTrackingScreen(order: order),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Call Captain'), findsOneWidget);
      expect(find.text('Track'), findsOneWidget);
      expect(find.text('Copy AWB'), findsNothing);
    });
  });

  group('OrdersScreen Delivery Partner & Tracking Pill Tests', () {
    testWidgets('Displays Out for Delivery: Delhivery • Tracking: PKL-123456 in OrdersScreen without AWB',
        (tester) async {
      final appState = AppState();
      final outOrder = UserOrder.fromJson({
        'id': 'ORD-DELHIVERY-LIST',
        'displayId': 'PKL-90003',
        'status': 'Out for Delivery',
        'carrier': 'Delhivery',
        'trackingNumber': 'PKL-123456',
        'total': 499,
        'items': [],
      });

      appState.setActiveOrder(outOrder);

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: const MaterialApp(
            home: OrdersScreen(isTab: false),
          ),
        ),
      );
      await tester.pump();

      // Verify order badge shows Out for Delivery
      expect(find.text('Out for Delivery'), findsWidgets);

      // Verify delivery partner Delhivery and tracking number are visible without AWB
      expect(find.textContaining('Delhivery'), findsWidgets);
      expect(find.textContaining('PKL-123456'), findsWidgets);
      expect(find.textContaining('AWB'), findsNothing);
    });
  });
}

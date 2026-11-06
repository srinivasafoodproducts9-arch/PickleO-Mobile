import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/order.dart';
import 'package:pickleo/screens/order_tracking_screen.dart';
import 'package:pickleo/screens/profile_screen.dart';
import 'package:pickleo/screens/tax_invoice_screen.dart';
import 'package:pickleo/state/app_state.dart';

void main() {
  group('Order Status & Model Tests', () {
    const allStatuses = [
      'Pending',
      'Confirmed',
      'Processing',
      'Packed',
      'Ready for Dispatch',
      'Shipped',
      'Delivered',
      'Cancelled',
      'Returned',
    ];

    test('All 9 statuses parse properly from JSON with correct flags', () {
      for (final status in allStatuses) {
        final json = {
          'id': 'ORD-123',
          'displayId': 'SFPKLO101',
          'status': status,
          'amount': 250,
          'subtotal': 250,
          'items': [],
        };

        final order = UserOrder.fromJson(json);
        expect(order.status, equals(status));

        switch (status) {
          case 'Pending':
            expect(order.isLiveActive, isTrue);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isTrue);
            expect(order.orderStep, equals(0));
            break;
          case 'Confirmed':
            expect(order.isLiveActive, isTrue);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isTrue);
            expect(order.orderStep, equals(1));
            break;
          case 'Processing':
            expect(order.isLiveActive, isTrue);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isTrue);
            expect(order.cancelClosed, isFalse);
            expect(order.orderStep, equals(2));
            break;
          case 'Packed':
            expect(order.isLiveActive, isTrue);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isFalse);
            expect(order.cancelClosed, isTrue);
            expect(order.orderStep, equals(3));
            break;
          case 'Ready for Dispatch':
            expect(order.isLiveActive, isTrue);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isFalse);
            expect(order.cancelClosed, isTrue);
            expect(order.orderStep, equals(4));
            break;
          case 'Shipped':
            expect(order.isLiveActive, isTrue);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isFalse);
            expect(order.cancelClosed, isTrue);
            expect(order.orderStep, equals(5));
            break;
          case 'Delivered':
            expect(order.isLiveActive, isFalse);
            expect(order.isDelivered, isTrue);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isFalse);
            expect(order.cancelClosed, isFalse);
            expect(order.orderStep, equals(6));
            break;
          case 'Cancelled':
            expect(order.isLiveActive, isFalse);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isTrue);
            expect(order.isReturned, isFalse);
            expect(order.canCancel, isFalse);
            expect(order.cancelClosed, isFalse);
            break;
          case 'Returned':
            expect(order.isLiveActive, isFalse);
            expect(order.isDelivered, isFalse);
            expect(order.isCancelled, isFalse);
            expect(order.isReturned, isTrue);
            expect(order.canCancel, isFalse);
            expect(order.cancelClosed, isFalse);
            break;
        }
      }
    });

    test('Tracking steps timeline generates 7 stages with correct progress', () {
      final orderDelivered = UserOrder.fromJson({
        'id': 'ORD-DEL',
        'status': 'Delivered',
        'items': [],
      });
      expect(orderDelivered.trackingSteps.length, equals(7));
      expect(orderDelivered.trackingSteps.every((s) => s.state == 'done'), isTrue);

      final orderShipped = UserOrder.fromJson({
        'id': 'ORD-SHIP',
        'status': 'Shipped',
        'items': [],
      });
      expect(orderShipped.trackingSteps.length, equals(7));
      expect(orderShipped.trackingSteps[5].state, equals('now'));
      expect(orderShipped.trackingSteps[6].state, equals('todo'));
    });
  });

  group('OrderTrackingScreen Rate Button Visibility Tests', () {
    testWidgets('Rate button is HIDDEN when order is in Pending status',
        (tester) async {
      final appState = AppState();
      final pendingOrder = UserOrder.fromJson({
        'id': 'ORD-PENDING',
        'displayId': 'SFPKLO101',
        'status': 'Pending',
        'amount': 250,
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: pendingOrder),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rate Your Delivery Experience'), findsNothing);
      expect(find.text('Order Placed (Pending)'), findsOneWidget);
    });

    testWidgets('Rate button is HIDDEN when order is Shipped',
        (tester) async {
      final appState = AppState();
      final shippedOrder = UserOrder.fromJson({
        'id': 'ORD-SHIPPED',
        'displayId': 'SFPKLO102',
        'status': 'Shipped',
        'amount': 250,
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: shippedOrder),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rate Your Delivery Experience'), findsNothing);
      expect(find.text('Shipped & On The Way'), findsOneWidget);
    });

    testWidgets('Rate button is DISPLAYED when order is Delivered',
        (tester) async {
      final appState = AppState();
      final deliveredOrder = UserOrder.fromJson({
        'id': 'ORD-DELIVERED',
        'displayId': 'SFPKLO103',
        'status': 'Delivered',
        'amount': 250,
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: deliveredOrder),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rate Your Delivery Experience'), findsOneWidget);
      expect(find.text('Delivered! Enjoy your jars'), findsOneWidget);
    });

    testWidgets('Rate button is HIDDEN when order is Cancelled',
        (tester) async {
      final appState = AppState();
      final cancelledOrder = UserOrder.fromJson({
        'id': 'ORD-CANCELLED',
        'displayId': 'SFPKLO104',
        'status': 'Cancelled',
        'amount': 250,
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: cancelledOrder),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rate Your Delivery Experience'), findsNothing);
      expect(find.text('Order Cancelled'), findsOneWidget);
    });

    testWidgets('Rate button is HIDDEN when order is Returned',
        (tester) async {
      final appState = AppState();
      final returnedOrder = UserOrder.fromJson({
        'id': 'ORD-RETURNED',
        'displayId': 'SFPKLO105',
        'status': 'Returned',
        'amount': 250,
        'items': [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: returnedOrder),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rate Your Delivery Experience'), findsNothing);
      expect(find.text('Order Returned'), findsOneWidget);
    });
  });

  group('DeliveredAt & Server Response Parsing Tests', () {
    test('Correctly parses deliveredAt date and rating from server order details response', () {
      final jsonResponse = {
        "id": "ord-server-001",
        "displayId": "SFPKLO888",
        "status": "Delivered",
        "paymentMethod": "COD",
        "paymentStatus": "Paid",
        "items": [],
        "subtotal": 350,
        "amount": 350,
        "fulfilmentCentre": "Bangalore Central Cold Hub",
        "deliveredAt": "2026-10-07T06:39:26.409Z",
        "rating": {
          "orderId": "ord-server-001",
          "rating": 5,
          "tags": ["Authentic Grandmother Taste", "Safe Glass Packaging"],
          "feedback": "Outstanding traditional taste and safely packed!",
          "photoKey": "string",
          "photoUrl": "string",
          "rewardPoints": 50,
          "createdAt": "2026-10-07T06:39:26.409Z"
        },
        "createdAt": "2026-10-07T06:39:26.409Z"
      };

      final order = UserOrder.fromJson(jsonResponse);

      expect(order.id, equals('ord-server-001'));
      expect(order.displayId, equals('SFPKLO888'));
      expect(order.isDelivered, isTrue);
      expect(order.deliveredAt, isNotNull);
      expect(order.deliveredAt!.year, equals(2026));
      expect(order.deliveredAt!.month, equals(10));
      expect(order.deliveredAt!.day, equals(7));

      // Rating object parsed
      expect(order.rating, isNotNull);
      expect(order.rating!.rating, equals(5));
      expect(order.rating!.tags, contains('Authentic Grandmother Taste'));
      expect(order.rating!.feedback, equals('Outstanding traditional taste and safely packed!'));
      expect(order.rating!.rewardPoints, equals(50));
      // Defensive check: 'string' swagger placeholders ignored
      expect(order.rating!.photoUrl, isNull);
      expect(order.rating!.photoKey, isNull);

      // deliveredDateFormatted should format cleanly
      expect(order.deliveredDateFormatted, contains('7 Oct 2026'));
      expect(order.deliveredTimeShort, contains('7 Oct'));
    });

    test('Tracking steps show Pending for future stages and deliveredAt for final stage when delivered', () {
      final json = {
        "id": "ord-step-test",
        "status": "Delivered",
        "deliveredAt": "2026-10-07T06:39:26.409Z",
        "deliverySlot": "2:00 pm - 6:00 pm",
        "items": [],
      };
      final order = UserOrder.fromJson(json);
      final steps = order.trackingSteps;

      expect(steps.length, equals(7));
      expect(steps.every((s) => s.state == 'done'), isTrue);
      expect(steps.last.time, contains('7 Oct'));
    });
  });

  group('Cancellation Rule Based on Status (No Cancellation If Already Packed)', () {
    test('Early stages can cancel (Pending, Confirmed, Processing)', () {
      for (final s in ['Pending', 'Confirmed', 'Processing']) {
        final order = UserOrder.fromJson({'id': 'ord-cancel-1', 'status': s, 'items': []});
        expect(order.canCancel, isTrue, reason: 'Status $s should be cancellable');
        expect(order.cancelClosed, isFalse);
      }
    });

    test('Stages after and including Packed CANNOT cancel', () {
      for (final s in ['Packed', 'Ready for Dispatch', 'Shipped', 'Delivered', 'Cancelled', 'Returned']) {
        final order = UserOrder.fromJson({'id': 'ord-cancel-2', 'status': s, 'items': []});
        expect(order.canCancel, isFalse, reason: 'Status $s should NOT be cancellable');
      }
    });

    testWidgets('OrderTrackingScreen displays cancel link before packed, closed notice once packed', (tester) async {
      final appState = AppState();

      // Test 1: Processing -> Cancel link visible
      final processingOrder = UserOrder.fromJson({
        'id': 'ord-proc',
        'status': 'Processing',
        'items': [],
      });
      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: processingOrder),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Cancel Order · free cancellation before packing'), findsOneWidget);

      // Test 2: Packed -> Cancellation closed notice visible
      final packedOrder = UserOrder.fromJson({
        'id': 'ord-packed',
        'status': 'Packed',
        'items': [],
      });
      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: packedOrder),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Cancel Order · free cancellation before packing'), findsNothing);
      expect(find.textContaining('Cancellation closed'), findsOneWidget);
    });
  });

  group('OrderTrackingScreen Rating Card & CTA Visibility Tests', () {
    testWidgets('Shows rating card with stars, tags & feedback when rating != null', (tester) async {
      final appState = AppState();
      final ratedOrder = UserOrder.fromJson({
        'id': 'ord-with-rating',
        'status': 'Delivered',
        'items': [],
        'deliveredAt': '2026-10-07T06:39:26.409Z',
        'rating': {
          'orderId': 'ord-with-rating',
          'rating': 5,
          'tags': ['Authentic Taste', 'Aromatic Oils'],
          'feedback': 'Traditional perfection!',
          'rewardPoints': 50,
        },
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: ratedOrder),
          ),
        ),
      );
      await tester.pump();

      // Rating card is displayed
      expect(find.text('Your Delivery Rating'), findsOneWidget);
      expect(find.text('5.0 / 5.0'), findsOneWidget);
      expect(find.text('Authentic Taste'), findsOneWidget);
      expect(find.text('Aromatic Oils'), findsOneWidget);
      expect(find.text('Traditional perfection!'), findsOneWidget);
      expect(find.text('+50 Spice Pts'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      // Rate CTA button is NOT shown because rating already exists
      expect(find.text('Rate Your Delivery Experience'), findsNothing);
    });

    testWidgets('Shows Rate Your Delivery Experience CTA when isDelivered and rating == null', (tester) async {
      final appState = AppState();
      final deliveredUnratedOrder = UserOrder.fromJson({
        'id': 'ord-unrated',
        'status': 'Delivered',
        'items': [],
        'deliveredAt': '2026-10-07T06:39:26.409Z',
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: deliveredUnratedOrder),
          ),
        ),
      );
      await tester.pump();

      // CTA button is displayed
      expect(find.text('Rate Your Delivery Experience'), findsOneWidget);
      // Rating card is NOT shown
      expect(find.text('Your Delivery Rating'), findsNothing);
    });
  });

  group('ProfileScreen Feature Hub Tests', () {
    testWidgets(
        'PickleO Wallet, Spice Points, Refer a Friend, Saved Addresses, Orders, and Help are displayed, while Payment Methods and Loyalty Tier Card remain hidden',
        (tester) async {
      final appState = AppState(initialLoggedIn: true);

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: const MaterialApp(
            home: ProfileScreen(isTab: false),
          ),
        ),
      );
      await tester.pump();

      // Verify active account hub items are displayed
      expect(find.text('PickleO Wallet & Cash'), findsOneWidget);
      expect(find.text('Spice Points & Rewards'), findsOneWidget);
      expect(find.text('Refer a Friend'), findsOneWidget);
      expect(find.text('Saved Addresses'), findsOneWidget);
      expect(find.text('My Orders & Invoices'), findsOneWidget);
      expect(find.text('Help & Support'), findsOneWidget);

      // Verify upcoming features remain hidden
      expect(find.text('Payment Methods & UPI'), findsNothing);
      expect(find.text('PickleO Explorer'), findsNothing);
      expect(find.text('Benefits ›'), findsNothing);
    });
  });

  group('StatusHistory Timeline Date & Time Display Tests', () {
    test('Correctly parses statusHistory and maps changedAt to tracking step times', () {
      final jsonResponse = {
        "id": "ord-timeline-101",
        "displayId": "SFPKLO555",
        "status": "Ready for Dispatch",
        "createdAt": "2026-10-07T04:25:00.000Z",
        "statusHistory": [
          {
            "status": "Pending",
            "changedAt": "2026-10-07T04:25:00.000Z"
          },
          {
            "status": "Confirmed",
            "changedAt": "2026-10-07T04:35:00.000Z"
          },
          {
            "status": "Processing",
            "changedAt": "2026-10-07T04:50:00.000Z"
          },
          {
            "status": "Packed",
            "changedAt": "2026-10-07T05:10:00.000Z"
          },
          {
            "status": "Ready for Dispatch",
            "changedAt": "2026-10-07T05:40:00.000Z"
          }
        ]
      };

      final order = UserOrder.fromJson(jsonResponse);

      expect(order.statusHistory.length, equals(5));
      expect(order.orderStep, equals(4));

      final steps = order.trackingSteps;
      expect(steps.length, equals(7));

      // Steps 0-3 are 'done'
      expect(steps[0].state, equals('done'));
      expect(steps[0].title, equals('Order Placed'));

      expect(steps[1].state, equals('done'));
      expect(steps[1].title, equals('Order Confirmed'));

      expect(steps[2].state, equals('done'));
      expect(steps[2].title, equals('Processing & Jarring'));

      expect(steps[3].state, equals('done'));
      expect(steps[3].title, equals('Freshly Packed in Ceramic Martaban'));

      // Step 4 is 'now'
      expect(steps[4].state, equals('now'));
      expect(steps[4].title, equals('Ready for Dispatch'));

      // Steps 5 & 6 are 'todo' and show 'Pending'
      expect(steps[5].state, equals('todo'));
      expect(steps[5].title, equals('Shipped & In Transit'));
      expect(steps[5].time, equals('Pending'));

      expect(steps[6].state, equals('todo'));
      expect(steps[6].title, equals('Delivered to Doorstep'));
      expect(steps[6].time, equals('Pending'));

      // Exact times match the formatted changedAt from statusHistory
      final t0 = DateTime.parse("2026-10-07T04:25:00.000Z").toLocal();
      final expected0Min = t0.minute.toString().padLeft(2, '0');
      final expected0Hour = t0.hour > 12 ? t0.hour - 12 : (t0.hour == 0 ? 12 : t0.hour);
      final expected0AmPm = t0.hour >= 12 ? 'PM' : 'AM';
      expect(steps[0].time, equals('$expected0Hour:$expected0Min $expected0AmPm'));

      final t4 = DateTime.parse("2026-10-07T05:40:00.000Z").toLocal();
      final expected4Min = t4.minute.toString().padLeft(2, '0');
      final expected4Hour = t4.hour > 12 ? t4.hour - 12 : (t4.hour == 0 ? 12 : t4.hour);
      final expected4AmPm = t4.hour >= 12 ? 'PM' : 'AM';
      expect(steps[4].time, equals('$expected4Hour:$expected4Min $expected4AmPm'));
    });

    test('Delivered status in statusHistory automatically populates deliveredAt and doorstep step', () {
      final jsonResponse = {
        "id": "ord-timeline-102",
        "displayId": "SFPKLO556",
        "status": "Delivered",
        "createdAt": "2026-10-07T06:00:00.000Z",
        "statusHistory": [
          {
            "status": "Pending",
            "changedAt": "2026-10-07T06:00:00.000Z"
          },
          {
            "status": "Confirmed",
            "changedAt": "2026-10-07T06:15:00.000Z"
          },
          {
            "status": "Delivered",
            "changedAt": "2026-10-07T08:30:00.000Z"
          }
        ]
      };

      final order = UserOrder.fromJson(jsonResponse);

      expect(order.statusHistory.length, equals(3));
      expect(order.isDelivered, isTrue);
      expect(order.deliveredAt, isNotNull);
      expect(order.deliveredAt, equals(DateTime.parse("2026-10-07T08:30:00.000Z")));

      final steps = order.trackingSteps;
      expect(steps.every((s) => s.state == 'done'), isTrue);

      final tDelivered = DateTime.parse("2026-10-07T08:30:00.000Z").toLocal();
      final expectedHour = tDelivered.hour > 12 ? tDelivered.hour - 12 : (tDelivered.hour == 0 ? 12 : tDelivered.hour);
      final expectedMin = tDelivered.minute.toString().padLeft(2, '0');
      final expectedAmPm = tDelivered.hour >= 12 ? 'PM' : 'AM';
      expect(steps.last.time, contains('$expectedHour:$expectedMin $expectedAmPm'));
    });

    testWidgets('OrderTrackingScreen renders exact timeline times on screen', (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        "id": "ord-timeline-ui",
        "displayId": "SFPKLO777",
        "status": "Ready for Dispatch",
        "createdAt": "2026-10-07T04:25:00.000Z",
        "statusHistory": [
          {
            "status": "Pending",
            "changedAt": "2026-10-07T04:25:00.000Z"
          },
          {
            "status": "Ready for Dispatch",
            "changedAt": "2026-10-07T05:40:00.000Z"
          }
        ]
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

      expect(find.text('Tracking Status'), findsOneWidget);
      expect(find.text('Live Updates'), findsOneWidget);
      expect(find.text('Order Placed'), findsOneWidget);
      // 'Ready for Dispatch' appears as both the top banner title and the timeline step
      expect(find.text('Ready for Dispatch'), findsNWidgets(2));
      expect(find.text('Shipped & In Transit'), findsOneWidget);
      // 'Pending' appears for the pending steps in the timeline
      expect(find.text('Pending'), findsWidgets);
    });

    test('UserOrder.shortOrderNumber truncates 64-char hex hash cleanly and preserves friendly IDs', () {
      final friendlyOrder = UserOrder.fromJson({
        'id': 'ord-123',
        'displayId': 'SFPKLO104',
        'items': [],
      });
      expect(friendlyOrder.shortOrderNumber, equals('SFPKLO104'));

      final longHexOrder = UserOrder.fromJson({
        'id': 'bda476d2078445e9c47ed73dfc601058f965d651b93f827f524875ab71b9f62b',
        'displayId': 'bda476d2078445e9c47ed73dfc601058f965d651b93f827f524875ab71b9f62b',
        'items': [],
      });
      expect(longHexOrder.shortOrderNumber, equals('BDA476D207'));
    });

    testWidgets('TaxInvoiceScreen displays Order ID instead of Invoice ID and handles long UUID', (tester) async {
      final appState = AppState();
      final longIdOrder = UserOrder.fromJson({
        "id": "bda476d2078445e9c47ed73dfc601058f965d651b93f827f524875ab71b9f62b",
        "displayId": "bda476d2078445e9c47ed73dfc601058f965d651b93f827f524875ab71b9f62b",
        "status": "Delivered",
        "amount": 410,
        "subtotal": 390,
        "packagingFee": 20,
        "items": [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: TaxInvoiceScreen(order: longIdOrder),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tax Invoice'), findsNWidgets(2));
      // Shows Order ID, NOT "Invoice #INV-..."
      expect(find.text('Order #BDA476D207'), findsOneWidget);
      expect(find.text('#BDA476D207'), findsOneWidget);
      expect(find.textContaining('Invoice #INV'), findsNothing);
      expect(find.text('Download PDF'), findsOneWidget);
      expect(find.text('Email Invoice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TaxInvoiceScreen Email Invoice opens modal and sends invoice email', (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        "id": "ord-test-email",
        "displayId": "SFPKLO104",
        "status": "Delivered",
        "amount": 300,
        "items": [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: TaxInvoiceScreen(order: order),
          ),
        ),
      );
      await tester.pump();

      await tester.ensureVisible(find.text('Email Invoice'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email Invoice'));
      await tester.pumpAndSettle();
      expect(find.text('Email Tax Invoice'), findsOneWidget);
      expect(find.text('Send Invoice PDF'), findsOneWidget);

      await tester.tap(find.text('Send Invoice PDF'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tax invoice emailed to'), findsOneWidget);
    });

    testWidgets('TaxInvoiceScreen Download PDF generates and shows download modal', (tester) async {
      final appState = AppState();
      final order = UserOrder.fromJson({
        "id": "ord-test-pdf",
        "displayId": "SFPKLO104",
        "status": "Delivered",
        "amount": 300,
        "items": [],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: TaxInvoiceScreen(order: order),
          ),
        ),
      );
      await tester.pump();

      final downloadButton = find.byKey(const Key('download_pdf_button'));
      await tester.ensureVisible(downloadButton);
      await tester.pumpAndSettle();
      await tester.tap(downloadButton);
      await tester.pumpAndSettle();
      expect(find.text('Invoice PDF Downloaded'), findsOneWidget);
      expect(find.text('Preview Document'), findsOneWidget);
    });
  });
}

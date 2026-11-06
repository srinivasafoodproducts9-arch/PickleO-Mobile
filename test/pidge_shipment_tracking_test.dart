import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleo/models/order.dart';
import 'package:pickleo/screens/order_tracking_screen.dart';
import 'package:pickleo/services/auth_service.dart';
import 'package:pickleo/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'mock-consumer-token-12345',
      'refresh_token': 'mock-refresh-token-12345',
    });
    AuthService().authToken = 'mock-consumer-token-12345';
    AuthService().mockAuthenticatedRequestHandler = null;
  });

  tearDown(() {
    AuthService().mockAuthenticatedRequestHandler = null;
  });

  group('Pidge DeliveryTracking Model Tests', () {
    test('Parses complete DeliveryTracking snapshot from backend payload', () {
      final json = {
        'provider': 'Pidge',
        'shipmentId': 'pid-sh-99001',
        'orderStatus': 'fulfilled',
        'fulfillmentStatus': 'OUT_FOR_DELIVERY',
        'trackingCode': 'trk-code-123',
        'trackingUrl': 'https://tracking.pidge.in/?t=trk-code-123',
        'updatedAt': '2026-10-20T04:00:00Z',
        'checkedAt': '2026-10-20T04:01:00.000Z',
      };

      final tracking = DeliveryTracking.fromJson(json);

      expect(tracking.provider, equals('Pidge'));
      expect(tracking.shipmentId, equals('pid-sh-99001'));
      expect(tracking.orderStatus, equals('fulfilled'));
      expect(tracking.fulfillmentStatus, equals('OUT_FOR_DELIVERY'));
      expect(tracking.trackingCode, equals('trk-code-123'));
      expect(tracking.trackingUrl, equals('https://tracking.pidge.in/?t=trk-code-123'));
      expect(tracking.displayStatus, equals('OUT_FOR_DELIVERY'));
      expect(tracking.formattedDisplayStatus, equals('Out for Delivery'));
      expect(tracking.hasValidTrackingUrl, isTrue);
      expect(tracking.isPidge, isTrue);
      expect(tracking.isOutForDelivery, isTrue);
      expect(tracking.isDelivered, isFalse);

      final outJson = tracking.toJson();
      expect(outJson['provider'], equals('Pidge'));
      expect(outJson['shipmentId'], equals('pid-sh-99001'));
      expect(outJson['trackingUrl'], equals('https://tracking.pidge.in/?t=trk-code-123'));
    });

    test('Display rules: displays fulfillmentStatus when present, otherwise orderStatus', () {
      final withBoth = DeliveryTracking(
        orderStatus: 'fulfilled',
        fulfillmentStatus: 'REACHED_DELIVERY',
      );
      expect(withBoth.displayStatus, equals('REACHED_DELIVERY'));
      expect(withBoth.formattedDisplayStatus, equals('Reached Delivery'));

      final orderStatusOnly = DeliveryTracking(
        orderStatus: 'pending',
        fulfillmentStatus: '',
      );
      expect(orderStatusOnly.displayStatus, equals('pending'));
      expect(orderStatusOnly.formattedDisplayStatus, equals('Pending Allocation'));
    });

    test('Supports unknown status values without crashing or translating to Delivered', () {
      final unknownStatus = DeliveryTracking(
        fulfillmentStatus: 'CUSTOM_HUB_TRANSIT',
      );
      expect(unknownStatus.displayStatus, equals('CUSTOM_HUB_TRANSIT'));
      expect(unknownStatus.formattedDisplayStatus, equals('Custom Hub Transit'));
      expect(unknownStatus.isDelivered, isFalse);
    });

    test('Validates HTTPS-only trackingUrl and rejects insecure or empty URLs', () {
      final httpTracking = DeliveryTracking(
        trackingUrl: 'http://tracking.pidge.in/?t=123',
      );
      expect(httpTracking.hasValidTrackingUrl, isFalse);

      final emptyTracking = DeliveryTracking(
        trackingUrl: '',
      );
      expect(emptyTracking.hasValidTrackingUrl, isFalse);

      final httpsTracking = DeliveryTracking(
        trackingUrl: 'https://tracking.pidge.in/?t=abc',
      );
      expect(httpsTracking.hasValidTrackingUrl, isTrue);
    });
  });

  group('UserOrder Pidge Shipment Tracking Integration Tests', () {
    test('UserOrder parses deliveryTracking and enables Pidge tracking getters', () {
      final json = {
        'id': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'displayId': 'TEST-1001',
        'status': 'Packed',
        'carrier': 'Pidge',
        'trackingNumber': 'example-pidge-shipment',
        'trackingUrl': 'https://tracking.pidge.in/?t=example-code',
        'deliveryTracking': {
          'provider': 'Pidge',
          'shipmentId': 'example-pidge-shipment',
          'orderStatus': 'fulfilled',
          'fulfillmentStatus': 'OUT_FOR_DELIVERY',
          'trackingCode': 'example-code',
          'trackingUrl': 'https://tracking.pidge.in/?t=example-code',
          'updatedAt': '2026-10-20T04:00:00Z',
          'checkedAt': '2026-10-20T04:01:00.000Z',
        },
        'statusHistory': [
          {'status': 'Packed', 'changedAt': '2026-10-20T03:00:00Z'}
        ],
        'items': [],
      };

      final order = UserOrder.fromJson(json);

      expect(order.deliveryTracking, isNotNull);
      expect(order.deliveryTracking!.provider, equals('Pidge'));
      expect(order.deliveryPartner, equals('Pidge'));
      expect(order.hasCourierAssigned, isTrue);
      expect(order.hasValidTrackingUrl, isTrue);
      expect(order.effectiveTrackingUrl, equals('https://tracking.pidge.in/?t=example-code'));
      // Commerce Packed coexists with Pidge OUT_FOR_DELIVERY
      expect(order.status, equals('Packed'));
      expect(order.isOutForDelivery, isTrue);
    });

    test('UserOrder marks isDelivered true when deliveryTracking reports DELIVERED', () {
      final json = {
        'id': 'del-order-64hex-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'displayId': 'DEL-1002',
        'status': 'Shipped',
        'deliveryTracking': {
          'provider': 'Pidge',
          'shipmentId': 'pid-del-1',
          'orderStatus': 'completed',
          'fulfillmentStatus': 'DELIVERED',
          'trackingUrl': 'https://tracking.pidge.in/?t=del-code',
        },
        'items': [],
      };

      final order = UserOrder.fromJson(json);
      expect(order.deliveryTracking!.isDelivered, isTrue);
      expect(order.isDelivered, isTrue);
    });

    test('UserOrder serializes trackingUrl and deliveryTracking to JSON', () {
      final order = UserOrder.placeholder('ord-json-test').copyWith(
        carrier: 'Pidge',
        trackingNumber: 'pid-123',
        trackingUrl: 'https://tracking.pidge.in/?t=code-123',
        deliveryTracking: const DeliveryTracking(
          provider: 'Pidge',
          shipmentId: 'pid-123',
          fulfillmentStatus: 'OUT_FOR_DELIVERY',
          trackingUrl: 'https://tracking.pidge.in/?t=code-123',
        ),
      );

      final json = order.toJson();
      expect(json['trackingUrl'], equals('https://tracking.pidge.in/?t=code-123'));
      expect(json['deliveryTracking'], isNotNull);
      expect(json['deliveryTracking']['provider'], equals('Pidge'));
      expect(json['deliveryTracking']['fulfillmentStatus'], equals('OUT_FOR_DELIVERY'));
    });
  });

  group('AuthService refreshOrderTracking API Tests', () {
    test('refreshOrderTracking sends POST with {} and parses 200 response', () async {
      final auth = AuthService();
      final mockOrderId = 'a' * 64;

      auth.mockAuthenticatedRequestHandler = (token) async {
        expect(token, equals('mock-consumer-token-12345'));
        return http.Response(
          jsonEncode({
            'id': mockOrderId,
            'displayId': 'TEST-1001',
            'status': 'Packed',
            'carrier': 'Pidge',
            'trackingNumber': 'pidge-ship-1',
            'trackingUrl': 'https://tracking.pidge.in/?t=code-1',
            'deliveryTracking': {
              'provider': 'Pidge',
              'shipmentId': 'pidge-ship-1',
              'orderStatus': 'fulfilled',
              'fulfillmentStatus': 'OUT_FOR_DELIVERY',
              'trackingCode': 'code-1',
              'trackingUrl': 'https://tracking.pidge.in/?t=code-1',
              'checkedAt': '2026-10-20T04:01:00Z',
            },
            'items': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final response = await auth.refreshOrderTracking(orderId: mockOrderId);

      expect(response.success, isTrue);
      expect(response.data, isNotNull);
      expect(response.data!.id, equals(mockOrderId));
      expect(response.data!.carrier, equals('Pidge'));
      expect(response.data!.deliveryTracking?.fulfillmentStatus, equals('OUT_FOR_DELIVERY'));
      expect(response.data!.effectiveTrackingUrl, equals('https://tracking.pidge.in/?t=code-1'));
    });

    test('refreshOrderTracking handles 409 unbooked shipment conflict gracefully', () async {
      final auth = AuthService();
      final mockOrderId = 'b' * 64;

      auth.mockAuthenticatedRequestHandler = (_) async {
        return http.Response(
          jsonEncode({'error': 'No saved confirmed shipment'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      };

      final response = await auth.refreshOrderTracking(orderId: mockOrderId);

      expect(response.success, isFalse);
      expect(response.statusCode, equals(409));
      expect(response.message, contains('confirmed shipment'));
    });

    test('refreshOrderTracking handles 502 upstream Pidge failure', () async {
      final auth = AuthService();
      final mockOrderId = 'c' * 64;

      auth.mockAuthenticatedRequestHandler = (_) async {
        return http.Response(
          jsonEncode({'error': 'Upstream gateway timeout'}),
          502,
          headers: {'content-type': 'application/json'},
        );
      };

      final response = await auth.refreshOrderTracking(orderId: mockOrderId);

      expect(response.success, isFalse);
      expect(response.statusCode, equals(502));
      expect(response.message, contains('Pidge tracking service is temporarily unavailable'));
    });
  });

  group('AppState refreshOrderTracking Spacing & Persistence Tests', () {
    test('Enforces 30s rate limiting unless forced', () async {
      final appState = AppState();
      final mockOrderId = 'd' * 64;
      final testOrder = UserOrder.fromJson({
        'id': mockOrderId,
        'displayId': 'TEST-30S',
        'status': 'Processing',
        'items': [],
      });
      appState.setActiveOrder(testOrder);

      AuthService().mockAuthenticatedRequestHandler = (_) async {
        return http.Response(
          jsonEncode({
            'id': mockOrderId,
            'displayId': 'TEST-30S',
            'status': 'Processing',
            'deliveryTracking': {
              'provider': 'Pidge',
              'shipmentId': 'pid-30s',
              'fulfillmentStatus': 'CREATED',
            },
            'items': [],
          }),
          200,
        );
      };

      // First call succeeds
      final res1 = await appState.refreshOrderTracking(mockOrderId);
      expect(res1.success, isTrue);

      // Immediate second call is rate-limited by client recommendation
      final res2 = await appState.refreshOrderTracking(mockOrderId, force: false);
      expect(res2.success, isFalse);
      expect(res2.statusCode, equals(429));
      expect(res2.message, contains('wait'));

      // Forced call bypasses rate limit (e.g. user taps Refresh Status)
      final res3 = await appState.refreshOrderTracking(mockOrderId, force: true);
      expect(res3.success, isTrue);
    });

    test('Retains previously displayed snapshot on refresh failure', () async {
      final appState = AppState();
      final mockOrderId = 'e' * 64;
      final initialOrder = UserOrder.fromJson({
        'id': mockOrderId,
        'displayId': 'TEST-RETAIN',
        'status': 'Packed',
        'carrier': 'Pidge',
        'trackingNumber': 'pid-retain-1',
        'deliveryTracking': {
          'provider': 'Pidge',
          'shipmentId': 'pid-retain-1',
          'fulfillmentStatus': 'OUT_FOR_DELIVERY',
          'trackingCode': 'code-retain',
          'checkedAt': '2026-10-20T04:00:00Z',
        },
        'items': [],
      });
      appState.setActiveOrder(initialOrder);

      AuthService().mockAuthenticatedRequestHandler = (_) async {
        return http.Response(
          jsonEncode({'error': 'Pidge 503 unavailable'}),
          503,
        );
      };

      final failRes = await appState.refreshOrderTracking(mockOrderId, force: true);
      expect(failRes.success, isFalse);

      // Cached order in AppState still preserves the previous snapshot
      final current = appState.orders.firstWhere((o) => o.id == mockOrderId);
      expect(current.deliveryTracking, isNotNull);
      expect(current.deliveryTracking!.fulfillmentStatus, equals('OUT_FOR_DELIVERY'));
      expect(current.deliveryTracking!.shipmentId, equals('pid-retain-1'));
    });
  });

  group('OrderTrackingScreen UI & Track Shipment Widget Tests', () {
    testWidgets('Displays Pidge Shipment Tracking Card when order is delivered',
        (tester) async {
      final appState = AppState();
      final deliveredOrder = UserOrder.fromJson({
        'id': 'f' * 64,
        'displayId': 'TEST-DEL-1',
        'status': 'Delivered',
        'carrier': 'Pidge',
        'trackingNumber': 'PID-DEL-999',
        'trackingUrl': 'https://tracking.pidge.in/?t=pidge-del-code',
        'deliveryTracking': {
          'provider': 'Pidge',
          'shipmentId': 'PID-DEL-999',
          'orderStatus': 'completed',
          'fulfillmentStatus': 'DELIVERED',
          'trackingCode': 'pidge-del-code',
          'trackingUrl': 'https://tracking.pidge.in/?t=pidge-del-code',
          'checkedAt': '2026-10-20T08:00:00Z',
        },
        'items': [],
      });
      appState.setActiveOrder(deliveredOrder);

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: deliveredOrder),
          ),
        ),
      );
      await tester.pump();

      // Banner shows Delivered! Enjoy your jars
      expect(find.text('Delivered! Enjoy your jars'), findsOneWidget);

      // Pidge carrier displayed with verified badge
      expect(find.text('Pidge'), findsWidgets);
      expect(find.text('Verified'), findsWidgets);

      // Tracking Number box displays PID-DEL-999
      expect(find.text('Tracking Number'), findsOneWidget);
      expect(find.text('PID-DEL-999'), findsOneWidget);

      // Track action button is present in the action row
      expect(find.text('Track'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      // Verified timestamp snapshot displayed
      expect(find.textContaining('Verified with Pidge at'), findsOneWidget);

      // Rate delivery experience action is also present
      expect(find.text('Rate Your Delivery Experience'), findsOneWidget);
    });

    testWidgets('Tapping Track button informs user when trackingUrl is pending',
        (tester) async {
      final appState = AppState();
      final orderWithoutUrl = UserOrder.fromJson({
        'id': 'g' * 64,
        'displayId': 'TEST-NO-URL',
        'status': 'Packed',
        'carrier': 'Pidge',
        'trackingNumber': 'PID-NO-URL',
        'trackingUrl': '',
        'deliveryTracking': {
          'provider': 'Pidge',
          'shipmentId': 'PID-NO-URL',
          'orderStatus': 'fulfilled',
          'fulfillmentStatus': 'OUT_FOR_PICKUP',
          'trackingCode': null,
          'trackingUrl': null,
          'checkedAt': '2026-10-20T08:00:00Z',
        },
        'items': [],
      });
      appState.setActiveOrder(orderWithoutUrl);

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen(order: orderWithoutUrl),
          ),
        ),
      );
      await tester.pump();

      // Track and Share action buttons are present; standalone WhatsApp is removed
      expect(find.text('Track'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('WhatsApp'), findsNothing);

      // Tapping Track informs user tracking link will be active once dispatched
      await tester.ensureVisible(find.text('Track'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track'));
      await tester.pump();

      expect(
        find.text('Live tracking link will be active once dispatched by Pidge'),
        findsOneWidget,
      );

      // Carrier status and tracking number box are visible
      expect(find.text('PID-NO-URL'), findsOneWidget);
      expect(find.text('Out for Pickup'), findsWidgets);
    });

    test('DeliveryTracking parses webhook fields (source, receivedAt, attemptType) correctly', () {
      final json = {
        'provider': 'Pidge',
        'shipmentId': 'example-pidge-shipment',
        'orderStatus': 'fulfilled',
        'fulfillmentStatus': 'OUT_FOR_DELIVERY',
        'trackingCode': 'example-code',
        'trackingUrl': 'https://tracking.pidge.in/?t=example-code',
        'updatedAt': '2026-10-20T04:00:00.000Z',
        'checkedAt': '2026-10-20T04:01:02.000Z',
        'source': 'webhook',
        'receivedAt': '2026-10-20T04:01:00.000Z',
        'attemptType': 'FORWARD',
      };

      final dt = DeliveryTracking.fromJson(json);

      expect(dt.provider, 'Pidge');
      expect(dt.shipmentId, 'example-pidge-shipment');
      expect(dt.orderStatus, 'fulfilled');
      expect(dt.fulfillmentStatus, 'OUT_FOR_DELIVERY');
      expect(dt.isOutForDelivery, isTrue);
      expect(dt.isFromWebhook, isTrue);
      expect(dt.source, 'webhook');
      expect(dt.attemptType, 'FORWARD');
      expect(dt.receivedAt, isNotNull);
      expect(dt.checkedAt, isNotNull);
      expect(dt.updatedAt, isNotNull);

      // Verify toJson roundtrip
      final serialized = dt.toJson();
      expect(serialized['source'], 'webhook');
      expect(serialized['attemptType'], 'FORWARD');
      expect(serialized['receivedAt'], isNotNull);
    });

    test('DeliveryTracking handles missing/null webhook fields safely', () {
      final json = {
        'provider': 'Pidge',
        'shipmentId': 'pid-standard-1',
        'orderStatus': 'pending',
        'fulfillmentStatus': 'CREATED',
        'checkedAt': '2026-10-20T08:00:00Z',
      };

      final dt = DeliveryTracking.fromJson(json);

      expect(dt.provider, 'Pidge');
      expect(dt.isFromWebhook, isFalse);
      expect(dt.source, isNull);
      expect(dt.receivedAt, isNull);
      expect(dt.attemptType, isNull);
      expect(dt.formattedDisplayStatus, 'Shipment Created');
    });

    test('Webhook DELIVERED forward completion automatically marks order Delivered', () {
      final orderJson = {
        'id': 'a' * 64,
        'displayId': 'TEST-DELIVERED-WH',
        'status': 'Delivered',
        'deliveredAt': '2026-10-20T10:00:00Z',
        'carrier': 'Pidge',
        'trackingNumber': 'PID-DEL-WH',
        'deliveryTracking': {
          'provider': 'Pidge',
          'shipmentId': 'PID-DEL-WH',
          'orderStatus': 'completed',
          'fulfillmentStatus': 'DELIVERED',
          'source': 'webhook',
          'receivedAt': '2026-10-20T10:00:00Z',
          'checkedAt': '2026-10-20T10:00:02Z',
        },
        'items': [],
      };

      final order = UserOrder.fromJson(orderJson);

      expect(order.isDelivered, isTrue);
      expect(order.deliveredAt, isNotNull);
      expect(order.deliveryTracking?.isDelivered, isTrue);
      expect(order.deliveryTracking?.isFromWebhook, isTrue);
    });
  });
}

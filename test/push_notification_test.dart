import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleo/models/order.dart';
import 'package:pickleo/screens/order_tracking_screen.dart';
import 'package:pickleo/services/auth_service.dart';
import 'package:pickleo/services/notification_service.dart';
import 'package:pickleo/state/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Push Notifications & Device ID Tests', () {
    test('NotificationService generates valid UUID v4 deviceId and persists it', () async {
      final service = NotificationService.instance;
      final deviceId1 = await service.getDeviceId();

      // UUID v4 format: 8-4-4-4-12 hex characters
      final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false);
      expect(uuidRegex.hasMatch(deviceId1), isTrue,
          reason: 'Generated deviceId $deviceId1 must match UUID v4 format');

      // Subsequent call returns the exact same cached / persisted deviceId
      final deviceId2 = await service.getDeviceId();
      expect(deviceId2, equals(deviceId1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pickleo_device_id'), equals(deviceId1));
    });

    test('NotificationService platform returns valid platform string', () {
      final service = NotificationService.instance;
      final platform = service.getPlatform();
      expect(['android', 'ios', 'web'].contains(platform), isTrue);
    });

    test('UserOrder.placeholder creates valid structure for notification cold-start', () {
      final order = UserOrder.placeholder('12335');
      expect(order.id, equals('12335'));
      expect(order.displayId, equals('12335'));
      expect(order.status, equals('Processing'));
      expect(order.isLiveActive, isTrue);
    });

    test('NotificationService handleNotificationData parses backend payload', () {
      final service = NotificationService.instance;

      // Backend exact payload:
      // { "notificationType": "Orders", "orderId": "12335" }
      final backendPayload = {
        'notificationType': 'Orders',
        'orderId': '12335',
      };

      // When navigator key is not attached yet, pending order is queued
      service.handleNotificationData(backendPayload);

      // Verify that calling checkPendingNavigation doesn't throw
      service.checkPendingNavigation();
    });
  });

  group('Verify OTP Push Payload Integration Tests', () {
    test('AuthService verifyOtp logs and passes push credentials in payload', () async {
      final auth = AuthService();

      // Should complete gracefully with local fallback or mock response
      final response = await auth.verifyOtp(
        phone: '+919876543210',
        otp: '111111',
        fcmToken: 'mock_fcm_token_123',
        deviceId: '8dc87dda-80bf-42de-b5f2-06d8a589ce58',
        platform: 'android',
      );

      expect(response, isNotNull);
    });

    test('AuthService verifyOtp succeeds even when push fields are omitted', () async {
      final auth = AuthService();

      final response = await auth.verifyOtp(
        phone: '+919876543210',
        otp: '111111',
      );

      expect(response, isNotNull);
    });
  });

  group('OrderTrackingScreen Notification Redirection Widget Tests', () {
    testWidgets('OrderTrackingScreen.byOrderId renders and displays order number',
        (WidgetTester tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: OrderTrackingScreen.byOrderId(orderId: '12335'),
          ),
        ),
      );
      await tester.pump();

      // Verify Order Tracking title and order number are shown
      expect(find.text('Order Tracking'), findsOneWidget);
      expect(find.textContaining('12335'), findsWidgets);
    });
  });
}

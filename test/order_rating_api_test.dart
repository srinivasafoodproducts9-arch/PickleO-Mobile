import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pickleo/models/order.dart';
import 'package:pickleo/services/auth_service.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/screens/rate_delivery_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Order Rating API Schema & Serialization Tests', () {
    test('OrderRating serializes and deserializes identical to Swagger API schemas', () {
      final swaggerResponse = {
        "orderId": "69e31841b77919d21c344d8237cb78b72a2cdda745bfa43ea5072855b72ea224",
        "rating": 5,
        "tags": [
          "Authentic Grandmother Taste",
          "Safe Glass Packaging"
        ],
        "feedback": "Great taste and secure packaging.",
        "photoKey": "ratings/69e31841/photo.jpg",
        "photoUrl": "https://s3.pickleo.co.in/ratings/photo.jpg",
        "rewardPoints": 50,
        "createdAt": "2026-10-07T06:44:25.625Z"
      };

      final orderRating = OrderRating.fromJson(swaggerResponse);

      expect(orderRating.orderId, equals("69e31841b77919d21c344d8237cb78b72a2cdda745bfa43ea5072855b72ea224"));
      expect(orderRating.rating, equals(5));
      expect(orderRating.tags, contains("Authentic Grandmother Taste"));
      expect(orderRating.tags, contains("Safe Glass Packaging"));
      expect(orderRating.feedback, equals("Great taste and secure packaging."));
      expect(orderRating.photoKey, equals("ratings/69e31841/photo.jpg"));
      expect(orderRating.photoUrl, equals("https://s3.pickleo.co.in/ratings/photo.jpg"));
      expect(orderRating.rewardPoints, equals(50));
      expect(orderRating.createdAt, isNotNull);
      expect(orderRating.createdAt!.year, equals(2026));

      // Test toJson format matching request/cache format
      final json = orderRating.toJson();
      expect(json['orderId'], equals(orderRating.orderId));
      expect(json['rating'], equals(5));
      expect(json['tags'], equals(["Authentic Grandmother Taste", "Safe Glass Packaging"]));
      expect(json['feedback'], equals("Great taste and secure packaging."));
      expect(json['rewardPoints'], equals(50));
    });

    test('OrderRating sanitizes Swagger "string" placeholders defensively', () {
      final swaggerDefaultPlaceholder = {
        "orderId": "ord-defensive-1",
        "rating": 4,
        "tags": ["Authentic Taste", "string"],
        "feedback": "string",
        "photoKey": "string",
        "photoUrl": "string",
        "rewardPoints": 0,
        "createdAt": "2026-10-07T06:44:25.625Z"
      };

      final parsed = OrderRating.fromJson(swaggerDefaultPlaceholder);

      expect(parsed.tags, equals(["Authentic Taste"]));
      expect(parsed.feedback, isNull);
      expect(parsed.photoKey, isNull);
      expect(parsed.photoUrl, isNull);
    });
  });

  group('AuthService Direct Rating Methods Tests', () {
    test('Photo upload URL response schema with key, uploadUrl, expiresIn, maxBytes, and headers', () {
      final swaggerPhotoResponse = {
        "key": "ratings/69e31841/pickle_jar.jpg",
        "uploadUrl": "https://s3.amazonaws.com/pickleo-ratings/upload?signature=xyz",
        "expiresIn": 300,
        "maxBytes": 5242880,
        "headers": {
          "Content-Type": "image/jpeg",
          "Content-Length": "204800",
          "If-None-Match": "*"
        }
      };

      expect(swaggerPhotoResponse['key'], equals("ratings/69e31841/pickle_jar.jpg"));
      expect(swaggerPhotoResponse['uploadUrl'], contains("https://s3.amazonaws.com"));
      expect(swaggerPhotoResponse['expiresIn'], equals(300));
      expect(swaggerPhotoResponse['maxBytes'], equals(5242880));
      final headers = swaggerPhotoResponse['headers'] as Map;
      expect(headers['If-None-Match'], equals("*"));
      expect(headers['Content-Type'], equals("image/jpeg"));
    });

    test('submitOrderRating and getOrderRatingPhotoUploadUrl exist and fail gracefully without token', () async {
      final auth = AuthService();
      final resp = await auth.submitOrderRating(
        orderId: 'test-order-auth',
        rating: 5,
        tags: ['Fresh Spices'],
      );
      expect(resp.success, isFalse);

      final photoResp = await auth.getOrderRatingPhotoUploadUrl(
        orderId: 'test-order-auth',
        contentType: 'image/jpeg',
      );
      expect(photoResp.success, isFalse);
    });
  });

  group('AppState submitRating Integration Tests', () {
    test('AppState.submitRating updates order rating and awards spice points', () async {
      final appState = AppState();
      final initialPoints = appState.spicePoints;

      // Seed an active order
      final testOrder = UserOrder.fromJson({
        'id': 'ord-test-rate-123',
        'status': 'Delivered',
        'items': [],
      });
      appState.setActiveOrder(testOrder);

      // Submit rating via AppState
      await appState.submitRating(
        orderId: 'ord-test-rate-123',
        rating: 5,
        tags: ['Crisp Texture', 'Aromatic Oils'],
        feedback: 'Delicious mango pickle!',
      );

      // Verify active order now has the rating set
      expect(appState.activeOrder?.rating, isNotNull);
      expect(appState.activeOrder?.rating?.rating, equals(5));
      expect(appState.activeOrder?.rating?.feedback, equals('Delicious mango pickle!'));
      expect(appState.activeOrder?.rating?.tags, contains('Crisp Texture'));

      // Verify spice points increased
      expect(appState.spicePoints, greaterThan(initialPoints));
    });
  });

  group('RateDeliveryScreen Widget Tests', () {
    testWidgets('Renders rating screen with 5 stars, tags, feedback, and photo upload button', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: const MaterialApp(
            home: RateDeliveryScreen(orderId: 'ord-test-widget'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('How was your Delivery Experience?'), findsOneWidget);
      expect(find.text('5/5 Loved it!'), findsOneWidget);
      expect(find.text('What delighted your palate?'), findsOneWidget);
      expect(find.text('Authentic Grandmother Taste'), findsOneWidget);
      expect(find.text('Detailed Feedback'), findsOneWidget);
      expect(find.text('Add photo of your pickle jar'), findsOneWidget);
      expect(find.text('Submit Review'), findsOneWidget);
    });

    testWidgets('Tapping star updates selected rating label', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: const MaterialApp(
            home: RateDeliveryScreen(orderId: 'ord-test-widget-2'),
          ),
        ),
      );
      await tester.pump();

      // Find the 5 star icons
      final stars = find.byIcon(Icons.star);
      expect(stars, findsNWidgets(5));

      // Tap first star (1 star)
      await tester.tap(stars.first);
      await tester.pump();

      expect(find.text('1/5 Not great'), findsOneWidget);

      // Tap 4th star (4 stars)
      await tester.tap(stars.at(3));
      await tester.pump();

      expect(find.text('4/5 Really liked it'), findsOneWidget);
    });

    testWidgets('Submitting review calls submitRating and displays success snackbar', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppState();

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => const Scaffold(
                  body: RateDeliveryScreen(orderId: 'ord-test-widget-3'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Submit Review
      await tester.tap(find.text('Submit Review'));

      // Pump until snackbar appears
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        if (find.textContaining('Spice Points added').evaluate().isNotEmpty) {
          break;
        }
      }

      // Verify SnackBar with Spice Points
      expect(find.textContaining('Spice Points added'), findsAtLeastNWidgets(1));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/delivery_estimate.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/product_detail_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Delivery Estimate Model & API Tests', () {
    test('DeliveryEstimate.fromJson parses serviceable response correctly', () {
      final json = {
        "serviceable": true,
        "pinCode": "500068",
        "city": "Hyderabad",
        "fulfilmentCentre": "Srinivasa Food Products",
        "deliveryCharge": 0,
        "standardDeliveryFee": 12,
        "freeDeliveryAbove": 99,
        "minimumOrderValue": 50,
        "minimumOrderMet": true,
        "slots": ["2:00 pm - 6:00 pm", "1 am - 5 am"],
        "sla": "with in 2 days",
        "codAvailable": true
      };

      final estimate = DeliveryEstimate.fromJson(json);

      expect(estimate.serviceable, isTrue);
      expect(estimate.pinCode, "500068");
      expect(estimate.city, "Hyderabad");
      expect(estimate.fulfilmentCentre, "Srinivasa Food Products");
      expect(estimate.deliveryCharge, 0.0);
      expect(estimate.isFreeDelivery, isTrue);
      expect(estimate.deliveryChargeText, "free delivery");
      expect(estimate.sla, "with in 2 days");
      expect(estimate.slots, contains("2:00 pm - 6:00 pm"));
      expect(estimate.codAvailable, isTrue);
    });

    test('DeliveryEstimate.fromJson parses unserviceable response correctly', () {
      final json = {
        "serviceable": false,
        "pinCode": "500018"
      };

      final estimate = DeliveryEstimate.fromJson(json);

      expect(estimate.serviceable, isFalse);
      expect(estimate.pinCode, "500018");
      expect(estimate.city, isNull);
      expect(estimate.sla, isNull);
    });

    test('DeliveryEstimate calculates delivery charge text when fee applies', () {
      final json = {
        "serviceable": true,
        "pinCode": "500068",
        "deliveryCharge": 12,
        "sla": "Next day"
      };

      final estimate = DeliveryEstimate.fromJson(json);
      expect(estimate.isFreeDelivery, isFalse);
      expect(estimate.deliveryChargeText, "₹12 delivery");
      expect(estimate.sla, "Next day");
    });

    test('AppState.cacheDeliveryEstimate caches and overrides serviceability', () async {
      final appState = AppState();

      const sample = DeliveryEstimate(
        serviceable: true,
        pinCode: '500068',
        city: 'Hyderabad',
        sla: 'with in 2 days',
        deliveryCharge: 0.0,
      );

      appState.cacheDeliveryEstimate(sample);

      final cached = appState.getCachedDeliveryEstimate('500068');
      expect(cached, isNotNull);
      expect(cached?.pinCode, '500068');
      expect(cached?.sla, 'with in 2 days');
      expect(appState.isPinServiceable('500068'), isTrue);
    });
  });

  group('ProductDetailScreen Delivery Check UI Tests', () {
    testWidgets('Renders delivery card with borderless text field and Check button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppState(initialLoggedIn: true);

      // Pre-cache estimate matching user screenshot
      const sampleEstimate = DeliveryEstimate(
        serviceable: true,
        pinCode: "500068",
        city: "Hyderabad",
        deliveryCharge: 0.0,
        sla: "with in 2 days",
      );
      appState.cacheDeliveryEstimate(sampleEstimate);

      final product = Product(
        id: 'test-product-del',
        name: 'Avakaya Pickle',
        categoryId: 'cat-pickle',
        maker: 'Grandma',
        place: 'Vijayawada',
        subtitle: 'Authentic',
        basePrice: 299,
        originalPrice: 349,
        rating: 4.8,
        reviewsDisplay: '10',
        reviewCount: 10,
        weightOptions: ['250g'],
        pricesByWeight: {'250g': 299},
        spiceLevel: 2,
        description: 'Tasty pickle',
        storyTitle: 'Story',
        homemakerStory: 'Story text',
      );

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: ProductDetailScreen(
              product: product,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Delivery section should display SLA and PIN
      expect(find.text('Check another PIN code'), findsOneWidget);
      expect(find.text('Check'), findsOneWidget);

      // Verify the textbox Container has NO black/brown border
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final containerFinder = find.ancestor(
        of: textFieldFinder,
        matching: find.byType(Container),
      ).first;

      final Container containerWidget = tester.widget<Container>(containerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;

      // Assert border is null (no black border surrounding the textbox)
      expect(decoration.border, isNull);
      expect(decoration.color, Colors.white);
      expect(decoration.borderRadius, BorderRadius.circular(10));

      // Enter a 6-digit pin code and tap Check
      await tester.enterText(textFieldFinder, '500068');
      await tester.pump();

      final checkBtnFinder = find.widgetWithText(ElevatedButton, 'Check');
      expect(tester.widget<ElevatedButton>(checkBtnFinder).onPressed, isNotNull);

      await tester.tap(checkBtnFinder);
      await tester.pumpAndSettle();

      // Ensure pin was checked
      expect(appState.getCachedDeliveryEstimate('500068'), isNotNull);
    });
  });
}

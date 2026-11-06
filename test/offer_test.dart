import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/offer.dart';
import 'package:pickleo/models/cart_item.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/widgets/offer_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OfferItem Model Tests', () {
    test('parses product offer from real API response', () {
      final json = {
        "id": "e98d1dcd-4e17-4d5b-9ddd-f531ae6d4f51",
        "title": "PRAWN OFFER",
        "code": "PRAWN",
        "description": "",
        "offerType": "product",
        "productIds": ["fc698611-3804-4d7c-b02d-2f4c7435945c"],
        "discountType": "flat",
        "discountValue": 20,
        "discountPercent": null,
        "status": "Active",
        "minimumOrderValue": 0,
        "maxDiscountAmount": null,
        "totalRedemptionLimit": null,
        "perCustomerLimit": 1,
        "flashBanner": false,
        "startsAt": "2026-10-06",
        "endsAt": "2026-10-10",
        "imageKey":
            "offers/2026-10-06/47944592-d2c8-4b8e-8bd2-b35339a994d6.webp",
        "imageUrl":
            "https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/offers/sample.webp",
        "createdAt": "2026-10-06T06:46:35.382Z",
        "updatedAt": "2026-10-06T06:46:35.382Z"
      };

      final offer = OfferItem.fromJson(json);

      expect(offer.id, 'e98d1dcd-4e17-4d5b-9ddd-f531ae6d4f51');
      expect(offer.title, 'PRAWN OFFER');
      expect(offer.code, 'PRAWN');
      expect(offer.offerType, 'product');
      expect(offer.productIds, ['fc698611-3804-4d7c-b02d-2f4c7435945c']);
      expect(offer.discountType, 'flat');
      expect(offer.discountValue, 20.0);
      expect(offer.discountPercent, isNull);
      expect(offer.isActive, isTrue);
      expect(offer.isPercentage, isFalse);
      expect(offer.discountBadgeText, 'Flat ₹20 OFF');
      expect(offer.imageUrl, contains('sample.webp'));
      expect(offer.startsAt, '2026-10-06');
      expect(offer.endsAt, '2026-10-10');
      expect(offer.perCustomerLimit, 1);
    });

    test('parses percentage order offer and converts to CouponOffer correctly', () {
      final json = {
        "id": "daef9347-6ab2-4df8-8a6f-21e8b4eedbf2",
        "title": "Winter Offer",
        "code": "WINTER",
        "description": "Seasonal discount",
        "offerType": "order",
        "productIds": [],
        "discountType": "percentage",
        "discountValue": 10,
        "discountPercent": 10.0,
        "status": "Active",
        "minimumOrderValue": 100,
        "maxDiscountAmount": 50,
        "flashBanner": false,
        "imageKey": "offers/sample2.webp",
        "imageUrl": ""
      };

      final offer = OfferItem.fromJson(json);

      expect(offer.code, 'WINTER');
      expect(offer.isPercentage, isTrue);
      expect(offer.discountBadgeText, '10% OFF');
      // Verifies fallback URL from imageKey
      expect(offer.imageUrl, contains('offers/sample2.webp'));

      // Check conversion to CouponOffer
      final coupon = offer.toCouponOffer();
      expect(coupon.code, 'WINTER');
      expect(coupon.type, 'pct');
      expect(coupon.value, 10.0);
      expect(coupon.minOrder, 100.0);
      expect(coupon.cap, 50.0);

      // Verify discount calculations
      expect(coupon.isEligible(50.0), isFalse);
      expect(coupon.isEligible(200.0), isTrue);
      expect(coupon.calculateDiscount(200.0), 20.0); // 10% of 200 = 20
      expect(coupon.calculateDiscount(600.0), 50.0); // Capped at 50
    });
  });

  group('DynamicOffersSection Widget Tests', () {
    testWidgets('renders offer card with title, description, and copy code button',
        (tester) async {
      const testOffer = OfferItem(
        id: 'test_1',
        title: 'Winter Offer',
        code: 'WINTER',
        description: 'Special seasonal discount on authentic pickles',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicOffersSection(
              offers: const [testOffer],
              onApplyCode: (_) {},
            ),
          ),
        ),
      );

      // Verify Title is displayed
      expect(find.text('Winter Offer'), findsOneWidget);

      // Verify Description is displayed
      expect(find.text('Special seasonal discount on authentic pickles'),
          findsOneWidget);

      // Verify Code & COPY button are displayed
      expect(find.text('WINTER'), findsOneWidget);
      expect(find.text('COPY'), findsOneWidget);

      // Verify redundant elements are NOT present
      expect(find.text('Apply'), findsNothing);
      expect(find.textContaining('Valid till'), findsNothing);
    });

    testWidgets('does not render any offer card when offers list is empty',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicOffersSection(
              offers: const [],
              onApplyCode: (_) {},
            ),
          ),
        ),
      );

      // Verify no fallback card or offer elements are displayed
      expect(find.text('Flat 20% OFF on Traditional Combos'), findsNothing);
      expect(find.text('Stock up your grandma favorites with extra savings!'),
          findsNothing);
      expect(find.text('TRADITION20'), findsNothing);
      expect(find.text('COPY'), findsNothing);
      expect(find.text('EXCLUSIVE OFFERS'), findsNothing);
    });
  });

  group('AppState Coupons & Offers Exclusivity Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('coupons getter contains only API offers and no fake default coupons', () {
      final appState = AppState();

      // Initially without API offers, coupons list should be empty (no fake coupons)
      expect(appState.coupons, isEmpty);
      expect(appState.coupons.any((c) => c.code == 'PICKLEFIRST'), isFalse);
      expect(appState.coupons.any((c) => c.code == 'TRADITION20'), isFalse);
      expect(appState.coupons.any((c) => c.code == 'FREEPACK'), isFalse);

      // When an API offer is added
      const apiOffer = OfferItem(
        id: 'api-123',
        title: 'PRAWN OFFER',
        code: 'PRAWN',
        discountType: 'flat',
        discountValue: 20,
        minimumOrderValue: 0,
      );
      appState.addOrUpdateCoupon(apiOffer.toCouponOffer());

      // Only the API offer is present
      expect(appState.coupons.length, 1);
      expect(appState.coupons.first.code, 'PRAWN');
      expect(appState.coupons.first.desc, 'PRAWN OFFER');
      expect(appState.coupons.first.value, 20.0);
    });

    test('applyCoupon rejects empty code', () async {
      final appState = AppState();
      final res = await appState.applyCoupon('');
      expect(res.success, isFalse);
      expect(appState.appliedCoupon, isNull);
      expect(appState.couponDiscount, 0.0);
    });

    test('applyCoupon rejects code when subtotal is below minimum order requirement', () async {
      final appState = AppState();
      const minOrderOffer = OfferItem(
        id: 'api-min',
        title: 'BIG SAVINGS',
        code: 'BIG50',
        discountType: 'flat',
        discountValue: 50,
        minimumOrderValue: 500,
      );
      appState.addOrUpdateCoupon(minOrderOffer.toCouponOffer());

      // Cart is currently empty (subtotal = 0 < 500)
      final res = await appState.applyCoupon('BIG50');
      expect(res.success, isFalse);
      expect(res.message, contains('Add ₹500 more to use BIG50'));
      expect(appState.appliedCoupon, isNull);
      expect(appState.couponDiscount, 0.0);
    });

    test('removeCoupon clears coupon discount and appliedCoupon', () {
      final appState = AppState();
      appState.removeCoupon();
      expect(appState.appliedCoupon, isNull);
      expect(appState.couponDiscount, 0.0);
    });

    test('CartPriceBreakdown parses null totalPayable and ConsumerCartResponse parses pricingIssues', () {
      final json = {
        'items': [],
        'itemCount': 0,
        'subtotal': 100.0,
        'priceBreakdown': {
          'currency': 'INR',
          'itemsMrpTotal': 120.0,
          'totalPayable': null,
        },
        'pricingIssues': [
          {
            'code': 'UNSERVICEABLE_PIN',
            'message': 'Selected PIN code is outside our delivery zone.',
          }
        ],
      };

      final cartResponse = ConsumerCartResponse.fromJson(json);
      expect(cartResponse.priceBreakdown?.totalPayable, isNull);
      expect(cartResponse.pricingIssues.length, 1);
      expect(cartResponse.pricingIssues.first.message, 'Selected PIN code is outside our delivery zone.');
    });

    test('CartPriceBreakdown parses positive totalPayable correctly', () {
      final json = {
        'totalPayable': 350.0,
        'currency': 'INR',
      };
      final breakdown = CartPriceBreakdown.fromJson(json);
      expect(breakdown.totalPayable, 350.0);
    });
  });
}



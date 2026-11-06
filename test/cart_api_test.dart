import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/cart_item.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/services/auth_service.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Cart API (PUT /consumer/cart/{productId}) Schema & Integration Tests', () {
    test('Parses CartItemResponse correctly from 200 response schema', () {
      final jsonResponse = {
        "productId": "prawn-pickle-123",
        "quantity": 2,
        "availableQuantity": 15
      };

      final response = CartItemResponse.fromJson(jsonResponse);

      expect(response.productId, 'prawn-pickle-123');
      expect(response.quantity, 2);
      expect(response.availableQuantity, 15);
      expect(response.toJson(), {
        'productId': 'prawn-pickle-123',
        'quantity': 2,
        'availableQuantity': 15,
      });
    });

    test('Parses CartItemResponse correctly when quantity is 0 (item removed)', () {
      final jsonResponse = {
        "productId": "avakaya",
        "quantity": 0,
        "availableQuantity": 50
      };

      final response = CartItemResponse.fromJson(jsonResponse);

      expect(response.productId, 'avakaya');
      expect(response.quantity, 0);
      expect(response.availableQuantity, 50);
    });

    test('AppState tracks cart quantities and computes getProductQty correctly', () {
      final appState = AppState();
      final avakaya = ProductData.findById('avakaya');

      expect(appState.getProductQty(avakaya.id), 0);

      // Add 250g jar
      appState.addToCart(avakaya, '250g', qty: 2);
      expect(appState.getProductQty(avakaya.id), 2);

      // Add 500g jar of the same product
      appState.addToCart(avakaya, '500g', qty: 1);
      expect(appState.getProductQty(avakaya.id), 3);

      // Update quantity of 250g jar
      final itemKey = '${avakaya.id}_250g';
      appState.updateQuantity(itemKey, -1);
      expect(appState.getProductQty(avakaya.id), 2);

      // Set product quantity directly for a catalog product
      final gongura = ProductData.findById('gongura');
      appState.setProductQty(gongura, 4);
      expect(appState.getProductQty(gongura.id), 4);

      // Remove product by setting qty to 0
      appState.setProductQty(gongura, 0);
      expect(appState.getProductQty(gongura.id), 0);
    });

    test('Parses CartItemDeleteResponse correctly from DELETE 200 response schema', () {
      final jsonResponse = {
        "deleted": true
      };

      final response = CartItemDeleteResponse.fromJson(jsonResponse);

      expect(response.deleted, isTrue);
      expect(response.toJson(), {'deleted': true});
    });

    test('AppState removeItem and clearCart update quantity to 0', () {
      final appState = AppState();
      final avakaya = ProductData.findById('avakaya');
      final gongura = ProductData.findById('gongura');

      appState.addToCart(avakaya, '250g', qty: 1);
      appState.addToCart(gongura, '300g', qty: 2);

      expect(appState.getProductQty(avakaya.id), 1);
      expect(appState.getProductQty(gongura.id), 2);

      appState.removeItem('${avakaya.id}_250g');
      expect(appState.getProductQty(avakaya.id), 0);

      appState.clearCart();
      expect(appState.getProductQty(gongura.id), 0);
      expect(appState.hasCart, isFalse);
    });

    test('Parses GET /consumer/cart Swagger response schema correctly', () {
      final jsonResponse = {
        "items": [
          {
            "productId": "string",
            "quantity": 0,
            "product": {
              "id": "string",
              "name": "string",
              "region": "string",
              "tags": ["string"],
              "category": "string",
              "mrp": 0,
              "price": 0,
              "stock": 0,
              "stockUnit": "string",
              "lowStockThreshold": 0,
              "unitsSold": 0,
              "imageKey": "string",
              "imageUrl": "string",
              "mediaItems": [
                {
                  "key": "string",
                  "mediaType": "image",
                  "contentType": "image/jpeg",
                  "url": "string"
                }
              ],
              "createdAt": "2026-10-04T02:18:41.771Z",
              "updatedAt": "2026-10-04T02:18:41.773Z"
            },
            "availableQuantity": 0,
            "inStock": true,
            "lineTotal": 0
          }
        ],
        "itemCount": 0,
        "subtotal": 0
      };

      final cartResponse = ConsumerCartResponse.fromJson(jsonResponse);

      expect(cartResponse.itemCount, 0);
      expect(cartResponse.subtotal, 0.0);
      expect(cartResponse.items.length, 1);

      final item = cartResponse.items.first;
      expect(item.productId, 'string');
      expect(item.quantity, 0);
      expect(item.inStock, isTrue);
      expect(item.availableQuantity, 0);
      expect(item.lineTotal, 0.0);
      expect(item.product.id, 'string');
      expect(item.product.name, 'string');
    });

    test('Parses populated ConsumerCartResponse with product items and totals', () {
      final jsonResponse = {
        "items": [
          {
            "productId": "prod-mango-99",
            "quantity": 2,
            "product": {
              "id": "prod-mango-99",
              "name": "Spicy Mango Pickle",
              "region": "Andhra",
              "tags": ["Spicy", "Authentic"],
              "category": "Pickles",
              "mrp": 299,
              "price": 249,
              "stock": 45,
              "stockUnit": "Jar",
              "lowStockThreshold": 5,
              "unitsSold": 120,
              "imageKey": "mango.jpg",
              "imageUrl": "https://example.com/mango.jpg",
              "mediaItems": [
                {
                  "key": "mango-1",
                  "mediaType": "image",
                  "contentType": "image/jpeg",
                  "url": "https://example.com/mango-1.jpg"
                }
              ],
              "createdAt": "2026-10-04T02:18:41.771Z",
              "updatedAt": "2026-10-04T02:18:41.773Z"
            },
            "availableQuantity": 10,
            "inStock": true,
            "lineTotal": 498.0
          }
        ],
        "itemCount": 2,
        "subtotal": 498.0
      };

      final cartResponse = ConsumerCartResponse.fromJson(jsonResponse);

      expect(cartResponse.itemCount, 2);
      expect(cartResponse.subtotal, 498.0);
      expect(cartResponse.items.length, 1);

      final item = cartResponse.items.first;
      expect(item.productId, 'prod-mango-99');
      expect(item.quantity, 2);
      expect(item.availableQuantity, 10);
      expect(item.inStock, isTrue);
      expect(item.lineTotal, 498.0);
      expect(item.product.name, 'Spicy Mango Pickle');
      expect(item.product.region, 'Andhra');
      expect(item.product.basePrice, 249.0);
      expect(item.product.tags, contains('Spicy'));
    });

    test('Parses ClearCartResponse correctly from DELETE /consumer/cart 200 response schema', () {
      final jsonResponse = {
        "deleted": true,
        "removedCount": 0
      };

      final response = ClearCartResponse.fromJson(jsonResponse);

      expect(response.deleted, isTrue);
      expect(response.removedCount, 0);
      expect(response.toJson(), {
        'deleted': true,
        'removedCount': 0,
      });
    });

    test('Parses ClearCartResponse correctly when items were removed', () {
      final jsonResponse = {
        "deleted": true,
        "removedCount": 5
      };

      final response = ClearCartResponse.fromJson(jsonResponse);

      expect(response.deleted, isTrue);
      expect(response.removedCount, 5);
      expect(response.toJson(), {
        'deleted': true,
        'removedCount': 5,
      });
    });

    test('Parses CartDeliveryInfo and delivery slots from Cart API response schema', () {
      final jsonResponse = {
        "items": [],
        "itemCount": 0,
        "subtotal": 0,
        "delivery": {
          "serviceable": true,
          "pinCode": "560001",
          "slots": ["9 AM - 12 PM", "2 PM - 5 PM"],
          "codAvailable": true,
          "sla": "Delivered within 2 hours",
          "deliveryCharge": 0,
          "minimumOrderMet": true
        }
      };

      final cartResponse = ConsumerCartResponse.fromJson(jsonResponse);

      expect(cartResponse.deliveryInfo, isNotNull);
      final delivery = cartResponse.deliveryInfo!;
      expect(delivery.serviceable, isTrue);
      expect(delivery.pinCode, '560001');
      expect(delivery.slots, ['9 AM - 12 PM', '2 PM - 5 PM']);
      expect(delivery.codAvailable, isTrue);
      expect(delivery.sla, 'Delivered within 2 hours');
      expect(delivery.deliveryCharge, 0);
      expect(delivery.minimumOrderMet, isTrue);
    });

    test('AppState delivery slot selection and reset lifecycle', () {
      final appState = AppState();

      expect(appState.hasDeliverySlots, isFalse);
      expect(appState.isDeliverySlotSelected, isFalse);
      expect(appState.selectedDeliverySlot, isNull);

      // Select a slot
      appState.selectDeliverySlot('2 PM - 5 PM');
      expect(appState.isDeliverySlotSelected, isTrue);
      expect(appState.selectedDeliverySlot, '2 PM - 5 PM');

      // Clear cart resets slot selection
      appState.clearCart();
      expect(appState.isDeliverySlotSelected, isFalse);
      expect(appState.selectedDeliverySlot, isNull);
    });

    test('HTTP 409 Conflict: Does NOT add to local cart or cache when backend rejects item', () async {
      final auth = AuthService();
      await auth.saveTokens(
        token: 'test-token-409',
        refreshToken: 'refresh-token-409',
        expiresIn: 3600,
      );

      // Simulate backend returning 409 Conflict with out of stock error
      auth.mockAuthenticatedRequestHandler = (token) async {
        return http.Response(
          jsonEncode({'error': 'Only 0 units are currently available.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      };

      try {
        final appState = AppState();
        final avakaya = ProductData.findById('avakaya');

        expect(appState.getProductQty(avakaya.id), 0);

        final res = await appState.addToCart(avakaya, '250g', qty: 1);

        // 1. Returns error response with exact message
        expect(res, isNotNull);
        expect(res!.success, isFalse);
        expect(res.statusCode, 409);
        expect(res.message, 'Only 0 units are currently available.');

        // 2. Local cart does NOT have the item
        expect(appState.getProductQty(avakaya.id), 0);
        expect(appState.cartItems, isEmpty);

        // 3. SharedPreferences cache does NOT have the item
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_cart_items');
        if (cached != null) {
          final list = jsonDecode(cached) as List;
          expect(list, isEmpty);
        }
      } finally {
        auth.mockAuthenticatedRequestHandler = null;
        await auth.logout();
      }
    });

    test('HTTP 409 Conflict: updateQuantity does NOT increment when backend rejects delta', () async {
      final auth = AuthService();
      await auth.saveTokens(
        token: 'test-token-409-update',
        refreshToken: 'refresh-token-409-update',
        expiresIn: 3600,
      );

      // Initially allow adding 1 unit
      auth.mockAuthenticatedRequestHandler = (token) async {
        return http.Response(
          jsonEncode({
            'productId': 'avakaya',
            'quantity': 1,
            'availableQuantity': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      };

      final appState = AppState();
      final avakaya = ProductData.findById('avakaya');
      await appState.addToCart(avakaya, '250g', qty: 1);
      expect(appState.getProductQty(avakaya.id), 1);

      // Now simulate backend rejecting increment due to stock limit reached (409)
      auth.mockAuthenticatedRequestHandler = (token) async {
        return http.Response(
          jsonEncode({'error': 'Only 1 units are currently available.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      };

      try {
        final res = await appState.updateQuantity('${avakaya.id}_250g', 1);

        expect(res, isNotNull);
        expect(res!.success, isFalse);
        expect(res.statusCode, 409);
        expect(res.message, 'Only 1 units are currently available.');

        // Quantity remains at 1, NOT incremented to 2!
        expect(appState.getProductQty(avakaya.id), 1);
      } finally {
        auth.mockAuthenticatedRequestHandler = null;
        await auth.logout();
      }
    });
  });
}


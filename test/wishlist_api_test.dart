import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/wishlist_item.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Wishlist API (GET /consumer/wishlist) Schema & Integration Tests', () {
    test('Parses GET /consumer/wishlist Swagger response schema correctly', () {
      final jsonResponse = {
        "items": [
          {
            "productId": "string",
            "addedAt": "2026-10-04T02:24:41.338Z",
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
              "createdAt": "2026-10-04T02:24:41.338Z",
              "updatedAt": "2026-10-04T02:24:41.338Z"
            }
          }
        ]
      };

      final response = ConsumerWishlistResponse.fromJson(jsonResponse);

      expect(response.items.length, 1);
      final item = response.items.first;
      expect(item.productId, 'string');
      expect(item.addedAt, isNotNull);
      expect(item.addedAt?.year, 2026);
      expect(item.product.id, 'string');
      expect(item.product.name, 'string');
      expect(item.product.tags, contains('string'));
    });

    test('Parses populated wishlist items with real products correctly', () {
      final jsonResponse = {
        "items": [
          {
            "productId": "prod-avakaya-01",
            "addedAt": "2026-10-04T02:30:00.000Z",
            "product": {
              "id": "prod-avakaya-01",
              "name": "Authentic Andhra Avakaya",
              "region": "Andhra Pradesh",
              "tags": ["Spicy", "Bestseller"],
              "category": "Pickles",
              "mrp": 299,
              "price": 249,
              "stock": 35,
              "stockUnit": "Jar",
              "imageUrl": "https://example.com/avakaya.jpg",
              "mediaItems": [],
              "createdAt": "2026-10-04T00:00:00.000Z",
              "updatedAt": "2026-10-04T00:00:00.000Z"
            }
          },
          {
            "productId": "prod-gongura-02",
            "addedAt": "2026-10-04T02:31:00.000Z",
            "product": {
              "id": "prod-gongura-02",
              "name": "Tangy Gongura Pickle",
              "region": "Guntur",
              "tags": ["Tangy"],
              "category": "Pickles",
              "mrp": 250,
              "price": 199,
              "stock": 20,
              "stockUnit": "Jar",
              "imageUrl": "https://example.com/gongura.jpg",
              "mediaItems": [],
              "createdAt": "2026-10-04T00:00:00.000Z",
              "updatedAt": "2026-10-04T00:00:00.000Z"
            }
          }
        ]
      };

      final response = ConsumerWishlistResponse.fromJson(jsonResponse);

      expect(response.items.length, 2);
      expect(response.items[0].productId, 'prod-avakaya-01');
      expect(response.items[0].product.name, 'Authentic Andhra Avakaya');
      expect(response.items[1].productId, 'prod-gongura-02');
      expect(response.items[1].product.name, 'Tangy Gongura Pickle');
    });

    test('Handles empty wishlist response gracefully', () {
      final jsonResponse = {
        "items": []
      };

      final response = ConsumerWishlistResponse.fromJson(jsonResponse);
      expect(response.items, isEmpty);
    });

    test('AppState tracks wishlist correctly and supports toggleWishlist', () {
      final appState = AppState(initialLoggedIn: true);

      expect(appState.isWishlisted('avakaya'), isFalse);
      appState.toggleWishlist('avakaya');
      expect(appState.isWishlisted('avakaya'), isTrue);
      appState.toggleWishlist('avakaya');
      expect(appState.isWishlisted('avakaya'), isFalse);

      expect(appState.isWishlisted('unknown-product'), isFalse);
      appState.toggleWishlist('unknown-product');
      expect(appState.isWishlisted('unknown-product'), isTrue);
      appState.toggleWishlist('unknown-product');
      expect(appState.isWishlisted('unknown-product'), isFalse);
    });

    test('Parses AddToWishlistResponse correctly from PUT /consumer/wishlist/{productId} 200 response schema', () {
      final jsonResponse = {
        "productId": "string",
        "added": true
      };

      final response = AddToWishlistResponse.fromJson(jsonResponse);

      expect(response.productId, 'string');
      expect(response.added, isTrue);
      expect(response.toJson(), {
        'productId': 'string',
        'added': true,
      });
    });

    test('Parses AddToWishlistResponse for specific product ID correctly', () {
      final jsonResponse = {
        "productId": "prod-avakaya-01",
        "added": true
      };

      final response = AddToWishlistResponse.fromJson(jsonResponse);

      expect(response.productId, 'prod-avakaya-01');
      expect(response.added, isTrue);
      expect(response.toJson(), {
        'productId': 'prod-avakaya-01',
        'added': true,
      });
    });

    test('Parses RemoveFromWishlistResponse correctly from DELETE /consumer/wishlist/{productId} 200 response schema', () {
      final jsonResponse = {
        "deleted": true
      };

      final response = RemoveFromWishlistResponse.fromJson(jsonResponse);

      expect(response.deleted, isTrue);
      expect(response.toJson(), {
        'deleted': true,
      });
    });

    test('Parses RemoveFromWishlistResponse when deleted is false', () {
      final jsonResponse = {
        "deleted": false
      };

      final response = RemoveFromWishlistResponse.fromJson(jsonResponse);

      expect(response.deleted, isFalse);
      expect(response.toJson(), {
        'deleted': false,
      });
    });
  });
}

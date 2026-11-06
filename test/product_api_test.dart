import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/widgets/product_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Product Model & /consumer/products API Schema Tests', () {
    test('Parses Product correctly from GET /consumer/products item schema', () {
      final json = {
        "id": "fc698611-3804-4d7c-b02d-2f4c7435945c",
        "name": "Prawn Pickle",
        "category": "Pickle & Achaar",
        "region": "Bhimavaram",
        "tags": ["Very Spice"],
        "mrp": 580,
        "price": 550,
        "stock": 100,
        "stockUnit": "Jar",
        "lowStockThreshold": 10,
        "unitsSold": 45,
        "imageKey": "",
        "imageUrl": "https://example.com/prawn.png",
        "mediaItems": [
          {
            "key": "products/prawn.png",
            "mediaType": "image",
            "contentType": "image/png",
            "url": "https://example.com/prawn.png"
          }
        ],
        "createdAt": "2026-10-04T01:36:17.970Z",
        "updatedAt": "2026-10-04T01:36:17.970Z"
      };

      final product = Product.fromJson(json);

      expect(product.id, 'fc698611-3804-4d7c-b02d-2f4c7435945c');
      expect(product.name, 'Prawn Pickle');
      expect(product.categoryName, 'Pickle & Achaar');
      expect(product.region, 'Bhimavaram');
      expect(product.tags, contains('Very Spice'));
      expect(product.mrp, 580.0);
      expect(product.price, 550.0);
      expect(product.basePrice, 550.0);
      expect(product.originalPrice, 580.0);
      expect(product.stock, 100);
      expect(product.stockUnit, 'Jar');
      expect(product.lowStockThreshold, 10);
      expect(product.unitsSold, 45);
      expect(product.spiceLevel, 3); // Very Spice -> 3
      expect(product.hasValidImage, isTrue);
      expect(product.resolvedImageUrl, 'https://example.com/prawn.png');
    });

    test('Resolves image from mediaItems or imageKey fallback when imageUrl is empty', () {
      final jsonWithMedia = {
        "id": "1",
        "name": "Mango Pickle",
        "price": 200,
        "mediaItems": [
          {
            "url": "https://pickleo.s3.amazonaws.com/mango.png",
          }
        ]
      };
      final prod1 = Product.fromJson(jsonWithMedia);
      expect(prod1.hasValidImage, isTrue);
      expect(prod1.resolvedImageUrl, 'https://pickleo.s3.amazonaws.com/mango.png');

      final jsonWithKey = {
        "id": "2",
        "name": "Lemon Pickle",
        "imageKey": "products/lemon.png",
      };
      final prod2 = Product.fromJson(jsonWithKey);
      expect(prod2.hasValidImage, isTrue);
      expect(prod2.resolvedImageUrl, contains('products/lemon.png'));

      final jsonNoImage = {
        "id": "3",
        "name": "Plain Pickle",
      };
      final prod3 = Product.fromJson(jsonNoImage);
      expect(prod3.hasValidImage, isFalse);
      expect(prod3.resolvedImageUrl, isNull);
    });

    test('Parses ProductListResponse correctly from GET /consumer/products envelope', () {
      final rawEnvelope = {
        "items": [
          {
            "id": "p1",
            "name": "Nuvvula Karam Podi",
            "category": "Podis & Powders",
            "region": "Andhra Style",
            "tags": ["Spicy"],
            "mrp": 150,
            "price": 135,
            "stock": 30,
            "stockUnit": "Packet"
          },
          {
            "id": "p2",
            "name": "Mango Pickle",
            "category": "Pickle & Achaar",
            "region": "Andhra Style",
            "tags": ["Spicy"],
            "mrp": 250,
            "price": 230,
            "stock": 100,
            "stockUnit": "Jar"
          }
        ],
        "nextToken": "token_abc_123",
        "hasMore": true
      };

      final response = ProductListResponse.fromJson(rawEnvelope);
      expect(response.items.length, 2);
      expect(response.items[0].name, 'Nuvvula Karam Podi');
      expect(response.items[1].name, 'Mango Pickle');
      expect(response.nextToken, 'token_abc_123');
      expect(response.hasMore, isTrue);
    });

    test('AppState bestsellers initializes empty and has no static fallback on error', () {
      final appState = AppState();
      expect(appState.bestsellerProducts, isEmpty);
      expect(appState.isLoadingBestsellers, isFalse);
    });

    testWidgets('Shows "No image available" when product has no image',
        (tester) async {
      final productWithoutImage = Product.fromJson({
        'id': 'no-img-1',
        'name': 'Special Garlic Pickle',
        'price': 220,
      });

      expect(productWithoutImage.hasValidImage, isFalse);
      expect(productWithoutImage.imageAsset, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 150,
              child: ProductImage(product: productWithoutImage),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(NoProductImagePlaceholder), findsOneWidget);
      expect(find.text('No image available'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('NoProductImagePlaceholder standalone renders "No image available"',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: NoProductImagePlaceholder(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No image available'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    test('Parses all new fields from /consumer/products schema', () {
      final json = {
        "id": "prod-101",
        "name": "Avakaya Pickle",
        "category": "Pickles",
        "region": "Guntur",
        "kitchen": "Sri Lakshmi Kitchens",
        "spiceLevel": "3",
        "purityClaims": ["100% Homemade", "Zero Preservatives"],
        "sku": "AVK-350",
        "variantSize": "350g",
        "label": "Traditional",
        "serves": 4,
        "packaging": "Ceramic Martaban",
        "safetyStock": 10,
        "bestValue": true,
        "batchAgeDays": 2,
        "shelfLifeDays": 180,
        "subcategory": "Raw Mango",
        "badge": "Bestseller",
        "dietMark": "Vegetarian",
        "zeroPreservatives": true,
        "shortDescription": "Traditional spicy pickle",
        "storyTitle": "Heirloom Recipe",
        "description": "Slow matured in porcelain jars",
        "featuredReviewName": "Ramesh",
        "reviewCount": 85,
        "hsnCode": "200190",
        "gstRate": 5.0,
        "minOrderQty": 1,
        "maxOrderQty": 10,
        "deliveryPromise": "Delivered in 2 days",
        "freeDelivery": true,
        "highlightTags": ["Sun Matured"],
        "searchKeywords": ["avakaya", "mango"],
        "seoTitle": "Authentic Avakaya Pickle",
        "relatedProductIds": ["rel-1"],
        "frequentlyBoughtTogether": ["fbt-1", "fbt-2"],
        "catalogProductId": "cat-prod-1",
        "mrp": 350,
        "price": 299,
        "stock": 50,
        "stockUnit": "Jar",
        "imageKey": "key1",
        "imageUrl": "https://example.com/img1.jpg",
        "mediaItems": [
          {
            "key": "m1",
            "mediaType": "image",
            "contentType": "image/jpeg",
            "url": "https://example.com/img2.jpg"
          }
        ],
        "status": "Active",
        "createdAt": "2026-10-06T06:18:19.697Z",
        "updatedAt": "2026-10-06T06:18:19.697Z"
      };

      final p = Product.fromJson(json);

      expect(p.kitchen, 'Sri Lakshmi Kitchens');
      expect(p.purityClaims, contains('100% Homemade'));
      expect(p.sku, 'AVK-350');
      expect(p.variantSize, '350g');
      expect(p.defaultWeight, '350g');
      expect(p.serves, 4);
      expect(p.packaging, 'Ceramic Martaban');
      expect(p.safetyStock, 10);
      expect(p.bestValue, isTrue);
      expect(p.batchAgeDays, 2);
      expect(p.shelfLifeDays, 180);
      expect(p.badge, 'Bestseller');
      expect(p.isBestseller, isTrue);
      expect(p.dietMark, 'Vegetarian');
      expect(p.isVeg, isTrue);
      expect(p.zeroPreservatives, isTrue);
      expect(p.shortDescription, 'Traditional spicy pickle');
      expect(p.reviewCount, 85);
      expect(p.hsnCode, '200190');
      expect(p.gstRate, 5.0);
      expect(p.deliveryPromise, 'Delivered in 2 days');
      expect(p.freeDelivery, isTrue);
      expect(p.highlightTags, contains('Sun Matured'));
      expect(p.frequentlyBoughtTogether, containsAll(['fbt-1', 'fbt-2']));
      expect(p.allImageUrls, containsAll(['https://example.com/img1.jpg', 'https://example.com/img2.jpg']));
      expect(p.status, 'Active');
    });

    test('ProductListResponse strictly shows only status Active products', () {
      final envelope = {
        "items": [
          {
            "id": "p-active-1",
            "name": "Avakaya Pickle",
            "price": 249,
            "status": "Active"
          },
          {
            "id": "p-draft",
            "name": "Draft Pickle Experiment",
            "price": 200,
            "status": "Draft"
          },
          {
            "id": "p-inactive",
            "name": "Discontinued Chutney",
            "price": 180,
            "status": "Inactive"
          },
          {
            "id": "p-active-2",
            "name": "Gongura Pickle",
            "price": 229
            // defaults to Active
          }
        ],
        "nextToken": "next-tok-123",
        "hasMore": true
      };

      final response = ProductListResponse.fromJson(envelope);
      expect(response.items.length, 2);
      expect(response.items.map((p) => p.id), containsAll(['p-active-1', 'p-active-2']));
      expect(response.items.map((p) => p.id), isNot(contains('p-draft')));
      expect(response.items.map((p) => p.id), isNot(contains('p-inactive')));
    });

    test('AppState resolvedDietMark formats according to Swagger spec', () {
      final appState = AppState();
      expect(appState.resolvedDietMark, isNull);

      appState.toggleDietVeg();
      expect(appState.resolvedDietMark, 'Vegetarian');

      appState.toggleDietNonVeg();
      expect(appState.resolvedDietMark, 'Vegetarian,Non-vegetarian');

      appState.toggleDietVeg();
      expect(appState.resolvedDietMark, 'Non-vegetarian');

      appState.toggleDietNonVeg();
      expect(appState.resolvedDietMark, isNull);
    });

    test('ProductDetailsResponse parses POST /consumer/products/details payload correctly', () {
      final json = {
        "items": [
          {
            "id": "fbt-1",
            "name": "Avakaya Pickle",
            "price": 249,
            "status": "Active",
            "variants": [
              {
                "id": "var-1",
                "variantSize": "250g",
                "label": "Small Jar",
                "price": 249,
                "mrp": 299,
                "status": "Active"
              },
              {
                "id": "var-2",
                "variantSize": "500g",
                "label": "Medium Jar",
                "price": 449,
                "mrp": 549,
                "status": "Active"
              }
            ],
            "relatedProductIds": ["rel-1", "rel-2"],
            "frequentlyBoughtTogether": ["fbt-2"]
          },
          {
            "id": "fbt-2",
            "name": "Garlic Pickle",
            "price": 199,
            "status": "Active"
          },
          {
            "id": "fbt-draft",
            "name": "Draft Chutney",
            "price": 100,
            "status": "Draft"
          }
        ],
        "missingIds": ["catalog-not-found-1"]
      };

      final details = ProductDetailsResponse.fromJson(json);
      expect(details.items.length, 2);
      expect(details.missingIds, contains('catalog-not-found-1'));

      final p1 = details.items.firstWhere((p) => p.id == 'fbt-1');
      expect(p1.name, 'Avakaya Pickle');
      expect(p1.variants.length, 2);
      expect(p1.hasMultipleVariants, isTrue);
      expect(p1.frequentlyBoughtTogether, contains('fbt-2'));
      expect(p1.relatedProductIds, containsAll(['rel-1', 'rel-2']));

      final p2 = details.items.firstWhere((p) => p.id == 'fbt-2');
      expect(p2.name, 'Garlic Pickle');
      expect(p2.hasMultipleVariants, isFalse);
    });

    test('ProductDetailsResponse handles alternative envelope keys and empty payloads', () {
      final emptyResponse = ProductDetailsResponse.fromJson({});
      expect(emptyResponse.items, isEmpty);
      expect(emptyResponse.missingIds, isEmpty);

      final altEnvelope = {
        "products": [
          {
            "id": "alt-1",
            "name": "Tomato Thokku",
            "price": 180,
            "status": "Active"
          }
        ],
        "missingIds": ["missing-1"]
      };
      final altResponse = ProductDetailsResponse.fromJson(altEnvelope);
      expect(altResponse.items.length, 1);
      expect(altResponse.items.first.name, 'Tomato Thokku');
      expect(altResponse.missingIds, ['missing-1']);
    });
  });
}

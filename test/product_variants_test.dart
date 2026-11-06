import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/cart_item.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/widgets/product_card.dart';
import 'package:pickleo/widgets/product_variant_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Product Variants Model Tests', () {
    test('Parses variants list from new GET /consumer/products response item', () {
      final json = {
        "id": "bisleri-soda-1",
        "name": "Bisleri Soda | Sparkling Mineral Water",
        "category": "Beverages",
        "region": "National",
        "kitchen": "Bottling Plant",
        "spiceLevel": "None",
        "purityClaims": ["Pure Spring Water"],
        "batchAgeDays": 1,
        "shelfLifeDays": 365,
        "subcategory": "Soda",
        "badge": "Popular",
        "dietMark": "Vegetarian",
        "zeroPreservatives": true,
        "shortDescription": "Sparkling soda with crisp taste",
        "description": "Crisp and bubbly mineral soda",
        "imageUrl": "https://example.com/soda.jpg",
        "variants": [
          {
            "id": "var-2pack",
            "sku": "BIS-SODA-750-X2",
            "variantSize": "750 ml X 2",
            "label": "750 ml X 2",
            "serves": 2,
            "packaging": "Bottle",
            "safetyStock": 5,
            "bestValue": true,
            "minOrderQty": 1,
            "maxOrderQty": 10,
            "mrp": 40.0,
            "price": 38.0,
            "stock": 50,
            "stockUnit": "Bottle",
            "status": "Active"
          },
          {
            "id": "var-1pc",
            "sku": "BIS-SODA-750-X1",
            "variantSize": "1 pc (750 ml)",
            "label": "1 pc (750 ml)",
            "serves": 1,
            "packaging": "Bottle",
            "safetyStock": 5,
            "bestValue": false,
            "minOrderQty": 1,
            "maxOrderQty": 10,
            "mrp": 20.0,
            "price": 20.0,
            "stock": 80,
            "stockUnit": "Bottle",
            "status": "Active"
          }
        ]
      };

      final product = Product.fromJson(json);

      expect(product.id, 'bisleri-soda-1');
      expect(product.name, 'Bisleri Soda | Sparkling Mineral Water');
      expect(product.variants.length, 2);
      expect(product.hasMultipleVariants, isTrue);

      // Default variant is the first one in the list
      final defaultVar = product.defaultVariant;
      expect(defaultVar.id, 'var-2pack');
      expect(defaultVar.variantSize, '750 ml X 2');
      expect(defaultVar.price, 38.0);
      expect(defaultVar.mrp, 40.0);
      expect(defaultVar.bestValue, isTrue);

      // Product card prices mirror first variant
      expect(product.basePrice, 38.0);
      expect(product.originalPrice, 40.0);
      expect(product.defaultWeight, '750 ml X 2');
    });

    test('Calculates unitPriceText exactly matching Screenshot 2 rates', () {
      final v1 = ProductVariant(
        id: 'v1',
        variantSize: '750 ml X 2',
        label: '750 ml X 2',
        mrp: 40,
        price: 38,
      );
      // 750 ml * 2 = 1500 ml -> 38 / 1500 * 100 = 2.5333... -> ₹2.53/100ml
      expect(v1.unitPriceText, '₹2.53/100ml');

      final v2 = ProductVariant(
        id: 'v2',
        variantSize: '1 pc (750 ml)',
        label: '1 pc (750 ml)',
        mrp: 20,
        price: 20,
      );
      // 750 ml -> 20 / 750 * 100 = 2.6666... -> ₹2.66/100ml
      expect(v2.unitPriceText, '₹2.66/100ml');
    });

    test('Calculates saveBadgeText correctly (Save ₹2 / Best Value)', () {
      final discountedVar = ProductVariant(
        id: 'v1',
        label: '750 ml X 2',
        mrp: 40,
        price: 38,
        bestValue: true,
      );
      expect(discountedVar.saveBadgeText, 'Save ₹2');

      final nonDiscountBestValue = ProductVariant(
        id: 'v2',
        label: 'Special Pack',
        mrp: 100,
        price: 100,
        bestValue: true,
      );
      expect(nonDiscountBestValue.saveBadgeText, 'Best Value');

      final standardVar = ProductVariant(
        id: 'v3',
        label: 'Standard',
        mrp: 50,
        price: 50,
        bestValue: false,
      );
      expect(standardVar.saveBadgeText, isNull);
    });

    test('Normalizes variantSize units (250G->250g, 1000G->1kg) and replaces style labels', () {
      final v1kg = ProductVariant(
        id: 'var-1kg',
        variantSize: '1000G',
        label: 'Traditional Andhra Style',
        mrp: 2000,
        price: 1800,
      );
      expect(v1kg.unitLabel, '1kg');
      expect(v1kg.displayLabel, '1kg');

      final v250g = ProductVariant(
        id: 'var-250g',
        variantSize: '250G',
        label: 'Traditional Andhra Style',
        mrp: 500,
        price: 450,
      );
      expect(v250g.unitLabel, '250g');
      expect(v250g.displayLabel, '250g');

      final v500g = ProductVariant(
        id: 'var-500g',
        variantSize: '500G',
        label: 'Traditional Andhra Style',
        mrp: 1000,
        price: 900,
      );
      expect(v500g.unitLabel, '500g');
      expect(v500g.displayLabel, '500g');
    });

    test('Single variant product hasMultipleVariants is false', () {
      final json = {
        "id": "single-prod",
        "name": "Single Variant Item",
        "price": 100,
        "variants": [
          {
            "id": "v-only",
            "label": "500g",
            "price": 100,
            "mrp": 120
          }
        ]
      };
      final product = Product.fromJson(json);
      expect(product.hasMultipleVariants, isFalse);
      expect(product.variants.length, 1);
      expect(product.defaultVariant.id, 'v-only');
    });
  });

  group('Cart & Variant Integration Tests', () {
    test('AppState tracks quantities per variantId and cart item keys', () {
      final appState = AppState();
      final product = Product.fromJson({
        'id': 'bisleri-soda',
        'name': 'Bisleri Soda',
        'category': 'beverages',
        'variants': [
          {
            'id': 'v-2pack',
            'label': '750 ml X 2',
            'price': 38.0,
            'mrp': 40.0,
          },
          {
            'id': 'v-1pc',
            'label': '1 pc (750 ml)',
            'price': 20.0,
            'mrp': 20.0,
          },
        ],
      });

      // Add 2 units of 2pack
      appState.addToCart(
        product,
        '750 ml X 2',
        variant: product.variants[0],
        qty: 2,
      );

      // Add 3 units of 1pc
      appState.addToCart(
        product,
        '1 pc (750 ml)',
        variant: product.variants[1],
        qty: 3,
      );

      expect(appState.cartCount, 5);
      expect(appState.getVariantQty('bisleri-soda', 'v-2pack'), 2);
      expect(appState.getVariantQty('bisleri-soda', 'v-1pc'), 3);
      expect(appState.getProductQty('bisleri-soda'), 5);

      // Cart total calculation
      // 2 * 38 + 3 * 20 = 76 + 60 = 136 subtotal
      expect(appState.subtotal, 136.0);
      expect(appState.cartTotal, 151.0); // 136 + 15 delivery fee

      // Update variant quantity
      appState.setProductQty(
        product,
        0,
        variant: product.variants[0],
      );
      expect(appState.getVariantQty('bisleri-soda', 'v-2pack'), 0);
      expect(appState.getVariantQty('bisleri-soda', 'v-1pc'), 3);
      expect(appState.cartCount, 3);
      expect(appState.subtotal, 60.0);
      expect(appState.cartTotal, 75.0); // 60 + 15 delivery fee
    });

    test('CartItem holds effectiveVariantId and serializes correctly', () {
      final item = CartItem(
        product: Product.fromJson({'id': 'prod-1', 'name': 'Pickle'}),
        selectedWeight: '500g',
        quantity: 2,
        variantId: 'var-500g',
        variant: ProductVariant(
          id: 'var-500g',
          label: '500g',
          price: 250,
          mrp: 300,
        ),
      );

      expect(item.effectiveVariantId, 'var-500g');
      expect(item.itemKey, 'prod-1_var-500g');
      expect(item.unitPrice, 250.0);
      expect(item.totalPrice, 500.0);

      final json = item.toJson();
      expect(json['variantId'], 'var-500g');
      expect(json['quantity'], 2);
    });
  });

  group('ProductCard & BottomSheet Widget Tests', () {
    testWidgets('ProductCard shows "ADD 2 options" when product has multiple variants (Screenshot 1)',
        (tester) async {
      final appState = AppState();
      final product = Product.fromJson({
        'id': 'bisleri-soda',
        'name': 'Bisleri Soda | Sparkling Mineral Water',
        'category': 'beverages',
        'variants': [
          {
            'id': 'v1',
            'label': '750 ml X 2',
            'variantSize': '750 ml X 2',
            'price': 38.0,
            'mrp': 40.0,
          },
          {
            'id': 'v2',
            'label': '1 pc (750 ml)',
            'variantSize': '1 pc (750 ml)',
            'price': 20.0,
            'mrp': 20.0,
          },
        ],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 300,
                child: ProductCard(
                  product: product,
                  appState: appState,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find 'ADD' and '2 options' text on button (matching Screenshot 1)
      expect(find.text('ADD'), findsOneWidget);
      expect(find.text('2 options'), findsOneWidget);
    });

    testWidgets('Tapping ADD button opens ProductVariantBottomSheet modal (Screenshot 2)',
        (tester) async {
      final appState = AppState();
      // Authenticate so requireAuth does not intercept
      appState.login('9876543210');
      appState.clearCart();

      final product = Product.fromJson({
        'id': 'bisleri-soda',
        'name': 'Bisleri Soda | Sparkling Mineral Water',
        'category': 'beverages',
        'variants': [
          {
            'id': 'v1',
            'label': '750 ml X 2',
            'variantSize': '750 ml X 2',
            'price': 38.0,
            'mrp': 40.0,
            'bestValue': true,
          },
          {
            'id': 'v2',
            'label': '1 pc (750 ml)',
            'variantSize': '1 pc (750 ml)',
            'price': 20.0,
            'mrp': 20.0,
          },
        ],
      });

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 300,
                child: ProductCard(
                  product: product,
                  appState: appState,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap the ADD button with options
      await tester.tap(find.text('2 options'));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed with product title
      expect(find.text('Bisleri Soda | Sparkling Mineral Water'), findsWidgets);

      // Displays each variant label, price, and rates inside bottom sheet
      expect(
          find.descendant(
              of: find.byType(ProductVariantBottomSheet),
              matching: find.text('750 ml X 2')),
          findsOneWidget);
      expect(find.text('1 pc (750 ml)'), findsOneWidget);
      expect(find.text('Save ₹2'), findsOneWidget);
      expect(find.text('₹2.53/100ml'), findsOneWidget);
      expect(find.text('₹2.66/100ml'), findsOneWidget);

      // Tap ADD on the second variant (1 pc 750ml at ₹20)
      final addButtons = find.text('ADD');
      expect(addButtons, findsWidgets);
      await tester.tap(addButtons.last);
      await tester.pumpAndSettle();

      // Variant added to cart
      expect(appState.getVariantQty('bisleri-soda', 'v2'), 1);
      expect(appState.subtotal, 20.0);
    });

    testWidgets('ProductVariantBottomSheet displays variant units (1kg, 250g, 500g) and prices without Traditional Andhra Style', (WidgetTester tester) async {
      final appState = AppState();
      final product = Product.fromJson({
        'id': 'mutton-pickle',
        'name': 'MUTTON',
        'kitchen': 'SRINIVASA FOOD PRODUCTS',
        'variants': [
          {
            'id': 'var-1000g',
            'variantSize': '1000G',
            'label': 'Traditional Andhra Style',
            'price': 1800,
            'mrp': 2000,
          },
          {
            'id': 'var-250g',
            'variantSize': '250G',
            'label': 'Traditional Andhra Style',
            'price': 450,
            'mrp': 500,
          },
          {
            'id': 'var-500g',
            'variantSize': '500G',
            'label': 'Traditional Andhra Style',
            'price': 900,
            'mrp': 1000,
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppStateProvider(
              appState: appState,
              child: ProductVariantBottomSheet(product: product),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Displays units (1kg, 250g, 500g)
      expect(find.text('1kg'), findsOneWidget);
      expect(find.text('250g'), findsOneWidget);
      expect(find.text('500g'), findsOneWidget);

      // Displays prices (₹1800, ₹450, ₹900)
      expect(find.text('₹1800'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
      expect(find.text('₹900'), findsOneWidget);

      // Does NOT display 'Traditional Andhra Style'
      expect(find.text('Traditional Andhra Style'), findsNothing);
    });

    testWidgets('Tapping ADD on a variant changes to stepper [- 1 +] and does NOT revert back to ADD after server sync', (WidgetTester tester) async {
      final appState = AppState();
      final product = Product.fromJson({
        'id': 'mutton-pickle',
        'name': 'MUTTON',
        'kitchen': 'SRINIVASA FOOD PRODUCTS',
        'variants': [
          {
            'id': 'var-1000g',
            'variantSize': '1000G',
            'price': 1800,
            'mrp': 2000,
          },
          {
            'id': 'var-250g',
            'variantSize': '250G',
            'price': 450,
            'mrp': 500,
          },
          {
            'id': 'var-500g',
            'variantSize': '500G',
            'price': 900,
            'mrp': 1000,
          },
        ],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppStateProvider(
              appState: appState,
              child: ProductVariantBottomSheet(product: product),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially all 3 variants show ADD
      expect(find.text('ADD'), findsNWidgets(3));

      // Tap ADD on the 250g variant (second ADD button)
      await tester.tap(find.text('ADD').at(1));
      await tester.pumpAndSettle();

      // Now 2 ADD buttons remain, and one stepper with '1' is displayed
      expect(find.text('ADD'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget);
      expect(appState.getVariantQty('mutton-pickle', 'var-250g'), 1);

      // Simulate a server sync response (GET /consumer/cart) where product JSON lacks variants array
      // and productId equals the variant ID
      final serverCart = ConsumerCartResponse.fromJson({
        "items": [
          {
            "productId": "var-250g",
            "quantity": 1,
            "product": {
              "id": "mutton-pickle",
              "name": "MUTTON",
              "price": 450,
            },
            "lineTotal": 450.0
          }
        ],
        "itemCount": 1,
        "subtotal": 450.0
      });

      // AppState processes response
      appState.populateCartFromResponseForTesting(serverCart);
      await tester.pumpAndSettle();

      // CRITICAL CHECK: Does NOT revert back to ADD!
      // Must still show 2 ADD buttons and one stepper with '1'
      expect(find.text('ADD'), findsNWidgets(2));
      expect(find.text('1'), findsOneWidget);
      expect(appState.getVariantQty('mutton-pickle', 'var-250g'), 1);

      // Tap '+' icon on the stepper
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Quantity is now 2
      expect(find.text('2'), findsOneWidget);
      expect(appState.getVariantQty('mutton-pickle', 'var-250g'), 2);

      // Tap '-' icon on the stepper
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Quantity is back to 1
      expect(find.text('1'), findsOneWidget);
      expect(appState.getVariantQty('mutton-pickle', 'var-250g'), 1);

      // Tap '-' icon again to decrement to 0
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pumpAndSettle();

      // Item removed, all 3 variants show ADD again
      expect(find.text('ADD'), findsNWidgets(3));
      expect(appState.getVariantQty('mutton-pickle', 'var-250g'), 0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/product_detail_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Companion Products & Details API Tests', () {
    test('ProductDetailsResponse correctly handles grouped product records and missingIds', () {
      final jsonResponse = {
        "items": [
          {
            "id": "paired-1",
            "name": "Gongura Pickle",
            "price": 249,
            "mrp": 299,
            "status": "Active",
            "variants": [
              {
                "id": "g-var-1",
                "variantSize": "250g",
                "label": "250g Jar",
                "price": 249,
                "mrp": 299,
                "status": "Active"
              }
            ],
            "frequentlyBoughtTogether": ["paired-2"],
            "relatedProductIds": ["rel-1"]
          },
          {
            "id": "paired-2",
            "name": "Garlic Pickle",
            "price": 229,
            "mrp": 279,
            "status": "Active",
            "variants": [
              {
                "id": "gar-var-1",
                "variantSize": "300g",
                "label": "300g Jar",
                "price": 229,
                "mrp": 279,
                "status": "Active"
              },
              {
                "id": "gar-var-2",
                "variantSize": "500g",
                "label": "500g Jar",
                "price": 389,
                "mrp": 450,
                "status": "Active"
              }
            ]
          }
        ],
        "missingIds": ["unknown-id-99"]
      };

      final parsed = ProductDetailsResponse.fromJson(jsonResponse);
      expect(parsed.items.length, 2);
      expect(parsed.missingIds, ['unknown-id-99']);

      final gongura = parsed.items[0];
      expect(gongura.id, 'paired-1');
      expect(gongura.hasMultipleVariants, isFalse);

      final garlic = parsed.items[1];
      expect(garlic.id, 'paired-2');
      expect(garlic.hasMultipleVariants, isTrue);
      expect(garlic.variants.length, 2);
    });

    test('AppState cache preserves fetched companion products for findProductById', () {
      final appState = AppState();

      final sampleProduct = Product(
        id: 'cached-prod-1',
        name: 'Avakaya Classic',
        categoryId: 'cat-1',
        maker: 'Grandma Sita',
        place: 'Guntur',
        subtitle: 'Authentic spice',
        basePrice: 249,
        originalPrice: 299,
        rating: 4.8,
        reviewsDisplay: '120',
        reviewCount: 120,
        weightOptions: ['250g'],
        pricesByWeight: {'250g': 249},
        spiceLevel: 3,
        description: 'Traditional recipe',
        storyTitle: 'Heritage',
        homemakerStory: 'Made with stone-pressed oil',
      );

      // Directly cache
      appState.cacheDetailedProduct(sampleProduct);

      final found = appState.findProductById('cached-prod-1');
      expect(found, isNotNull);
      expect(found!.id, 'cached-prod-1');
      expect(found.name, 'Avakaya Classic');
    });

    testWidgets('ProductDetailScreen renders Frequently Paired with Add buttons and Related Products', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appState = AppState(initialLoggedIn: true);

      final pairedProduct = Product(
        id: 'paired-garlic',
        name: 'Garlic Pickle',
        categoryId: 'cat-pickle',
        maker: 'Grandma',
        place: 'Guntur',
        subtitle: 'Tasty',
        basePrice: 199,
        originalPrice: 249,
        rating: 4.7,
        reviewsDisplay: '50',
        reviewCount: 50,
        weightOptions: ['250g'],
        pricesByWeight: {'250g': 199},
        spiceLevel: 2,
        description: 'Fresh garlic',
        storyTitle: 'Story',
        homemakerStory: 'Story text',
      );

      final relProduct = Product(
        id: 'related-tomato',
        name: 'Tomato Thokku',
        categoryId: 'cat-pickle',
        maker: 'Grandma',
        place: 'Tenali',
        subtitle: 'Tangy',
        basePrice: 179,
        originalPrice: 219,
        rating: 4.6,
        reviewsDisplay: '40',
        reviewCount: 40,
        weightOptions: ['250g'],
        pricesByWeight: {'250g': 179},
        spiceLevel: 2,
        description: 'Sun-dried tomatoes',
        storyTitle: 'Story',
        homemakerStory: 'Story text',
      );

      appState.cacheDetailedProduct(pairedProduct);
      appState.cacheDetailedProduct(relProduct);

      final mainProduct = Product(
        id: 'main-avakaya',
        name: 'Avakaya Mango Pickle',
        categoryId: 'cat-pickle',
        maker: 'Grandma',
        place: 'Vijayawada',
        subtitle: 'Classic',
        basePrice: 299,
        originalPrice: 349,
        rating: 4.9,
        reviewsDisplay: '100',
        reviewCount: 100,
        weightOptions: ['250g'],
        pricesByWeight: {'250g': 299},
        spiceLevel: 3,
        description: 'Authentic mango pickle',
        storyTitle: 'Story',
        homemakerStory: 'Story text',
        frequentlyBoughtTogether: ['paired-garlic'],
        relatedProductIds: ['related-tomato'],
      );

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: ProductDetailScreen(
              product: mainProduct,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final addBtnFinder = find.text('+ Add');
      await tester.ensureVisible(addBtnFinder);
      await tester.pumpAndSettle();

      // Frequently Paired section should be visible
      expect(find.text('Frequently Paired'), findsOneWidget);
      expect(find.text('Garlic Pickle'), findsOneWidget);
      expect(addBtnFinder, findsOneWidget);

      // Tap + Add on the paired product
      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      // Paired product should now be in cart
      expect(appState.getProductQty('paired-garlic'), 1);

      // Related Products section header should be visible
      final relSectionFinder = find.text('Related Products');
      await tester.ensureVisible(relSectionFinder);
      expect(relSectionFinder, findsOneWidget);
    });

    testWidgets('ProductDetailScreen does NOT render Frequently Paired or Related Products when product has none defined', (tester) async {
      final appState = AppState(initialLoggedIn: true);

      final standaloneProduct = Product(
        id: 'standalone-mutton',
        name: 'MUTTON',
        categoryId: 'cat-nonveg',
        maker: 'SRINIVASA FOOD PRODUCTS',
        place: 'Bhimavaram',
        subtitle: 'Authentic Mutton Pickle',
        basePrice: 1800,
        originalPrice: 2000,
        rating: 4.8,
        reviewsDisplay: '12',
        reviewCount: 12,
        weightOptions: ['250g', '500g', '1kg'],
        pricesByWeight: {'250g': 450, '500g': 900, '1kg': 1800},
        spiceLevel: 3,
        description: 'Made with tender mutton',
        storyTitle: 'Story',
        homemakerStory: 'Story text',
        frequentlyBoughtTogether: const [],
        relatedProductIds: const [],
      );

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: ProductDetailScreen(
              product: standaloneProduct,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Neither Frequently Paired nor Related Products should be displayed
      expect(find.text('Frequently Paired'), findsNothing);
      expect(find.text('Related Products'), findsNothing);
    });

    testWidgets('ProductDetailScreen does NOT fall back to static products (e.g. Avakaya) when companion IDs do not resolve from API', (tester) async {
      final appState = AppState(initialLoggedIn: true);

      final fishProduct = Product(
        id: 'fish-sandh-123',
        name: 'FISH (SANDHYA SPECIAL)',
        categoryId: 'cat-nonveg',
        maker: 'Sandhya Kitchens',
        place: 'Kakinada',
        subtitle: 'Authentic Fish Pickle',
        basePrice: 1688,
        originalPrice: 1899,
        rating: 4.8,
        reviewsDisplay: '50',
        reviewCount: 50,
        weightOptions: ['250g', '500g', '1kg'],
        pricesByWeight: {'250g': 422, '500g': 844, '1kg': 1688},
        spiceLevel: 3,
        description: 'Made with fresh fish',
        storyTitle: 'Story',
        homemakerStory: 'Story text',
        frequentlyBoughtTogether: const ['unknown-companion-id-999'],
        relatedProductIds: const ['unknown-rel-id-999'],
      );

      await tester.pumpWidget(
        AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: ProductDetailScreen(
              product: fishProduct,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Frequently Paired must NOT be rendered with static fallback products (e.g. Andhra Avakaya)
      expect(find.text('Frequently Paired'), findsNothing);
      expect(find.textContaining('Avakaya'), findsNothing);
      expect(find.text('Related Products'), findsNothing);
    });
  });
}

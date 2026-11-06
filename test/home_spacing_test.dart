import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/offer.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/screens/home_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/widgets/offer_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Uint8List kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class TestAssetBundle extends PlatformAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.png') || key.endsWith('.jpg') || key.endsWith('.jpeg')) {
      return ByteData.view(kTransparentImage.buffer);
    }
    return super.load(key);
  }
}

Product _createTestProduct() {
  return const Product(
    id: 'p1',
    name: 'Panasapappu Pachadi',
    categoryId: 'pickles',
    categoryName: 'Pickle & Achaar',
    maker: 'SRINIVASA FOOD PRODUCTS',
    place: 'Bhimavaram',
    subtitle: 'Authentic jackfruit seed pickle',
    basePrice: 800,
    originalPrice: 1000,
    rating: 4.8,
    reviewsDisplay: '120',
    reviewCount: 120,
    weightOptions: ['250g', '500g', '1kg'],
    pricesByWeight: {'250g': 200, '500g': 400, '1kg': 800},
    spiceLevel: 3,
    description: 'Authentic jackfruit seed pickle',
    storyTitle: 'Story',
    homemakerStory: 'Story text',
    status: 'Active',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'HomeScreen provides 24dp gap after products grid and separates from trust cards when offers are absent',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    await appState.initSession();
    appState.setBestsellersForTesting([_createTestProduct()]);
    appState.setOffersForTesting([]);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: HomeScreen(onNavigateTab: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify SliverPadding for product grid has 24dp bottom spacing
    final sliverPaddingWidgets = tester
        .widgetList<SliverPadding>(find.byType(SliverPadding))
        .toList();
    final productGridPadding = sliverPaddingWidgets.firstWhere(
      (sp) => sp.padding == const EdgeInsets.fromLTRB(16, 0, 16, 24),
      orElse: () => throw TestFailure(
          'Product grid SliverPadding must have EdgeInsets.fromLTRB(16, 0, 16, 24)'),
    );
    expect(productGridPadding.padding, const EdgeInsets.fromLTRB(16, 0, 16, 24));

    // Verify 4 Trust Cards are present
    expect(find.text('100% Traditional'), findsOneWidget);
    expect(find.text('Cold-Pressed Oils'), findsOneWidget);
    expect(find.text('Zero Chemicals'), findsOneWidget);
    expect(find.text('Fast Dispatch'), findsOneWidget);
  });

  testWidgets(
      'HomeScreen wraps DynamicOffersSection with 24dp bottom padding when offers are present',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    appState.setBestsellersForTesting([_createTestProduct()]);
    appState.setOffersForTesting([
      const OfferItem(
        id: 'off-1',
        title: 'SPECIAL OFFER',
        code: 'SPECIAL20',
        discountType: 'flat',
        discountValue: 20,
        description: 'Flat 20 OFF',
        status: 'Active',
      ),
    ]);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: HomeScreen(onNavigateTab: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify DynamicOffersSection is rendered
    expect(find.byType(DynamicOffersSection), findsOneWidget);

    // Verify DynamicOffersSection parent padding provides 24dp bottom margin
    final offersPaddingFinder = find.ancestor(
      of: find.byType(DynamicOffersSection),
      matching: find.byWidgetPredicate((widget) {
        if (widget is Padding) {
          final padding = widget.padding as EdgeInsets;
          return padding.bottom == 24.0;
        }
        return false;
      }),
    );
    expect(offersPaddingFinder, findsOneWidget,
        reason: 'DynamicOffersSection must have bottom: 24 padding for proper component-wise gap');
  });

  testWidgets(
      'HomeScreen empty bestsellers state also has 24dp bottom margin to maintain component-wise gap',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final appState = AppState();
    appState.setBestsellersForTesting([]);
    appState.setOffersForTesting([]);

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: AppStateProvider(
          appState: appState,
          child: MaterialApp(
            home: HomeScreen(onNavigateTab: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Empty state container should have bottom margin of 24
    final emptyStateContainerFinder = find.byWidgetPredicate((w) {
      if (w is Container && w.margin is EdgeInsets) {
        final margin = w.margin as EdgeInsets;
        return margin == const EdgeInsets.fromLTRB(16, 8, 16, 24);
      }
      return false;
    });
    expect(emptyStateContainerFinder, findsOneWidget);
  });
}

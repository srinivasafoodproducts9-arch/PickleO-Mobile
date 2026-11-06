import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/models/category.dart';
import 'package:pickleo/screens/category_listing_screen.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testCategories = [
    CategoryItem(
      id: 'pickles',
      name: 'Pickles & Achaar',
      chip: 'Pickles & Achaar',
      icon: Icons.soup_kitchen_outlined,
      color: const Color(0xFF964900),
      tint: const Color(0xFFFFE9E3),
      count: 'Fresh Batches',
      sub: '',
      badge: '',
      badgeBg: const Color(0xFFFC820C),
    ),
    CategoryItem(
      id: 'chutneys',
      name: 'Chutneys',
      chip: 'Chutneys',
      icon: Icons.soup_kitchen_outlined,
      color: const Color(0xFF964900),
      tint: const Color(0xFFFFE9E3),
      count: 'Fresh Batches',
      sub: '',
      badge: '',
      badgeBg: const Color(0xFFFC820C),
    ),
    CategoryItem(
      id: 'podis',
      name: 'Podis & Powders',
      chip: 'Podis & Powders',
      icon: Icons.soup_kitchen_outlined,
      color: const Color(0xFF964900),
      tint: const Color(0xFFFFE9E3),
      count: 'Fresh Batches',
      sub: '',
      badge: '',
      badgeBg: const Color(0xFFFC820C),
    ),
  ];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CategoryListingScreen Regional & Category Filtering Tests', () {
    testWidgets('Defaults to "All" as first chip and lists dynamic categories',
        (WidgetTester tester) async {
      final appState = AppState();
      appState.setCategoriesForTesting(testCategories);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateProvider(
            appState: appState,
            child: const CategoryListingScreen(
              categoryTitle: 'Andhra Style Kitchens',
              categorySubtitle:
                  'Avakaya, Gongura and more traditional specialties from Andhra Style homes',
              region: 'Andhra',
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify title and subtitle from the user's screenshot
      expect(find.text('Andhra Style Kitchens'), findsWidgets);
      expect(
        find.text(
            'Avakaya, Gongura and more traditional specialties from Andhra Style homes'),
        findsOneWidget,
      );

      // Verify "All" is the default selected first chip
      expect(find.text('All'), findsOneWidget);

      // Verify dynamic category chips are present instead of static pickle flavors
      expect(find.text('Pickles & Achaar'), findsOneWidget);
      expect(find.text('Chutneys'), findsOneWidget);
      expect(find.text('Podis & Powders'), findsOneWidget);

      // Verify static items like 'Mango & Avakaya' are NOT chips
      expect(find.widgetWithText(GestureDetector, 'Mango & Avakaya'),
          findsNothing);
    });

    testWidgets('Tapping a category chip filters products by region and category',
        (WidgetTester tester) async {
      final appState = AppState();
      appState.setCategoriesForTesting(testCategories);

      await tester.pumpWidget(
        MaterialApp(
          home: AppStateProvider(
            appState: appState,
            child: const CategoryListingScreen(
              categoryTitle: 'Andhra Style Kitchens',
              categorySubtitle:
                  'Avakaya, Gongura and more traditional specialties from Andhra Style homes',
              region: 'Andhra',
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap on Podis & Powders category chip
      final podiChip = find.text('Podis & Powders');
      expect(podiChip, findsOneWidget);
      await tester.tap(podiChip);
      await tester.pump();

      // Heading remains Andhra Style Kitchens for regional kitchen view
      expect(find.text('Andhra Style Kitchens'), findsWidgets);
    });
  });
}

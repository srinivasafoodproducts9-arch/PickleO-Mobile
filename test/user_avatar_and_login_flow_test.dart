import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pickleo/state/app_state.dart';
import 'package:pickleo/widgets/user_avatar.dart';
import 'package:pickleo/screens/auth_screen.dart';
import 'package:pickleo/screens/home_screen.dart';
import 'package:pickleo/screens/profile_setup_screen.dart';
import 'package:pickleo/utils/auth_guard.dart';
import 'package:pickleo/models/product.dart';
import 'package:pickleo/models/product_region.dart';
import 'package:pickleo/widgets/product_card.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserAvatar Widget Tests', () {
    testWidgets('Shows outline avatar icon when not logged in and no image',
        (tester) async {
      final appState = AppState();
      appState.logout();

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: Scaffold(
                body: UserAvatar(radius: 16),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets('Shows solid avatar icon when logged in and no profile image',
        (tester) async {
      final appState = AppState();
      appState.login('9876543210');

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: Scaffold(
                body: UserAvatar(radius: 16),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('Tapping UserAvatar when logged out opens AuthScreen',
        (tester) async {
      final appState = AppState();
      appState.logout();

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: Scaffold(
                body: UserAvatar(radius: 16),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(UserAvatar));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });

  group('ProfileSetupScreen Login Completion Flow Tests', () {
    testWidgets('ProfileSetupScreen contains PopScope with canPop false',
        (tester) async {
      final appState = AppState();
      appState.login('9876543210');

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: ProfileSetupScreen(phone: '9876543210'),
            ),
          ),
        ),
      );
      await tester.pump();

      final popScopeFinder =
          find.byWidgetPredicate((widget) => widget is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final dynamic popScope = tester.widget(popScopeFinder);
      expect(popScope.canPop, false);
    });

    testWidgets('Cancel button opens confirmation dialog to sign out',
        (tester) async {
      final appState = AppState();
      appState.login('9876543210');

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: ProfileSetupScreen(phone: '9876543210'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Setup?'), findsOneWidget);
      expect(find.text('Cancel & Sign Out'), findsOneWidget);
      expect(find.text('Continue Setup'), findsOneWidget);

      await tester.tap(find.text('Cancel & Sign Out'));
      await tester.pumpAndSettle();

      expect(appState.isLoggedIn, false);
    });

    testWidgets('Quick Profile Setup validates all mandatory fields',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      appState.setProductRegionsForTesting(const [
        ProductRegion(id: 'andhra', name: 'Andhra'),
      ]);
      appState.login('9876543210');

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: const MaterialApp(
              home: ProfileSetupScreen(phone: '9876543210'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure mandatory labels and indicators are present
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);
      expect(find.text('Spice Tolerance'), findsOneWidget);
      expect(find.text('Preferred Regional Styles'), findsOneWidget);

      // Tap Complete Registration without filling fields
      await tester.tap(find.text('Complete Registration'));
      await tester.pumpAndSettle();

      // Check inline validation error messages
      expect(find.text('Full Name is required'), findsOneWidget);
      expect(find.text('Email Address is required'), findsOneWidget);
      expect(find.text('Date of Birth is required'), findsOneWidget);
      expect(find.text('Please select at least one preferred regional style'),
          findsOneWidget);
    });
  });

  group('Unauthenticated User Action Guards (Address, Account, Add to Cart, Orders, Checkout)', () {
    testWidgets('requireAuth executes callback immediately if user is already logged in',
        (tester) async {
      final appState = AppState();
      appState.login('9876543210');
      bool actionExecuted = false;

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      requireAuth(context, onAuthenticated: () {
                        actionExecuted = true;
                      });
                    },
                    child: const Text('Guarded Button'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Guarded Button'));
      await tester.pump();

      expect(actionExecuted, true);
      expect(find.byType(AuthScreen), findsNothing);
    });

    testWidgets('requireAuth redirects to AuthScreen if user is not logged in',
        (tester) async {
      final appState = AppState();
      appState.logout();
      bool actionExecuted = false;

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      requireAuth(context, onAuthenticated: () {
                        actionExecuted = true;
                      });
                    },
                    child: const Text('Guarded Button'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Guarded Button'));
      await tester.pumpAndSettle();

      expect(actionExecuted, false);
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('Add to Cart on ProductCard opens AuthScreen when user is logged out',
        (tester) async {
      final appState = AppState();
      final product = ProductData.findById('avakaya');

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 340,
                  child: ProductCard(
                    product: product,
                    appState: appState,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Add button
      final addButton = find.text('ADD');
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // AuthScreen is presented
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(appState.cartCount, 0);
    });

    testWidgets('Tapping UserAvatar on HomeScreen when logged out takes to AuthScreen and not Profile/Accounts',
        (tester) async {
      final appState = AppState(); // default unauthenticated
      expect(appState.isLoggedIn, false);

      int navigatedTab = -1;

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: HomeScreen(
                onNavigateTab: (index) {
                  navigatedTab = index;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find UserAvatar on HomeScreen
      final avatarFinder = find.byType(UserAvatar);
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      // Verify AuthScreen is opened
      expect(find.byType(AuthScreen), findsOneWidget);
      // Verify did NOT navigate to account tab 4
      expect(navigatedTab, -1);
    });

    testWidgets('Tapping Wishlist icon on HomeScreen when logged out takes to AuthScreen',
        (tester) async {
      final appState = AppState();
      expect(appState.isLoggedIn, false);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: HomeScreen(
                onNavigateTab: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Guest wishlist must be empty and no counter badge shown
      expect(appState.favoriteProductIds.isEmpty, true);
      expect(appState.favoriteProductIds.length, 0);

      // Find Wishlist icon on HomeScreen (top bar size 22)
      final wishlistFinder = find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.favorite_border && w.size == 22);
      expect(wishlistFinder, findsOneWidget);

      await tester.tap(wishlistFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify AuthScreen opened
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('Tapping Cart icon on HomeScreen when logged out takes to AuthScreen',
        (tester) async {
      final appState = AppState();
      expect(appState.isLoggedIn, false);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: HomeScreen(
                onNavigateTab: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final cartFinder = find.byIcon(Icons.shopping_bag_outlined);
      expect(cartFinder, findsOneWidget);

      await tester.tap(cartFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify AuthScreen opened
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('Tapping Location row on HomeScreen when logged out takes to AuthScreen',
        (tester) async {
      final appState = AppState();
      expect(appState.isLoggedIn, false);

      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: TestAssetBundle(),
          child: AppStateProvider(
            appState: appState,
            child: MaterialApp(
              home: HomeScreen(
                onNavigateTab: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Deliver to Location
      final locationFinder = find.text('Deliver to');
      expect(locationFinder, findsOneWidget);

      await tester.tap(locationFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AuthScreen), findsOneWidget);
    });
  });
}

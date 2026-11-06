import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../utils/responsive.dart';
import '../widgets/mobile_frame_wrapper.dart';
import 'home_screen.dart';
import 'products_catalog_screen.dart';
import 'search_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import '../utils/auth_guard.dart';
import 'package:upgrader/upgrader.dart';
import '../utils/app_upgrader.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  bool _isStickyCartDismissed = false;
  int _prevCartCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        if (appState.isLoggedIn) {
          appState.loadCartFromApi();
        }
      }
    });
  }

  void _onTabChanged(int index) {
    if (index == 3 || index == 4) {
      final appState = AppStateProvider.of(context);
      if (!appState.isLoggedIn) {
        requireAuth(context, onAuthenticated: () {
          if (mounted) setState(() => _currentIndex = index);
        });
        return;
      }
    }
    setState(() => _currentIndex = index);
    final appState = AppStateProvider.of(context);
    if (appState.isLoggedIn) {
      appState.loadCartFromApi();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isWide = Responsive.isWideTablet(context);

    final screens = [
      HomeScreen(onNavigateTab: _onTabChanged),
      const ProductsCatalogScreen(isTab: true),
      const SearchScreen(isTab: true),
      OrdersScreen(
        isTab: true,
        onNavigateTab: _onTabChanged,
        onNavigateHome: () => _onTabChanged(0),
      ),
      const ProfileScreen(),
    ];

    if (appState.cartCount != _prevCartCount) {
      _prevCartCount = appState.cartCount;
      _isStickyCartDismissed = false;
    }

    final bodyStack = Stack(
      children: [
        IndexedStack(
          index: _currentIndex,
          children: screens,
        ),

        // Sticky Cart Bar (Home, Categories, Search tabs)
        if (appState.hasCart &&
            !_isStickyCartDismissed &&
            (_currentIndex == 0 || _currentIndex == 1 || _currentIndex == 2))
          Positioned(
            left: 16,
            right: 16,
            bottom: isWide ? 20 : 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _buildStickyCartBar(context, appState),
              ),
            ),
          ),
      ],
    );

    Widget scaffold;

    if (isWide) {
      // Landscape Tablet / iPad wide view with left NavigationRail
      scaffold = Scaffold(
        backgroundColor: AppColors.surface,
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabChanged,
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.leafGreen.withValues(alpha: 0.12),
                minWidth: 76,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.eco,
                            size: 26,
                            color: AppColors.leafGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PickleO',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pickleOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon: Icon(Icons.storefront_rounded,
                        color: AppColors.pickleOrange),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.category_outlined),
                    selectedIcon: Icon(Icons.category_rounded,
                        color: AppColors.pickleOrange),
                    label: Text('Categories'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.search_rounded,
                        color: AppColors.pickleOrange),
                    label: Text('Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded,
                        color: AppColors.pickleOrange),
                    label: Text('Orders'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon: Icon(Icons.person_rounded,
                        color: AppColors.pickleOrange),
                    label: Text('Account'),
                  ),
                ],
              ),
            ),
            const VerticalDivider(
              thickness: 1,
              width: 1,
              color: AppColors.cardBorder,
            ),
            Expanded(child: bodyStack),
          ],
        ),
      );
    } else {
      // Standard Mobile / Portrait Tablet bottom navigation
      scaffold = Scaffold(
        body: bodyStack,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.cardBorder)),
            boxShadow: [
              BoxShadow(
                color: AppColors.earthBrown.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabChanged,
              backgroundColor: Colors.white,
              indicatorColor: AppColors.leafGreen.withValues(alpha: 0.12),
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded,
                      color: AppColors.pickleOrange),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.category_outlined),
                  selectedIcon: Icon(Icons.category_rounded,
                      color: AppColors.pickleOrange),
                  label: 'Categories',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon:
                      Icon(Icons.search_rounded, color: AppColors.pickleOrange),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded,
                      color: AppColors.pickleOrange),
                  label: 'Orders',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded,
                      color: AppColors.pickleOrange),
                  label: 'Account',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final wrappedScaffold = PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: UpgradeAlert(
        upgrader: AppUpgraderConfig.shared,
        dialogStyle: UpgradeDialogStyle.material,
        showIgnore: false,
        showLater: true,
        child: scaffold,
      ),
    );

    return MobileFrameWrapper(child: wrappedScaffold);
  }

  Widget _buildStickyCartBar(BuildContext context, AppState appState) {
    return GestureDetector(
      onTap: () {
        requireAuth(context, onAuthenticated: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        });
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF003820),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003820).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0F5132),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 22,
                color: Color(0xFF95D4AC),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${appState.cartCount} ${appState.cartCount == 1 ? "Jar" : "Jars"} selected',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '₹${appState.cartTotal.toStringAsFixed(0)} ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF95D4AC),
                          ),
                        ),
                        TextSpan(
                          text: 'plus free delivery',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFC0C9C0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFC820C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Cart',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Close / Dismiss cross icon for sticky cart bar (Page 14 Bug 3)
            GestureDetector(
              onTap: () {
                setState(() => _isStickyCartDismissed = true);
              },
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

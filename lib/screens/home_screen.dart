import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';
import 'address_screen.dart';
import 'address_edit_screen.dart';
import 'wishlist_screen.dart';
import 'category_listing_screen.dart';
import 'cart_screen.dart';
import '../widgets/user_avatar.dart';
import '../widgets/video_banner.dart';
import '../models/category.dart';
import '../models/product_region.dart';
import '../models/product_tag.dart';
import '../widgets/offer_banner.dart';
import '../utils/auth_guard.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        if (!appState.hasDetectedLocation && !appState.isDetectingLocation) {
          appState.detectAndApplyLocation();
        }
        if (!appState.hasLoadedBanners && !appState.isLoadingBanners) {
          appState.fetchBanners();
        }
        if (!appState.hasLoadedCategories && !appState.isLoadingCategories) {
          appState.fetchCategories();
        }
        if (!appState.hasLoadedProductRegions &&
            !appState.isLoadingProductRegions) {
          appState.fetchProductRegions();
        }
        if (!appState.hasLoadedProductTags &&
            !appState.isLoadingProductTags) {
          appState.fetchProductTags();
        }
        if (!appState.hasLoadedOffers && !appState.isLoadingOffers) {
          appState.fetchOffers();
        }
      }
    });
  }

  String? _selectedRegion;
  String? _selectedFilterTag;

  void _checkAndFetchBestsellers(
      AppState appState, String? region, String? tag) {
    if (!appState.isLoadingBestsellers &&
        (!appState.hasLoadedBestsellers ||
            appState.currentBestsellerRegion != region ||
            appState.currentBestsellerTag != tag)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          appState.fetchBestsellers(region: region, tag: tag);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);

    final String? activeRegion = (_selectedRegion != null &&
            appState.productRegions.any((r) => r.name == _selectedRegion))
        ? _selectedRegion
        : (appState.productRegions.isNotEmpty
            ? appState.productRegions.first.name
            : null);

    final String? activeFilterTag = (_selectedFilterTag != null &&
            appState.productTags.any((t) => t.name == _selectedFilterTag))
        ? _selectedFilterTag
        : null;

    _checkAndFetchBestsellers(appState, activeRegion, activeFilterTag);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F6),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: const Color(0xFFF57C00),
              onRefresh: () async {
                await Future.wait([
                  appState.fetchBanners(forceRefresh: true),
                  appState.fetchCategories(forceRefresh: true),
                  appState.fetchProductRegions(forceRefresh: true),
                  appState.fetchProductTags(forceRefresh: true),
                  appState.fetchBestsellers(
                      region: activeRegion,
                      tag: activeFilterTag,
                      forceRefresh: true),
                  appState.fetchOffers(forceRefresh: true),
                  appState.detectAndApplyLocation(forceGps: true),
                ]);
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Top App Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        // PickleO Branded App Icon (38x38 rounded 10px) matching prototype
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/app-icon.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Deliver to Location
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              requireAuth(context, onAuthenticated: () {
                                _showLocationSelector(context, appState);
                              });
                            },
                            child: Row(
                              children: [
                                Icon(
                                  appState.isNearSavedAddress
                                      ? Icons.location_on
                                      : Icons.location_on_outlined,
                                  size: 16,
                                  color: const Color(0xFF003820),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              appState.deliveryHeaderTitle,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF796C62),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          const Icon(
                                            Icons.keyboard_arrow_down,
                                            size: 14,
                                            color: Color(0xFF796C62),
                                          ),
                                          if (appState.isDetectingLocation) ...[
                                            const SizedBox(width: 4),
                                            const SizedBox(
                                              width: 9,
                                              height: 9,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: Color(0xFF003820),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        appState.deliveryHeaderSubtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2C160E),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Wishlist Heart with count
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            requireAuth(context, onAuthenticated: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const WishlistScreen(),
                                ),
                              );
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.favorite_border,
                                  size: 22, color: Color(0xFF2C160E)),
                              if (appState.favoriteProductIds.isNotEmpty)
                                Positioned(
                                  top: -5,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF003820),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 14, minHeight: 14),
                                    child: Center(
                                      child: Text(
                                        '${appState.favoriteProductIds.length}',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Cart Bag Icon with orange badge counter matching prototype
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            requireAuth(context, onAuthenticated: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CartScreen(),
                                ),
                              );
                            });
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  size: 24, color: Color(0xFF2C160E)),
                              if (appState.cartCount > 0)
                                Positioned(
                                  top: -5,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFC820C),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 16, minHeight: 16),
                                    child: Center(
                                      child: Text(
                                        '${appState.cartCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // User Avatar Icon (Redirects to Login if not logged in, or Profile tab)
                        UserAvatar(
                          radius: 17,
                          onTap: () => widget.onNavigateTab(4),
                        ),
                      ],
                    ),
                  ),
                ),

                // Global Search Bar with Mic and Camera Lens
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: InkWell(
                      onTap: () => widget.onNavigateTab(2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEBDDC9)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5D4037).withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                size: 20, color: Color(0xFF796C62)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Search pickles, snacks, spices, reg...',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF796C62),
                                ),
                              ),
                            ),
                            const Icon(Icons.mic_none_rounded,
                                size: 20, color: Color(0xFF796C62)),
                            const SizedBox(width: 10),
                            const Icon(Icons.camera_alt_outlined,
                                size: 20, color: Color(0xFF796C62)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Diet Toggles Row ([Veg] & [Non-Veg] with toggle switch and status note matching prototype)
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        // Veg Toggle
                        GestureDetector(
                          onTap: () => appState.toggleDietVeg(),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.only(left: 10, right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: appState.dietVegOn
                                    ? const Color(0xFF0F5132)
                                    : const Color(0xFFFFDBD0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFF0F5132),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F5132),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Veg',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2C160E),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 30,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: appState.dietVegOn
                                        ? const Color(0xFF0F5132)
                                        : const Color(0xFFC0C9C0),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: appState.dietVegOn
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Non-Veg Toggle
                        GestureDetector(
                          onTap: () => appState.toggleDietNonVeg(),
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.only(left: 10, right: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: appState.dietNonVegOn
                                    ? const Color(0xFFC0392B)
                                    : const Color(0xFFFFDBD0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: const Color(0xFFC0392B),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFC0392B),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Non-Veg',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF2C160E),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 30,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: appState.dietNonVegOn
                                        ? const Color(0xFFC0392B)
                                        : const Color(0xFFC0C9C0),
                                  ),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: appState.dietNonVegOn
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.all(2.0),
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Diet Note Label
                        Text(
                          appState.dietNote,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF8D6E63),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Dynamic Banners from /consumer/banners (Video & Image Support)
                if (!appState.hasLoadedBanners ||
                    appState.isLoadingBanners ||
                    appState.banners.isNotEmpty)
                  SliverToBoxAdapter(
                    child: DynamicHomeBanner(
                      banners: appState.banners,
                      isLoading:
                          !appState.hasLoadedBanners || appState.isLoadingBanners,
                      onShopNow: () => widget.onNavigateTab(1),
                    ),
                  ),

                // Explore Categories Section
                // Categories Row matching Stitch (Dynamic /consumer/categories API)
                if (appState.categories.isNotEmpty) ...[
                  // Explore Categories Title
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explore Categories',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF2C160E),
                                  ),
                                ),
                                Text(
                                  'Traditional specialties lovingly prepared',
                                  style: GoogleFonts.lora(
                                    fontSize: 11,
                                    color: const Color(0xFF796C62),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => widget.onNavigateTab(1),
                            child: Text(
                              'See All >',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF003820),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Categories Row matching Stitch (Dynamic /consumer/categories API)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 98,
                      child: appState.isLoadingCategories &&
                              appState.categories.isEmpty
                          ? ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: 4,
                              itemBuilder: (context, index) {
                                return Container(
                                  width: 82,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 58,
                                        height: 58,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEDE8),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        width: 50,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEDE8),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: appState.categories.length,
                              itemBuilder: (context, index) {
                                final CategoryItem cat =
                                    appState.categories[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => CategoryListingScreen(
                                          initialCategoryChip: 'All',
                                          categoryTitle: cat.name,
                                          categorySubtitle: cat.sub,
                                          category: cat.name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 82,
                                    margin:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 58,
                                          height: 58,
                                          decoration: BoxDecoration(
                                            color: cat.tint,
                                            borderRadius:
                                              BorderRadius.circular(16),
                                            border: Border.all(
                                                color: const Color(0xFFFBD1C4)),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(15),
                                            child: cat.hasValidImage
                                                ? Image.network(
                                                    cat.resolvedImageUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) =>
                                                        _buildCategoryPlaceholder(cat),
                                                    loadingBuilder:
                                                        (context, child, progress) {
                                                      if (progress == null) {
                                                        return child;
                                                      }
                                                      return ShimmerLoading(
                                                        child: Container(
                                                          width: 58,
                                                          height: 58,
                                                          color: cat.tint,
                                                        ),
                                                      );
                                                    },
                                                  )
                                                : _buildCategoryPlaceholder(cat),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          cat.name,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF2C160E),
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],

                // Regional Kitchens Horizontal Strip (Dynamic /consumer/product-regions API)
                if (appState.productRegions.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.explore_outlined,
                              size: 16, color: Color(0xFF003820)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Regional Kitchens',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C160E),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Regional Chips (from /consumer/product-regions API)
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 38,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: appState.productRegions.length,
                        itemBuilder: (context, index) {
                          final ProductRegion reg =
                              appState.productRegions[index];
                          final isSel = activeRegion == reg.name;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedRegion = reg.name);
                              appState.fetchBestsellers(
                                  region: reg.name,
                                  tag: activeFilterTag,
                                  forceRefresh: true);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF003820)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF003820)
                                      : const Color(0xFFEBDDC9),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (reg.hasValidImage) ...[
                                    ClipOval(
                                      child: Image.network(
                                        reg.resolvedImageUrl!,
                                        width: 16,
                                        height: 16,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    reg.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSel
                                          ? Colors.white
                                          : const Color(0xFF2C160E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // Filter Strip (Dynamic /consumer/product-tags API)
                if (appState.productTags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(
                            'FILTER: ',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF796C62),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ...appState.productTags.map((ProductTag tag) {
                            final isSel = activeFilterTag == tag.name;
                            return GestureDetector(
                              onTap: () {
                                final nextTag = isSel ? null : tag.name;
                                setState(() {
                                  _selectedFilterTag = nextTag;
                                });
                                appState.fetchBestsellers(
                                    region: activeRegion,
                                    tag: nextTag,
                                    forceRefresh: true);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? const Color(0xFFFFEDE8)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFFF57C00)
                                        : const Color(0xFFEBDDC9),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (tag.hasValidImage) ...[
                                      ClipOval(
                                        child: Image.network(
                                          tag.imageUrl!,
                                          width: 14,
                                          height: 14,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ] else if (tag.icon != null &&
                                        tag.icon!.trim().isNotEmpty) ...[
                                      Text(
                                        tag.icon!.trim(),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      tag.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: isSel
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSel
                                            ? const Color(0xFFF57C00)
                                            : const Color(0xFF2C160E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),

                // Community Bestsellers Section (Dynamic /consumer/products API)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.stars_rounded,
                                  size: 18, color: Color(0xFFF57C00)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Community Bestsellers',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF2C160E),
                                      ),
                                    ),
                                    Text(
                                      'Top-rated homemade pantry must-haves',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.lora(
                                        fontSize: 11,
                                        color: const Color(0xFF796C62),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (appState.isLoadingBestsellers ||
                            !appState.hasLoadedBestsellers)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFF57C00),
                            ),
                          )
                        else if (appState.dietFilteredBestsellers.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDE8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${appState.dietFilteredBestsellers.length} Items',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF964900),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Bestsellers Grid / Loading Placeholder / Empty State
                if ((appState.isLoadingBestsellers ||
                        !appState.hasLoadedBestsellers) &&
                    appState.dietFilteredBestsellers.isEmpty)
                  ProductGridSkeleton.sliver(context: context, itemCount: 4)
                else if (appState.dietFilteredBestsellers.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEBDDC9)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2C160E)
                                .withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEDE8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.storefront_outlined,
                              color: Color(0xFFF57C00),
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            activeRegion != null
                                ? 'No best sellers available for $activeRegion'
                                : 'No products available currently',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2C160E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activeRegion != null
                                ? 'We are curating authentic home-cooked delicacies for $activeRegion. Please explore our other regional kitchens.'
                                : 'Please check back soon as our home kitchens prepare fresh batches.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lora(
                              fontSize: 12,
                              color: const Color(0xFF796C62),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 900
                                ? 4
                                : MediaQuery.of(context).size.width > 600
                                    ? 3
                                    : 2,
                        childAspectRatio:
                            MediaQuery.of(context).size.width > 600
                                ? 0.72
                                : 0.64,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product =
                              appState.dietFilteredBestsellers[index];
                          return ProductCard(
                            product: product,
                            appState: appState,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailScreen(product: product),
                                ),
                              );
                            },
                          );
                        },
                        childCount: appState.dietFilteredBestsellers.length,
                      ),
                    ),
                  ),

                // Dynamic Offers & Deals Section (GET /consumer/offers)
                if (appState.isLoadingOffers || appState.offers.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: DynamicOffersSection(
                        offers: appState.offers,
                        isLoading: appState.isLoadingOffers,
                        onApplyCode: (code) {
                          requireAuth(context, onAuthenticated: () async {
                            final res = await appState.applyCoupon(code);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                backgroundColor: res.success
                                    ? const Color(0xFF003820)
                                    : Colors.orange.shade800,
                                content: Text(
                                  res.message,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: Colors.white),
                                ),
                              ),
                            );
                          });
                        },
                      ),
                    ),
                  ),

                // 4 Trust Feature Cards (matching Stitch)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildTrustCard(
                                icon: Icons.verified_user_outlined,
                                title: '100% Traditional',
                                desc: 'Real grandmother methods & recipes',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTrustCard(
                                icon: Icons.water_drop_outlined,
                                title: 'Cold-Pressed Oils',
                                desc: 'Sesame, groundnut & mustard only',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTrustCard(
                                icon: Icons.eco_outlined,
                                title: 'Zero Chemicals',
                                desc: 'Naturally preserved by salt & sun',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildTrustCard(
                                icon: Icons.local_shipping_outlined,
                                title: 'Fast Dispatch',
                                desc: 'Safe, sealed glass-safe packaging',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(height: appState.hasCart ? 120 : 24),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustCard({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBDDC9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF003820)),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2C160E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: GoogleFonts.lora(
              fontSize: 10.5,
              color: const Color(0xFF796C62),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationSelector(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderCard,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Delivery Location',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    children: [
                      // Current GPS Location Option
                      InkWell(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Detecting current GPS location...',
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              backgroundColor: AppColors.textPrimary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          await appState.detectAndApplyLocation(forceGps: true);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: !appState.isManualAddressSelected
                                ? AppColors.leafGreen.withValues(alpha: 0.08)
                                : AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: !appState.isManualAddressSelected
                                  ? AppColors.leafGreen
                                  : AppColors.borderCard,
                              width: !appState.isManualAddressSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.leafGreen
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.my_location_rounded,
                                  color: AppColors.leafGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Use Current Location',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (appState.isDetectingLocation) ...[
                                          const SizedBox(width: 6),
                                          const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.leafGreen,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Auto-detects saved address (< 1 km) or GPS coordinates',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!appState.isManualAddressSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.leafGreen,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Saved Addresses Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SAVED ADDRESSES',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AddressScreen(isSelectMode: true),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                'Manage',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.pickleOrange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (appState.addresses.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.location_off_outlined,
                                  color: AppColors.textTertiary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No saved addresses yet',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AddressEditScreen(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  '+ Add',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.leafGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        ...appState.addresses.map((addr) {
                          final isSelected = appState.isManualAddressSelected &&
                              appState.activeDeliveryAddress?.id == addr.id;
                          final isNear = appState.isNearSavedAddress &&
                              appState.nearestSavedAddress?.id == addr.id;
                          final distance = appState.getDistanceToAddress(addr);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () {
                                appState.setSelectedAddress(addr);
                                Navigator.of(ctx).pop();
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isSelected || isNear)
                                      ? AppColors.leafGreen
                                          .withValues(alpha: 0.06)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (isSelected || isNear)
                                        ? AppColors.leafGreen
                                        : AppColors.borderCard,
                                    width: (isSelected || isNear) ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainer,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        addr.label == 'Home'
                                            ? Icons.home_outlined
                                            : (addr.label == 'Work'
                                                ? Icons.work_outline
                                                : Icons.location_on_outlined),
                                        size: 18,
                                        color: AppColors.orangeDark,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                addr.label,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              if (distance != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: distance < 1000
                                                        ? AppColors.leafGreen
                                                            .withValues(
                                                                alpha: 0.12)
                                                        : AppColors
                                                            .surfaceContainer,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            999),
                                                    border: Border.all(
                                                      color: distance < 1000
                                                          ? AppColors.leafGreen
                                                              .withValues(
                                                                  alpha: 0.3)
                                                          : AppColors
                                                              .borderCard,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        distance < 1000
                                                            ? Icons
                                                                .near_me_rounded
                                                            : Icons
                                                                .place_outlined,
                                                        size: 10,
                                                        color: distance < 1000
                                                            ? AppColors
                                                                .leafGreen
                                                            : AppColors
                                                                .textSecondary,
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        distance < 1000
                                                            ? 'Within 1 km (${distance.round()}m)'
                                                            : '${(distance / 1000).toStringAsFixed(1)} km',
                                                        style:
                                                            GoogleFonts.poppins(
                                                          fontSize: 9.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: distance < 1000
                                                              ? AppColors
                                                                  .leafGreen
                                                              : AppColors
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            addr.fullAddress,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected || isNear) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.leafGreen,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],

                      const SizedBox(height: 12),

                      // Add New Address Button
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddressEditScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Add New Address',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.leafGreen,
                          side: const BorderSide(color: AppColors.leafGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryPlaceholder(CategoryItem cat) {
    if (cat.assetImage != null && cat.assetImage!.isNotEmpty) {
      return Image.asset(
        cat.assetImage!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(cat.icon, size: 26, color: cat.color),
        ),
      );
    }
    return Center(
      child: Icon(
        cat.icon,
        size: 26,
        color: cat.color,
      ),
    );
  }
}

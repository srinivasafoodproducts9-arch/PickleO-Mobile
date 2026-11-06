import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/category.dart';
import '../models/product_region.dart';
import '../state/app_state.dart';
import '../utils/responsive.dart';
import 'category_listing_screen.dart';

class ProductsCatalogScreen extends StatefulWidget {
  final bool isTab;

  const ProductsCatalogScreen({super.key, this.isTab = true});

  @override
  State<ProductsCatalogScreen> createState() => _ProductsCatalogScreenState();
}

class _ProductsCatalogScreenState extends State<ProductsCatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        if (!appState.hasLoadedCategories && !appState.isLoadingCategories) {
          appState.fetchCategories();
        }
        if (!appState.hasLoadedProductRegions &&
            !appState.isLoadingProductRegions) {
          appState.fetchProductRegions();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final categories = appState.categories;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.isTab
          ? null
          : AppBar(
              backgroundColor: AppColors.surface,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Categories',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.pickleOrange,
          onRefresh: () async {
            await Future.wait([
              appState.fetchCategories(forceRefresh: true),
              appState.fetchProductRegions(forceRefresh: true),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 12, 16, appState.hasCart ? 120 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Shop by Category',
                        style: GoogleFonts.lora(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (appState.isLoadingCategories) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.pickleOrange,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  categories.isNotEmpty
                      ? '${categories.length} traditional shelves, every jar made by hand'
                      : 'Explore our authentic artisanal shelves',
                  style: GoogleFonts.lora(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

              // 3x3 Grid of Categories
              if (categories.isEmpty && !appState.isLoadingCategories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No categories available',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.gridColumns(
                      context,
                      phone: 3,
                      tabletPortrait: 4,
                      tabletLandscape: 6,
                      largeScreen: 6,
                    ),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: categories.length,
                itemBuilder: (context, index) {
                  final CategoryItem cat = categories[index];
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderCard),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F5D4037),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: cat.tint,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.borderCard.withValues(alpha: 0.6),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: (cat.assetImage != null && cat.assetImage!.isNotEmpty)
                                      ? Image.asset(
                                          cat.assetImage!,
                                          fit: BoxFit.contain,
                                        )
                                      : (cat.hasValidImage
                                          ? Image.network(
                                              cat.resolvedImageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _buildCategoryPlaceholder(cat),
                                            )
                                          : _buildCategoryPlaceholder(cat)),
                                ),
                              ),
                              if (cat.badge.isNotEmpty)
                                Positioned(
                                  top: -4,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cat.badgeBg,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      cat.badge,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Regional Kitchens Section (only when regions exist)
              if (appState.productRegions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(Icons.explore_outlined,
                        size: 20, color: AppColors.orangeDark),
                    const SizedBox(width: 8),
                    Text(
                      'Regional Kitchens',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2-column Grid of Regional Kitchens
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.gridColumns(
                      context,
                      phone: 2,
                      tabletPortrait: 3,
                      tabletLandscape: 4,
                      largeScreen: 4,
                    ),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.1,
                  ),
                  itemCount: appState.productRegions.length,
                  itemBuilder: (context, index) {
                    final ProductRegion reg = appState.productRegions[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CategoryListingScreen(
                              initialCategoryChip: 'All',
                              categoryTitle: reg.name
                                      .toLowerCase()
                                      .contains('kitchen')
                                  ? reg.name
                                  : (reg.name.toLowerCase().contains('style')
                                      ? '${reg.name} Kitchens'
                                      : '${reg.name} Style Kitchens'),
                              categorySubtitle:
                                  '${reg.sub} and more traditional specialties from ${reg.name} Style homes',
                              region: reg.name,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderCard),
                        ),
                        child: Row(
                          children: [
                            if (reg.hasValidImage) ...[
                              ClipOval(
                                child: Image.network(
                                  reg.resolvedImageUrl!,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    reg.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    reg.sub,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 18, color: AppColors.orangeDark),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Festival Gift Hampers Card (only show if hamper/combo/gift category exists in live data)
              if (appState.categories.any((c) =>
                  c.name.toLowerCase().contains('hamper') ||
                  c.name.toLowerCase().contains('combo') ||
                  c.name.toLowerCase().contains('gift'))) ...[
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CategoryListingScreen(
                          initialCategoryChip: 'All',
                          categoryTitle: 'Festival Gift Hampers',
                          categorySubtitle:
                              'Curated 3-jar sets in a traditional jute basket',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33003820),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: AppColors.leafGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.card_giftcard,
                                size: 24, color: AppColors.onPrimaryContainer),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Festival Gift Hampers',
                                style: GoogleFonts.lora(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Curated 3-jar sets in a jute basket, from ₹699',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.outlineVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward,
                            size: 20, color: AppColors.onPrimaryContainer),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
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
      child: Icon(cat.icon, size: 26, color: cat.color),
    );
  }
}

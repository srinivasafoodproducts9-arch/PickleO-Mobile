import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';
import '../utils/auth_guard.dart';
import '../utils/responsive.dart';
import '../widgets/product_variant_bottom_sheet.dart';
import '../widgets/shimmer_loading.dart';

class CategoryListingScreen extends StatefulWidget {
  final String initialCategoryChip;
  final String categoryTitle;
  final String categorySubtitle;
  final String? category;
  final String? region;

  const CategoryListingScreen({
    super.key,
    this.initialCategoryChip = 'All',
    this.categoryTitle = 'Pickles & Achaar',
    this.categorySubtitle = 'Sun-cured in cold-pressed mustard & sesame oil',
    this.category,
    this.region,
  });

  @override
  State<CategoryListingScreen> createState() => _CategoryListingScreenState();
}

class _CategoryListingScreenState extends State<CategoryListingScreen> {
  late String _selectedChip;
  List<Product>? _apiProducts;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCategoryChip.isEmpty ||
        widget.initialCategoryChip == 'All Pickles' ||
        widget.initialCategoryChip == 'All') {
      _selectedChip = 'All';
    } else {
      _selectedChip = widget.initialCategoryChip;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchProducts();
      }
    });
  }

  Future<void> _fetchProducts({String? categoryOverride}) async {
    setState(() => _isLoading = true);
    final String? queryCategory = categoryOverride ??
        (widget.region != null
            ? (_selectedChip != 'All' ? _selectedChip : null)
            : widget.category);

    String? dietMark;
    if (mounted) {
      try {
        dietMark = AppStateProvider.of(context).resolvedDietMark;
      } catch (_) {
        dietMark = null;
      }
    }

    final res = await AuthService().getProducts(
      category: queryCategory,
      region: widget.region,
      dietMark: dietMark,
      limit: 50,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res.success && res.data != null) {
          _apiProducts = res.data!.items;
        } else {
          _apiProducts = [];
        }
      });
    }
  }

  List<String> _getCategoryChips(AppState appState) {
    final List<String> categories = appState.categories
        .map((c) => c.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (categories.isEmpty) return const [];
    final chips = <String>['All'];
    for (final cat in categories) {
      if (!chips.contains(cat)) {
        chips.add(cat);
      }
    }
    return chips;
  }

  bool _productMatchesCategory(Product product, String categoryChip) {
    if (categoryChip == 'All') return true;

    final chipLower = categoryChip.toLowerCase().trim();
    final pCatName = product.categoryName.toLowerCase().trim();
    final pCatId = product.categoryId.toLowerCase().trim();
    final pName = product.name.toLowerCase().trim();
    final pTags = product.tags.map((t) => t.toLowerCase().trim()).toList();

    // 1. Direct equality
    if (pCatName == chipLower || pCatId == chipLower) return true;

    // 2. Substring matching
    if (pCatName.isNotEmpty &&
        (chipLower.contains(pCatName) || pCatName.contains(chipLower))) {
      return true;
    }

    // 3. Category keyword semantic matching
    // Pickles & Achaar
    if (chipLower.contains('pickle') || chipLower.contains('achaar')) {
      if (pCatId.contains('pickle') ||
          pCatName.contains('pickle') ||
          pCatName.contains('achaar') ||
          pCatName.contains('avakaya') ||
          pName.contains('pickle') ||
          pName.contains('achaar') ||
          pName.contains('avakaya') ||
          pTags.any((t) =>
              t.contains('pickle') ||
              t.contains('achaar') ||
              t.contains('avakaya'))) {
        return true;
      }
    }

    // Chutneys & Pachadi
    if (chipLower.contains('chutney') || chipLower.contains('pachadi')) {
      if (pCatId.contains('chutney') ||
          pCatName.contains('chutney') ||
          pCatName.contains('pachadi') ||
          pName.contains('chutney') ||
          pName.contains('pachadi') ||
          pTags.any((t) => t.contains('chutney') || t.contains('pachadi'))) {
        return true;
      }
    }

    // Podis & Powders
    if (chipLower.contains('podi') || chipLower.contains('powder')) {
      if (pCatId.contains('podi') ||
          pCatName.contains('podi') ||
          pCatName.contains('powder') ||
          pCatName.contains('karam') ||
          pName.contains('podi') ||
          pName.contains('powder') ||
          pName.contains('karampodi') ||
          pTags.any((t) =>
              t.contains('podi') ||
              t.contains('powder') ||
              t.contains('karampodi'))) {
        return true;
      }
    }

    // Snacks & Murukku
    if (chipLower.contains('snack') ||
        chipLower.contains('murukku') ||
        chipLower.contains('namkeen')) {
      if (pCatId.contains('snack') ||
          pCatName.contains('snack') ||
          pCatName.contains('murukku') ||
          pCatName.contains('namkeen') ||
          pName.contains('murukku') ||
          pName.contains('snack') ||
          pName.contains('namkeen') ||
          pTags.any((t) =>
              t.contains('snack') ||
              t.contains('murukku') ||
              t.contains('namkeen'))) {
        return true;
      }
    }

    // Spices & Masalas
    if (chipLower.contains('spice') || chipLower.contains('masala')) {
      if (pCatId.contains('spice') ||
          pCatName.contains('spice') ||
          pCatName.contains('masala') ||
          pCatName.contains('chilli') ||
          pName.contains('spice') ||
          pName.contains('masala') ||
          pName.contains('chilli') ||
          pTags.any((t) => t.contains('spice') || t.contains('masala'))) {
        return true;
      }
    }

    // Sweets & Mithai
    if (chipLower.contains('sweet') || chipLower.contains('mithai')) {
      if (pCatId.contains('sweet') ||
          pCatName.contains('sweet') ||
          pCatName.contains('mithai') ||
          pCatName.contains('laddu') ||
          pName.contains('sweet') ||
          pName.contains('laddu') ||
          pName.contains('sunnundalu') ||
          pTags.any((t) => t.contains('sweet') || t.contains('mithai'))) {
        return true;
      }
    }

    // Millets & Grains
    if (chipLower.contains('millet') || chipLower.contains('grain')) {
      if (pCatId.contains('millet') ||
          pCatName.contains('millet') ||
          pCatName.contains('ragi') ||
          pCatName.contains('jowar') ||
          pName.contains('millet') ||
          pName.contains('ragi') ||
          pTags.any((t) => t.contains('millet') || t.contains('ragi'))) {
        return true;
      }
    }

    // Ready to Eat
    if (chipLower.contains('ready')) {
      if (pCatId.contains('ready') ||
          pCatName.contains('ready') ||
          pName.contains('ready') ||
          pTags.any((t) => t.contains('ready'))) {
        return true;
      }
    }

    // Combos & Gifts
    if (chipLower.contains('combo') ||
        chipLower.contains('gift') ||
        chipLower.contains('hamper')) {
      if (pCatId.contains('combo') ||
          pCatName.contains('combo') ||
          pCatName.contains('gift') ||
          pName.contains('combo') ||
          pName.contains('gift') ||
          pName.contains('hamper') ||
          pTags.any((t) =>
              t.contains('combo') ||
              t.contains('gift') ||
              t.contains('hamper'))) {
        return true;
      }
    }

    // 4. Tag or Name matches
    return pTags.any((t) => t.contains(chipLower)) || pName.contains(chipLower);
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final List<String> chips = _getCategoryChips(appState);

    // Products: strictly use API products without static catalog fallbacks
    final List<Product> baseProducts = _apiProducts ?? [];

    // Filter by selected category chip when browsing by region
    final List<Product> products = (widget.region != null && chips.isNotEmpty)
        ? ((_selectedChip == 'All' || _selectedChip.isEmpty)
            ? baseProducts
            : baseProducts
                .where((p) => _productMatchesCategory(p, _selectedChip))
                .toList())
        : baseProducts;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.categoryTitle,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: const [
          UserAvatar(radius: 16),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: appState.hasCart ? 120 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header Banner
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.pickleOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ARTISANAL PANTRY',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.categoryTitle,
                              style: GoogleFonts.lora(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.categorySubtitle,
                              style: GoogleFonts.lora(
                                fontStyle: FontStyle.italic,
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${products.length} ${products.length == 1 ? "Jar" : "Jars"}',
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

                // Horizontal Filter Chips (only when browsing by region and chips exist)
                if (widget.region != null && chips.length > 1) ...[
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: chips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final chip = chips[index];
                        final isSelected = chip == _selectedChip;

                        return GestureDetector(
                          onTap: () {
                            if (_selectedChip != chip) {
                              setState(() => _selectedChip = chip);
                              _fetchProducts(
                                  categoryOverride: chip == 'All' ? null : chip);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.leafGreen
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.leafGreen
                                    : AppColors.surfaceHighest,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              chip,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Sort & Spicy Pills
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.swap_vert,
                                size: 16, color: AppColors.textPrimary),
                            const SizedBox(width: 4),
                            Text(
                              'Sort: Bestsellers',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department,
                                size: 16, color: AppColors.chilliRed),
                            const SizedBox(width: 4),
                            Text(
                              'Traditional Spicy',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 2-Column Product Grid or Loading / Empty State
                if (_isLoading)
                  const ProductGridSkeleton(itemCount: 6)
                else if (products.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.inventory_2_outlined,
                              size: 48, color: AppColors.outline),
                          const SizedBox(height: 12),
                          Text(
                            'No products available in this section',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: Responsive.gridColumns(
                          context,
                          phone: 2,
                          tabletPortrait: 3,
                          tabletLandscape: 4,
                          largeScreen: 5,
                        ),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: Responsive.cardAspectRatio(
                          context,
                          phone: 0.55,
                          tabletPortrait: 0.62,
                          tabletLandscape: 0.56,
                        ),
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return _buildCatalogProductCard(
                            context, product, appState);
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // Know Your Maker Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceHighest,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.face_4_outlined,
                            size: 28, color: AppColors.orangeDark),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Know Your Maker',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orangeDark,
                              ),
                            ),
                            Text(
                              'Ammamma Satyavathi',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '“Our mangoes come straight from the orchards of Rajahmundry, pickled on the first sunny day.”',
                              style: GoogleFonts.lora(
                                fontStyle: FontStyle.italic,
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Sticky Cart Bar (Hidden until Cart API is integrated)
          // if (appState.hasCart)
          //   ...
        ],
      ),
    );
  }

  Widget _buildCatalogProductCard(
      BuildContext context, Product product, AppState appState) {
    final qty = appState.getProductQty(product.id);
    final inCart = qty > 0;
    final isWished = appState.isWishlisted(product.id);

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Container
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        productId: product.id,
                        product: product,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: 125,
                  width: double.infinity,
                  child: ProductImage(
                    product: product,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Veg / Non-veg Symbol (Top Left)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: product.isVeg
                          ? AppColors.leafGreen
                          : AppColors.chilliRed,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: product.isVeg
                            ? AppColors.leafGreen
                            : AppColors.chilliRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),

              // Wishlist Heart Button (Top Right)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    requireAuth(context, onAuthenticated: () {
                      appState.toggleWishlist(product.id, product: product);
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      isWished ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                      color: isWished
                          ? AppColors.chilliRed
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),

              // Batch Badge (Bottom Left)
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.batchTag,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showProductRatings) ...[
                    // Star Rating
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 14, color: AppColors.spiceYellow),
                        const SizedBox(width: 3),
                        Text(
                          '${product.rating}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (showProductReviews) ...[
                          const SizedBox(width: 2),
                          Text(
                            '(${product.reviewsDisplay})',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Name
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(productId: product.id),
                        ),
                      );
                    },
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Maker
                  Text(
                    product.maker,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Weight & Chillies
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.defaultVariant.displayLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        product.chillies,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Price Row
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹${product.defaultVariant.price.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (product.defaultVariant.mrp >
                            product.defaultVariant.price) ...[
                          const SizedBox(width: 4),
                          Text(
                            '₹${product.defaultVariant.mrp.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.outline,
                            ),
                          ),
                        ],
                        if (product.defaultVariant.hasDiscount) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${product.defaultVariant.discountPercent}% OFF',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.orangeDark,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Add Button / Quantity Stepper / Options Button
                  if (product.hasMultipleVariants)
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () {
                          ProductVariantBottomSheet.show(context,
                              product: product);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFE21A5E), width: 1.5),
                          backgroundColor: const Color(0xFFFFF0F5),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              inCart ? 'ADD · $qty' : 'ADD',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE21A5E),
                                height: 1.1,
                              ),
                            ),
                            Text(
                              '${product.variants.length} options',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF555555),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (!inCart)
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton(
                        onPressed: () {
                          requireAuth(context, onAuthenticated: () async {
                            final res = await appState.addToCart(
                              product,
                              product.defaultVariant.displayLabel,
                              variant: product.defaultVariant,
                            );
                            if (!context.mounted) return;
                            if (res != null && !res.success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res.message ?? 'Failed to add item to cart'),
                                  backgroundColor: AppColors.chilliRed,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '${product.name.split(' ').take(2).join(' ')} added to cart'),
                                  backgroundColor: AppColors.textPrimary,
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFE21A5E), width: 1.5),
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'ADD',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE21A5E),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFE21A5E), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove,
                                size: 16, color: Color(0xFFE21A5E)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            onPressed: () {
                              requireAuth(context, onAuthenticated: () async {
                                final itemKey =
                                    '${product.id}_${product.defaultVariant.id}';
                                final res = await appState.updateQuantity(itemKey, -1);
                                if (!context.mounted) return;
                                if (res != null && !res.success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message ?? 'Failed to update quantity'),
                                      backgroundColor: AppColors.chilliRed,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                          Text(
                            '$qty',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE21A5E),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add,
                                size: 16, color: Color(0xFFE21A5E)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            onPressed: () {
                              requireAuth(context, onAuthenticated: () async {
                                final itemKey =
                                    '${product.id}_${product.defaultVariant.id}';
                                final res = await appState.updateQuantity(itemKey, 1);
                                if (!context.mounted) return;
                                if (res != null && !res.success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message ?? 'Failed to update quantity'),
                                      backgroundColor: AppColors.chilliRed,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension ProductFilterExtension on List<Product> {
  List<Product> filterProducts(String chip) {
    if (chip == 'All Pickles') {
      return this;
    }
    return where((p) {
      final matchCat = p.categoryName.toLowerCase() == chip.toLowerCase();
      final matchName = p.name.toLowerCase().contains(chip.toLowerCase());
      final matchTags = p.tags.any((t) => t.toLowerCase() == chip.toLowerCase());
      return matchCat || matchName || matchTags;
    }).toList();
  }
}

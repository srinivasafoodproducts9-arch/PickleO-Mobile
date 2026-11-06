import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../services/auth_service.dart';
import '../widgets/product_image.dart';
import 'product_detail_screen.dart';
import '../utils/auth_guard.dart';
import '../widgets/product_variant_bottom_sheet.dart';

class SearchScreen extends StatefulWidget {
  final bool isTab;
  final VoidCallback? onNavigateHome;

  const SearchScreen({super.key, this.isTab = true, this.onNavigateHome});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;
  List<Product>? _apiResults;
  bool _isSearching = false;
  bool _vegOn = false;
  bool _nonVegOn = false;

  void _saveSearch(String text) {
    final q = text.trim();
    if (q.isNotEmpty && mounted) {
      AppStateProvider.of(context).addRecentSearch(q);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _resolveDietMark() {
    if (_vegOn && _nonVegOn) return 'Vegetarian,Non-vegetarian';
    if (_vegOn) return 'Vegetarian';
    if (_nonVegOn) return 'Non-vegetarian';
    return null;
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    final q = text.trim();
    final dietMark = _resolveDietMark();
    if (q.isEmpty && dietMark == null) {
      setState(() {
        _apiResults = null;
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final res = await AuthService().getProducts(
        search: q.isNotEmpty ? q : null,
        dietMark: dietMark,
        limit: 30,
      );
      if (mounted) {
        setState(() {
          _isSearching = false;
          if (res.success && res.data != null) {
            _apiResults = res.data!.items;
          } else {
            _apiResults = [];
          }
        });
        if (q.length >= 2) {
          _saveSearch(q);
        }
      }
    });
  }

  void _applyQuery(String q) {
    _searchController.text = q;
    _onSearchChanged(q);
    _saveSearch(q);
  }

  void _openProductDetail(Product product) {
    final q = _searchController.text.trim();
    if (q.isNotEmpty) {
      _saveSearch(q);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: product.id,
          product: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final dietNote = _vegOn && _nonVegOn
        ? 'Veg & non-veg'
        : (_vegOn
            ? 'Veg only'
            : (_nonVegOn ? 'Non-veg only' : 'Showing all jars'));

    final rawResults = _apiResults ?? <Product>[];

    final results = rawResults.where((p) {
      if (!_vegOn && !_nonVegOn) return true;
      if (_vegOn && _nonVegOn) return true;
      if (_vegOn) return p.isVeg;
      if (_nonVegOn) return !p.isVeg;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: AppColors.textPrimary),
          onPressed: () {
            if (widget.onNavigateHome != null) {
              widget.onNavigateHome!();
            } else if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          'Search',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 4, 16, appState.hasCart ? 120 : 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Search Input Box with Leaf Green Border
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.leafGreen, width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      size: 22, color: AppColors.leafGreen),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search pickles, snacks, spices…',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (val) => _saveSearch(val),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  if (hasQuery)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: const Icon(Icons.close,
                          size: 20, color: AppColors.outline),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Diet Toggles Row (Veg / Non-Veg Pills)
            Row(
              children: [
                // Veg Pill
                GestureDetector(
                  onTap: () {
                    setState(() => _vegOn = !_vegOn);
                    _onSearchChanged(_searchController.text);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _vegOn ? const Color(0xFF0F5132) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _vegOn ? const Color(0xFF0F5132) : const Color(0xFFFFDBD0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _vegOn ? Colors.white : const Color(0xFF0F5132),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Veg',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _vegOn ? Colors.white : const Color(0xFF2C160E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Non-Veg Pill
                GestureDetector(
                  onTap: () {
                    setState(() => _nonVegOn = !_nonVegOn);
                    _onSearchChanged(_searchController.text);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _nonVegOn ? const Color(0xFFC0392B) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _nonVegOn ? const Color(0xFFC0392B) : const Color(0xFFFFDBD0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _nonVegOn ? Colors.white : const Color(0xFFC0392B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Non-Veg',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _nonVegOn ? Colors.white : const Color(0xFF2C160E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dietNote,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!hasQuery) ...[
              if (appState.recentSearches.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent searches',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => appState.clearRecentSearches(),
                      child: Text(
                        'Clear all',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: appState.recentSearches.map((term) {
                    return Container(
                      height: 36,
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.surfaceHighest),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _applyQuery(term),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history,
                                    size: 16, color: AppColors.outline),
                                const SizedBox(width: 6),
                                Text(
                                  term,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => appState.removeRecentSearch(term),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.outline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5EFEB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search,
                            size: 28,
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Search for authentic pickles, powders & snacks',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Type above to see matching regional specialties',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            color: AppColors.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else ...[
              // Results Header
              Text(
                '${results.length} result${results.length == 1 ? '' : 's'} for “${_searchController.text}”',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No jars match “${_searchController.text}”. Try “mango” or “pickle”.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = results[index];
                    final qty = appState.getProductQty(product.id);
                    final inCart = qty > 0;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _openProductDetail(product),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: ProductImage(
                                product: product,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _openProductDetail(product),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(
                                            color: product.isVeg
                                                ? const Color(0xFF0F5132)
                                                : const Color(0xFFC0392B),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: product.isVeg
                                              ? const Color(0xFF0F5132)
                                              : const Color(0xFFC0392B),
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          '${product.kitchen} · ${product.defaultVariant.displayLabel}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '₹${product.defaultVariant.price.toInt()}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (product.defaultVariant.mrp >
                                          product.defaultVariant.price) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '₹${product.defaultVariant.mrp.toInt()}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: AppColors.outline,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (product.hasMultipleVariants)
                            SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () {
                                  final q = _searchController.text.trim();
                                  if (q.isNotEmpty) {
                                    _saveSearch(q);
                                  }
                                  ProductVariantBottomSheet.show(context,
                                      product: product);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: Color(0xFFE21A5E), width: 1.5),
                                  backgroundColor: const Color(0xFFFFF0F5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 2),
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
                          else
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () {
                                  requireAuth(context, onAuthenticated: () async {
                                    final q = _searchController.text.trim();
                                    if (q.isNotEmpty) {
                                      _saveSearch(q);
                                    }
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
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              '${product.name.split(' ').take(2).join(' ')} added to cart'),
                                          backgroundColor: AppColors.textPrimary,
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE21A5E),
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  inCart ? 'Added · $qty' : 'ADD',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    ),
  ),
);
}
}

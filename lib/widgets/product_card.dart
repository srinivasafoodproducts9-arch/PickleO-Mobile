import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import 'product_image.dart';
import '../utils/auth_guard.dart';
import '../theme/app_theme.dart';
import 'product_variant_bottom_sheet.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  final AppState appState;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final isFav = appState.isFavorite(product.id);
    final defaultVariant = product.defaultVariant;
    final defaultWeight = defaultVariant.displayLabel;
    final itemKey = '${product.id}_${defaultVariant.id}';
    final cartItem = appState.cartItems[itemKey];
    final hasMultipleVariants = product.hasMultipleVariants;
    final totalQty = appState.getProductQty(product.id);
    final inCart = hasMultipleVariants ? totalQty > 0 : (cartItem != null && cartItem.quantity > 0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0E4D7), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5D4037).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Container with badges
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 1.12,
                    child: ProductImage(
                      product: product,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Top Left: Veg Mark & Weight Pill
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(
                    children: [
                      // Veg Indicator
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: product.isVeg
                                ? Colors.green.shade800
                                : const Color(0xFFC0392B),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.circle,
                          size: 7,
                          color: product.isVeg
                              ? Colors.green.shade800
                              : const Color(0xFFC0392B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Weight badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          defaultWeight,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Top Right: Favorite Heart
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        requireAuth(context, onAuthenticated: () {
                          appState.toggleFavorite(product.id, product: product);
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFav
                              ? const Color(0xFFC0392B)
                              : const Color(0xFF5D4037),
                        ),
                      ),
                    ),
                  ),
                ),

                // Batch Tag / Badge pill near bottom of image
                if ((product.badge?.trim().isNotEmpty == true) ||
                    product.batchTag.trim().isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1ED).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFBD1C4), width: 1),
                      ),
                      child: Text(
                        (product.badge?.trim().isNotEmpty == true)
                            ? product.badge!
                            : product.batchTag,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF964900),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Card Body Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showProductRatings) ...[
                          // Rating Pill
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star,
                                        size: 12, color: Color(0xFFF4C430)),
                                    const SizedBox(width: 3),
                                    Text(
                                      product.rating.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF2C160E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (showProductReviews) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '(${product.reviewCount})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(0xFF796C62),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Kitchen Origin
                        Text(
                          product.kitchen,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF796C62),
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Product Title
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2C160E),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),

                    // Price and Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price Block
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      '₹${defaultVariant.price.toInt()}',
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF003820),
                                      ),
                                    ),
                                  ),
                                  if (defaultVariant.mrp > defaultVariant.price) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '₹${defaultVariant.mrp.toInt()}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        decoration: TextDecoration.lineThrough,
                                        color: const Color(0xFF796C62),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (defaultVariant.hasDiscount)
                                Text(
                                  '${defaultVariant.discountPercent}% OFF',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF964900),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Action Button: Multiple Options vs Single Variant
                        if (hasMultipleVariants)
                          InkWell(
                            onTap: () {
                              ProductVariantBottomSheet.show(context,
                                  product: product);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(0xFFE21A5E), width: 1.5),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    inCart ? 'ADD · $totalQty' : 'ADD',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFE21A5E),
                                      height: 1.1,
                                    ),
                                  ),
                                  Text(
                                    '${product.variants.length} options',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
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
                          InkWell(
                            onTap: () {
                              requireAuth(context, onAuthenticated: () async {
                                final res = await appState.addToCart(
                                  product,
                                  defaultWeight,
                                  variant: defaultVariant,
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
                                      content:
                                          Text('Added ${product.name} to cart!'),
                                      backgroundColor: const Color(0xFF0F5132),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFE21A5E), width: 1.5),
                              ),
                              child: Text(
                                'ADD',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFE21A5E),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF0F5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFE21A5E), width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    requireAuth(context, onAuthenticated: () async {
                                      final res = await appState.updateQuantity(itemKey, -1);
                                      if (!context.mounted) return;
                                      if (res != null && !res.success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res.message ?? 'Failed to update quantity'),
                                            backgroundColor: AppColors.chilliRed,
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    child: Icon(Icons.remove,
                                        size: 14, color: Color(0xFFE21A5E)),
                                  ),
                                ),
                                Text(
                                  '${cartItem?.quantity ?? totalQty}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE21A5E),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    requireAuth(context, onAuthenticated: () async {
                                      final res = await appState.updateQuantity(itemKey, 1);
                                      if (!context.mounted) return;
                                      if (res != null && !res.success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res.message ?? 'Failed to update quantity'),
                                            backgroundColor: AppColors.chilliRed,
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 4),
                                    child: Icon(Icons.add,
                                        size: 14, color: Color(0xFFE21A5E)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

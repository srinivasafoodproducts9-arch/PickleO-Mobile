import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'product_image.dart';

class ProductVariantBottomSheet extends StatelessWidget {
  final Product product;

  const ProductVariantBottomSheet({
    super.key,
    required this.product,
  });

  static Future<void> show(
    BuildContext context, {
    required Product product,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProductVariantBottomSheet(product: product),
    );
  }

  static const Color accentPink = Color(0xFFE21A5E);
  static const Color accentGreen = Color(0xFF00A368);

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final variants = product.variants.isNotEmpty
        ? product.variants
        : [product.defaultVariant];

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular close button centered above modal
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E).withValues(alpha: 0.85),
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          // Main White Modal Container
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                // Product Title Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1E2022),
                                height: 1.25,
                              ),
                            ),
                            if (product.kitchen.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                product.kitchen,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF757575),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF9E9E9E)),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F0)),

                // Variants List
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    shrinkWrap: true,
                    itemCount: variants.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final variant = variants[index];
                      final qty = appState.getVariantQty(
                        product.id,
                        variant.id,
                        variant.displayLabel,
                      );
                      final saveBadge = variant.saveBadgeText;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Thumbnail Image
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF0F0F0),
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: ProductImage(
                                    product: product,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Variant Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        variant.displayLabel,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF2C160E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '₹${variant.price.toInt()}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E2022),
                                            ),
                                          ),
                                          if (variant.mrp > variant.price) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              '₹${variant.mrp.toInt()}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11.5,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                                color: const Color(0xFF9E9E9E),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (variant.unitPriceText != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          variant.unitPriceText!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: accentGreen,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Action Button: ADD or Stepper
                                if (qty == 0)
                                  InkWell(
                                    onTap: () async {
                                      final res = await appState.addToCart(
                                        product,
                                        variant.displayLabel,
                                        variant: variant,
                                        qty: 1,
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
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 80,
                                        minHeight: 36,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: accentPink,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'ADD',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: accentPink,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0F5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: accentPink,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        InkWell(
                                          onTap: () async {
                                            final res = await appState.updateVariantQuantity(
                                              product.id,
                                              variant.id,
                                              -1,
                                              weight: variant.displayLabel,
                                            );
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
                                          },
                                          borderRadius: const BorderRadius.horizontal(
                                            left: Radius.circular(8),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            child: Icon(
                                              Icons.remove,
                                              size: 15,
                                              color: accentPink,
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Text(
                                            '$qty',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: accentPink,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () async {
                                            final res = await appState.updateVariantQuantity(
                                              product.id,
                                              variant.id,
                                              1,
                                              weight: variant.displayLabel,
                                            );
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
                                          },
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                            right: Radius.circular(8),
                                          ),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            child: Icon(
                                              Icons.add,
                                              size: 15,
                                              color: accentPink,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // Savings Tag Badge on Top Edge (Matching Screenshot 2)
                          if (saveBadge != null)
                            Positioned(
                              top: -10,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accentGreen,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x26000000),
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    saveBadge,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../state/app_state.dart';
import 'product_detail_screen.dart';
import 'products_catalog_screen.dart';
import 'cart_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/user_avatar.dart';
import '../widgets/product_variant_bottom_sheet.dart';
import '../utils/auth_guard.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final wishedProducts = appState.wishlistProductList;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Wishlist',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: AppColors.textPrimary),
                onPressed: () {
                  requireAuth(context, onAuthenticated: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  });
                },
              ),
              if (appState.cartCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.pickleOrange,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      '${appState.cartCount}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const UserAvatar(radius: 16),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.leafGreen,
        onRefresh: () async {
          if (appState.isLoggedIn) {
            await appState.loadWishlistFromApi();
          }
        },
        child: wishedProducts.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: const BoxDecoration(
                                color: AppColors.surfaceContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite,
                                size: 40,
                                color: AppColors.chilliRed,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nothing saved yet',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap the heart on any jar to keep it here',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ProductsCatalogScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.leafGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Browse Pickles',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (!appState.isLoggedIn) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: () => requireAuth(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.pickleOrange),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Sign In to Sync Wishlist',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.pickleOrange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${wishedProducts.length} ${wishedProducts.length == 1 ? 'item' : 'items'} saved',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _addAllWishlistToCart(
                              context, appState, wishedProducts),
                          icon: const Icon(Icons.add_shopping_cart,
                              size: 16, color: AppColors.pickleOrange),
                          label: Text(
                            'Add All to Cart',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.pickleOrange,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor:
                                AppColors.pickleOrange.withValues(alpha: 0.1),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: wishedProducts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                final product = wishedProducts[index];
                final qty = appState.getProductQty(product.id);
                final inCart = qty > 0;

                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: inCart
                          ? AppColors.pickleOrange.withValues(alpha: 0.5)
                          : AppColors.borderCard,
                      width: inCart ? 1.2 : 1.0,
                    ),
                    boxShadow: inCart
                        ? [
                            BoxShadow(
                              color: AppColors.pickleOrange
                                  .withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      // Thumbnail
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductDetailScreen(productId: product.id),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ProductImage(
                            product: product,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(productId: product.id),
                              ),
                            );
                          },
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
                              const SizedBox(height: 2),
                              Text(
                                '${product.maker} · ${product.defaultVariant.displayLabel}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
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
                                  const SizedBox(width: 6),
                                  if (product.defaultVariant.mrp > product.defaultVariant.price)
                                    Text(
                                      '₹${product.defaultVariant.mrp.toInt()}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                ],
                              ),
                              if (inCart) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.leafGreen
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.shopping_bag_outlined,
                                          size: 11,
                                          color: AppColors.leafGreen),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$qty in cart',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.leafGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Heart & Add / Stepper Button
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              requireAuth(context, onAuthenticated: () {
                                appState.toggleWishlist(product.id,
                                    product: product);
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.favorite,
                                size: 22,
                                color: AppColors.chilliRed,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!inCart)
                            if (product.hasMultipleVariants)
                              SizedBox(
                                height: 38,
                                child: OutlinedButton(
                                  onPressed: () {
                                    requireAuth(context, onAuthenticated: () {
                                      ProductVariantBottomSheet.show(context,
                                          product: product);
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFFF0F5),
                                    side: const BorderSide(
                                        color: Color(0xFFE91E63), width: 1.4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 2),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'ADD',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFE91E63),
                                          letterSpacing: 0.5,
                                          height: 1.1,
                                        ),
                                      ),
                                      Text(
                                        '${product.variants.length} options',
                                        style: GoogleFonts.poppins(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w500,
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
                                height: 34,
                                child: ElevatedButton(
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
                                            duration: const Duration(seconds: 1),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.pickleOrange,
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add,
                                          size: 14, color: Colors.white),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Add',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                          else
                            Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1ED),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: AppColors.pickleOrange,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    borderRadius:
                                        const BorderRadius.horizontal(
                                            left: Radius.circular(8)),
                                    onTap: () {
                                      requireAuth(context, onAuthenticated: () {
                                        appState.setProductQty(
                                            product, qty - 1);
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      child: Icon(Icons.remove,
                                          size: 14,
                                          color: AppColors.pickleOrange),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Text(
                                      '$qty',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.pickleOrange,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius:
                                        const BorderRadius.horizontal(
                                            right: Radius.circular(8)),
                                    onTap: () {
                                      requireAuth(context, onAuthenticated: () {
                                        appState.setProductQty(
                                            product, qty + 1);
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      child: Icon(Icons.add,
                                          size: 14,
                                          color: AppColors.pickleOrange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      ),
      bottomNavigationBar: appState.hasCart
          ? Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SafeArea(
                child: GestureDetector(
                  onTap: () {
                    requireAuth(context, onAuthenticated: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    });
                  },
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.pickleOrange,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pickleOrange.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            size: 20, color: Colors.white),
                        const SizedBox(width: 10),
                        Text(
                          '${appState.cartCount} ${appState.cartCount == 1 ? 'item' : 'items'} in cart',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'View Cart',
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  void _addAllWishlistToCart(BuildContext context, AppState appState, List<Product> wishedProducts) {
    requireAuth(context, onAuthenticated: () async {
      int addedCount = 0;
      String? lastError;
      for (final product in wishedProducts) {
        final variant = product.variants.isNotEmpty
            ? product.variants.first
            : product.defaultVariant;
        final res = await appState.addToCart(
          product,
          variant.displayLabel,
          variant: variant,
          qty: 1,
        );
        if (res == null || res.success) {
          addedCount++;
        } else {
          lastError = res.message;
        }
      }
      if (!context.mounted) return;
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount item(s) from wishlist added to cart'),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (lastError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lastError),
            backgroundColor: AppColors.chilliRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

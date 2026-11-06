import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/product.dart';
import '../models/delivery_estimate.dart';
import '../state/app_state.dart';
import '../widgets/product_image.dart';
import '../widgets/user_avatar.dart';
import '../widgets/product_card.dart';
import '../widgets/product_variant_bottom_sheet.dart';
import 'cart_screen.dart';
import '../utils/auth_guard.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  final Product? product;

  ProductDetailScreen({
    super.key,
    String? productId,
    this.product,
  }) : productId = productId ?? product?.id ?? 'avakaya';

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String _selectedWeight = '250g';
  ProductVariant? _selectedVariant;
  int _quantity = 1;
  int _selectedImageIndex = 0;
  String? _checkedPin;
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();

  List<Product>? _apiFbtProducts;
  List<Product>? _apiRelatedProducts;
  DeliveryEstimate? _deliveryEstimate;
  bool _isCheckingDelivery = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null && widget.product!.variants.isNotEmpty) {
      _selectedVariant = widget.product!.variants.first;
      _selectedWeight = _selectedVariant!.displayLabel;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCompanionProducts();
      _checkInitialDeliveryEstimate();
    });
  }

  void _checkInitialDeliveryEstimate() {
    if (!mounted) return;
    final appState = AppStateProvider.of(context);
    final initialPin = appState.defaultAddress.postalCode;
    if (initialPin.length == 6 && _deliveryEstimate == null) {
      final mult = _weightDetails[_selectedWeight]?['mult'] ?? 1.0;
      final sizedPrice = widget.product?.variants.isNotEmpty == true
          ? (_selectedVariant?.price.round() ?? widget.product!.basePrice.round())
          : (widget.product != null
              ? (widget.product!.basePrice * mult).round()
              : 499);
      appState
          .checkDeliveryEstimate(
        pinCode: initialPin,
        subtotal: sizedPrice,
      )
          .then((est) {
        if (mounted && est != null) {
          setState(() {
            _deliveryEstimate = est;
          });
        }
      });
    }
  }

  Future<void> _checkDeliveryEstimate(String pin, num subtotal) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 6) return;

    setState(() {
      _isCheckingDelivery = true;
    });

    final appState = AppStateProvider.of(context);
    final estimate = await appState.checkDeliveryEstimate(
      pinCode: cleanPin,
      subtotal: subtotal,
    );

    if (!mounted) return;

    setState(() {
      _checkedPin = cleanPin;
      _deliveryEstimate = estimate;
      _isCheckingDelivery = false;
    });

    final isServiceable =
        estimate?.serviceable ?? appState.isPinServiceable(cleanPin);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isServiceable
              ? 'Great! We deliver to $cleanPin'
              : "Sorry, $cleanPin isn't serviceable yet",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF2C160E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant ProductDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        oldWidget.product?.id != widget.product?.id) {
      _apiFbtProducts = null;
      _apiRelatedProducts = null;
      if (widget.product != null && widget.product!.variants.isNotEmpty) {
        _selectedVariant = widget.product!.variants.first;
        _selectedWeight = _selectedVariant!.displayLabel;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCompanionProducts();
      });
    }
  }

  Future<void> _loadCompanionProducts() async {
    if (!mounted) return;
    final appState = AppStateProvider.of(context);
    final product = widget.product ??
        appState.findProductById(widget.productId);
    if (product == null) return;

    final fbtIds = product.frequentlyBoughtTogether
        .where((id) => id.trim().isNotEmpty)
        .toList();
    final relIds = product.relatedProductIds
        .where((id) => id.trim().isNotEmpty)
        .toList();

    final allIdsToFetch = <String>{...fbtIds, ...relIds}.toList();
    if (allIdsToFetch.isEmpty) {
      if (mounted) {
        setState(() {
          _apiFbtProducts = [];
          _apiRelatedProducts = [];
        });
      }
      return;
    }

    try {
      final fetched = await appState.fetchProductDetails(allIdsToFetch);
      if (!mounted) return;

      Product? matchForId(String id) {
        final clean = id.trim().toLowerCase();
        for (final p in fetched) {
          if (p.id.toLowerCase() == clean) return p;
          if (p.catalogProductId != null &&
              p.catalogProductId!.toLowerCase() == clean) {
            return p;
          }
          if (p.variants.any((v) =>
              v.id.toLowerCase() == clean ||
              (v.sku.isNotEmpty && v.sku.toLowerCase() == clean))) {
            return p;
          }
        }
        return appState.findProductById(id);
      }

      final fbtList = <Product>[];
      for (final id in fbtIds) {
        final p = matchForId(id);
        if (p != null &&
            p.id != product.id &&
            !fbtList.any((x) => x.id == p.id)) {
          fbtList.add(p);
        }
      }

      final relList = <Product>[];
      for (final id in relIds) {
        final p = matchForId(id);
        if (p != null &&
            p.id != product.id &&
            p.isVeg == product.isVeg &&
            !relList.any((x) => x.id == p.id)) {
          relList.add(p);
        }
      }

      // If fetched items were returned from the backend API but could not match
      // via ID string comparison (e.g. backend returned generated IDs), distribute them
      // to fbtList and relList as long as they are distinct from the current product
      if (fbtList.isEmpty && fbtIds.isNotEmpty && fetched.isNotEmpty) {
        for (final p in fetched) {
          if (p.id != product.id && !fbtList.any((x) => x.id == p.id)) {
            fbtList.add(p);
            if (fbtList.length >= fbtIds.length) break;
          }
        }
      }

      if (relList.isEmpty && relIds.isNotEmpty && fetched.isNotEmpty) {
        for (final p in fetched) {
          if (p.id != product.id &&
              p.isVeg == product.isVeg &&
              !fbtList.any((x) => x.id == p.id) &&
              !relList.any((x) => x.id == p.id)) {
            relList.add(p);
            if (relList.length >= relIds.length) break;
          }
        }
      }

      setState(() {
        _apiFbtProducts = fbtList;
        _apiRelatedProducts = relList;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _apiFbtProducts = [];
          _apiRelatedProducts = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _pinFocusNode.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // Accordion states
  final Map<String, bool> _accordionOpen = {
    'heritage': true,
    'ingredients': false,
    'storage': false,
    'fssai': false,
  };

  final Map<String, Map<String, dynamic>> _weightDetails = {
    '250g': {'mult': 1.0, 'note': 'Daily Table', 'best': false},
    '500g': {'mult': 1.8, 'note': 'Popular', 'best': true},
    '1kg': {'mult': 3.4, 'note': 'Family Jar', 'best': false},
  };

  void _toggleAccordion(String key) {
    setState(() {
      _accordionOpen[key] = !(_accordionOpen[key] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final product = widget.product ??
        appState.findProductById(widget.productId);

    if (product == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Product'),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              Text(
                'Product not found',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'The product you are looking for is unavailable.',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final isWished = appState.isWishlisted(product.id);

    final List<ProductVariant> variants = product.variants.isNotEmpty
        ? product.variants
        : [product.defaultVariant];

    if (_selectedVariant == null ||
        !variants.any((v) => v.id == _selectedVariant!.id)) {
      _selectedVariant = variants.first;
      _selectedWeight = _selectedVariant!.displayLabel;
    }
    final activeVariant = _selectedVariant!;

    final mult = _weightDetails[_selectedWeight]?['mult'] ?? 1.0;
    final sizedPrice = product.variants.isNotEmpty
        ? activeVariant.price.round()
        : (product.basePrice * mult).round();
    final sizedMrp = product.variants.isNotEmpty
        ? (activeVariant.mrp > 0
            ? activeVariant.mrp.round()
            : (activeVariant.price * 1.15).round())
        : (product.originalPrice * mult).round();
    final discountPercent = product.variants.isNotEmpty
        ? activeVariant.discountPercent
        : (((sizedMrp - sizedPrice) / sizedMrp) * 100).round();

    // Build image list (product image + any additional media)
    final List<String?> mediaUrls = product.allImageUrls.isNotEmpty
        ? List<String?>.from(product.allImageUrls)
        : [
            product.resolvedImageUrl,
            ...product.mediaItems
                .where((m) =>
                    m['mediaType'] == 'image' &&
                    m['url'] != null &&
                    (m['url'] as String).startsWith('http'))
                .map((m) => m['url'] as String?),
          ];
    if (mediaUrls.isEmpty) {
      mediaUrls.add(null);
    }
    while (mediaUrls.length < 4) {
      mediaUrls.add(null);
    }

    // Frequently paired products (only populated from live API response, or fallback to catalog products)
    final List<Product> pairedProducts = [];
    if (_apiFbtProducts != null && _apiFbtProducts!.isNotEmpty) {
      pairedProducts.addAll(_apiFbtProducts!);
    } else if (product.frequentlyBoughtTogether.isNotEmpty) {
      for (final fbtId in product.frequentlyBoughtTogether) {
        final p = appState.findProductById(fbtId);
        if (p != null &&
            p.id != product.id &&
            !pairedProducts.any((x) => x.id == p.id)) {
          pairedProducts.add(p);
        }
      }
    }

    // Related products (filtered by same dietary preference: non-veg with non-veg, veg with veg)
    final List<Product> relatedProducts = [];
    if (_apiRelatedProducts != null && _apiRelatedProducts!.isNotEmpty) {
      relatedProducts.addAll(_apiRelatedProducts!.where((p) => p.isVeg == product.isVeg));
    } else if (product.relatedProductIds.isNotEmpty) {
      for (final relId in product.relatedProductIds) {
        final p = appState.findProductById(relId);
        if (p != null &&
            p.id != product.id &&
            p.isVeg == product.isVeg &&
            !relatedProducts.any((x) => x.id == p.id)) {
          relatedProducts.add(p);
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Product Details',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Cart icon with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_outlined,
                    color: AppColors.textPrimary, size: 22),
                onPressed: () {
                  _pinFocusNode.unfocus();
                  requireAuth(context, onAuthenticated: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  });
                },
              ),
              if (appState.cartCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.pickleOrange,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${appState.cartCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Top Badges Bar (Veg/Non-veg + 100% Homemade + Share + Wishlist)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: product.isVeg
                              ? AppColors.leafGreen
                              : AppColors.chilliRed,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: product.isVeg
                            ? AppColors.leafGreen
                            : AppColors.chilliRed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.leafGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '100% Homemade',
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
                Row(
                  children: [
                    _circleActionBtn(
                      icon: Icons.share_outlined,
                      onTap: () {
                        requireAuth(context, onAuthenticated: () {
                          _showShareSheet(context, product, sizedPrice);
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _circleActionBtn(
                      icon: isWished ? Icons.favorite : Icons.favorite_border,
                      iconColor: isWished ? AppColors.chilliRed : AppColors.textPrimary,
                      onTap: () {
                        requireAuth(context, onAuthenticated: () {
                          appState.toggleWishlist(product.id, product: product);
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Big Jar Hero Image
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _selectedImageIndex == 0
                        ? ProductImage(product: product, fit: BoxFit.cover)
                        : (mediaUrls[_selectedImageIndex] != null
                            ? Image.network(
                                mediaUrls[_selectedImageIndex]!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    ProductImage(product: product, fit: BoxFit.cover),
                              )
                            : ProductImage(product: product, fit: BoxFit.cover)),
                  ),
                  // Bottom Overlay Pills
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Row(
                      children: [
                        _overlayPill(
                          icon: Icons.local_fire_department,
                          iconColor: const Color(0xFFFF8A65),
                          label: product.spiceLabel,
                          bg: const Color(0xC02C160E),
                        ),
                        const SizedBox(width: 8),
                        if (product.zeroPreservatives || product.purityClaims.isNotEmpty)
                          _overlayPill(
                            icon: Icons.eco,
                            iconColor: Colors.white,
                            label: product.zeroPreservatives
                                ? 'Zero Preservatives'
                                : product.purityClaims.first,
                            bg: AppColors.leafGreen,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Thumbnail Media Strip
            SizedBox(
              height: 62,
              child: Row(
                children: List.generate(4, (i) {
                  final isSelected = _selectedImageIndex == i;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedImageIndex = i),
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.leafGreen
                              : AppColors.borderCard,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: i == 0
                          ? ProductImage(product: product, fit: BoxFit.cover)
                          : (mediaUrls.length > i && mediaUrls[i] != null
                              ? Image.network(mediaUrls[i]!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholderThumb(i))
                              : _placeholderThumb(i)),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            // Kitchen Origin
            Text(
              product.kitchen.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: AppColors.orangeDark,
              ),
            ),
            const SizedBox(height: 4),

            // Product Name
            Text(
              product.name,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Heirloom Subtitle in Lora Serif Italic
            Text(
              product.subtitle,
              style: GoogleFonts.lora(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            if (showProductRatings) ...[
              // Rating Stars Summary
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${product.rating}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.star,
                            size: 14, color: AppColors.textPrimary),
                      ],
                    ),
                  ),
                  if (showProductReviews) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${product.reviewsDisplay} ratings • ${product.reviewCount} reviews',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
            ],

            // Price Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          '₹$sizedPrice',
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orangeDark,
                          ),
                        ),
                        Text(
                          '₹$sizedMrp',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.outline,
                          ),
                        ),
                        Text(
                          '$discountPercent% OFF',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.pickleOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Incl. all taxes',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Interactive Pincode Serviceability Card (Matching Prototype)
            Builder(builder: (context) {
              final activePin = _checkedPin ?? appState.defaultAddress.postalCode;
              final estimate = _deliveryEstimate ?? appState.getCachedDeliveryEstimate(activePin);
              final isServiceable = estimate != null
                  ? estimate.serviceable
                  : appState.isPinServiceable(activePin);
              final isDefault = activePin == appState.defaultAddress.postalCode;
              final pinBg = isServiceable ? const Color(0xFFDFF3E6) : const Color(0xFFFFDAD6);
              final pinIconBg = isServiceable ? AppColors.leafGreen : const Color(0xFFC0392B);
              final pinIcon = isServiceable ? Icons.local_shipping_outlined : Icons.location_off_outlined;
              final pinTitleColor = isServiceable ? const Color(0xFF003820) : const Color(0xFF7A1F14);
              final pinSubColor = isServiceable ? AppColors.leafGreen : const Color(0xFFA3382A);

              final defaultPromise = (product.deliveryPromise != null &&
                      product.deliveryPromise!.trim().isNotEmpty &&
                      product.deliveryPromise != 'string')
                  ? product.deliveryPromise!.trim()
                  : 'with in 2 days';
              final pinTitle = isServiceable
                  ? ((estimate?.sla != null && estimate!.sla!.trim().isNotEmpty)
                      ? estimate.sla!.trim()
                      : defaultPromise)
                  : 'Not serviceable at PIN $activePin yet';

              String locationTag = '';
              final matchedAddress = appState.addresses
                  .where((a) => a.postalCode == activePin)
                  .firstOrNull;
              if (matchedAddress != null) {
                locationTag = ' - ${matchedAddress.label}, ${matchedAddress.city}';
              } else if (isDefault && appState.defaultAddress.city.isNotEmpty) {
                locationTag = ' - ${appState.defaultAddress.label}, ${appState.defaultAddress.city}';
              } else if (estimate?.city != null && estimate!.city!.isNotEmpty) {
                locationTag = ' - ${estimate.city}';
              }

              final deliveryCost = estimate?.deliveryChargeText ??
                  (product.freeDelivery ? 'free delivery' : 'free delivery');
              final pinSub = isServiceable
                  ? 'To PIN $activePin$locationTag · $deliveryCost'
                  : "We're adding new cities every month. Try another PIN or notify me.";

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: pinBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: pinIconBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(pinIcon, size: 20, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pinTitle,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: pinTitleColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pinSub,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: pinSubColor,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: _pinController,
                              focusNode: _pinFocusNode,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Check another PIN code',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textTertiary,
                                  letterSpacing: 0,
                                ),
                                counterText: '',
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: (_pinController.text.trim().length == 6 &&
                                  !_isCheckingDelivery)
                              ? () => _checkDeliveryEstimate(
                                    _pinController.text.trim(),
                                    sizedPrice,
                                  )
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF64665C),
                            disabledBackgroundColor:
                                const Color(0xFF64665C).withValues(alpha: 0.5),
                            foregroundColor: Colors.white,
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            minimumSize: const Size(0, 40),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isCheckingDelivery
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Check',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Select Jar Size
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    product.variants.isNotEmpty ? 'Select Option' : 'Select Jar Size',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${activeVariant.displayLabel} active',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.orangeDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Size / Variant Cards
            if (product.variants.isNotEmpty)
              variants.length <= 3
                  ? Row(
                      children: variants
                          .map((v) => Expanded(
                              child: _buildVariantCard(v, activeVariant)))
                          .toList(),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: variants
                            .map((v) => SizedBox(
                                width: 110,
                                child: _buildVariantCard(v, activeVariant)))
                            .toList(),
                      ),
                    )
            else
              Row(
                children: _weightDetails.keys.map((size) {
                  final info = _weightDetails[size]!;
                  final isSelected = _selectedWeight == size;
                  final price = (product.basePrice * info['mult']).round();
                  final isBest = info['best'] as bool;

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedWeight = size),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.leafGreen
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.leafGreen
                                    : AppColors.surfaceHighest,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  size,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '₹$price',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  info['note'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.8)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isBest)
                            Positioned(
                              top: -8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.pickleOrange,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Best Value',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // ── Frequently Paired Section ──────────────────────────────
            if (pairedProducts.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.fastfood_outlined,
                                size: 18, color: AppColors.orangeDark),
                            const SizedBox(width: 8),
                            Text(
                              'Frequently Paired',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Save ₹${(pairedProducts.fold<double>(0, (s, p) => s + p.basePrice * 0.12)).round()}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 132,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Current product thumb
                            _pairedProductThumb(
                              product,
                              isCurrent: true,
                              appState: appState,
                            ),
                            ...pairedProducts.map((p) => Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 6),
                                  child: Icon(Icons.add,
                                      size: 16, color: AppColors.outline),
                                ),
                                _pairedProductThumb(
                                  p,
                                  isCurrent: false,
                                  appState: appState,
                                ),
                              ],
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${(product.basePrice + pairedProducts.fold<double>(0, (s, p) => s + p.basePrice)).round()}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '₹${(product.originalPrice + pairedProducts.fold<double>(0, (s, p) => s + p.originalPrice)).round()} total MRP',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              requireAuth(context, onAuthenticated: () async {
                                final res = await appState.addToCart(
                                    product, activeVariant.displayLabel,
                                    variant: activeVariant,
                                    qty: 1);
                                if (!context.mounted) return;
                                if (res != null && !res.success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res.message ?? 'Failed to add combo to cart'),
                                      backgroundColor: AppColors.chilliRed,
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                for (final p in pairedProducts) {
                                  await appState.addToCart(
                                    p,
                                    p.defaultVariant.displayLabel,
                                    variant: p.defaultVariant,
                                    qty: 1,
                                  );
                                }
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Combo added to cart!'),
                                    backgroundColor: AppColors.leafGreen,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              });
                            },
                            icon: const Icon(Icons.shopping_bag_outlined,
                                size: 16),
                            label: Text(
                              'Add ${pairedProducts.length + 1}-in-1 Combo',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.pickleOrange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Accordion Sections ─────────────────────────────────────

            // 1. Grandmother's Heritage Story (open by default)
            _accordionCard(
              key: 'heritage',
              icon: Icons.menu_book_outlined,
              title: product.storyTitle,
              isOpen: _accordionOpen['heritage'] ?? true,
              onToggle: () => _toggleAccordion('heritage'),
              child: Text(
                product.homemakerStory,
                style: GoogleFonts.lora(
                  fontSize: 13.5,
                  color: AppColors.textPrimary,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Natural Clean Ingredients
            _accordionCard(
              key: 'ingredients',
              icon: Icons.eco_outlined,
              title: 'Natural Clean Ingredients',
              isOpen: _accordionOpen['ingredients'] ?? false,
              onToggle: () => _toggleAccordion('ingredients'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.ingredients.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: product.ingredients.map((ing) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.borderCard),
                        ),
                        child: Text(
                          ing,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      )).toList(),
                    ),
                  ] else ...[
                    _ingredientRow('Raw Mango', 'Handpicked Ramkela/Totapuri'),
                    _ingredientRow('Gingelly Oil',
                        'Cold-pressed sesame, stone-ground'),
                    _ingredientRow('Red Chillies', 'Guntur Teja variety'),
                    _ingredientRow('Rock Salt', 'Natural mineral, unpurified'),
                    _ingredientRow('Mustard Seeds',
                        'Whole, sun-dried 14 days'),
                    _ingredientRow('Fenugreek', 'Whole seeds, dry roasted'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_outlined,
                              size: 14, color: AppColors.leafGreen),
                          const SizedBox(width: 6),
                          Text(
                            product.zeroPreservatives
                                ? 'Zero artificial preservatives guaranteed'
                                : 'No artificial preservatives, colors or additives',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.leafGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (product.purityClaims.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: product.purityClaims.map((claim) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.leafGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_outlined,
                                size: 14, color: AppColors.leafGreen),
                            const SizedBox(width: 5),
                            Text(
                              claim,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.leafGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3. Storage & Tradition Tips
            _accordionCard(
              key: 'storage',
              icon: Icons.kitchen_outlined,
              title: 'Storage & Tradition Tips',
              isOpen: _accordionOpen['storage'] ?? false,
              onToggle: () => _toggleAccordion('storage'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _storageRow(Icons.thermostat_outlined,
                      'Store away from direct sunlight in a cool, dry pantry',
                      'Avoid refrigeration — cold temps solidify oil'),
                  const SizedBox(height: 8),
                  _storageRow(Icons.back_hand_outlined,
                      'Always use a dry spoon to serve',
                      'Moisture accelerates spoilage of handmade batches'),
                  const SizedBox(height: 8),
                  _storageRow(Icons.timelapse_outlined,
                      'Best consumed within 12 months of manufacture',
                      'Oil-marinated pickles improve in depth over 3–6 months'),
                  const SizedBox(height: 8),
                  _storageRow(Icons.restaurant_outlined,
                      'Pairs perfectly with hot steamed rice + ghee',
                      'Also great with parathas, curd rice & idli'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 4. FSSAI & Replacement Assurance
            _accordionCard(
              key: 'fssai',
              icon: Icons.shield_outlined,
              title: 'FSSAI & Replacement Assurance',
              isOpen: _accordionOpen['fssai'] ?? false,
              onToggle: () => _toggleAccordion('fssai'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fssaiRow(Icons.verified_user_outlined, AppColors.leafGreen,
                      'FSSAI Licensed Maker',
                      'Lic No: 10020042000000 — All food safety standards met'),
                  const SizedBox(height: 8),
                  _fssaiRow(Icons.local_shipping_outlined, AppColors.pickleOrange,
                      'Breakage Guard',
                      'Glass jars double-wrapped in bubble foam with cushion packing'),
                  const SizedBox(height: 8),
                  _fssaiRow(Icons.replay_outlined, AppColors.leafGreen,
                      '100% Replacement Policy',
                      'Damaged or unsealed product on arrival? We replace it free, no questions asked'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Contact us within 48 hours of delivery for replacement requests',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (showProductReviews) ...[
              const SizedBox(height: 16),

              // Customer Reviews Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Customer Reviews',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'View all ${product.reviewCount}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.leafGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Review Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              'RV',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orangeDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ravi Varma',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Verified Andhra Gourmet',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Text(
                          '★★★★★',
                          style: TextStyle(
                            color: AppColors.spiceYellow,
                            fontSize: 14,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"Brought back memories of my grandmother\'s veranda in Vijayawada! Crisp mango bone, real pungent cold-pressed gingelly oil, and genuine spice."',
                      style: GoogleFonts.lora(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Related Products Section ───────────────────────────────
            if (relatedProducts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          size: 18, color: AppColors.orangeDark),
                      const SizedBox(width: 8),
                      Text(
                        'Related Products',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Text(
                      '${relatedProducts.length} items',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: relatedProducts.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final relProduct = relatedProducts[index];
                    return SizedBox(
                      width: 175,
                      child: ProductCard(
                        product: relProduct,
                        appState: appState,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                productId: relProduct.id,
                                product: relProduct,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  ),

      // Bottom Sticky Bar (Stepper + Add to Cart + Buy Now)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.borderCard)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x145D4037),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                // Stepper
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceHighest),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove,
                            size: 18, color: AppColors.leafGreen),
                        onPressed: () {
                          if (_quantity > 1) {
                            setState(() => _quantity--);
                          }
                        },
                      ),
                      Text(
                        '$_quantity',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add,
                            size: 18, color: AppColors.leafGreen),
                        onPressed: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Add to Cart
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        requireAuth(context, onAuthenticated: () async {
                          final res = await appState.addToCart(
                            product,
                            activeVariant.displayLabel,
                            variant: activeVariant,
                            qty: _quantity,
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
                                    '$_quantity × ${activeVariant.displayLabel} added to cart'),
                                backgroundColor: AppColors.textPrimary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        });
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, size: 17),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Add to Cart',
                          maxLines: 1,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pickleOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Buy Now
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        _pinFocusNode.unfocus();
                        requireAuth(context, onAuthenticated: () async {
                          final res = await appState.addToCart(
                            product,
                            activeVariant.displayLabel,
                            variant: activeVariant,
                            qty: _quantity,
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
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const CartScreen()),
                          );
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Buy Now',
                          maxLines: 1,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildVariantCard(ProductVariant v, ProductVariant activeVariant) {
    final isSelected = activeVariant.id == v.id;
    final badge = v.saveBadgeText;
    final isBest = v.bestValue || (badge != null && badge.isNotEmpty);
    final badgeText =
        (badge != null && badge.isNotEmpty) ? badge : 'Best Value';
    final unitPrice = v.unitPriceText;
    final note = v.serves > 0
        ? 'Serves ${v.serves}'
        : (v.packaging.isNotEmpty && v.packaging != 'string'
            ? v.packaging
            : ((unitPrice != null && unitPrice.isNotEmpty)
                ? unitPrice
                : 'Jar'));

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVariant = v;
          _selectedWeight = v.displayLabel;
        });
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.leafGreen : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.leafGreen
                    : AppColors.surfaceHighest,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.displayLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  '₹${v.price.toInt()}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isBest)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.pickleOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _circleActionBtn({
    required IconData icon,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderCard),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: iconColor ?? AppColors.textPrimary),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _overlayPill({
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderThumb(int index) {
    final icons = [
      Icons.local_dining,
      Icons.spa_outlined,
      Icons.kitchen_outlined
    ];
    return Center(
      child: Icon(
        icons[index % icons.length],
        size: 22,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _pairedProductThumb(
    Product p, {
    bool isCurrent = false,
    required AppState appState,
  }) {
    final hasMultipleVariants = p.hasMultipleVariants;
    final totalQty = appState.getProductQty(p.id);
    final inCart = totalQty > 0;

    return GestureDetector(
      onTap: isCurrent
          ? null
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailScreen(
                    productId: p.id,
                    product: p,
                  ),
                ),
              );
            },
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent ? AppColors.surfaceLow : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? AppColors.leafGreen.withValues(alpha: 0.35)
                : AppColors.borderCard,
            width: isCurrent ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image with badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ProductImage(product: p, fit: BoxFit.cover),
                ),
                if (isCurrent)
                  Positioned(
                    bottom: -3,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.leafGreen,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.poppins(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '₹${p.basePrice.toInt()}',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.leafGreen,
              ),
            ),
            const SizedBox(height: 4),
            if (isCurrent)
              Container(
                height: 22,
                alignment: Alignment.center,
                child: Text(
                  'Selected',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else if (hasMultipleVariants)
              InkWell(
                onTap: () {
                  ProductVariantBottomSheet.show(context, product: p);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFFE21A5E),
                      width: 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inCart ? 'ADD · $totalQty' : '+ Opts',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFE21A5E),
                    ),
                  ),
                ),
              )
            else
              InkWell(
                onTap: () {
                  requireAuth(context, onAuthenticated: () async {
                    final res = await appState.addToCart(
                      p,
                      p.defaultVariant.displayLabel,
                      variant: p.defaultVariant,
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
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${p.name} to cart!'),
                          backgroundColor: AppColors.leafGreen,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 22,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: inCart ? AppColors.successBg : AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: inCart ? AppColors.leafGreen : AppColors.borderCard,
                      width: 1.0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inCart ? '✓ ($totalQty)' : '+ Add',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: inCart ? AppColors.leafGreen : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _accordionCard({
    required String key,
    required IconData icon,
    required String title,
    required bool isOpen,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderCard),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.orangeDark),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1, color: AppColors.borderCard),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: child,
            ),
          ],
        ],
      ),
    );
  }

  Widget _ingredientRow(String name, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.pickleOrange),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$name  ',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: detail,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

  Widget _storageRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.pickleOrange),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fssaiRow(
      IconData icon, Color iconColor, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                desc,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showShareSheet(BuildContext context, Product product, int price) {
    final shareUrl = 'https://pickleo.in/jar/${product.id}';
    final shareText =
        '${product.name} by ${product.maker} on PickleO — from ₹$price. $shareUrl';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0C9C0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Share this jar',
                    style: GoogleFonts.lora(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF1ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Product Preview Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: ProductImage(product: product, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.maker} · from ₹$price',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Copy Link Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 20, color: AppColors.leafGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        shareUrl,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Color(0xFF95D4AC), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                    'Link copied · pickleo.in/jar/${product.id}',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2C160E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999)),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2C160E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        minimumSize: Size.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Copy',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3 Share Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildShareChannelBtn(
                      icon: Icons.chat_bubble,
                      iconColor: Colors.white,
                      iconBg: const Color(0xFF25D366),
                      label: 'WhatsApp',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening WhatsApp share...'),
                            backgroundColor: Color(0xFF25D366),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildShareChannelBtn(
                      icon: Icons.sms,
                      iconColor: Colors.white,
                      iconBg: AppColors.leafGreen,
                      label: 'Message',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening SMS Message...'),
                            backgroundColor: AppColors.leafGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildShareChannelBtn(
                      icon: Icons.mail,
                      iconColor: Colors.white,
                      iconBg: AppColors.orangeDark,
                      label: 'Email',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: shareText));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Opening Email...'),
                            backgroundColor: AppColors.orangeDark,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareChannelBtn({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderCard),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


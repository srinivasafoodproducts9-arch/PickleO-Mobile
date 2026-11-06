import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/coupon.dart';
import '../models/order.dart';
import 'address_screen.dart';
import 'product_detail_screen.dart';
import 'products_catalog_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/user_avatar.dart';
import '../widgets/order_success_celebration_dialog.dart';
import '../utils/auth_guard.dart';

class CartScreen extends StatefulWidget {
  final bool isTab;

  const CartScreen({super.key, this.isTab = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  final TextEditingController _couponController = TextEditingController();
  bool _isOpeningOnlinePayment = false;
  bool _showSlotError = false;
  bool _useWallet = false;
  final GlobalKey _deliverySlotKey = GlobalKey();

  late Razorpay _razorpay;
  Map<String, dynamic>? _pendingOrderData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCartData();
    });
  }

  Future<void> _initCartData() async {
    final appState = AppStateProvider.of(context);
    // Fetch live offers from GET /consumer/offers
    appState.fetchOffers();

    // If signed in, ensure saved addresses are loaded and sync cart with address
    if (appState.isLoggedIn) {
      if (!appState.hasLoadedAddresses && !appState.isLoadingAddresses) {
        await appState.loadAddressesFromApi();
      }
      await appState.loadCartFromApi();
      await appState.loadWalletFromApi();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _razorpay.clear();
    _couponController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _initCartData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTab = widget.isTab;
    final appState = AppStateProvider.of(context);
    final cartList = appState.cartList;
    final hasCart = appState.hasCart;
    final defAddr = appState.defaultAddress;
    final hasValidAddress = appState.hasValidDeliveryAddress;
    final hasCoupon = appState.appliedCoupon != null;
    final isTotalPayableNull = appState.isTotalPayableNull;
    final issueReason = appState.pricingIssuesReason;
    final isDeliverySlotMissing =
        appState.hasDeliverySlots && !appState.isDeliverySlotSelected;

    final instructions = [
      {'label': 'Leave at door', 'icon': Icons.door_front_door_outlined},
      {'label': 'Call on arrival', 'icon': Icons.phone_in_talk_outlined},
      {'label': 'Ring the bell', 'icon': Icons.notifications_active_outlined},
      {'label': "Don't ring bell", 'icon': Icons.notifications_off_outlined},
      {'label': 'Dog at home', 'icon': Icons.pets_outlined},
      {'label': 'Small kid sleeping', 'icon': Icons.bedtime_outlined},
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: isTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Cart & Checkout',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (hasCart)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined,
                  color: AppColors.error),
              tooltip: 'Clear Cart',
              onPressed: () => _confirmClearCart(context, appState),
            ),
          const UserAvatar(
            radius: 16,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.leafGreen,
        onRefresh: () async {
          await appState.fetchOffers(forceRefresh: true);
          if (appState.isLoggedIn) {
            await appState.loadAddressesFromApi();
            await appState.loadCartFromApi();
          }
        },
        child: !hasCart
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
                                Icons.shopping_basket_outlined,
                                size: 40,
                                color: AppColors.orangeDark,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your pantry basket is empty',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Add a jar or two from the bestsellers',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ProductsCatalogScreen(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: AppColors.leafGreen, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Browse Pickles',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.leafGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // Delivering to Address Strip (Mandatory)
                  if (!hasValidAddress) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.pickleOrange, width: 1.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.pickleOrange.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on,
                                size: 22, color: AppColors.orangeDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Address Required',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Please select or add a delivery address to calculate delivery fees, local taxes, and proceed to checkout.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    requireAuth(context, onAuthenticated: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AddressScreen(isSelectMode: true),
                                        ),
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.add_location_alt_outlined,
                                      size: 16, color: Colors.white),
                                  label: Text(
                                    'Select or Add Address',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.pickleOrange,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: () {
                        requireAuth(context, onAuthenticated: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AddressScreen(isSelectMode: true)),
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        color: AppColors.surfaceLow,
                        child: Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 20, color: AppColors.leafGreen),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Delivering to ${defAddr.label}',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (defAddr.isDefault) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceHigh,
                                            borderRadius:
                                                BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            'Default',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  AppColors.onSecondaryContainer,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    defAddr.fullAddress,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Change',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pickleOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!appState.isAddressServiceable(defAddr)) ...[
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFDAD6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 18, color: Color(0xFF7A1F14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "We don't deliver to PIN ${defAddr.postalCode} yet. Choose another address to continue.",
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF7A1F14),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 10),

                  // Quality Assurance Banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.leafGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_outlined,
                            size: 18, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '100% Sun-Ripened & Hand-Pounded • Grandma\'s Batch',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Fresh Batch',
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
                  const SizedBox(height: 14),

                  // Order Items Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Order Items ',
                                  style: GoogleFonts.poppins(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      '(${appState.cartCount} Jar${appState.cartCount == 1 ? '' : 's'})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'In Stock',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Cart Item Cards
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: cartList.map((item) {
                        final product = item.product;
                        final mrp = (item.variant != null && item.variant!.mrp > 0)
                            ? (item.variant!.mrp * item.quantity).round()
                            : (product.mrp > 0
                                ? (product.mrp * item.quantity).round()
                                : (product.originalPrice /
                                        product.basePrice *
                                        item.unitPrice *
                                        item.quantity)
                                    .round());

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: !item.inStock
                                  ? const Color(0xFFFFCDD2)
                                  : AppColors.borderCard,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(
                                          productId: product.id),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Opacity(
                                        opacity: item.inStock ? 1.0 : 0.6,
                                        child: ProductImage(
                                          product: product,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    if (!item.inStock)
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        right: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.chilliRed.withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'OUT OF STOCK',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: item.inStock
                                                  ? AppColors.textPrimary
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => appState
                                              .removeItem(item.itemKey),
                                          child: const Icon(Icons.close,
                                              size: 18,
                                              color: AppColors.outline),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.selectedWeight} · ${item.variant != null && item.variant!.packaging.isNotEmpty && item.variant!.packaging != 'string' ? item.variant!.packaging : product.packaging}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceContainer,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            product.batchTag,
                                            style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.chilliRed,
                                            ),
                                          ),
                                        ),
                                        if (!item.inStock) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFDAD6),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Out of Stock',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.chilliRed,
                                              ),
                                            ),
                                          ),
                                        ] else if (item.availableQuantity > 0 &&
                                            item.availableQuantity <= 5) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF3E0),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Only ${item.availableQuantity} left',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFFE65100),
                                              ),
                                            ),
                                          ),
                                        ],
                                        // Save for later link
                                        GestureDetector(
                                          onTap: () {
                                            appState.toggleWishlist(product.id, product: product);
                                            appState.removeItem(item.itemKey);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${product.name} saved for later',
                                                  style: GoogleFonts.poppins(
                                                      color: Colors.white),
                                                ),
                                                backgroundColor:
                                                    AppColors.leafGreen,
                                                duration:
                                                    const Duration(seconds: 2),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: Text(
                                            'Save for later',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.pickleOrange,
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  AppColors.pickleOrange,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline:
                                              TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              '₹${item.totalPrice.toInt()}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '₹$mrp',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                decoration: TextDecoration
                                                    .lineThrough,
                                                color: AppColors.outline,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Inline Stepper
                                        Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceContainer,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  requireAuth(context,
                                                      onAuthenticated: () async {
                                                    final res = await appState.updateQuantity(
                                                        item.itemKey, -1);
                                                    if (!context.mounted) return;
                                                    if (res != null && !res.success) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(res.message ?? 'Failed to update quantity'),
                                                          backgroundColor: AppColors.chilliRed,
                                                          behavior: SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                    }
                                                  });
                                                },
                                                child: const Icon(
                                                    Icons.remove,
                                                    size: 16,
                                                    color:
                                                        AppColors.leafGreen),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                                child: Text(
                                                  '${item.quantity}',
                                                  style:
                                                      GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  requireAuth(context,
                                                      onAuthenticated: () async {
                                                    if (!item.inStock) {
                                                      ScaffoldMessenger.of(context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            '${product.name} is currently out of stock',
                                                            style: GoogleFonts.poppins(
                                                                color: Colors.white),
                                                          ),
                                                          backgroundColor:
                                                              AppColors.chilliRed,
                                                          behavior:
                                                              SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    if (item.availableQuantity > 0 &&
                                                        item.quantity >=
                                                            item.availableQuantity) {
                                                      ScaffoldMessenger.of(context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Only ${item.availableQuantity} units available in stock',
                                                            style: GoogleFonts.poppins(
                                                                color: Colors.white),
                                                          ),
                                                          backgroundColor:
                                                              AppColors.orangeDark,
                                                          behavior:
                                                              SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    final res = await appState.updateQuantity(
                                                        item.itemKey, 1);
                                                    if (!context.mounted) return;
                                                    if (res != null && !res.success) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text(res.message ?? 'Failed to update quantity'),
                                                          backgroundColor: AppColors.chilliRed,
                                                          behavior: SnackBarBehavior.floating,
                                                        ),
                                                      );
                                                    }
                                                  });
                                                },
                                                child: Icon(
                                                  Icons.add,
                                                  size: 16,
                                                  color: (!item.inStock ||
                                                          (item.availableQuantity > 0 &&
                                                              item.quantity >=
                                                                  item.availableQuantity))
                                                      ? AppColors.outline
                                                      : AppColors.leafGreen,
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
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Apply Offers & Coupons Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.confirmation_number_outlined,
                                      size: 18, color: AppColors.orangeDark),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'APPLY OFFERS & COUPONS',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                requireAuth(context, onAuthenticated: () {
                                  _showCouponsSheet(context, appState);
                                });
                              },
                              child: Text(
                                'View All Offers',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.pickleOrange,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Applied coupon chip
                        if (hasCoupon) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.successBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.leafGreen.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 20, color: AppColors.leafGreen),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              appState.apiAppliedPromotion?.code.isNotEmpty == true
                                                  ? appState.apiAppliedPromotion!.code
                                                  : (appState.appliedCoupon ?? ''),
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.leafGreen,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Applied ✓',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        appState.apiAppliedPromotion?.title.isNotEmpty == true
                                            ? '${appState.apiAppliedPromotion!.title} · Saved ₹${appState.couponDiscount.toInt()}'
                                            : 'You saved ₹${appState.couponDiscount.toInt()} on this order!',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.leafGreen,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    appState.removeCoupon();
                                  },
                                  child: Text(
                                    'Remove',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.chilliRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Quick coupon input & active offers
                        if (!hasCoupon) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLow,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.borderCard),
                                  ),
                                  child: TextField(
                                    controller: _couponController,
                                    textCapitalization: TextCapitalization.characters,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                                      LengthLimitingTextInputFormatter(16),
                                    ],
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      letterSpacing: 0.5,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter coupon or offer code',
                                      hintStyle: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.outline,
                                        fontWeight: FontWeight.w400,
                                        letterSpacing: 0,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 44,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final code = _couponController.text.trim().toUpperCase();
                                    if (code.isEmpty) return;
                                    requireAuth(context, onAuthenticated: () async {
                                      final res = await appState.applyCoupon(code);
                                      if (!context.mounted) return;
                                      if (res.success) {
                                        _couponController.clear();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res.message),
                                            backgroundColor: AppColors.leafGreen,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res.message),
                                            backgroundColor: AppColors.orangeDark,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.leafGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    'APPLY',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (appState.coupons.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  ...appState.coupons.take(4).map((c) => _buildOfferChip(
                                        context,
                                        appState,
                                        c,
                                        badgeText: c.valueLabel,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Delivery Slot Selection Card (Mandatory from GET /consumer/cart)
                  Container(
                    key: _deliverySlotKey,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _showSlotError
                            ? const Color(0xFFC0392B)
                            : (appState.isDeliverySlotSelected
                                ? AppColors.leafGreen.withValues(alpha: 0.6)
                                : AppColors.borderCard),
                        width: _showSlotError ? 1.8 : 1.0,
                      ),
                      boxShadow: _showSlotError
                          ? [
                              BoxShadow(
                                color: const Color(0xFFC0392B)
                                    .withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _showSlotError
                                    ? const Color(0xFFFFDAD6)
                                    : (appState.isDeliverySlotSelected
                                        ? AppColors.leafGreen
                                            .withValues(alpha: 0.12)
                                        : AppColors.pickleOrange
                                            .withValues(alpha: 0.12)),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.access_time_filled_rounded,
                                size: 18,
                                color: _showSlotError
                                    ? const Color(0xFFC0392B)
                                    : (appState.isDeliverySlotSelected
                                        ? AppColors.leafGreen
                                        : AppColors.pickleOrange),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Delivery Slot',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: appState.isDeliverySlotSelected
                                              ? AppColors.successBg
                                              : (_showSlotError
                                                  ? const Color(0xFFFFDAD6)
                                                  : const Color(0xFFFFF3E0)),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          appState.isDeliverySlotSelected
                                              ? 'Selected'
                                              : 'Required',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: appState.isDeliverySlotSelected
                                                ? AppColors.leafGreen
                                                : (_showSlotError
                                                    ? const Color(0xFFC0392B)
                                                    : AppColors.pickleOrange),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    appState.isDeliverySlotSelected
                                        ? 'Slot: ${appState.selectedDeliverySlot}'
                                        : 'Select your preferred delivery time window',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: _showSlotError
                                          ? const Color(0xFFC0392B)
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (appState.parsedDeliveryInfo?.sla.isNotEmpty ==
                                true) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  appState.parsedDeliveryInfo!.sla,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.leafGreen,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Slot Choices
                        if (appState.deliverySlots.isEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    hasValidAddress
                                        ? 'Standard Delivery (Slots will be assigned based on location)'
                                        : 'Select a delivery address to view available time slots',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: appState.deliverySlots.map((slot) {
                              final isSelected =
                                  appState.selectedDeliverySlot == slot;

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _showSlotError = false);
                                  appState.selectDeliverySlot(slot);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.leafGreen
                                        : AppColors.surfaceLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.leafGreen
                                          : AppColors.borderCard,
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.leafGreen
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle_rounded
                                            : Icons.radio_button_unchecked,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        slot,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          if (_showSlotError) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 14, color: Color(0xFFC0392B)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Please choose a delivery slot to proceed with your order',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFC0392B),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Delivery Instructions Card (3x2 Grid Multi-Select)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined,
                                size: 18, color: AppColors.orangeDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Delivery Instructions',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (appState.deliveryInstructionsSet.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${appState.deliveryInstructionsSet.length} selected',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.leafGreen,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: instructions.length,
                          itemBuilder: (context, index) {
                            final ins = instructions[index];
                            final label = ins['label'] as String;
                            final icon = ins['icon'] as IconData;
                            final isSelected = appState.hasDeliveryInstruction(label);

                            return GestureDetector(
                              onTap: () => appState.toggleDeliveryInstruction(label),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.leafGreen
                                      : AppColors.surfaceLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.leafGreen
                                        : AppColors.borderCard,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      icon,
                                      size: 20,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      label,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Celebration Savings Banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryFixed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.celebration,
                            size: 20, color: AppColors.tertiary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'You are saving ₹${appState.totalSaved.toInt()} on this order!',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Price Breakdown Card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Price Breakdown',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _priceRow('Items MRP Total',
                            '₹${appState.mrpTotal.toInt()}'),
                        const SizedBox(height: 8),
                        _priceRow(
                          'Product Discount',
                          '−₹${appState.productDiscount.toInt()}',
                          valueColor: AppColors.leafGreen,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        if (hasCoupon && appState.couponDiscount > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Coupon ',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.successBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      appState.apiAppliedPromotion?.code.isNotEmpty == true
                                          ? appState.apiAppliedPromotion!.code
                                          : (appState.appliedCoupon ?? 'COUPON'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.leafGreen,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '−₹${appState.couponDiscount.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.leafGreen,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Delivery Fee',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!hasValidAddress) ...[
                              Flexible(
                                child: Text(
                                  'Address required',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                              ),
                            ] else if (appState.isFreeDelivery) ...[
                              Row(
                                children: [
                                  Text(
                                    '₹${appState.standardDeliveryFee.toInt()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      decoration: TextDecoration.lineThrough,
                                      color: AppColors.outline,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'FREE',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.leafGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                '₹${appState.deliveryFee.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        _priceRow('Cushion Packaging', '₹${appState.packagingFee.toInt()}'),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Payable',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Inclusive of all local taxes',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isTotalPayableNull
                                  ? '--'
                                  : '₹${appState.grandTotal.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: isTotalPayableNull
                                    ? AppColors.orangeDark
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (isTotalPayableNull && issueReason != null && issueReason.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFFFB74D)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline,
                                    size: 18, color: Color(0xFFE65100)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    issueReason,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFBF360C),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Payment Method Section (Online vs PickleO Wallet + Online)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildPaymentMethodSection(context, appState),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Bottom Sticky Pay Action Bar
      bottomNavigationBar: hasCart
          ? Container(
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
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top Row: Amount & Savings Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'TO PAY',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isTotalPayableNull
                                    ? '--'
                                    : '₹${appState.grandTotal.toInt()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: isTotalPayableNull
                                      ? AppColors.orangeDark
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (isTotalPayableNull) ...[
                                const SizedBox(width: 4),
                                Text(
                                  'Issue',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                              ] else if (appState.totalSaved > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Saved ₹${appState.totalSaved.toInt()}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.leafGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (cartList.isNotEmpty)
                            Text(
                              '${cartList.length} item${cartList.length == 1 ? '' : 's'}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Checkout / Pay Online Button (Full Width)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isOpeningOnlinePayment
                              ? null
                              : () {
                                  if (isDeliverySlotMissing) {
                                    setState(() => _showSlotError = true);
                                    if (_deliverySlotKey.currentContext != null) {
                                      Scrollable.ensureVisible(
                                        _deliverySlotKey.currentContext!,
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                    _showDeliverySlotBottomSheet(context, appState);
                                    return;
                                  }
                                  _handleProceedWithOnline(appState);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pickleOrange,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isOpeningOnlinePayment
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Opening Payment...',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDeliverySlotMissing
                                          ? Icons.schedule_rounded
                                          : Icons.bolt_rounded,
                                      size: 19,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isDeliverySlotMissing
                                          ? 'Select Delivery Slot'
                                          : (_useWallet
                                              ? 'Pay with Wallet + Online'
                                              : 'Pay Online'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
      : null,
    );
  }

  Widget _buildPaymentMethodSection(BuildContext context, AppState appState) {
    final walletBal = appState.walletBalance;
    final canUseWallet = appState.isLoggedIn && walletBal > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
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
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: AppColors.pickleOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Payment Mode',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 11, color: Color(0xFF16A34A)),
                    const SizedBox(width: 3),
                    Text(
                      '100% Secure',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Standard Online Payment Option
          InkWell(
            onTap: () {
              if (_useWallet) setState(() => _useWallet = false);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: !_useWallet
                    ? AppColors.pickleOrange.withValues(alpha: 0.06)
                    : AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: !_useWallet
                      ? AppColors.pickleOrange
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    !_useWallet
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: !_useWallet ? AppColors.pickleOrange : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Online Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'UPI, Credit/Debit Cards, NetBanking via Razorpay',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // PickleO Wallet + Online Option
          InkWell(
            onTap: canUseWallet
                ? () {
                    setState(() => _useWallet = !_useWallet);
                  }
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          appState.isLoggedIn
                              ? 'PickleO Wallet balance is ₹0. Top up in Wallet tab to use it for orders.'
                              : 'Please login to use PickleO Wallet cash.',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: AppColors.textPrimary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: _useWallet
                    ? const Color(0xFF0F5132).withValues(alpha: 0.06)
                    : AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _useWallet
                      ? const Color(0xFF0F5132)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _useWallet
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off,
                    size: 18,
                    color: _useWallet
                        ? const Color(0xFF0F5132)
                        : (canUseWallet ? Colors.grey : Colors.grey.shade400),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'PickleO Wallet + Online',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: canUseWallet
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: canUseWallet
                                    ? const Color(0xFFDFF3E6)
                                    : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '₹${walletBal.toStringAsFixed(walletBal.truncateToDouble() == walletBal ? 0 : 2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: canUseWallet
                                      ? const Color(0xFF0F5132)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          canUseWallet
                              ? 'Server applies up to 90% from wallet; Razorpay collects remainder'
                              : 'No wallet cash available (Top up in Wallet tab)',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
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

  Widget _buildOfferChip(
    BuildContext context,
    AppState appState,
    CouponOffer coupon, {
    String? badgeText,
  }) {
    final elig = coupon.isEligible(appState.subtotal);
    final label = badgeText ?? coupon.valueLabel;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          requireAuth(context, onAuthenticated: () async {
            if (elig) {
              final res = await appState.applyCoupon(coupon.code);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(res.message),
                  backgroundColor: res.success ? AppColors.leafGreen : AppColors.orangeDark,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              final needed = coupon.minOrder - appState.subtotal;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Add ₹${needed.toInt()} more to use ${coupon.code}'),
                  backgroundColor: AppColors.orangeDark,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: elig ? AppColors.surfaceContainer : AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: elig
                  ? AppColors.pickleOrange.withValues(alpha: 0.4)
                  : AppColors.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                coupon.code,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orangeDark,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: elig ? AppColors.leafGreen : AppColors.outline,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value,
      {Color? valueColor, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _confirmClearCart(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear Cart?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all items from your cart?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              appState.clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Cart cleared',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  backgroundColor: AppColors.textPrimary,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCouponsSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        final bottomInset = mq.viewInsets.bottom;
        final systemBottom = mq.padding.bottom;
        final effectiveBottom = bottomInset > 0
            ? (bottomInset + 16)
            : (systemBottom > 0 ? (systemBottom + 16) : 24.0);

        return Container(
          constraints: BoxConstraints(
            maxHeight: mq.size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x332C160E),
                blurRadius: 32,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: effectiveBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Drag handle
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

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Offers & Coupons',
                      style: GoogleFonts.lora(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF1ED),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Quick promo input in sheet
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFDBD0)),
                        ),
                        child: TextField(
                          controller: _couponController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                            LengthLimitingTextInputFormatter(16),
                          ],
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter coupon or offer code',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.outline,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () async {
                          final code = _couponController.text.trim().toUpperCase();
                          if (code.isEmpty) return;
                          final res = await appState.applyCoupon(code);
                          if (!sheetContext.mounted) return;
                          if (res.success) {
                            _couponController.clear();
                            Navigator.of(sheetContext).pop();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppColors.leafGreen,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(res.message),
                                backgroundColor: AppColors.orangeDark,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.leafGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Coupon list or empty state
                if (appState.coupons.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF1ED),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_offer_outlined,
                            size: 28,
                            color: AppColors.pickleOrange,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No offers available right now',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check back soon for exclusive deals and discounts!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...appState.coupons.map((c) {
                    final applied = appState.appliedCoupon == c.code;
                    final elig = c.isEligible(appState.subtotal);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: applied ? AppColors.leafGreen : AppColors.borderCard,
                          width: applied ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.code,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.desc,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${c.valueLabel} · ${c.minLabel}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: const Color(0xFF8D6E63),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  if (applied) return;
                                  if (!elig) {
                                    final needed = c.minOrder - appState.subtotal;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Add ₹${needed.toInt()} more to use ${c.code}',
                                          style: GoogleFonts.poppins(color: Colors.white),
                                        ),
                                        backgroundColor: AppColors.orangeDark,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    return;
                                  }
                                  final res = await appState.applyCoupon(c.code);
                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        res.message,
                                        style: GoogleFonts.poppins(color: Colors.white),
                                      ),
                                      backgroundColor: res.success ? AppColors.leafGreen : AppColors.orangeDark,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: applied ? const Color(0xFFDFF3E6) : AppColors.leafGreen,
                                  foregroundColor: applied ? AppColors.leafGreen : Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                                  minimumSize: const Size(64, 34),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                                child: Opacity(
                                  opacity: elig || applied ? 1.0 : 0.45,
                                  child: Text(
                                    applied ? 'Applied' : 'Apply',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!elig) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Add ₹${(c.minOrder - appState.subtotal).toInt()} more to use this offer',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.orangeDark,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  void _showDeliverySlotBottomSheet(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final mq = MediaQuery.of(sheetContext);
        final bottomInset = mq.viewInsets.bottom;
        final systemBottom = mq.padding.bottom;
        final effectiveBottom = bottomInset > 0
            ? (bottomInset + 16)
            : (systemBottom > 0 ? (systemBottom + 16) : 24.0);

        return Container(
          constraints: BoxConstraints(
            maxHeight: mq.size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF8F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x332C160E),
                blurRadius: 32,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: effectiveBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Drag handle
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
              const SizedBox(height: 14),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.pickleOrange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time_filled_rounded,
                          size: 18,
                          color: AppColors.pickleOrange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Select Delivery Slot',
                        style: GoogleFonts.lora(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(),
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
              const SizedBox(height: 8),

              Text(
                'Choose your preferred delivery time window for this order',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),

              if (appState.parsedDeliveryInfo?.sla.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            size: 15, color: AppColors.leafGreen),
                        const SizedBox(width: 6),
                        Text(
                          appState.parsedDeliveryInfo!.sla,
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.leafGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Slots list
              ...appState.deliverySlots.map((slot) {
                final isSelected = appState.selectedDeliverySlot == slot;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () {
                      setState(() => _showSlotError = false);
                      appState.selectDeliverySlot(slot);
                      Navigator.of(sheetContext).pop();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.leafGreen.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.leafGreen
                              : AppColors.borderCard,
                          width: isSelected ? 1.6 : 1.0,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.leafGreen
                                      .withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: isSelected
                                ? AppColors.leafGreen
                                : AppColors.outline,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              slot,
                              style: GoogleFonts.poppins(
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.leafGreen
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.leafGreen,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Selected',
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
                  ),
                );
              }),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  },
);
}

  Future<bool> _validateCheckoutRequirements(AppState appState) async {
    final defAddr = appState.activeDeliveryAddress ?? appState.defaultAddress;
    final hasValidAddress = appState.hasValidDeliveryAddress ||
        (defAddr.id.isNotEmpty && defAddr.id != '0');

    if (!hasValidAddress) {
      final selected = await Navigator.of(context).push<DeliveryAddress?>(
        MaterialPageRoute(
          builder: (_) => const AddressScreen(isSelectMode: true),
        ),
      );
      if (selected != null) {
        appState.setSelectedAddress(selected);
      }
      return false;
    }

    if (appState.isTotalPayableNull) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            appState.pricingIssuesReason ??
                'Cannot calculate total payable. Please check your address or cart items.',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF7A1F14),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    if (!appState.isAddressServiceable(defAddr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "PIN ${defAddr.postalCode} isn't serviceable — change address to continue",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF7A1F14),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    final cartList = appState.cartList;
    final outOfStock = cartList.any((i) => !i.inStock);
    if (outOfStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please remove out of stock items to proceed',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }

    // Mandatory delivery slot check
    if (appState.hasDeliverySlots && !appState.isDeliverySlotSelected) {
      setState(() => _showSlotError = true);
      if (_deliverySlotKey.currentContext != null) {
        Scrollable.ensureVisible(
          _deliverySlotKey.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
      _showDeliverySlotBottomSheet(context, appState);
      return false;
    }

    return true;
  }

  Future<void> _handleProceedWithOnline(AppState appState) async {
    requireAuth(context, onAuthenticated: () async {
      if (!mounted) return;
      final isValid = await _validateCheckoutRequirements(appState);
      if (!isValid) return;

      if (!mounted) return;
      setState(() => _isOpeningOnlinePayment = true);

      try {
        final res = await appState.initiateOnlineOrder(
          paymentMethod: _useWallet ? 'Wallet' : 'Online',
        );
        if (!mounted) return;

        if (!res.success || res.data == null) {
          setState(() => _isOpeningOnlinePayment = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.message ?? 'Failed to initiate order. Please try again.',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: AppColors.chilliRed,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _handleProceedWithOnline(appState),
              ),
            ),
          );
          return;
        }

        final orderData = res.data!;
        _pendingOrderData = orderData;

        // Extract backend-generated order ID (orderId from /consumer/payments/razorpay/order)
        final backendOrderId = orderData['orderId']?.toString() ??
            orderData['razorpayOrderId']?.toString() ??
            orderData['razorpay_order_id']?.toString() ??
            orderData['id']?.toString() ??
            '';

        // Publishable Razorpay Key ID (Never put Key Secret in the app!)
        final razorpayKeyId = orderData['keyId']?.toString() ??
            orderData['razorpayKeyId']?.toString() ??
            orderData['razorpay_key_id']?.toString() ??
            const String.fromEnvironment('RAZORPAY_KEY_ID',
                defaultValue: 'rzp_test_1DP5mmOlF5G5ag');

        // Amount is returned in paise from POST /consumer/payments/razorpay/order
        final int amountInPaise = orderData['amount'] != null
            ? (orderData['amount'] as num).toInt()
            : (appState.grandTotal * 100).round();

        final currency = orderData['currency']?.toString() ?? 'INR';

        final profile = appState.userProfile;
        final phone = profile?.phone.isNotEmpty == true
            ? profile!.phone
            : (appState.activeDeliveryAddress?.phone ?? '');
        final email = profile?.email.isNotEmpty == true ? profile!.email : '';

        final displayOrderId = orderData['displayId']?.toString() ??
            (backendOrderId.isNotEmpty ? backendOrderId : 'PickleO Order');

        final walletUsed = (orderData['walletUsed'] ?? orderData['wallet_used'] as num?)?.toDouble() ?? 0.0;
        final gatewayAmt = (orderData['gatewayAmount'] ?? orderData['gateway_amount'] as num?)?.toDouble() ?? 0.0;
        final paymentDesc = walletUsed > 0
            ? 'Order #$displayOrderId (₹${walletUsed.toInt()} Wallet + ₹${gatewayAmt > 0 ? gatewayAmt.toInt() : (amountInPaise / 100).toInt()} Online)'
            : 'Order #$displayOrderId';

        final options = <String, dynamic>{
          'key': razorpayKeyId,
          'amount': amountInPaise,
          'currency': currency,
          'name': 'PickleO',
          'description': paymentDesc,
          if (backendOrderId.isNotEmpty) 'order_id': backendOrderId,
          'timeout': 300,
          'prefill': {
            if (phone.isNotEmpty) 'contact': phone,
            if (email.isNotEmpty) 'email': email,
          },
          'theme': {
            'color': '#FC820C', // AppColors.pickleOrange
          },
          'send_sms_hash': true,
          'notes': {
            'requestId': orderData['requestId']?.toString() ??
                appState.activeCheckoutRequestId ??
                '',
            'merchant_order_id': backendOrderId,
            'app': 'PickleO Mobile',
          },
        };

        _razorpay.open(options);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isOpeningOnlinePayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment initiation error: $e'),
            backgroundColor: AppColors.chilliRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final appState = AppStateProvider.of(context);
    setState(() => _isOpeningOnlinePayment = true);

    try {
      final backendOrderId = _pendingOrderData?['orderId']?.toString() ??
          _pendingOrderData?['razorpayOrderId']?.toString() ??
          _pendingOrderData?['id']?.toString() ??
          '';

      final order = await appState.completeOnlineOrder(
        orderData: _pendingOrderData ?? {},
        razorpayPaymentId: response.paymentId ?? '',
        razorpayOrderId: response.orderId ?? backendOrderId,
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) return;
      setState(() => _isOpeningOnlinePayment = false);

      // Show celebration dialog with flower animation and redirect to home
      await OrderSuccessCelebrationDialog.show(context, order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOpeningOnlinePayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finalizing order: $e'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isOpeningOnlinePayment = false);

    final isCancelled = response.code == Razorpay.PAYMENT_CANCELLED ||
        response.message == null ||
        response.message!.trim().isEmpty ||
        response.message!.trim().toLowerCase() == 'undefined' ||
        response.message!.trim().toLowerCase() == 'null' ||
        response.message!.trim().toLowerCase().contains('cancel') ||
        response.message!.trim().toLowerCase().contains('dismiss');

    final String errorMsg = isCancelled
        ? 'Payment cancelled'
        : (response.message != null &&
                response.message!.trim().isNotEmpty &&
                response.message!.trim().toLowerCase() != 'undefined' &&
                response.message!.trim().toLowerCase() != 'null')
            ? response.message!.trim()
            : 'Payment cancelled or could not be completed';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMsg,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppColors.chilliRed,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: () {
            final appState = AppStateProvider.of(context);
            _handleProceedWithOnline(appState);
          },
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isOpeningOnlinePayment = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Redirected to ${response.walletName ?? 'external wallet'}',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: AppColors.leafGreen,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/order.dart';
import 'order_tracking_screen.dart';
import 'tax_invoice_screen.dart';
import 'cart_screen.dart';
import 'products_catalog_screen.dart';
import '../widgets/product_image.dart';
import '../widgets/user_avatar.dart';

class OrdersScreen extends StatefulWidget {
  final bool isTab;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onNavigateHome;

  const OrdersScreen({
    super.key,
    this.isTab = true,
    this.onNavigateTab,
    this.onNavigateHome,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        appState.fetchOrders();
      }
    });
  }

  Color _getStatusBgColor(UserOrder order) {
    final s = order.status.toLowerCase().trim();
    if (order.isCancelled || s == 'cancelled' || s.contains('cancel')) {
      return const Color(0xFFFFEBEE);
    }
    if (order.isReturned || s == 'returned' || s.contains('return')) {
      return const Color(0xFFEDE7F6);
    }
    if (order.isDelivered || s == 'delivered' || s.contains('deliver')) {
      return AppColors.successBg;
    }
    if (s == 'out for delivery' || s.contains('out for delivery')) {
      return const Color(0xFFFFF3E0);
    }
    if (s == 'shipped' || s.contains('transit')) {
      return const Color(0xFFE0F2F1);
    }
    if (s == 'ready for dispatch' || s.contains('dispatch')) {
      return const Color(0xFFE1F5FE);
    }
    if (s == 'packed') {
      return const Color(0xFFFFF3E0);
    }
    if (s == 'processing') {
      return const Color(0xFFFFF8E1);
    }
    if (s == 'confirmed') {
      return const Color(0xFFE8F5E9);
    }
    return const Color(0xFFFFF8E1);
  }

  Color _getStatusTextColor(UserOrder order) {
    final s = order.status.toLowerCase().trim();
    if (order.isCancelled || s == 'cancelled' || s.contains('cancel')) {
      return AppColors.chilliRed;
    }
    if (order.isReturned || s == 'returned' || s.contains('return')) {
      return const Color(0xFF5E35B1);
    }
    if (order.isDelivered || s == 'delivered' || s.contains('deliver')) {
      return AppColors.leafGreen;
    }
    if (s == 'out for delivery' || s.contains('out for delivery')) {
      return AppColors.orangeDark;
    }
    if (s == 'shipped' || s.contains('transit')) {
      return const Color(0xFF00796B);
    }
    if (s == 'ready for dispatch' || s.contains('dispatch')) {
      return const Color(0xFF0277BD);
    }
    if (s == 'packed') {
      return AppColors.pickleOrange;
    }
    if (s == 'processing') {
      return const Color(0xFFE65100);
    }
    if (s == 'confirmed') {
      return const Color(0xFF2E7D32);
    }
    return AppColors.pickleOrange;
  }

  String _getStatusText(UserOrder order) {
    if (order.status.trim().isNotEmpty) {
      return order.status.trim();
    }
    if (order.isCancelled) return 'Cancelled';
    if (order.isReturned) return 'Returned';
    if (order.isDelivered) return 'Delivered';
    return order.isLiveActive ? 'In Progress' : 'Delivered';
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final orders = appState.orders;
    final isLoading = appState.isLoadingOrders && orders.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: widget.isTab
            ? (widget.onNavigateHome != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.textPrimary),
                    onPressed: widget.onNavigateHome,
                  )
                : null)
            : IconButton(
                icon: const Icon(Icons.arrow_back,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Orders',
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
      body: RefreshIndicator(
        onRefresh: () => appState.fetchOrders(forceRefresh: true),
        color: AppColors.pickleOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Orders',
                    style: GoogleFonts.lora(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (orders.isNotEmpty)
                    Text(
                      '${orders.length} order${orders.length == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.pickleOrange,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              else if (orders.isEmpty)
                _buildEmptyOrdersState(context)
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(context, appState, order);
                  },
                ),

              // Pagination Load More
              if (appState.hasMoreOrders) ...[
                const SizedBox(height: 16),
                Center(
                  child: SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _isLoadingMore
                          ? null
                          : () async {
                              setState(() => _isLoadingMore = true);
                              await appState.loadMoreOrders();
                              if (mounted) {
                                setState(() => _isLoadingMore = false);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.pickleOrange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoadingMore
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.pickleOrange,
                              ),
                            )
                          : Text(
                              'Load More Orders',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.pickleOrange,
                              ),
                            ),
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
);
}

  Widget _buildEmptyOrdersState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.leafGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 36,
                color: AppColors.leafGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No orders placed yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your placed orders will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (widget.onNavigateTab != null) {
                  widget.onNavigateTab!(1);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProductsCatalogScreen(),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pickleOrange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Explore Jars',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    AppState appState,
    UserOrder order,
  ) {
    final isActive = order.isLiveActive;
    final orderNumber = order.shortOrderNumber;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingScreen(order: order),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header (Order #, Date and Status Badge)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #$orderNumber',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.dateDisplay,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusBgColor(order),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _getStatusText(order),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _getStatusTextColor(order),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Item Thumbnails + Summary Description + Total
          Row(
            children: [
              if (order.items.isNotEmpty)
                Row(
                  children: [
                    ...order.items.take(2).map((it) {
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ProductImage(
                            product: it.product,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }),
                    if (order.items.length > 2)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '+${order.items.length - 2}',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    size: 22,
                    color: AppColors.leafGreen,
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.summaryDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      order.paymentMethod,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '₹${order.total.toInt()}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Delivery Partner & Tracking Pill
          if (order.isOutForDelivery ||
              order.carrier.isNotEmpty ||
              order.trackingNumber.isNotEmpty ||
              order.deliveryTracking != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: order.isOutForDelivery
                    ? const Color(0xFFFFF3E0)
                    : AppColors.surfaceContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: order.isOutForDelivery
                      ? AppColors.pickleOrange.withValues(alpha: 0.35)
                      : AppColors.borderCard,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    order.isOutForDelivery
                        ? Icons.delivery_dining_rounded
                        : Icons.local_shipping_outlined,
                    size: 16,
                    color: AppColors.orangeDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (order.isOutForDelivery) ...[
                            TextSpan(
                              text: 'Out for Delivery: ',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.orangeDark,
                              ),
                            ),
                          ],
                          if (order.deliveryPartner.isNotEmpty) ...[
                            TextSpan(
                              text: order.deliveryPartner,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                          if (order.trackingNumber.isNotEmpty) ...[
                            TextSpan(
                              text: order.deliveryPartner.isNotEmpty
                                  ? ' • Tracking: ${order.trackingNumber}'
                                  : 'Tracking: ${order.trackingNumber}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons: Track/Rate + Reorder
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => OrderTrackingScreen(order: order),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive
                          ? AppColors.leafGreen
                          : AppColors.surfaceContainer,
                      foregroundColor:
                          isActive ? Colors.white : AppColors.orangeDark,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive
                              ? Icons.local_shipping_outlined
                              : Icons.receipt_outlined,
                          size: 15,
                          color: isActive ? Colors.white : AppColors.orangeDark,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isActive ? 'Track Order' : 'Order Details',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.orangeDark,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () async {
                      await appState.reorder(order);
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CartScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: AppColors.leafGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.replay_rounded,
                          size: 15,
                          color: AppColors.leafGreen,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Reorder',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.leafGreen,
                              height: 1.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // GST Invoice Link
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TaxInvoiceScreen(order: order),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.surfaceHighest,
                    style: BorderStyle.solid,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long,
                      size: 18, color: AppColors.leafGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tax Invoice #${order.shortOrderNumber} · Paid via ${order.paymentMethod}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.leafGreen,
                    ),
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/order.dart';
import '../state/app_state.dart';
import 'rate_delivery_screen.dart';
import 'tax_invoice_screen.dart';
import 'main_navigation.dart';
import '../widgets/product_image.dart';
import '../widgets/user_avatar.dart';

class OrderTrackingScreen extends StatefulWidget {
  final UserOrder order;

  const OrderTrackingScreen({super.key, required this.order});

  OrderTrackingScreen.byOrderId({super.key, required String orderId})
      : order = UserOrder.placeholder(orderId);

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _isRefreshingTracking = false;
  Timer? _pollingTimer;
  bool _isPollingPaused = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
      _startForegroundPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopForegroundPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _isPollingPaused = false;
      // Immediately pull fresh details on resume
      _loadOrderDetails(silent: true);
      _startForegroundPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isPollingPaused = true;
      _stopForegroundPolling();
    }
  }

  void _startForegroundPolling() {
    _pollingTimer?.cancel();
    if (!mounted || _isPollingPaused) return;

    final appState = AppStateProvider.of(context);
    final current = _resolveCurrentOrder(appState);
    if (current.isDelivered || current.isCancelled || current.isReturned) {
      // Terminal state reached: no need to poll
      return;
    }

    // Recommended 30-second foreground GET detail polling
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted || _isPollingPaused) {
        _stopForegroundPolling();
        return;
      }
      final cur = _resolveCurrentOrder(AppStateProvider.of(context));
      if (cur.isDelivered || cur.isCancelled || cur.isReturned) {
        _stopForegroundPolling();
        return;
      }
      _loadOrderDetails(silent: true);
    });
  }

  void _stopForegroundPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  UserOrder _resolveCurrentOrder(AppState appState) {
    return appState.orders.firstWhere(
      (o) =>
          (widget.order.id.isNotEmpty && o.id == widget.order.id) ||
          (widget.order.displayId.isNotEmpty &&
              o.displayId == widget.order.displayId) ||
          (widget.order.id.isNotEmpty && o.displayId == widget.order.id) ||
          (widget.order.displayId.isNotEmpty && o.id == widget.order.displayId),
      orElse: () => widget.order,
    );
  }

  Future<void> _loadOrderDetails({bool silent = false}) async {
    if (!mounted || (_isRefreshing && silent)) return;
    if (!silent) {
      setState(() => _isRefreshing = true);
    }
    final appState = AppStateProvider.of(context);
    final current = _resolveCurrentOrder(appState);
    final idToFetch = current.id.isNotEmpty ? current.id : widget.order.id;
    await appState.fetchOrderDetails(
      idToFetch,
      displayId: current.displayId.isNotEmpty
          ? current.displayId
          : widget.order.displayId,
    );
    if (mounted) {
      if (!silent) {
        setState(() => _isRefreshing = false);
      }
      // Stop polling as soon as order reaches terminal completion
      final updated = _resolveCurrentOrder(appState);
      if (updated.isDelivered || updated.isCancelled || updated.isReturned) {
        _stopForegroundPolling();
      }
    }
  }

  Future<void> _refreshShipmentTracking({bool showToast = true}) async {
    if (!mounted || _isRefreshingTracking) return;
    final appState = AppStateProvider.of(context);
    final current = _resolveCurrentOrder(appState);
    final idToRefresh = current.id.isNotEmpty ? current.id : widget.order.id;

    setState(() => _isRefreshingTracking = true);

    final res = await appState.refreshOrderTracking(
      idToRefresh,
      force: true,
    );

    if (!mounted) return;
    setState(() => _isRefreshingTracking = false);

    if (showToast) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      if (res.success) {
        final providerName = res.data?.deliveryTracking?.provider.isNotEmpty == true
            ? res.data!.deliveryTracking!.provider
            : (res.data?.carrier.isNotEmpty == true
                ? res.data!.carrier
                : 'carrier');
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Latest shipment status updated with $providerName',
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.leafGreen,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    res.message ??
                        'Unable to refresh live tracking at this moment.',
                    style:
                        GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFC0392B),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatTrackingSnapshotTime(DeliveryTracking dt) {
    if (dt.checkedAt != null) {
      final local = dt.checkedAt!.toLocal();
      final hour = local.hour > 12
          ? local.hour - 12
          : (local.hour == 0 ? 12 : local.hour);
      final minute = local.minute.toString().padLeft(2, '0');
      final ampm = local.hour >= 12 ? 'PM' : 'AM';
      final provider = dt.provider.isNotEmpty ? dt.provider : 'carrier';
      return 'Verified with $provider at $hour:$minute $ampm';
    }
    if (dt.updatedAt != null) {
      final local = dt.updatedAt!.toLocal();
      final hour = local.hour > 12
          ? local.hour - 12
          : (local.hour == 0 ? 12 : local.hour);
      final minute = local.minute.toString().padLeft(2, '0');
      final ampm = local.hour >= 12 ? 'PM' : 'AM';
      return 'Carrier update: $hour:$minute $ampm';
    }
    return 'Carrier snapshot recorded';
  }

  String _getOrderBannerTitle(UserOrder order) {
    if (order.isCancelled) return 'Order Cancelled';
    if (order.isReturned) return 'Order Returned';
    if (order.isDelivered) return 'Delivered! Enjoy your jars';
    final s = order.status.trim().toLowerCase();
    if (s == 'out for delivery' || s.contains('out for delivery')) {
      return 'Out for Delivery!';
    }
    if (s == 'pending') return 'Order Placed (Pending)';
    if (s == 'confirmed') return 'Order Confirmed!';
    if (s == 'processing') return 'Preparing Your Pickles...';
    if (s == 'packed') return 'Packed in Ceramic Martabans';
    if (s == 'ready for dispatch') return 'Ready for Dispatch';
    if (s == 'shipped') return 'Shipped & On The Way';
    if (order.status.trim().isNotEmpty &&
        order.status.trim().toLowerCase() != 'arriving tomorrow') {
      return order.status.trim();
    }
    return order.orderStep == 0
        ? 'Order Placed Successfully!'
        : 'Your order is on its way';
  }

  String _buildTrackingShareMessage(UserOrder order) {
    final partner = order.deliveryPartner.isNotEmpty
        ? order.deliveryPartner
        : (order.carrier.isNotEmpty ? order.carrier : '');
    final tracking = order.trackingNumber;
    final orderNum = order.shortOrderNumber;

    if (tracking.isNotEmpty && partner.isNotEmpty) {
      return 'Hi! My Pickleo order #$orderNum is out for delivery with $partner.\nTracking Number: $tracking\nTrack your order in Pickleo app!';
    } else if (tracking.isNotEmpty) {
      return 'Hi! My Pickleo order #$orderNum tracking number is: $tracking.\nTrack your order in Pickleo app!';
    } else if (partner.isNotEmpty) {
      return 'Hi! My Pickleo order #$orderNum is out for delivery with $partner.';
    } else {
      return 'Hi! My Pickleo order #$orderNum is out for delivery.';
    }
  }

  Future<void> _handleTrackShipment(BuildContext context, UserOrder order) async {
    if (order.hasValidTrackingUrl && order.effectiveTrackingUrl != null) {
      final uri = Uri.parse(order.effectiveTrackingUrl!);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open tracking page'),
          backgroundColor: AppColors.orangeDark,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final partner = order.deliveryPartner.isNotEmpty
        ? order.deliveryPartner
        : (order.carrier.isNotEmpty ? order.carrier : 'carrier');

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Live tracking link will be active once dispatched by $partner',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.leafGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );

    if (!_isRefreshingTracking &&
        (order.carrier.toLowerCase() == 'pidge' ||
            order.deliveryTracking?.provider.toLowerCase() == 'pidge')) {
      _refreshShipmentTracking(showToast: false);
    }
  }

  Future<void> _shareViaWhatsApp(BuildContext context, UserOrder order) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = _buildTrackingShareMessage(order);
    final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
    final webWaUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');

    // Immediate backup copy to clipboard
    Clipboard.setData(ClipboardData(text: text));

    messenger?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text('Opening WhatsApp with tracking details...'),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF25D366),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(webWaUri)) {
        await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _shareViaSms(BuildContext context, UserOrder order) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = _buildTrackingShareMessage(order);
    final smsUri = Uri(
      scheme: 'sms',
      queryParameters: <String, String>{'body': text},
    );

    // Immediate backup copy to clipboard
    Clipboard.setData(ClipboardData(text: text));

    messenger?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(
              Icons.sms_outlined,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text('Opening messaging app with tracking details...'),
            ),
          ],
        ),
        backgroundColor: AppColors.leafGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      final fallbackSms = Uri.parse('sms:?body=${Uri.encodeComponent(text)}');
      if (await canLaunchUrl(fallbackSms)) {
        await launchUrl(fallbackSms, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _callCaptain(UserOrder order) async {
    final phone = order.courierPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isNotEmpty) {
      final telUri = Uri.parse('tel:$phone');
      try {
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
          return;
        }
      } catch (_) {}
    }
    if (!mounted) return;
    final contact = order.courierPhone.isNotEmpty ? order.courierPhone : order.courierName;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling Courier Captain $contact...'),
        backgroundColor: AppColors.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showShareTrackingSheet(BuildContext context, UserOrder order) {
    final partner = order.deliveryPartner.isNotEmpty
        ? order.deliveryPartner
        : (order.carrier.isNotEmpty ? order.carrier : 'Delivery Partner');
    final tracking = order.trackingNumber;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.share_rounded,
                        size: 20,
                        color: AppColors.leafGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Share Tracking Details',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Order #${order.shortOrderNumber}${partner.isNotEmpty ? ' • $partner' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tracking.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F8),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tag_rounded, size: 16, color: AppColors.pickleOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Tracking Number: ',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tracking,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8EE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF25D366),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'WhatsApp',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Share tracking details directly via WhatsApp',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareViaWhatsApp(context, order);
                  },
                ),
                const Divider(height: 16, thickness: 0.8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sms_rounded,
                      color: AppColors.leafGreen,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Default Messages (SMS)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Share using your phone\'s inbuilt message app',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _shareViaSms(context, order);
                  },
                ),
                const Divider(height: 16, thickness: 0.8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.copy_rounded,
                      color: AppColors.pickleOrange,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    'Copy Details',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Copy full tracking information to clipboard',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textTertiary),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final message = _buildTrackingShareMessage(order);
                    await Clipboard.setData(ClipboardData(text: message));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text('Tracking details copied to clipboard!'),
                          ],
                        ),
                        backgroundColor: AppColors.leafGreen,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final currentOrder = _resolveCurrentOrder(appState);

    final displayOrderNum = currentOrder.shortOrderNumber;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainNavigation()),
                (r) => false,
              );
            }
          },
        ),
        title: Text(
          'Order Tracking',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.pickleOrange,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _isRefreshing ? null : _loadOrderDetails,
            tooltip: 'Refresh order details',
          ),
          const UserAvatar(radius: 16),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: RefreshIndicator(
          onRefresh: _loadOrderDetails,
          color: AppColors.pickleOrange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).padding.bottom + 80,
            ),
            child: Column(
              children: [
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(
                    color: AppColors.pickleOrange,
                    backgroundColor: AppColors.surfaceLow,
                    minHeight: 2,
                  ),
                ),
            // Order Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: currentOrder.isCancelled
                    ? const Color(0xFFFFDAD6)
                    : (currentOrder.isReturned
                        ? const Color(0xFFEDE7F6)
                        : (currentOrder.isDelivered
                            ? const Color(0xFFDFF3E6)
                            : AppColors.surfaceLow)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: currentOrder.isCancelled
                          ? const Color(0xFFC0392B)
                          : (currentOrder.isReturned
                              ? const Color(0xFF5E35B1)
                              : AppColors.leafGreen),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      currentOrder.isCancelled
                          ? Icons.close
                          : (currentOrder.isReturned
                              ? Icons.keyboard_return
                              : (currentOrder.isDelivered
                                  ? Icons.done_all
                                  : Icons.check)),
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getOrderBannerTitle(currentOrder),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lora(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: currentOrder.isCancelled
                          ? const Color(0xFF7A1F14)
                          : (currentOrder.isReturned
                              ? const Color(0xFF4527A0)
                              : AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Order #$displayOrderNum • ${currentOrder.dateDisplay}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: currentOrder.isCancelled
                          ? const Color(0xFFA3382A)
                          : (currentOrder.isReturned
                              ? const Color(0xFF5E35B1)
                              : AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (currentOrder.isCancelled || currentOrder.isReturned)
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          currentOrder.isCancelled
                              ? Icons.currency_rupee
                              : (currentOrder.isReturned
                                  ? Icons.assignment_return
                                  : (currentOrder.isDelivered
                                      ? Icons.check_circle
                                      : Icons.schedule)),
                          size: 16,
                          color: currentOrder.isCancelled
                              ? const Color(0xFF7A1F14)
                              : (currentOrder.isReturned
                                  ? const Color(0xFF4527A0)
                                  : AppColors.onSecondaryContainer),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            currentOrder.isCancelled
                                ? 'Refund of ₹${currentOrder.total.toInt()} to ${currentOrder.paymentMethod.replaceAll(' (COD)', '')} in 3–5 days'
                                : (currentOrder.isReturned
                                    ? 'Returned • Refund processed for ₹${currentOrder.total.toInt()}'
                                    : (currentOrder.isDelivered
                                        ? 'Delivered ${currentOrder.deliveredDateFormatted}'
                                        : (currentOrder.isOutForDelivery
                                            ? 'Arriving Today • Out with ${currentOrder.deliveryPartner.isNotEmpty ? currentOrder.deliveryPartner : "delivery partner"}'
                                            : 'Arriving ${currentOrder.deliverySlot.isNotEmpty ? currentOrder.deliverySlot : "Tomorrow, 2:00 PM – 4:00 PM"}'))),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: currentOrder.isCancelled
                                  ? const Color(0xFF7A1F14)
                                  : (currentOrder.isReturned
                                      ? const Color(0xFF4527A0)
                                      : AppColors.onSecondaryContainer),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Fulfilment & Delivery Slot Card
            if (currentOrder.fulfilmentCentre.isNotEmpty ||
                currentOrder.deliverySlot.isNotEmpty ||
                currentOrder.isDelivered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Column(
                  children: [
                    if (currentOrder.fulfilmentCentre.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.warehouse_rounded,
                                size: 20, color: AppColors.leafGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fulfilment Centre',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  currentOrder.fulfilmentCentre,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (currentOrder.fulfilmentCentre.isNotEmpty &&
                        (currentOrder.deliverySlot.isNotEmpty || currentOrder.isDelivered))
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                    if (currentOrder.isDelivered)
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_circle_rounded,
                                size: 20, color: AppColors.leafGreen),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivered At',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  currentOrder.deliveredDateFormatted,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (currentOrder.deliverySlot.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.pickleOrange
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.access_time_filled_rounded,
                                size: 20, color: AppColors.pickleOrange),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delivery Slot',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  currentOrder.deliverySlot,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
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
              const SizedBox(height: 14),
            ],

            // Delivery Address Card
            if (currentOrder.deliveryAddress.fullAddress.trim().isNotEmpty &&
                currentOrder.deliveryAddress.flatHouseBuilding != 'Doorstep' &&
                currentOrder.deliveryAddress.streetArea != 'Selected Address') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          size: 20, color: AppColors.leafGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Delivery Address',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (currentOrder.deliveryAddress.label.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    currentOrder.deliveryAddress.label,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.leafGreen,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          if (currentOrder.deliveryAddress.receiverName.isNotEmpty)
                            Text(
                              currentOrder.deliveryAddress.receiverName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          Text(
                            currentOrder.deliveryAddress.fullAddress,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          if (currentOrder.deliveryAddress.phone.isNotEmpty)
                            Text(
                              'Phone: ${currentOrder.deliveryAddress.phone}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ] else if (currentOrder.addressId.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_rounded,
                          size: 20, color: AppColors.leafGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Address ID',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            currentOrder.addressId,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Delivery Partner & Tracking Card (Displayed when assigned, out for delivery, tracking available, or delivered)
            if (currentOrder.hasCourierAssigned ||
                currentOrder.isOutForDelivery ||
                currentOrder.carrier.isNotEmpty ||
                currentOrder.trackingNumber.isNotEmpty ||
                currentOrder.deliveryTracking != null ||
                currentOrder.isDelivered) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: currentOrder.isDelivered
                        ? AppColors.leafGreen.withValues(alpha: 0.35)
                        : (currentOrder.isOutForDelivery
                            ? AppColors.pickleOrange.withValues(alpha: 0.35)
                            : AppColors.borderCard),
                    width: (currentOrder.isOutForDelivery || currentOrder.isDelivered) ? 1.5 : 1,
                  ),
                  boxShadow: (currentOrder.isOutForDelivery || currentOrder.isDelivered)
                      ? [
                          BoxShadow(
                            color: (currentOrder.isDelivered
                                    ? AppColors.leafGreen
                                    : AppColors.pickleOrange)
                                .withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: currentOrder.isDelivered
                                ? const Color(0xFFE8F5E9)
                                : (currentOrder.isOutForDelivery
                                    ? const Color(0xFFFFF3E0)
                                    : AppColors.surfaceContainer),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            currentOrder.isDelivered
                                ? Icons.verified_rounded
                                : (currentOrder.isOutForDelivery
                                    ? Icons.delivery_dining_rounded
                                    : Icons.local_shipping_rounded),
                            size: 24,
                            color: currentOrder.isDelivered
                                ? AppColors.leafGreen
                                : AppColors.orangeDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      currentOrder.deliveryPartner.isNotEmpty
                                          ? currentOrder.deliveryPartner
                                          : (currentOrder.courierName.isNotEmpty
                                              ? currentOrder.courierName
                                              : 'Delivery Partner'),
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (currentOrder.carrier.isNotEmpty ||
                                      currentOrder.deliveryTracking?.provider.isNotEmpty == true) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Verified',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.leafGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                currentOrder.courierName.isNotEmpty &&
                                        currentOrder.courierName != currentOrder.deliveryPartner
                                    ? 'Captain: ${currentOrder.courierName}${currentOrder.courierRating > 0 ? " • ${currentOrder.courierRating} ★" : ""}'
                                    : 'Delivery Partner${currentOrder.courierRating > 0 ? " • ${currentOrder.courierRating} ★" : ""}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: currentOrder.isDelivered
                                ? const Color(0xFFE8F5E9)
                                : (currentOrder.isOutForDelivery
                                    ? const Color(0xFFFFF3E0)
                                    : AppColors.surfaceHigh),
                            borderRadius: BorderRadius.circular(999),
                            border: currentOrder.isDelivered
                                ? Border.all(
                                    color: AppColors.leafGreen.withValues(alpha: 0.3))
                                : (currentOrder.isOutForDelivery
                                    ? Border.all(
                                        color: AppColors.pickleOrange.withValues(alpha: 0.3))
                                    : null),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (currentOrder.isOutForDelivery) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.orangeDark,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ] else if (currentOrder.isDelivered) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: AppColors.leafGreen,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                currentOrder.deliveryTracking?.formattedDisplayStatus.isNotEmpty == true
                                    ? currentOrder.deliveryTracking!.formattedDisplayStatus
                                    : (currentOrder.isDelivered
                                        ? 'Delivered'
                                        : (currentOrder.isOutForDelivery
                                            ? 'Out for Delivery'
                                            : 'On Schedule')),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: currentOrder.isDelivered
                                      ? AppColors.leafGreen
                                      : (currentOrder.isOutForDelivery
                                          ? AppColors.orangeDark
                                          : AppColors.onSecondaryContainer),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Tracking Number Box
                    if (currentOrder.trackingNumber.isNotEmpty ||
                        (currentOrder.deliveryTracking?.shipmentId.isNotEmpty == true)) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderCard),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainer,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        Icons.tag_rounded,
                                        size: 14,
                                        color: AppColors.pickleOrange,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Tracking Number',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final trackNum = currentOrder.trackingNumber.isNotEmpty
                                        ? currentOrder.trackingNumber
                                        : currentOrder.deliveryTracking!.shipmentId;
                                    Clipboard.setData(ClipboardData(text: trackNum));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle_outline,
                                                color: Colors.white, size: 18),
                                            const SizedBox(width: 8),
                                            Text('Tracking # $trackNum copied!'),
                                          ],
                                        ),
                                        backgroundColor: AppColors.leafGreen,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded,
                                      size: 13, color: AppColors.pickleOrange),
                                  label: Text(
                                    'Copy',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.pickleOrange,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    elevation: 0,
                                    side: const BorderSide(color: AppColors.borderCard),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () {
                                final trackNum = currentOrder.trackingNumber.isNotEmpty
                                    ? currentOrder.trackingNumber
                                    : currentOrder.deliveryTracking!.shipmentId;
                                Clipboard.setData(ClipboardData(text: trackNum));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline,
                                            color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text('Tracking # $trackNum copied!'),
                                      ],
                                    ),
                                    backgroundColor: AppColors.leafGreen,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFECECEC)),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    currentOrder.trackingNumber.isNotEmpty
                                        ? currentOrder.trackingNumber
                                        : currentOrder.deliveryTracking!.shipmentId,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Pidge Tracking Code if different from shipmentId
                    if (currentOrder.deliveryTracking?.trackingCode.isNotEmpty == true &&
                        currentOrder.deliveryTracking!.trackingCode != currentOrder.trackingNumber &&
                        currentOrder.deliveryTracking!.trackingCode != currentOrder.deliveryTracking!.shipmentId) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'Carrier Tracking Code: ${currentOrder.deliveryTracking!.trackingCode}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],

                    // Carrier Checked/Updated Snapshot & Refresh Action
                    if (currentOrder.deliveryTracking?.checkedAt != null ||
                        currentOrder.deliveryTracking?.updatedAt != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.borderCard.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _formatTrackingSnapshotTime(currentOrder.deliveryTracking!),
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _isRefreshingTracking
                                  ? null
                                  : () => _refreshShipmentTracking(showToast: true),
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isRefreshingTracking)
                                      const SizedBox(
                                        width: 11,
                                        height: 11,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          color: AppColors.orangeDark,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.refresh_rounded,
                                          size: 13, color: AppColors.orangeDark),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isRefreshingTracking ? 'Updating...' : 'Refresh',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.orangeDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (currentOrder.carrier.toLowerCase() == 'pidge' ||
                        currentOrder.deliveryTracking?.provider.toLowerCase() == 'pidge') ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _isRefreshingTracking
                              ? null
                              : () => _refreshShipmentTracking(showToast: true),
                          icon: _isRefreshingTracking
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.8,
                                    color: AppColors.orangeDark,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded,
                                  size: 14, color: AppColors.orangeDark),
                          label: Text(
                            _isRefreshingTracking ? 'Refreshing...' : 'Refresh Live Status',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.orangeDark,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (currentOrder.courierPhone.isNotEmpty) ...[
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: () => _callCaptain(currentOrder),
                                icon: const Icon(Icons.call,
                                    size: 16, color: AppColors.textPrimary),
                                label: Text(
                                  'Call Captain',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceLow,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: () => _showShareTrackingSheet(context, currentOrder),
                                icon: const Icon(Icons.share_rounded,
                                    size: 16, color: Colors.white),
                                label: Text(
                                  'Share',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.leafGreen,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleTrackShipment(context, currentOrder),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Track',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.pickleOrange,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Tracking Status Timeline
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
                      Text(
                        'Tracking Status',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.leafGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Live Updates',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Timeline Steps
                  Column(
                    children: List.generate(currentOrder.trackingSteps.length, (index) {
                      final step = currentOrder.trackingSteps[index];
                      final isLast = index == currentOrder.trackingSteps.length - 1;
                      final isDone = step.state == 'done';
                      final isNow = step.state == 'now';

                      final dotBg = isDone
                          ? AppColors.leafGreen
                          : (isNow ? AppColors.pickleOrange : AppColors.outlineVariant);
                      final lineBg = isDone
                          ? AppColors.leafGreen
                          : AppColors.surfaceHighest;
                      final titleColor = isNow
                          ? AppColors.orangeDark
                          : (isDone
                              ? AppColors.textPrimary
                              : AppColors.textSecondary);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: dotBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isDone
                                      ? Icons.check
                                      : (isNow
                                          ? Icons.local_shipping
                                          : Icons.circle_outlined),
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 2,
                                  height: 38,
                                  color: lineBg,
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          step.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: titleColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        step.time,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step.sub,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Order Summary
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
                      Text(
                        'Order Summary',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaxInvoiceScreen(order: currentOrder),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.download,
                                size: 16, color: AppColors.leafGreen),
                            const SizedBox(width: 3),
                            Text(
                              'GST Invoice',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.leafGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Order items list
                  if (currentOrder.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              size: 22,
                              color: AppColors.leafGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentOrder.summaryDescription,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Placed via ${currentOrder.paymentMethod}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${currentOrder.total.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...currentOrder.items.map((it) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProductImage(
                                product: it.product,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.product.name.trim().isNotEmpty
                                        ? it.product.name.trim()
                                        : 'Artisan Kitchen Jar',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${it.selectedWeight} • Qty: ${it.quantity}${it.unitPrice > 0 ? " • ₹${it.unitPrice.toInt()}/ea" : ""}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Text(
                            '₹${it.totalPrice.toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Bill Breakdown
                  Text(
                    'Bill Details',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Item Total',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${currentOrder.subtotal.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (currentOrder.discount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Coupon Discount',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.leafGreen,
                          ),
                        ),
                        Text(
                          '-₹${currentOrder.discount.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.leafGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delivery Fee',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        currentOrder.deliveryFee == 0
                            ? 'FREE'
                            : '₹${currentOrder.deliveryFee.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: currentOrder.deliveryFee == 0
                              ? AppColors.leafGreen
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (currentOrder.packagingFee > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Packaging Fee',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '₹${currentOrder.packagingFee.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Total & Payment Information
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'via ${currentOrder.paymentMethod}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (currentOrder.paymentStatus.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: currentOrder.paymentStatus
                                                .toLowerCase()
                                                .contains('pending')
                                            ? const Color(0xFFFFF3E0)
                                            : AppColors.successBg,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        currentOrder.paymentStatus,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: currentOrder.paymentStatus
                                                  .toLowerCase()
                                                  .contains('pending')
                                              ? AppColors.pickleOrange
                                              : AppColors.leafGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '₹${currentOrder.total.toInt()}',
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentOrder.pointsLot != null || currentOrder.spicePointsEarned > 0) ...[
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final lot = currentOrder.pointsLot;
                        final pts = lot?.points ?? currentOrder.spicePointsEarned;
                        final state = lot?.state ??
                            (currentOrder.isDelivered
                                ? 'credited'
                                : (currentOrder.isCancelled ? 'voided' : 'pending'));

                        Color bg;
                        Color text;
                        IconData icon;
                        String label;
                        if (state == 'credited') {
                          bg = const Color(0xFFDFF3E6);
                          text = const Color(0xFF0F5132);
                          icon = Icons.check_circle_outline;
                          label = '+$pts Spice Points Credited';
                        } else if (state == 'voided' || state == 'reversed') {
                          bg = const Color(0xFFFEE2E2);
                          text = const Color(0xFFB91C1C);
                          icon = Icons.cancel_outlined;
                          label = '$pts Points ${state == 'reversed' ? 'Reversed' : 'Voided'}';
                        } else {
                          bg = const Color(0xFFFEF3C7);
                          text = const Color(0xFFD97706);
                          icon = Icons.hourglass_top_outlined;
                          label = '+$pts Spice Points Pending (Credited on delivery)';
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, size: 16, color: text),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: text,
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
            const SizedBox(height: 16),

            // Delivery Experience Rating Section
            if (currentOrder.rating != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFDF8), Color(0xFFFFF6EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFD59E), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pickleOrange.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE8CC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: AppColors.pickleOrange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your Delivery Rating',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Thank you for your feedback!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Edit button to update review
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RateDeliveryScreen(
                                  orderId: currentOrder.id,
                                  initialRating: currentOrder.rating,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFFD59E)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_outlined,
                                    size: 13, color: AppColors.pickleOrange),
                                const SizedBox(width: 4),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.pickleOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Stars row
                    Row(
                      children: [
                        Row(
                          children: List.generate(5, (starIdx) {
                            final isFilled = starIdx < currentOrder.rating!.rating;
                            return Icon(
                              isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 22,
                              color: isFilled ? const Color(0xFFFFB300) : const Color(0xFFD0D0D0),
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${currentOrder.rating!.rating}.0 / 5.0',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF8A5300),
                          ),
                        ),
                        if (currentOrder.rating!.rewardPoints > 0) ...[
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.stars_rounded, size: 14, color: AppColors.leafGreen),
                                const SizedBox(width: 4),
                                Text(
                                  '+${currentOrder.rating!.rewardPoints} Spice Pts',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.leafGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Tags chips if any
                    if (currentOrder.rating!.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: currentOrder.rating!.tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFE0B2)),
                            ),
                            child: Text(
                              tag,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6D4C41),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    // Feedback text if any
                    if (currentOrder.rating!.feedback != null &&
                        currentOrder.rating!.feedback!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF0E5D8)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.format_quote_rounded,
                                size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                currentOrder.rating!.feedback!,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textPrimary,
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
              const SizedBox(height: 12),
            ] else if (currentOrder.isDelivered) ...[
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RateDeliveryScreen(orderId: currentOrder.id),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star, size: 18, color: Colors.white),
                  label: Text(
                    'Rate Your Delivery Experience',
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
              const SizedBox(height: 10),
            ],

            // Explore More Artisanal Pickles button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainNavigation()),
                    (r) => false,
                  );
                },
                icon: const Icon(Icons.storefront,
                    size: 18, color: AppColors.leafGreen),
                label: Text(
                  'Explore More Artisanal Pickles',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.leafGreen,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.leafGreen, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Cancellation state handling
            if (currentOrder.canCancel) ...[
              GestureDetector(
                onTap: () => _showCancelOrderSheet(context, appState, currentOrder),
                child: Text(
                  'Cancel Order · free cancellation before packing',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.chilliRed,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.chilliRed,
                  ),
                ),
              ),
            ] else if (currentOrder.cancelClosed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderCard),
                ),
                child: Text(
                  'Cancellation closed — your jar is already packed in its martaban. Need help? Tap Help & Support in Account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ] else if (currentOrder.isCancelled) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Order #${currentOrder.displayId.isNotEmpty ? currentOrder.displayId : currentOrder.id} cancelled. 100% refund initiated to ${currentOrder.paymentMethod}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF7A1F14),
                  ),
                ),
              ),
            ] else if (currentOrder.isReturned) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE7F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Order #${currentOrder.displayId.isNotEmpty ? currentOrder.displayId : currentOrder.id} has been returned. Refund processed to ${currentOrder.paymentMethod}.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4527A0),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
);
}

  void _showCancelOrderSheet(BuildContext context, AppState appState, UserOrder currentOrder) {
    String selectedReason = 'Ordered by mistake';
    final otherController = TextEditingController();
    String? validationError;
    bool isSubmitting = false;

    final reasons = [
      'Ordered by mistake',
      'Want to change address',
      'Delivery is too late',
      'Found a better price',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
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
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: effectiveBottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Cancel this order?',
                            style: GoogleFonts.lora(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          GestureDetector(
                            onTap: isSubmitting
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
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
                      Text(
                        "Order #${currentOrder.displayId.isNotEmpty ? currentOrder.displayId : currentOrder.id} hasn't been packed yet, so cancellation is free. ₹${currentOrder.total.toInt()} will be refunded to ${currentOrder.paymentMethod} within 3–5 working days.",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Reason for cancelling',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reasons.map((r) {
                          final isSelected = r == selectedReason;
                          return GestureDetector(
                            onTap: isSubmitting
                                ? null
                                : () => setSheetState(() {
                                      selectedReason = r;
                                      validationError = null;
                                    }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2C160E) : const Color(0xFFFFF1ED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                r,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected ? Colors.white : const Color(0xFF2C160E),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (selectedReason == 'Other') ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: otherController,
                          maxLength: 50,
                          maxLines: 2,
                          minLines: 1,
                          enabled: !isSubmitting,
                          textInputAction: TextInputAction.done,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          onChanged: (val) {
                            if (validationError != null && val.trim().isNotEmpty) {
                              setSheetState(() => validationError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Reason for cancellation *',
                            labelStyle: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: validationError != null
                                  ? const Color(0xFFC0392B)
                                  : AppColors.textSecondary,
                            ),
                            hintText: 'Enter reason (mandatory, max 50 chars)',
                            hintStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.textSecondary.withValues(alpha: 0.6),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            errorText: validationError,
                            errorStyle: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFFC0392B),
                            ),
                            counterStyle: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFFFDBD0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: validationError != null
                                    ? const Color(0xFFC0392B)
                                    : const Color(0xFFFFDBD0),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: validationError != null
                                    ? const Color(0xFFC0392B)
                                    : AppColors.leafGreen,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(sheetContext).pop(),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.leafGreen, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(0, 48),
                              ),
                              child: Text(
                                'Keep Order',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.leafGreen,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSubmitting
                                  ? null
                                  : () async {
                                      String reasonToSubmit = selectedReason;
                                      if (selectedReason == 'Other') {
                                        final customReason = otherController.text.trim();
                                        if (customReason.isEmpty) {
                                          setSheetState(() {
                                            validationError = 'Please enter a cancellation reason';
                                          });
                                          return;
                                        }
                                        reasonToSubmit = customReason;
                                      }

                                      setSheetState(() => isSubmitting = true);

                                      final orderIdToCancel = currentOrder.id.isNotEmpty
                                          ? currentOrder.id
                                          : currentOrder.displayId;

                                      final resp = await appState.cancelOrder(
                                        orderIdToCancel,
                                        reason: reasonToSubmit,
                                      );

                                      if (!sheetContext.mounted) return;
                                      Navigator.of(sheetContext).pop();

                                      if (!context.mounted) return;
                                      if (resp.success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Order cancelled · refund initiated',
                                              style: GoogleFonts.poppins(color: Colors.white),
                                            ),
                                            backgroundColor: const Color(0xFFC0392B),
                                            duration: const Duration(seconds: 3),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              (resp.message != null && resp.message!.isNotEmpty)
                                                  ? resp.message!
                                                  : 'Failed to cancel order',
                                              style: GoogleFonts.poppins(color: Colors.white),
                                            ),
                                            backgroundColor: const Color(0xFFC0392B),
                                            duration: const Duration(seconds: 4),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC0392B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                minimumSize: const Size(0, 48),
                              ),
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Cancel Order',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      otherController.dispose();
    });
  }
}

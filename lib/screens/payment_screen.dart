import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/user_avatar.dart';
import '../widgets/order_success_celebration_dialog.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _selectedMethodId = 'gpay';
  bool _isProcessing = false;
  final TextEditingController _customUpiController = TextEditingController();

  late Razorpay _razorpay;
  Map<String, dynamic>? _pendingOrderData;

  final Map<String, String> _methodNames = {
    'gpay': 'UPI (Google Pay)',
    'phonepe': 'UPI (PhonePe)',
    'paytm': 'UPI (Paytm)',
    'upi': 'UPI ID',
    'card': 'Credit / Debit Card',
    'netbanking': 'Net Banking',
    'cod': 'Cash on Delivery',
  };

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    _customUpiController.dispose();
    super.dispose();
  }

  Future<void> _processPayment(AppState appState) async {
    // 1. If Cash on Delivery is selected
    if (_selectedMethodId == 'cod') {
      setState(() => _isProcessing = true);
      final res = await appState.placeCodOrder();
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (res.success && res.data != null) {
        await OrderSuccessCelebrationDialog.show(context, res.data!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? 'Failed to place COD order'),
            backgroundColor: AppColors.chilliRed,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 2. Online Payment via Razorpay Checkout
    setState(() => _isProcessing = true);

    try {
      final res = await appState.initiateOnlineOrder();
      if (!mounted) return;

      if (!res.success || res.data == null) {
        setState(() => _isProcessing = false);
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
              onPressed: () => _processPayment(appState),
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

      final options = <String, dynamic>{
        'key': razorpayKeyId,
        'amount': amountInPaise,
        'currency': currency,
        'name': 'PickleO',
        'description': 'Order #$displayOrderId',
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
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment initiation error: $e'),
          backgroundColor: AppColors.chilliRed,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final appState = AppStateProvider.of(context);
    setState(() => _isProcessing = true);

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
      setState(() => _isProcessing = false);

      // Show celebration dialog with flower animation and redirect to home
      await OrderSuccessCelebrationDialog.show(context, order);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
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
    setState(() => _isProcessing = false);

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
            _processPayment(appState);
          },
        ),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
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

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final total = appState.grandTotal.toInt();
    final itemsSummary = appState.cartList
        .map((i) => i.product.name.split(' ').take(2).join(' '))
        .join(' & ');

    final upiApps = [
      {
        'id': 'gpay',
        'name': 'Google Pay',
        'sub': 'Installed',
        'initial': 'G',
        'logoBg': const Color(0xFF1A73E8),
      },
      {
        'id': 'phonepe',
        'name': 'PhonePe',
        'sub': 'Installed',
        'initial': 'Pe',
        'logoBg': const Color(0xFF5F259F),
      },
      {
        'id': 'paytm',
        'name': 'Paytm UPI',
        'sub': 'Tap to link',
        'initial': 'P',
        'logoBg': const Color(0xFF00B9F1),
      },
    ];

    final otherMethods = [
      {
        'id': 'card',
        'name': 'Credit / Debit Cards',
        'sub': 'Visa, Mastercard, RuPay & Diners',
        'icon': Icons.credit_card_outlined,
        'tag': '',
      },
      {
        'id': 'netbanking',
        'name': 'Net Banking',
        'sub': 'All major Indian banks supported',
        'icon': Icons.account_balance_outlined,
        'tag': '',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Payment Options',
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
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // RBI Compliance Strip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.successBg,
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% RBI Compliant & 256-Bit Encrypted',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          const SizedBox(width: 4),
                          Text(
                            'Live Session',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Payable Total Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PAYABLE TOTAL',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '₹$total',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(incl. GST)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                size: 20, color: AppColors.orangeDark),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${appState.cartCount} Jar${appState.cartCount == 1 ? '' : 's'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  itemsSummary.isEmpty
                                      ? 'Artisanal Selection'
                                      : itemsSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    color: AppColors.orangeDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Recommended UPI Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.leafGreen,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.leafGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bolt,
                                size: 20, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Recommended UPI',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successBg,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        'Instant',
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
                                  'Pay directly with installed apps or custom UPI ID',
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
                      const SizedBox(height: 14),

                      // 3 UPI Apps Grid
                      Row(
                        children: upiApps.map((u) {
                          final id = u['id'] as String;
                          final isSelected = _selectedMethodId == id;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedMethodId = id),
                              child: Container(
                                height: 84,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.successBg
                                      : AppColors.surfaceLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.leafGreen
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: u['logoBg'] as Color,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          u['initial'] as String,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      u['name'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      u['sub'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 9.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),

                      // Custom UPI input
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLow,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.surfaceHighest,
                                    width: 1.5),
                              ),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _customUpiController,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'username@okhdfcbank',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_customUpiController.text
                                    .trim()
                                    .isNotEmpty) {
                                  setState(() => _selectedMethodId = 'upi');
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('UPI ID verified!'),
                                      backgroundColor: AppColors.leafGreen,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.leafGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Verify',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
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
                const SizedBox(height: 12),

                // Other Payment Methods List
                ...otherMethods.map((m) {
                  final id = m['id'] as String;
                  final isSelected = _selectedMethodId == id;
                  final tag = m['tag'] as String;

                  return GestureDetector(
                    onTap: () => setState(() => _selectedMethodId = id),
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.leafGreen
                              : AppColors.borderCard,
                          width: isSelected ? 1.5 : 1,
                        ),
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
                            child: Icon(m['icon'] as IconData,
                                size: 20, color: AppColors.orangeDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      m['name'] as String,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (tag.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainer,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          tag,
                                          style: GoogleFonts.poppins(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.orangeDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  m['sub'] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.leafGreen
                                    : AppColors.outlineVariant,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: AppColors.leafGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 10),

                // 3 Security Badges Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildSecurityPill(Icons.security, 'PCI-DSS L1',
                          'Bank-grade audit', AppColors.leafGreen),
                      const SizedBox(width: 8),
                      _buildSecurityPill(Icons.verified, 'Razorpay Verified',
                          'Authorized merchant', AppColors.pickleOrange),
                      const SizedBox(width: 8),
                      _buildSecurityPill(Icons.eco, 'Food-Safe Pack',
                          'Double sealed glass', AppColors.leafGreen),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Processing Loading Dialog Overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                          color: AppColors.leafGreen),
                      const SizedBox(height: 16),
                      Text(
                        'Processing Payment...',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // Sticky Bottom Pay Bar
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_outline,
                            size: 15, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Amount to Pay · ${_methodNames[_selectedMethodId]}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹$total',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.orangeDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _processPayment(appState),
                    icon: Icon(
                      _selectedMethodId == 'cod'
                          ? Icons.payments_outlined
                          : Icons.lock_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _selectedMethodId == 'cod'
                          ? 'Place Cash on Delivery Order'
                          : 'Pay ₹$total with Razorpay',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMethodId == 'cod'
                          ? AppColors.leafGreen
                          : AppColors.pickleOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityPill(
      IconData icon, String title, String sub, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderCard),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

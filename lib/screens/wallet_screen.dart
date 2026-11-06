import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/product.dart';
import '../models/referral.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';
import 'rewards_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  bool _isLoadingWallet = false;
  WalletDetails? _walletDetails;
  final List<WalletLedgerItem> _apiLedger = [];

  late Razorpay _razorpay;
  String? _pendingTopUpRequestId;
  double? _pendingTopUpAmount;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleTopUpPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleTopUpPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleTopUpExternalWallet);

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchLiveWallet();
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLiveWallet();
    }
  }

  Future<void> _handleTopUpPaymentSuccess(PaymentSuccessResponse response) async {
    final reqId = _pendingTopUpRequestId;
    final amt = _pendingTopUpAmount ?? 0.0;
    if (reqId == null || reqId.isEmpty) return;

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Verifying wallet top-up payment...'),
          ],
        ),
        backgroundColor: Color(0xFF2C160E),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final verifyRes = await AuthService().verifyWalletTopUp(
      requestId: reqId,
      razorpayOrderId: response.orderId ?? '',
      razorpayPaymentId: response.paymentId ?? '',
      razorpaySignature: response.signature ?? '',
    );

    if (!mounted) return;

    if (verifyRes.success && verifyRes.data != null) {
      final credited = verifyRes.data!.amountCredited > 0
          ? verifyRes.data!.amountCredited
          : amt;
      _fetchLiveWallet();
      try {
        AppStateProvider.of(context).loadWalletFromApi();
      } catch (_) {}

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF95D4AC), size: 20),
              const SizedBox(width: 10),
              Text(
                '₹${credited.toStringAsFixed(credited % 1 == 0 ? 0 : 2)} credited to your PickleO Wallet!',
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F5132),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verifyRes.message ?? 'Payment verification failed. Please contact support.',
          ),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _handleTopUpPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    final isCancelled = response.code == Razorpay.PAYMENT_CANCELLED ||
        response.message == null ||
        response.message!.trim().isEmpty ||
        response.message!.trim().toLowerCase() == 'undefined' ||
        response.message!.trim().toLowerCase() == 'null' ||
        response.message!.trim().toLowerCase().contains('cancel') ||
        response.message!.trim().toLowerCase().contains('dismiss');

    final msg = isCancelled
        ? 'Top-up was cancelled. Your wallet was not charged.'
        : (response.message != null &&
                response.message!.trim().isNotEmpty &&
                response.message!.trim().toLowerCase() != 'undefined' &&
                response.message!.trim().toLowerCase() != 'null')
            ? 'Top-up failed: ${response.message!.trim()}'
            : 'Top-up was cancelled. Your wallet was not charged.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2C160E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _handleTopUpExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
  }

  Future<void> _startRazorpayWalletTopUp(
    AppState appState,
    double amount,
  ) async {
    final requestId = AppState.generateUuidV4();
    _pendingTopUpRequestId = requestId;
    _pendingTopUpAmount = amount;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Creating secure payment order...'),
          ],
        ),
        backgroundColor: Color(0xFF2C160E),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final res = await AuthService().createWalletTopUpOrder(
      amount: amount,
      requestId: requestId,
    );

    if (!mounted) return;
    if (res.success && res.data != null) {
      final order = res.data!;
      final options = {
        'key': order.keyId,
        'amount': order.amount, // in paise
        'name': 'PickleO Wallet',
        'description':
            'Wallet Top-up of ₹${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}',
        'order_id': order.orderId,
        'currency': order.currency,
        'prefill': {
          'contact': appState.phoneNumber,
          'email': appState.userEmail,
          'name': appState.userName,
        },
        'notes': {
          'requestId': requestId,
          'module': 'wallet_top_up',
        },
      };

      try {
        _razorpay.open(options);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Razorpay checkout: $e'),
            backgroundColor: const Color(0xFFB91C1C),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Failed to initiate top-up. Please try again.'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _fetchLiveWallet() async {
    if (!mounted) return;
    setState(() => _isLoadingWallet = true);
    final response = await AuthService().getConsumerWallet();
    if (mounted) {
      if (response.success && response.data != null) {
        setState(() {
          _walletDetails = response.data;
          _apiLedger.clear();
          _apiLedger.addAll(response.data!.ledger);
          _isLoadingWallet = false;
        });
        try {
          AppStateProvider.of(context).loadWalletFromApi();
        } catch (_) {}
      } else {
        setState(() => _isLoadingWallet = false);
      }
    }
  }

  void _openAddMoneySheet(BuildContext context, AppState appState) {
    int selectedAmount = 200;
    final customCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF8F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final customVal = int.tryParse(customCtrl.text.trim()) ?? 0;
            final currentAdd = customVal > 0 ? customVal : selectedAmount;
            final newBalance = appState.walletBalance + currentAdd;

            final mq = MediaQuery.of(context);
            final bottomInset = mq.viewInsets.bottom;
            final systemBottom = mq.padding.bottom;
            final effectiveBottom = bottomInset > 0
                ? (bottomInset + 16)
                : (systemBottom > 0 ? (systemBottom + 16) : 24.0);

            return Padding(
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
                        'Add Money to Wallet',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Quick chips [100, 200, 500, 1000]
                  Row(
                    children: [100, 200, 500, 1000].map((amt) {
                      final isSelected = customVal == 0 && selectedAmount == amt;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              selectedAmount = amt;
                              customCtrl.clear();
                            });
                          },
                          child: Container(
                            height: 48,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F5132)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0F5132)
                                    : const Color(0xFFFFDBD0),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '₹$amt',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF2C160E),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Custom Input
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFDBD0),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2C160E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: customCtrl,
                            keyboardType: TextInputType.number,
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2C160E),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Enter custom amount',
                              border: InputBorder.none,
                            ),
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Preview new balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'New balance after top-up',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹${newBalance.toInt()}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C160E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Add Money Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentAdd < 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Minimum top-up is ₹10'),
                              backgroundColor: Color(0xFF2C160E),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        if (currentAdd > 10000) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Maximum top-up is ₹10,000 per transaction'),
                              backgroundColor: Color(0xFF2C160E),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        _startRazorpayWalletTopUp(appState, currentAdd.toDouble());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pickleOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Add ₹$currentAdd with Razorpay',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openGiftSheet(BuildContext context, AppState appState) {
    final products = appState.allProducts;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available for gifting right now.')),
      );
      return;
    }
    Product selectedProduct = products.first;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController(text: 'A jar of home, with love');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFFF8F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final price = selectedProduct.basePrice.toInt();
            final fromWallet = appState.walletBalance >= price;
            final shortBy = (price - appState.walletBalance).toInt();

            final mq = MediaQuery.of(context);
            final bottomInset = mq.viewInsets.bottom;
            final systemBottom = mq.padding.bottom;
            final effectiveBottom = bottomInset > 0
                ? (bottomInset + 16)
                : (systemBottom > 0 ? (systemBottom + 16) : 24.0);

            return Padding(
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
                        'Gift a Jar',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Horizontal jar carousel
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: products.take(4).length,
                      itemBuilder: (context, index) {
                        final p = products[index];
                        final isSel = p.id == selectedProduct.id;
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() => selectedProduct = p);
                          },
                          child: Container(
                            width: 104,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? const Color(0xFF0F5132)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    p.image,
                                    height: 56,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 56,
                                      color: AppColors.surfaceContainer,
                                      child: const Icon(Icons.local_dining,
                                          size: 24, color: AppColors.orangeDark),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p.name.split(' ').take(2).join(' '),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '₹${p.basePrice.toInt()} · ${p.weight}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF964900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Fields
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: "Friend's name",
                      labelStyle: GoogleFonts.poppins(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFDBD0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Friend's mobile (they get a WhatsApp link)",
                      labelStyle: GoogleFonts.poppins(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFDBD0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: msgCtrl,
                    decoration: InputDecoration(
                      labelText: "Gift message (optional)",
                      labelStyle: GoogleFonts.poppins(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFDBD0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment note
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        fromWallet
                            ? 'Paid from wallet balance'
                            : 'Wallet short by ₹$shortBy · rest via Google Pay',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        '₹$price',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C160E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Send Gift Jar Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final friend = nameCtrl.text.trim();
                        if (friend.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Add your friend's name"),
                              backgroundColor: Color(0xFF2C160E),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }

                        final deduct = appState.walletBalance >= price
                            ? price.toDouble()
                            : appState.walletBalance;
                        if (deduct > 0) {
                          appState.addWalletCash(-deduct);
                        }

                        setState(() {
                          _apiLedger.insert(
                            0,
                            WalletLedgerItem(
                              id: 'gift_${DateTime.now().millisecondsSinceEpoch}',
                              type: 'debit',
                              amount: deduct,
                              title:
                                  'Gift jar to $friend · ${selectedProduct.name.split(' ').take(2).join(' ')}',
                              createdAt: 'Today',
                            ),
                          );
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: Color(0xFF95D4AC), size: 18),
                                const SizedBox(width: 8),
                                Text('Gift sent! $friend gets a WhatsApp link'),
                              ],
                            ),
                            backgroundColor: const Color(0xFF2C160E),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.redeem_outlined, size: 20),
                      label: Text(
                        'Send Gift Jar · ₹$price',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pickleOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final displayBalance = _walletDetails?.balance ?? appState.walletBalance;

    // Dynamic loyalty tier info based on user's live spice points
    final points = appState.spicePoints;
    final String tierSubtitle;
    if (points < 200) {
      final needed = 200 - points;
      tierSubtitle = '$needed more points unlock Tier 1 · ₹50 off next order';
    } else if (points < 500) {
      final needed = 500 - points;
      tierSubtitle = '$needed more points unlock Tier 2 · free gift on orders';
    } else {
      final needed = (1000 - points).clamp(0, 500);
      tierSubtitle = needed > 0
          ? '$needed more points unlock Tier 3 · free delivery for a year'
          : 'Tier 3 VIP Member · free delivery on all orders';
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
          'PickleO Wallet',
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
        color: AppColors.leafGreen,
        onRefresh: _fetchLiveWallet,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dark Green Wallet Balance Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF003820),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AVAILABLE BALANCE',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: const Color(0xFF95D4AC),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${displayBalance.toInt()}',
                              style: GoogleFonts.poppins(
                                fontSize: 34,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 34,
                          color: Color(0xFF95D4AC),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: () => _openAddMoneySheet(context, appState),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.pickleOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Add Money',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 46,
                            child: OutlinedButton(
                              onPressed: () => _openGiftSheet(context, appState),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF95D4AC),
                                  width: 1.5,
                                ),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Gift a Jar',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
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
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Spice Points Tier Card
              InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RewardsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium,
                        size: 24,
                        color: Color(0xFFD2A500),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$points Spice Points',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              tierSubtitle,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: Color(0xFF707971),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Recent Activity Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_isLoadingWallet && _apiLedger.isNotEmpty)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.leafGreen,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Dynamic Activity List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.08),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoadingWallet && _apiLedger.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.leafGreen,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Loading wallet activity...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _apiLedger.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 36,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF4F6F4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_outlined,
                                      size: 26,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No transactions yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your cashback, referral bonuses, and wallet top-ups will appear here.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _apiLedger.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              color:
                                  AppColors.textSecondary.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (context, index) {
                              final item = _apiLedger[index];
                              final isCredit = item.isCredit;
                              final isReferral =
                                  item.title.toLowerCase().contains('referral');
                              final icon = isReferral
                                  ? Icons.group_add_outlined
                                  : (item.isReversal
                                      ? Icons.replay_outlined
                                      : (isCredit
                                          ? Icons.redeem_outlined
                                          : Icons.shopping_bag_outlined));
                              final color = isCredit
                                  ? const Color(0xFF0F5132)
                                  : const Color(0xFF2C160E);
                              final amtStr = item.amount % 1 == 0
                                  ? (isCredit
                                      ? '+₹${item.amount.toInt()}'
                                      : '−₹${item.amount.toInt()}')
                                  : (isCredit
                                      ? '+₹${item.amount.toStringAsFixed(2)}'
                                      : '−₹${item.amount.toStringAsFixed(2)}');
                              final dateStr = item.createdAt ?? 'Recent';

                              return Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: isCredit
                                            ? const Color(0xFFFFE9E3)
                                            : const Color(0xFFF2F4F2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 19,
                                        color: isCredit
                                            ? const Color(0xFF964900)
                                            : const Color(0xFF2C160E),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            dateStr,
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
                                      amtStr,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
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
      ),
    );
  }
}

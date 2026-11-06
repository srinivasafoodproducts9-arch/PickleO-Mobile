import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/order.dart';
import '../theme/app_theme.dart';
import '../screens/main_navigation.dart';
import '../screens/order_tracking_screen.dart';

/// Interactive celebration dialog displayed upon successful order placement.
/// Features celebratory flowers & floating petals animation and redirects to Home screen.
class OrderSuccessCelebrationDialog extends StatefulWidget {
  final UserOrder order;

  const OrderSuccessCelebrationDialog({
    super.key,
    required this.order,
  });

  /// Helper to show this celebration dialog modal
  static Future<void> show(BuildContext context, UserOrder order) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => OrderSuccessCelebrationDialog(order: order),
    );
  }

  @override
  State<OrderSuccessCelebrationDialog> createState() =>
      _OrderSuccessCelebrationDialogState();
}

class _OrderSuccessCelebrationDialogState
    extends State<OrderSuccessCelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _bloomController;
  late AnimationController _petalsController;
  late AnimationController _pulseController;
  late Animation<double> _bloomScale;
  late Animation<double> _badgeScale;
  late Animation<double> _contentFade;

  final List<_PetalParticle> _petals = [];
  Timer? _autoRedirectTimer;
  int _secondsRemaining = 5;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    // Central flower blooming entrance
    _bloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _bloomScale = CurvedAnimation(
      parent: _bloomController,
      curve: Curves.elasticOut,
    );

    _badgeScale = CurvedAnimation(
      parent: _bloomController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
    );

    _contentFade = CurvedAnimation(
      parent: _bloomController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    // Continuous flower petals floating & swaying
    _petalsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Subtle gentle glow pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Generate celebratory flower petals
    _generatePetals();

    _bloomController.forward();

    // Countdown and auto-redirect to Home Screen after 5 seconds
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });

    _autoRedirectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _redirectToHome();
      }
    });
  }

  void _generatePetals() {
    final rand = math.Random();
    const petalColors = [
      Color(0xFFFF9800), // Festive Marigold Orange
      Color(0xFFFFB300), // Marigold Amber
      Color(0xFFFFC107), // Golden Turmeric
      Color(0xFFE91E63), // Royal Rose Pink
      Color(0xFFF06292), // Lotus Blossom Pink
      Color(0xFFD32F2F), // Festive Crimson Red
      Color(0xFFFFF9C4), // Jasmine Cream
      Color(0xFF81C784), // Fresh Green Leaf
      Color(0xFF4CAF50), // Sacred Tulsi Leaf
    ];

    for (int i = 0; i < 42; i++) {
      _petals.add(
        _PetalParticle(
          x: rand.nextDouble(),
          y: rand.nextDouble() * -1.2, // start staggered above and across
          size: 9.0 + rand.nextDouble() * 11.0,
          color: petalColors[rand.nextInt(petalColors.length)],
          swayAmplitude: 15.0 + rand.nextDouble() * 25.0,
          swayFrequency: 2.0 + rand.nextDouble() * 3.0,
          fallSpeed: 0.18 + rand.nextDouble() * 0.28,
          rotationSpeed: (rand.nextDouble() - 0.5) * 4.0,
          type: rand.nextInt(4), // 0: Rose petal, 1: Teardrop, 2: 5-Petal Floret, 3: Leaf
          phase: rand.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    _bloomController.dispose();
    _petalsController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _redirectToHome() {
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const MainNavigation(initialIndex: 0),
      ),
      (route) => false,
    );
  }

  void _goToOrderTracking() {
    _autoRedirectTimer?.cancel();
    _countdownTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OrderTrackingScreen(order: widget.order),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final totalPayable = order.total.toInt();
    final displayId = order.displayId.isNotEmpty ? order.displayId : order.id;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _redirectToHome();
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Floating flower petals canvas
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _petalsController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CelebrationFlowerPetalsPainter(
                      progress: _petalsController.value,
                      petals: _petals,
                    ),
                  );
                },
              ),
            ),

            // Dialog main card
            Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: AppColors.pickleOrange.withValues(alpha: 0.12),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    // Top festive decorative floral arc background
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 140,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.primary.withValues(alpha: 0.08),
                              AppColors.pickleOrange.withValues(alpha: 0.04),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Main content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Animated Blossoming Flower Crown
                          _buildBloomingFlowerHero(),
                          const SizedBox(height: 18),

                          // Heading
                          ScaleTransition(
                            scale: _badgeScale,
                            child: Column(
                              children: [
                                Text(
                                  'Order Placed Successfully! 🎉',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Your authentic jars are being lovingly prepared!',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Order Summary Details Card
                          FadeTransition(
                            opacity: _contentFade,
                            child: _buildOrderDetailsCard(
                              order: order,
                              displayId: displayId,
                              totalPayable: totalPayable,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Action Buttons
                          FadeTransition(
                            opacity: _contentFade,
                            child: Column(
                              children: [
                                // Primary "Back to Home" Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _redirectToHome,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.pickleOrange,
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shadowColor: AppColors.pickleOrange
                                          .withValues(alpha: 0.4),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.home_rounded,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Back to Home',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Secondary Track Order Button
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _goToOrderTracking,
                                      icon: const Icon(
                                        Icons.navigation_outlined,
                                        size: 15,
                                        color: AppColors.leafGreen,
                                      ),
                                      label: Text(
                                        'Track Live Order',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.leafGreen,
                                        ),
                                      ),
                                    ),
                                    // Countdown badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Redirecting in ${_secondsRemaining}s',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade600,
                                        ),
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Center Blooming Flower Celebration Graphic
  Widget _buildBloomingFlowerHero() {
    return AnimatedBuilder(
      animation: Listenable.merge([_bloomController, _pulseController]),
      builder: (context, child) {
        final pulse = _pulseController.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Soft pulsating glowing aura
            Container(
              width: 104 + (pulse * 12),
              height: 104 + (pulse * 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.spiceYellow
                    .withValues(alpha: 0.15 + (pulse * 0.1)),
              ),
            ),
            // Outer golden petal ring
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFF3E0),
                    Color(0xFFFFE0B2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: AppColors.pickleOrange.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
            // Blooming Flower Painter
            ScaleTransition(
              scale: _bloomScale,
              child: SizedBox(
                width: 76,
                height: 76,
                child: CustomPaint(
                  painter: _FlowerBloomCenterPainter(
                    bloomProgress: _bloomScale.value.clamp(0.0, 1.0),
                    pulseProgress: pulse,
                  ),
                ),
              ),
            ),
            // Centered Festive Check Icon
            ScaleTransition(
              scale: _badgeScale,
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.leafGreen,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330F5132),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Compact Order Details Tile
  Widget _buildOrderDetailsCard({
    required UserOrder order,
    required String displayId,
    required int totalPayable,
  }) {
    final cleanMethod = order.paymentMethod.trim().toLowerCase();
    final isCod = cleanMethod == 'cod' ||
        cleanMethod.contains('cash on delivery') ||
        cleanMethod.contains('doorstep');

    final String paymentBadgeText;
    final Color paymentBadgeColor;
    final Color paymentBadgeBg;
    final Color paymentBadgeBorder;
    final IconData? paymentBadgeIcon;

    if (isCod) {
      paymentBadgeText = 'Cash on Delivery';
      paymentBadgeColor = AppColors.pickleOrange;
      paymentBadgeBg = AppColors.pickleOrange.withValues(alpha: 0.12);
      paymentBadgeBorder = AppColors.pickleOrange.withValues(alpha: 0.3);
      paymentBadgeIcon = null;
    } else {
      paymentBadgeText = 'Paid Online';
      paymentBadgeColor = AppColors.leafGreen;
      paymentBadgeBg = AppColors.leafGreen.withValues(alpha: 0.12);
      paymentBadgeBorder = AppColors.leafGreen.withValues(alpha: 0.3);
      paymentBadgeIcon = Icons.check_circle_rounded;
    }

    final String paymentPillText;
    if (order.walletUsed > 0 || cleanMethod.contains('wallet')) {
      paymentPillText = 'Wallet + Online';
    } else if (isCod) {
      paymentPillText = 'Cash / UPI';
    } else if (cleanMethod.contains('upi') ||
        cleanMethod.contains('gpay') ||
        cleanMethod.contains('phonepe') ||
        cleanMethod.contains('paytm')) {
      paymentPillText = 'UPI';
    } else if (cleanMethod.contains('card')) {
      paymentPillText = 'Card';
    } else if (cleanMethod.contains('netbanking') ||
        cleanMethod.contains('net banking')) {
      paymentPillText = 'Net Banking';
    } else {
      paymentPillText = 'Online';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Order ID & Payment Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.receipt_outlined,
                      size: 16,
                      color: AppColors.leafGreen,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Order #$displayId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: paymentBadgeBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: paymentBadgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (paymentBadgeIcon != null) ...[
                      Icon(
                        paymentBadgeIcon,
                        size: 11,
                        color: paymentBadgeColor,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      paymentBadgeText,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: paymentBadgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFE5E7EB)),

          // Delivery Slot
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Slot',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      order.deliverySlot.isNotEmpty
                          ? order.deliverySlot
                          : '9 AM - 12 PM',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Total Payment Row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 15,
                  color: AppColors.leafGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCod ? 'Payable on Delivery' : 'Amount Paid',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '₹$totalPayable',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.leafGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCod
                      ? Colors.white
                      : AppColors.leafGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCod
                        ? Colors.grey.shade300
                        : AppColors.leafGreen.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  paymentPillText,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: isCod ? FontWeight.w500 : FontWeight.w600,
                    color: isCod ? Colors.grey.shade700 : AppColors.leafGreen,
                  ),
                ),
              ),
            ],
          ),

          if (order.walletUsed > 0) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      size: 13, color: Color(0xFF16A34A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '₹${order.walletUsed.toStringAsFixed(order.walletUsed.truncateToDouble() == order.walletUsed ? 0 : 2)} paid via PickleO Wallet, remainder via Razorpay',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (order.fulfilmentCentre.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Fulfilled from ${order.fulfilmentCentre}',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (order.pointsLot != null || order.spicePointsEarned > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '+${order.pointsLot?.points ?? order.spicePointsEarned} Spice Points Pending (Credited on delivery)',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Represents a single celebratory flower or petal drifting down
class _PetalParticle {
  double x; // 0.0 to 1.0 (relative width)
  double y; // relative height
  final double size;
  final Color color;
  final double swayAmplitude;
  final double swayFrequency;
  final double fallSpeed;
  final double rotationSpeed;
  final int type; // 0: Rose petal, 1: Teardrop petal, 2: 5-Petal Floret, 3: Leaf
  final double phase;

  _PetalParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.swayAmplitude,
    required this.swayFrequency,
    required this.fallSpeed,
    required this.rotationSpeed,
    required this.type,
    required this.phase,
  });
}

/// Paints the animated celebratory flower petals cascading across the screen
class _CelebrationFlowerPetalsPainter extends CustomPainter {
  final double progress;
  final List<_PetalParticle> petals;

  _CelebrationFlowerPetalsPainter({
    required this.progress,
    required this.petals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in petals) {
      // Calculate continuous falling y position
      final effectiveY = ((p.y + (progress * p.fallSpeed * 3)) % 1.4) - 0.2;
      final currentY = effectiveY * size.height;

      // Calculate horizontal sway using sine wave
      final sway = math.sin((progress * 2 * math.pi * p.swayFrequency) + p.phase) *
          p.swayAmplitude;
      final currentX = (p.x * size.width) + sway;

      // Rotation & 3D tilt flip
      final rotation = (progress * 2 * math.pi * p.rotationSpeed) + p.phase;
      final flipX = math.cos((progress * 2 * math.pi) + p.phase);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(rotation);
      canvas.scale(flipX.abs().clamp(0.25, 1.0), 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.88)
        ..style = PaintingStyle.fill;

      switch (p.type) {
        case 0:
          // Rose petal (curved shell)
          final path = Path();
          final s = p.size;
          path.moveTo(0, -s * 0.5);
          path.cubicTo(s * 0.6, -s * 0.4, s * 0.7, s * 0.4, 0, s * 0.6);
          path.cubicTo(-s * 0.7, s * 0.4, -s * 0.6, -s * 0.4, 0, -s * 0.5);
          canvas.drawPath(path, paint);
          break;

        case 1:
          // Teardrop marigold petal
          final path = Path();
          final s = p.size;
          path.moveTo(0, -s * 0.6);
          path.quadraticBezierTo(s * 0.4, 0, 0, s * 0.6);
          path.quadraticBezierTo(-s * 0.4, 0, 0, -s * 0.6);
          canvas.drawPath(path, paint);
          break;

        case 2:
          // 5-Petal Miniature Flower
          final s = p.size * 0.55;
          for (int i = 0; i < 5; i++) {
            final angle = (i * 2 * math.pi) / 5;
            final px = math.cos(angle) * (s * 0.65);
            final py = math.sin(angle) * (s * 0.65);
            canvas.drawCircle(Offset(px, py), s * 0.45, paint);
          }
          // Center golden stigma
          final centerPaint = Paint()
            ..color = const Color(0xFFFFD54F)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset.zero, s * 0.35, centerPaint);
          break;

        case 3:
        default:
          // Fresh green leaf
          final path = Path();
          final s = p.size;
          path.moveTo(0, -s * 0.6);
          path.quadraticBezierTo(s * 0.5, 0, 0, s * 0.6);
          path.quadraticBezierTo(-s * 0.5, 0, 0, -s * 0.6);
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationFlowerPetalsPainter oldDelegate) =>
      true;
}

/// Paints the blossoming layered flower petals in the center hero graphic
class _FlowerBloomCenterPainter extends CustomPainter {
  final double bloomProgress;
  final double pulseProgress;

  _FlowerBloomCenterPainter({
    required this.bloomProgress,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) * bloomProgress;

    // Outer Layer: 8 Marigold Petals (Orange & Amber)
    const int petalCount = 8;
    for (int i = 0; i < petalCount; i++) {
      final angle = (i * 2 * math.pi) / petalCount;
      final dist = baseRadius * 0.72;
      final petalCenter = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );

      final petalPaint = Paint()
        ..color = (i % 2 == 0 ? AppColors.pickleOrange : const Color(0xFFFFB300))
            .withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(petalCenter, baseRadius * 0.32, petalPaint);
    }

    // Inner Layer: 8 Secondary Lotus/Rose Petals
    for (int i = 0; i < petalCount; i++) {
      final angle = ((i * 2 * math.pi) / petalCount) + (math.pi / petalCount);
      final dist = baseRadius * 0.52;
      final petalCenter = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );

      final innerPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(petalCenter, baseRadius * 0.26, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FlowerBloomCenterPainter oldDelegate) =>
      oldDelegate.bloomProgress != bloomProgress ||
      oldDelegate.pulseProgress != pulseProgress;
}

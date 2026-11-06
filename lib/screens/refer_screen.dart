import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import '../models/referral.dart';
import '../services/auth_service.dart';

class ReferScreen extends StatefulWidget {
  const ReferScreen({super.key});

  @override
  State<ReferScreen> createState() => _ReferScreenState();
}

class _ReferScreenState extends State<ReferScreen> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  ReferralProgramme? _programme;
  final List<ReferralFriend> _friends = [];
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAllData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh programme state when returning from sharing apps (WhatsApp, SMS, etc.)
      _loadProgramme(silent: true);
    }
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    await Future.wait([
      _loadProgramme(silent: false),
      _loadReferrals(reset: true),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProgramme({bool silent = false}) async {
    final response = await AuthService().getReferralMe();
    if (!mounted) return;
    if (response.success && response.data != null) {
      setState(() {
        _programme = response.data;
      });
    } else if (!silent && _programme == null) {
      // Local fallback for smooth offline prototyping
      setState(() {
        _programme = const ReferralProgramme(
          code: 'PRIYA100',
          link: 'https://pickleo.in/r/PRIYA100',
          rewardRs: 100,
          discountRs: 100,
          programmeActive: true,
          stats: ReferralStats(joined: 2, ordered: 1, rewarded: 0, expired: 0),
          cap: ReferralCap(
            monthlyRemaining: 9,
            monthlyCap: 20,
            lifetimeRewardCapRs: 5000.0,
          ),
          shareTexts: {
            'wa': 'Try PickleO and get ₹100 off your first order: https://pickleo.in/r/PRIYA100',
          },
        );
      });
    }
  }

  Future<void> _loadReferrals({bool reset = false}) async {
    if (reset) {
      _nextCursor = null;
      _friends.clear();
    } else {
      if (_isLoadingMore || _nextCursor == null) return;
      setState(() => _isLoadingMore = true);
    }

    final response = await AuthService().getReferralList(
      limit: 20,
      cursor: _nextCursor,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      setState(() {
        if (reset) {
          _friends.clear();
        }
        _friends.addAll(response.data!.items);
        _nextCursor = response.data!.nextCursor;
        _isLoadingMore = false;
      });
    } else {
      // Offline fallback mock data if empty
      if (reset && _friends.isEmpty) {
        setState(() {
          _friends.addAll(const [
            ReferralFriend(
              firstName: 'Anjali',
              initials: 'AS',
              state: 'ordered',
              createdAt: '2026-10-12T00:18:48.118Z',
            ),
            ReferralFriend(
              firstName: 'Karthik',
              initials: 'KM',
              state: 'joined',
              createdAt: '2026-10-10T14:22:10.000Z',
            ),
          ]);
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _handleShareAction(String medium, String text, String toast) async {
    // 1. Record share medium before launching share target
    AuthService().trackReferralShare(medium);

    // 2. If WhatsApp, launch WhatsApp directly
    if (medium == 'wa') {
      final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');
      final webWaUri = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}');

      bool launched = false;
      try {
        if (await canLaunchUrl(waUri)) {
          launched = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {}

      if (!launched) {
        try {
          if (await canLaunchUrl(webWaUri)) {
            launched = await launchUrl(webWaUri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
      }

      // Also copy text to clipboard as a helpful backup
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                launched ? Icons.chat_bubble_outline : Icons.check_circle_outline,
                color: const Color(0xFF95D4AC),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  launched
                      ? 'Redirecting to WhatsApp...'
                      : 'WhatsApp not detected. Referral message copied to clipboard!',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2C160E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // Copy Link / Copy Code action
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF95D4AC), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(toast)),
            ],
          ),
          backgroundColor: const Color(0xFF2C160E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    // Re-check programme after short delay to reflect possible counter updates
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _loadProgramme(silent: true);
    });
  }

  void _openCustomCodeSheet() {
    if (_programme?.customCodeRequest != null) {
      final req = _programme!.customCodeRequest!;
      final statusLabel = req.status.replaceAll('_', ' ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You already submitted a request for "${req.code}" ($statusLabel). Only one request is permitted.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: AppColors.textPrimary,
        ),
      );
      return;
    }

    final controller = TextEditingController();
    bool isSubmitting = false;
    final hostContext = context;

    showModalBottomSheet(
      context: hostContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final mq = MediaQuery.of(innerContext);
            final bottomInset = mq.viewInsets.bottom;
            final systemBottom = mq.padding.bottom;
            final effectiveBottom = bottomInset > 0
                ? (bottomInset + 16.0)
                : (systemBottom > 0 ? (systemBottom + 20.0) : 28.0);

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
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
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Request Custom Referral Code',
                    style: GoogleFonts.lora(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose a unique custom code for your friends. Custom codes are reviewed and approved within 24 hours.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    decoration: InputDecoration(
                      hintText: 'e.g. PRIYALOVES',
                      labelText: 'Your Desired Code',
                      prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.orangeDark),
                      filled: true,
                      fillColor: AppColors.surfaceLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final code = controller.text.trim().toUpperCase();
                              if (code.length < 4) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Code must be at least 4 characters long'),
                                    backgroundColor: AppColors.chilliRed,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => isSubmitting = true);
                              final res = await AuthService().submitCustomReferralCode(code);
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();

                              if (!mounted) return;

                              if (res.success) {
                                _loadAllData();
                                showDialog(
                                  context: hostContext,
                                  useRootNavigator: true,
                                  barrierDismissible: true,
                                  builder: (dialogCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: Color(0xFF0F5132)),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Request Submitted',
                                          style: GoogleFonts.lora(fontSize: 17, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      res.message ??
                                          'Your custom code "$code" has been submitted for approval. You will receive an update soon.',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        },
                                        child: Text(
                                          'OK',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F5132),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                showDialog(
                                  context: hostContext,
                                  useRootNavigator: true,
                                  barrierDismissible: true,
                                  builder: (dialogCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: AppColors.chilliRed),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Request Failed',
                                          style: GoogleFonts.lora(fontSize: 17, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      res.message ??
                                          'Failed to submit custom code "$code". Please try a different code.',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                                        },
                                        child: Text(
                                          'OK',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.pickleOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pickleOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'Submit Request',
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
            ),
          );
        },
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final prog = _programme;
    final reward = prog?.rewardRs.toInt() ?? 100;
    final discount = prog?.discountRs.toInt() ?? 100;
    final code = prog?.code ?? 'PRIYA100';
    final link = prog?.link ?? 'https://pickleo.in/r/$code';
    final shareWaText = prog?.getShareText(medium: 'wa') ??
        'Try PickleO and get ₹$discount off your first order: $link';

    final steps = [
      {
        'n': '1',
        'title': 'Share your code or link',
        'sub': 'WhatsApp it to friends and family who love authentic home-style food',
      },
      {
        'n': '2',
        'title': 'They order their first jar',
        'sub': '₹$discount automatically comes off their first order',
      },
      {
        'n': '3',
        'title': 'You get ₹$reward in your wallet',
        'sub': 'Credited 48 hours after their first jar is delivered',
      },
    ];

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
          'Refer a Friend',
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
      body: _isLoading && _programme == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.leafGreen),
            )
          : RefreshIndicator(
              color: AppColors.leafGreen,
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Hero Referral Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                      decoration: BoxDecoration(
                        color: const Color(0xFF003820),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0F5132),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group_add_outlined,
                              size: 30,
                              color: Color(0xFF95D4AC),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Give ₹$discount, Get ₹$reward',
                            style: GoogleFonts.lora(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.25,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Your friend gets ₹$discount off their first jar. You get ₹$reward in your PickleO Wallet once it's delivered.",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFFC0C9C0),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: const Color(0xFF95D4AC),
                                style: BorderStyle.solid,
                                width: 1.2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  code,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                InkWell(
                                  onTap: () => _handleShareAction(
                                    'cp',
                                    code,
                                    'Code $code copied to clipboard',
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    height: 32,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.pickleOrange,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.copy_rounded, size: 16, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Copy',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_programme?.customCodeRequest != null) ...[
                            Builder(
                              builder: (context) {
                                final req = _programme!.customCodeRequest!;
                                Color bg;
                                Color text;
                                IconData icon;
                                String label;

                                if (req.isPending) {
                                  bg = const Color(0xFFFEF3C7);
                                  text = const Color(0xFFB45309);
                                  icon = Icons.hourglass_top_rounded;
                                  label = 'Custom code "${req.code}" pending admin review';
                                } else if (req.isApproved) {
                                  bg = const Color(0xFFD1FAE5);
                                  text = const Color(0xFF047857);
                                  icon = Icons.check_circle_rounded;
                                  label = 'Custom code "${req.code}" approved';
                                } else {
                                  bg = const Color(0xFFFEE2E2);
                                  text = const Color(0xFFB91C1C);
                                  icon = Icons.cancel_rounded;
                                  final reasonSuffix = (req.rejectionReason != null &&
                                          req.rejectionReason!.trim().isNotEmpty)
                                      ? ': ${req.rejectionReason!.trim()}'
                                      : '';
                                  label = 'Request "${req.code}" rejected$reasonSuffix';
                                }

                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(icon, size: 14, color: text),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          label,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: text,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            InkWell(
                              onTap: _openCustomCodeSheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                child: Text(
                                  'Want a personalized code? Request here ›',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: const Color(0xFF95D4AC),
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Share Buttons: WhatsApp & Copy Link
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _handleShareAction(
                                'wa',
                                shareWaText,
                                'WhatsApp referral message copied to share',
                              ),
                              icon: const Icon(Icons.chat_bubble_outline, size: 20),
                              label: Text(
                                'WhatsApp',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _handleShareAction(
                                'cp',
                                link,
                                'Referral link copied',
                              ),
                              icon: const Icon(Icons.link_rounded, size: 20),
                              label: Text(
                                'Copy Link',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F5132),
                                side: const BorderSide(
                                  color: Color(0xFF0F5132),
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Metrics & Caps Summary Card
                    if (prog != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.textSecondary.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetricChip(
                                  'Joined',
                                  '${prog.stats.joined}',
                                  Icons.people_outline,
                                  const Color(0xFF176B4D),
                                ),
                                _buildMetricChip(
                                  'Ordered',
                                  '${prog.stats.ordered}',
                                  Icons.shopping_bag_outlined,
                                  const Color(0xFF964900),
                                ),
                                _buildMetricChip(
                                  'Rewarded',
                                  '${prog.stats.rewarded}',
                                  Icons.celebration_outlined,
                                  const Color(0xFF0F5132),
                                ),
                              ],
                            ),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.stars_rounded,
                                      size: 15,
                                      color: Color(0xFF0F5132),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Monthly rewards left: ${prog.cap.monthlyRemaining}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_outlined,
                                      size: 15,
                                      color: Color(0xFF964900),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Lifetime cap: ₹${prog.cap.lifetimeRewardCapRs.toInt()}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '• Cap applies to rewarded orders (max ${prog.cap.monthlyCap}/mo). Invites are unlimited.',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // How it works Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.textSecondary.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How it works',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...steps.map((st) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFFE9E3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          st['n']!,
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF964900),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            st['title']!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            st['sub']!,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Section Header: YOUR REFERRALS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'YOUR REFERRALS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '₹${(prog != null ? prog.stats.rewarded * reward : 0)} earned so far',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F5132),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Referrals List
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.textSecondary.withValues(alpha: 0.08),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _friends.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.group_outlined,
                                    size: 40,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No friends referred yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Share your code with friends to start earning ₹$reward!',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _friends.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: AppColors.textSecondary.withValues(alpha: 0.06),
                                  ),
                                  itemBuilder: (context, index) {
                                    final friend = _friends[index];
                                    final badgeStyle = _getBadgeStyle(friend.state);

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFFE9E3),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                friend.initials,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF964900),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  friend.firstName,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  friend.statusLabel,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeStyle.bg,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              badgeStyle.label,
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: badgeStyle.color,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (_nextCursor != null) ...[
                                  const Divider(height: 1),
                                  TextButton(
                                    onPressed: _isLoadingMore ? null : () => _loadReferrals(reset: false),
                                    child: _isLoadingMore
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(
                                            'Load More Referrals',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.orangeDark,
                                            ),
                                          ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricChip(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  _BadgeStyle _getBadgeStyle(String state) {
    switch (state) {
      case 'rewarded':
        return const _BadgeStyle(
          label: '₹100 earned',
          bg: Color(0xFFDFF3E6),
          color: Color(0xFF0F5132),
        );
      case 'ordered':
        return const _BadgeStyle(
          label: 'Ordered',
          bg: Color(0xFFFFF2D9),
          color: Color(0xFF964900),
        );
      case 'expired':
        return const _BadgeStyle(
          label: 'Expired',
          bg: Color(0xFFE9EBEA),
          color: Color(0xFF61716A),
        );
      case 'joined':
      default:
        return const _BadgeStyle(
          label: 'Pending',
          bg: Color(0xFFFFE2DA),
          color: Color(0xFF5E2C00),
        );
    }
  }
}

class _BadgeStyle {
  final String label;
  final Color bg;
  final Color color;

  const _BadgeStyle({
    required this.label,
    required this.bg,
    required this.color,
  });
}

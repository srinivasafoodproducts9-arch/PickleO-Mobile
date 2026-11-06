import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/loyalty.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen>
    with WidgetsBindingObserver {
  bool _isLoadingLedger = true;
  bool _isLoadingMoreLedger = false;
  bool _isRedeeming = false;

  LoyaltyAccount? _account;
  List<LoyaltyTierPerk> _tiers = [];
  final List<LoyaltyLedgerItem> _ledger = [];
  String? _nextToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAllData(showSpinner: false);
    }
  }

  Future<void> _loadAllData({bool showSpinner = true}) async {
    if (!mounted) return;
    if (showSpinner) {
      setState(() {
        _isLoadingLedger = true;
      });
    }

    final authService = AuthService();

    // 1. Fetch loyalty account
    final accountFuture = authService.getLoyaltyAccount();
    // 2. Fetch tiers
    final tiersFuture = authService.getLoyaltyTiers();
    // 3. Fetch initial ledger page
    final ledgerFuture = authService.getLoyaltyLedger(limit: 20);

    final results = await Future.wait([accountFuture, tiersFuture, ledgerFuture]);

    if (!mounted) return;

    final accountRes = results[0] as ApiResponse<LoyaltyAccount>;
    final tiersRes = results[1] as ApiResponse<LoyaltyTiersResponse>;
    final ledgerRes = results[2] as ApiResponse<LoyaltyLedgerResponse>;

    setState(() {
      _isLoadingLedger = false;

      if (accountRes.success && accountRes.data != null) {
        _account = accountRes.data;
        try {
          AppStateProvider.of(context).loadLoyaltyFromApi(notify: false);
        } catch (_) {}
      } else {
        // Fallback to local app state balance if API is unreachable
        final localPts = AppStateProvider.of(context).spicePoints;
        _account = LoyaltyAccount.initial(localPts);
      }

      if (tiersRes.success && tiersRes.data != null) {
        _tiers = tiersRes.data!.items;
      } else {
        _tiers = LoyaltyTiersResponse.defaultTiers();
      }

      if (ledgerRes.success && ledgerRes.data != null) {
        _ledger.clear();
        _ledger.addAll(ledgerRes.data!.items);
        _nextToken = ledgerRes.data!.nextToken;
      }
    });
  }

  Future<void> _loadMoreLedger() async {
    if (_nextToken == null || _isLoadingMoreLedger) return;

    setState(() => _isLoadingMoreLedger = true);
    final res = await AuthService().getLoyaltyLedger(
      limit: 20,
      nextToken: _nextToken,
    );

    if (!mounted) return;
    setState(() {
      _isLoadingMoreLedger = false;
      if (res.success && res.data != null) {
        _ledger.addAll(res.data!.items);
        _nextToken = res.data!.nextToken;
      }
    });
  }

  void _openRedemptionSheet(BuildContext context, AppState appState) {
    final account = _account ?? LoyaltyAccount.initial(appState.spicePoints);
    final blocksAvailable = account.redeemBlocksAvailable;

    if (blocksAvailable <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need at least 400 available points to redeem.'),
          backgroundColor: Color(0xFF2C160E),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int selectedBlocks = 1;

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
            final pointsToDebit = selectedBlocks * account.redeemBlockPoints;
            final cashToCredit = selectedBlocks * account.redeemBlockRupees;
            final pointsRemaining = account.balance - pointsToDebit;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  Text(
                    'Redeem Spice Points',
                    style: GoogleFonts.lora(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C160E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Convert points to cash credited directly into your PickleO Wallet.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Block selection card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.textSecondary.withValues(alpha: 0.12),
                      ),
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
                                  'Redemption Blocks',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '1 block = 400 pts → ₹40 wallet cash',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            // Block stepper
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F6F4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 16),
                                    onPressed: selectedBlocks > 1
                                        ? () => setSheetState(() => selectedBlocks--)
                                        : null,
                                  ),
                                  Text(
                                    '$selectedBlocks',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 16),
                                    onPressed: selectedBlocks < blocksAvailable
                                        ? () => setSheetState(() => selectedBlocks++)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Points to Debit',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '−$pointsToDebit pts',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Wallet Cash to Credit',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '+₹$cashToCredit',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F5132),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Points Balance After',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              '$pointsRemaining pts',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Confirm button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isRedeeming
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _performRedemption(selectedBlocks);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.pickleOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Confirm & Add ₹$cashToCredit to Wallet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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

  Future<void> _performRedemption(int blocks) async {
    setState(() => _isRedeeming = true);

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
            Text('Processing points redemption...'),
          ],
        ),
        backgroundColor: Color(0xFF2C160E),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    final appState = AppStateProvider.of(context);
    final res = await appState.redeemLoyaltyBlocks(blocks);

    if (!mounted) return;
    setState(() => _isRedeeming = false);

    if (res.success && res.data != null) {
      final credited = res.data!.walletCredited.toInt();
      final debited = res.data!.pointsDebited;

      // Reload fresh data from API
      _loadAllData(showSpinner: false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF95D4AC), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '₹$credited added to PickleO Wallet! ($debited points consumed)',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F5132),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      // On 409 conflict, reload authoritative server balances
      if (res.statusCode == 409) {
        _loadAllData(showSpinner: false);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ?? 'Redemption failed. Please try again.'),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final account = _account ?? LoyaltyAccount.initial(appState.spicePoints);
    final points = account.balance;
    final pending = account.pending;
    final tier = account.tier;
    final nextTier = account.nextTier;
    final progress = (account.progressPct / 100.0).clamp(0.0, 1.0);
    final expiringSoon = account.expiringSoon;

    final pointsNextText = nextTier != null
        ? '${account.pointsToGo} more points to reach Tier ${nextTier.id} (${nextTier.name})'
        : 'Top tier unlocked · enjoy every perk';

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
          'Spice Points',
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
        onRefresh: () => _loadAllData(showSpinner: false),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dark Brown Spice Points Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C160E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SPICE POINTS',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: const Color(0xFFFFDF90),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$points',
                              style: GoogleFonts.poppins(
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tier.name} · Tier ${tier.id}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFFFDCC6),
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.workspace_premium,
                          size: 38,
                          color: Color(0xFFFFDF90),
                        ),
                      ],
                    ),

                    // Pending points indicator (separate from spendable balance)
                    if (pending > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFFDF90).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.hourglass_top_outlined,
                              size: 14,
                              color: Color(0xFFFFDF90),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$pending points pending from recent orders',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFFFDF90),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Tier Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.pickleOrange,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pointsNextText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFFFFDCC6),
                      ),
                    ),

                    // Expiring soon alert banner
                    if (expiringSoon != null && expiringSoon.hasExpiring) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB91C1C).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFCA5A5).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.schedule_outlined,
                              size: 14,
                              color: Color(0xFFFFDCC6),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${expiringSoon.points} points expire on ${expiringSoon.formattedDate}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFFFFDCC6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Redemption Banner Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Redeem 400 pts → ₹40 wallet cash',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  account.redeemBlocksAvailable > 0
                                      ? '${account.redeemBlocksAvailable} blocks ready to convert'
                                      : 'Available in whole 400-point blocks',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xFFC0C9C0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: account.canRedeem && !_isRedeeming
                                ? () => _openRedemptionSheet(context, appState)
                                : () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'You need 400 available points to redeem (${account.balance} available).',
                                        ),
                                        backgroundColor:
                                            const Color(0xFF2C160E),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.pickleOrange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9),
                              ),
                            ),
                            child: Opacity(
                              opacity: account.canRedeem ? 1.0 : 0.6,
                              child: Text(
                                'Redeem',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // TIER BENEFITS Header
              Text(
                'TIER BENEFITS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),

              // Dynamic Tier Cards
              ..._tiers.map((t) {
                final isCurrent = t.id == tier.id;
                final isLocked = (account.earned12m) < t.minPoints;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFF0F5132)
                          : AppColors.textSecondary.withValues(alpha: 0.08),
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Opacity(
                    opacity: isLocked ? 0.75 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? const Color(0xFF0F5132)
                                    : const Color(0xFFFFE9E3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                t.id == 3
                                    ? Icons.military_tech_outlined
                                    : (t.id == 2
                                        ? Icons.workspace_premium_outlined
                                        : Icons.eco_outlined),
                                size: 20,
                                color: isCurrent
                                    ? Colors.white
                                    : const Color(0xFF964900),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        t.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDFF3E6),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Your tier',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF0F5132),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    t.minPoints == 0
                                        ? 'Starter tier'
                                        : 'From ${t.minPoints} rolling 12m points',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...t.perkDescriptions.map((pk) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Color(0xFF0F5132),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      pk,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),

              // POINTS HISTORY Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'POINTS HISTORY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_isLoadingLedger)
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

              // Points History List
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.08),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isLoadingLedger && _ledger.isEmpty
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
                                'Loading points activity...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _ledger.isEmpty
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
                                    width: 48,
                                    height: 48,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF4F6F4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.workspace_premium_outlined,
                                      size: 24,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No points history yet',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Earn points on every delivered order and rating bonus.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _ledger.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.06),
                                ),
                                itemBuilder: (context, index) {
                                  final item = _ledger[index];
                                  final ptsStr = item.points >= 0
                                      ? '+${item.points}'
                                      : '${item.points}';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.iconData,
                                          size: 20,
                                          color: const Color(0xFF964900),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item.title,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w500,
                                                        color: AppColors.textPrimary,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  // Explicit State Badge
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: item.stateBgColor,
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      item.stateBadgeText,
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: item.stateColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                item.createdAt,
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
                                          ptsStr,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: item.points >= 0
                                                ? const Color(0xFF0F5132)
                                                : const Color(0xFFB91C1C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              // Pagination Load More button
                              if (_nextToken != null)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: _isLoadingMoreLedger
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.leafGreen,
                                            ),
                                          )
                                        : TextButton(
                                            onPressed: _loadMoreLedger,
                                            child: Text(
                                              'Load More Activity',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.leafGreen,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

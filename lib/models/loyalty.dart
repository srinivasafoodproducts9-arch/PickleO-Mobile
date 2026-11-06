import 'package:flutter/material.dart';

/// Tier summary inside LoyaltyAccount: { "id": 2, "name": "PickleO Connoisseur", "min_points": 200 }
class LoyaltyTierInfo {
  final int id;
  final String name;
  final int minPoints;

  const LoyaltyTierInfo({
    required this.id,
    required this.name,
    this.minPoints = 0,
  });

  factory LoyaltyTierInfo.fromJson(Map<String, dynamic> json) {
    return LoyaltyTierInfo(
      id: (json['id'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? 'Pickle Rookie',
      minPoints: (json['min_points'] ?? json['minPoints'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'min_points': minPoints,
      };
}

/// Expiring soon details inside LoyaltyAccount: { "points": 50, "on": "2027-10-13T16:13:13.000Z" }
class ExpiringSoon {
  final int points;
  final DateTime? on;

  const ExpiringSoon({
    required this.points,
    this.on,
  });

  factory ExpiringSoon.fromJson(Map<String, dynamic> json) {
    final rawDate = json['on']?.toString();
    DateTime? parsedDate;
    if (rawDate != null && rawDate.trim().isNotEmpty && rawDate != 'null') {
      parsedDate = DateTime.tryParse(rawDate);
    }
    return ExpiringSoon(
      points: (json['points'] as num?)?.toInt() ?? 0,
      on: parsedDate,
    );
  }

  bool get hasExpiring => points > 0 && on != null;

  int get daysRemaining {
    if (on == null) return 0;
    return on!.difference(DateTime.now()).inDays.clamp(0, 365);
  }

  String get formattedDate {
    if (on == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${on!.day} ${months[on!.month - 1]} ${on!.year}';
  }
}

/// Loyalty account details returned by GET /consumer/loyalty/account
class LoyaltyAccount {
  final int balance; // Spendable Spice Points
  final int pending; // Pending from recent orders (not spendable yet)
  final int earned12m; // Rolling 12-month net points (determines tier)
  final LoyaltyTierInfo tier;
  final LoyaltyTierInfo? nextTier; // null if top tier reached
  final int pointsToGo;
  final double progressPct;
  final bool canRedeem;
  final int redeemBlocksAvailable;
  final int redeemBlockPoints; // 400
  final int redeemBlockRupees; // 40
  final ExpiringSoon? expiringSoon;

  const LoyaltyAccount({
    required this.balance,
    required this.pending,
    required this.earned12m,
    required this.tier,
    this.nextTier,
    required this.pointsToGo,
    required this.progressPct,
    required this.canRedeem,
    required this.redeemBlocksAvailable,
    this.redeemBlockPoints = 400,
    this.redeemBlockRupees = 40,
    this.expiringSoon,
  });

  factory LoyaltyAccount.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    final rawTier = data['tier'];
    final tier = rawTier is Map<String, dynamic>
        ? LoyaltyTierInfo.fromJson(rawTier)
        : const LoyaltyTierInfo(id: 1, name: 'Pickle Rookie', minPoints: 0);

    final rawNextTier = data['next_tier'] ?? data['nextTier'];
    final nextTier = rawNextTier is Map<String, dynamic>
        ? LoyaltyTierInfo.fromJson(rawNextTier)
        : null;

    final rawExpiring = data['expiring_soon'] ?? data['expiringSoon'];
    final expiringSoon = rawExpiring is Map<String, dynamic>
        ? ExpiringSoon.fromJson(rawExpiring)
        : null;

    final balanceVal = (data['balance'] as num?)?.toInt() ?? 0;
    final redeemBlocks = (data['redeem_blocks_available'] ??
            data['redeemBlocksAvailable'] as num?)
        ?.toInt() ??
        (balanceVal ~/ 400);

    return LoyaltyAccount(
      balance: balanceVal,
      pending: (data['pending'] as num?)?.toInt() ?? 0,
      earned12m: (data['earned_12m'] ?? data['earned12m'] as num?)?.toInt() ??
          balanceVal,
      tier: tier,
      nextTier: nextTier,
      pointsToGo: (data['points_to_go'] ?? data['pointsToGo'] as num?)?.toInt() ?? 0,
      progressPct: (data['progress_pct'] ?? data['progressPct'] as num?)?.toDouble() ?? 0.0,
      canRedeem: data['can_redeem'] == true || data['canRedeem'] == true || balanceVal >= 400,
      redeemBlocksAvailable: redeemBlocks,
      redeemBlockPoints: (data['redeem_block_points'] ??
              data['redeemBlockPoints'] as num?)
          ?.toInt() ??
          400,
      redeemBlockRupees: (data['redeem_block_rupees'] ??
              data['redeemBlockRupees'] as num?)
          ?.toInt() ??
          40,
      expiringSoon: expiringSoon,
    );
  }

  factory LoyaltyAccount.initial([int points = 0]) {
    final tier = points >= 500
        ? const LoyaltyTierInfo(id: 3, name: 'Martaban Master', minPoints: 500)
        : points >= 200
            ? const LoyaltyTierInfo(id: 2, name: 'PickleO Connoisseur', minPoints: 200)
            : const LoyaltyTierInfo(id: 1, name: 'Pickle Rookie', minPoints: 0);

    final nextTier = points < 200
        ? const LoyaltyTierInfo(id: 2, name: 'PickleO Connoisseur', minPoints: 200)
        : points < 500
            ? const LoyaltyTierInfo(id: 3, name: 'Martaban Master', minPoints: 500)
            : null;

    final toGo = nextTier != null ? (nextTier.minPoints - points).clamp(0, 500) : 0;
    final pct = nextTier != null
        ? (((points - tier.minPoints) / (nextTier.minPoints - tier.minPoints)) * 100)
            .clamp(0.0, 100.0)
        : 100.0;

    return LoyaltyAccount(
      balance: points,
      pending: 0,
      earned12m: points,
      tier: tier,
      nextTier: nextTier,
      pointsToGo: toGo,
      progressPct: pct,
      canRedeem: points >= 400,
      redeemBlocksAvailable: points ~/ 400,
      redeemBlockPoints: 400,
      redeemBlockRupees: 40,
      expiringSoon: null,
    );
  }
}

/// Loyalty ledger entry from GET /consumer/loyalty/ledger
class LoyaltyLedgerItem {
  final String id;
  final String title;
  final int points; // Signed: positive for credit, negative for debit/reversal
  final String state; // 'pending', 'credited', 'redeemed', 'voided', 'reversed', 'expired', 'adjusted'
  final String createdAt;
  final String? orderId;
  final String? expiresAt;

  const LoyaltyLedgerItem({
    required this.id,
    required this.title,
    required this.points,
    required this.state,
    required this.createdAt,
    this.orderId,
    this.expiresAt,
  });

  factory LoyaltyLedgerItem.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as num?)?.toInt() ?? 0;
    final rawDate = json['created_at']?.toString() ??
        json['createdAt']?.toString() ??
        json['date']?.toString();

    String friendlyDate = rawDate ?? 'Recent';
    if (rawDate != null) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final now = DateTime.now();
        final diff = now.difference(parsed);
        if (diff.inDays == 0 && now.day == parsed.day) {
          friendlyDate = 'Today';
        } else if (diff.inDays <= 1 && now.day - parsed.day == 1) {
          friendlyDate = 'Yesterday';
        } else {
          const months = [
            'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
          ];
          friendlyDate = '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
        }
      }
    }

    return LoyaltyLedgerItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Spice Points Activity',
      points: rawPoints,
      state: (json['state'] ?? 'credited').toString().toLowerCase().trim(),
      createdAt: friendlyDate,
      orderId: json['order_id']?.toString() ?? json['orderId']?.toString(),
      expiresAt: json['expires_at']?.toString() ?? json['expiresAt']?.toString(),
    );
  }

  bool get isPending => state == 'pending';
  bool get isCredited => state == 'credited';
  bool get isRedeemed => state == 'redeemed';
  bool get isVoided => state == 'voided';
  bool get isReversed => state == 'reversed';
  bool get isExpired => state == 'expired';
  bool get isAdjusted => state == 'adjusted';

  Color get stateColor {
    switch (state) {
      case 'pending':
        return const Color(0xFFD97706); // Amber
      case 'credited':
        return const Color(0xFF0F5132); // Green
      case 'redeemed':
        return const Color(0xFF4338CA); // Indigo
      case 'voided':
      case 'reversed':
      case 'expired':
        return const Color(0xFFB91C1C); // Red
      default:
        return const Color(0xFF2C160E);
    }
  }

  Color get stateBgColor {
    switch (state) {
      case 'pending':
        return const Color(0xFFFEF3C7);
      case 'credited':
        return const Color(0xFFDFF3E6);
      case 'redeemed':
        return const Color(0xFFEEF2FF);
      case 'voided':
      case 'reversed':
      case 'expired':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  String get stateBadgeText {
    switch (state) {
      case 'pending':
        return 'Pending';
      case 'credited':
        return 'Credited';
      case 'redeemed':
        return 'Redeemed';
      case 'voided':
        return 'Voided';
      case 'reversed':
        return 'Reversed';
      case 'expired':
        return 'Expired';
      case 'adjusted':
        return 'Adjusted';
      default:
        return state.toUpperCase();
    }
  }

  IconData get iconData {
    if (title.toLowerCase().contains('rating') ||
        title.toLowerCase().contains('photo')) {
      return Icons.photo_camera_outlined;
    }
    if (title.toLowerCase().contains('order')) {
      return Icons.shopping_bag_outlined;
    }
    if (title.toLowerCase().contains('welcome')) {
      return Icons.celebration_outlined;
    }
    if (isRedeemed) {
      return Icons.account_balance_wallet_outlined;
    }
    if (isPending) {
      return Icons.hourglass_top_outlined;
    }
    return Icons.workspace_premium_outlined;
  }
}

/// Response from GET /consumer/loyalty/ledger?limit=20&nextToken=`<token>`
class LoyaltyLedgerResponse {
  final List<LoyaltyLedgerItem> items;
  final String? nextToken;

  const LoyaltyLedgerResponse({
    required this.items,
    this.nextToken,
  });

  factory LoyaltyLedgerResponse.fromJson(Map<String, dynamic> json) {
    final list = <LoyaltyLedgerItem>[];
    final dynamic rawItems = json['items'] ?? json['data'] ?? json['ledger'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          list.add(LoyaltyLedgerItem.fromJson(item));
        }
      }
    }

    final rawToken = json['nextToken'] ?? json['next_token'];
    return LoyaltyLedgerResponse(
      items: list,
      nextToken: (rawToken != null && rawToken.toString().isNotEmpty && rawToken != 'null')
          ? rawToken.toString()
          : null,
    );
  }
}

/// Tier perk item from GET /consumer/loyalty/tiers
class LoyaltyTierPerk {
  final int id;
  final String name;
  final int minPoints;
  final int cashbackPct;
  final bool freeDelivery;
  final bool earlyAccess;
  final bool prioritySupport;
  final String birthdayPerk;

  const LoyaltyTierPerk({
    required this.id,
    required this.name,
    required this.minPoints,
    required this.cashbackPct,
    required this.freeDelivery,
    required this.earlyAccess,
    required this.prioritySupport,
    required this.birthdayPerk,
  });

  factory LoyaltyTierPerk.fromJson(Map<String, dynamic> json) {
    return LoyaltyTierPerk(
      id: (json['id'] as num?)?.toInt() ?? 1,
      name: json['name']?.toString() ?? 'Pickle Rookie',
      minPoints: (json['min_points'] ?? json['minPoints'] as num?)?.toInt() ?? 0,
      cashbackPct: (json['cashback_pct'] ?? json['cashbackPct'] as num?)?.toInt() ?? 0,
      freeDelivery: json['free_delivery'] == true || json['freeDelivery'] == true,
      earlyAccess: json['early_access'] == true || json['earlyAccess'] == true,
      prioritySupport: json['priority_support'] == true || json['prioritySupport'] == true,
      birthdayPerk: json['birthday_perk']?.toString() ??
          json['birthdayPerk']?.toString() ??
          'voucher',
    );
  }

  List<String> get perkDescriptions {
    final list = <String>[];
    if (minPoints == 0) {
      list.add('1 Spice Point for every ₹10 spent');
    }
    if (cashbackPct > 0) {
      list.add('$cashbackPct% cashback to wallet on delivered orders');
    }
    if (freeDelivery) {
      list.add('Free delivery across all orders');
    }
    if (earlyAccess) {
      list.add('Early access to seasonal batches');
    }
    if (prioritySupport) {
      list.add('Priority WhatsApp support');
    }
    if (birthdayPerk == 'free_jar') {
      list.add('Free birthday jar with your annual order');
    } else {
      list.add('Birthday celebration voucher');
    }
    return list;
  }
}

/// Response from GET /consumer/loyalty/tiers
class LoyaltyTiersResponse {
  final List<LoyaltyTierPerk> items;

  const LoyaltyTiersResponse({
    required this.items,
  });

  factory LoyaltyTiersResponse.fromJson(Map<String, dynamic> json) {
    final list = <LoyaltyTierPerk>[];
    final dynamic rawItems = json['items'] ?? json['tiers'] ?? json['data'];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map<String, dynamic>) {
          list.add(LoyaltyTierPerk.fromJson(item));
        }
      }
    }
    return LoyaltyTiersResponse(items: list);
  }

  static List<LoyaltyTierPerk> defaultTiers() => const [
        LoyaltyTierPerk(
          id: 1,
          name: 'Pickle Rookie',
          minPoints: 0,
          cashbackPct: 0,
          freeDelivery: false,
          earlyAccess: false,
          prioritySupport: false,
          birthdayPerk: 'voucher',
        ),
        LoyaltyTierPerk(
          id: 2,
          name: 'PickleO Connoisseur',
          minPoints: 200,
          cashbackPct: 5,
          freeDelivery: false,
          earlyAccess: true,
          prioritySupport: false,
          birthdayPerk: 'free_jar',
        ),
        LoyaltyTierPerk(
          id: 3,
          name: 'Martaban Master',
          minPoints: 500,
          cashbackPct: 10,
          freeDelivery: true,
          earlyAccess: false,
          prioritySupport: true,
          birthdayPerk: 'free_jar',
        ),
      ];
}

/// Result from POST /consumer/loyalty/redeem
class LoyaltyRedeemResult {
  final int pointsDebited;
  final double walletCredited;
  final int balance;
  final double walletBalance;

  const LoyaltyRedeemResult({
    required this.pointsDebited,
    required this.walletCredited,
    required this.balance,
    required this.walletBalance,
  });

  factory LoyaltyRedeemResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    return LoyaltyRedeemResult(
      pointsDebited: (data['points_debited'] ?? data['pointsDebited'] as num?)?.toInt() ?? 400,
      walletCredited: (data['wallet_credited'] ?? data['walletCredited'] as num?)?.toDouble() ?? 40.0,
      balance: (data['balance'] as num?)?.toInt() ?? 0,
      walletBalance: (data['wallet_balance'] ?? data['walletBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Response from POST /consumer/wallet/top-up/order (201)
class WalletTopUpOrder {
  final String keyId;
  final String orderId;
  final int amount; // in paise
  final String currency;
  final String requestId;
  final String paymentStatus;

  const WalletTopUpOrder({
    required this.keyId,
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.requestId,
    this.paymentStatus = 'Pending',
  });

  factory WalletTopUpOrder.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    return WalletTopUpOrder(
      keyId: data['keyId']?.toString() ??
          data['razorpayKeyId']?.toString() ??
          data['key']?.toString() ??
          '',
      orderId: data['orderId']?.toString() ??
          data['razorpayOrderId']?.toString() ??
          data['id']?.toString() ??
          '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      currency: data['currency']?.toString() ?? 'INR',
      requestId: data['requestId']?.toString() ?? '',
      paymentStatus: data['paymentStatus']?.toString() ?? 'Pending',
    );
  }
}

/// Response from POST /consumer/wallet/top-up/verify (200)
class WalletTopUpVerifyResult {
  final String paymentStatus;
  final double amountCredited;
  final double walletBalance;
  final String transactionId;

  const WalletTopUpVerifyResult({
    required this.paymentStatus,
    required this.amountCredited,
    required this.walletBalance,
    required this.transactionId,
  });

  factory WalletTopUpVerifyResult.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;

    return WalletTopUpVerifyResult(
      paymentStatus: data['paymentStatus']?.toString() ?? 'Paid',
      amountCredited: (data['amountCredited'] ?? data['amount'] as num?)?.toDouble() ?? 0.0,
      walletBalance: (data['walletBalance'] ?? data['balance'] as num?)?.toDouble() ?? 0.0,
      transactionId: data['transactionId']?.toString() ??
          data['id']?.toString() ??
          '',
    );
  }
}

/// Pending/credited points lot associated with an order
class OrderPointsLot {
  final int points;
  final String state; // 'pending', 'credited', 'voided', 'reversed'

  const OrderPointsLot({
    required this.points,
    required this.state,
  });

  factory OrderPointsLot.fromJson(Map<String, dynamic> json) {
    return OrderPointsLot(
      points: (json['points'] as num?)?.toInt() ?? 0,
      state: (json['state'] ?? 'pending').toString().toLowerCase().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points,
        'state': state,
      };

  bool get isPending => state == 'pending';
  bool get isCredited => state == 'credited';
  bool get isVoided => state == 'voided';
  bool get isReversed => state == 'reversed';
}

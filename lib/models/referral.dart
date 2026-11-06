import 'dart:convert';

/// Represents statistics of friends referred by the current user
class ReferralStats {
  final int joined;
  final int ordered;
  final int rewarded;
  final int expired;

  const ReferralStats({
    this.joined = 0,
    this.ordered = 0,
    this.rewarded = 0,
    this.expired = 0,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) {
    return ReferralStats(
      joined: (json['joined'] as num?)?.toInt() ?? 0,
      ordered: (json['ordered'] as num?)?.toInt() ?? 0,
      rewarded: (json['rewarded'] as num?)?.toInt() ?? 0,
      expired: (json['expired'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'joined': joined,
        'ordered': ordered,
        'rewarded': rewarded,
        'expired': expired,
      };
}

/// Represents the configuration rules for the referral programme (overridable by backend REFERRAL_CONFIG)
class ReferralConfig {
  /// Default: ₹100 reward credited to referrer wallet once friend's order is delivered
  final double referrerRewardRs;

  /// Default: ₹100 discount off referee's first jar
  final double refereeDiscountRs;

  /// Default: 20 rewarded referrals per month cap
  final int monthlyCap;

  /// Default: ₹5,000 lifetime reward cap in wallet cash
  final double lifetimeRewardCapRs;

  /// Default: 30-day attribution window for referral links/clicks
  final int attributionWindowDays;

  const ReferralConfig({
    this.referrerRewardRs = 100.0,
    this.refereeDiscountRs = 100.0,
    this.monthlyCap = 20,
    this.lifetimeRewardCapRs = 5000.0,
    this.attributionWindowDays = 30,
  });

  factory ReferralConfig.fromJson(Map<String, dynamic> json) {
    return ReferralConfig(
      referrerRewardRs: (json['referrerRewardRs'] ??
              json['referrerReward'] ??
              json['rewardRs']) is num
          ? (json['referrerRewardRs'] ??
                  json['referrerReward'] ??
                  json['rewardRs'] as num)
              .toDouble()
          : 100.0,
      refereeDiscountRs: (json['refereeDiscountRs'] ??
              json['refereeDiscount'] ??
              json['discountRs']) is num
          ? (json['refereeDiscountRs'] ??
                  json['refereeDiscount'] ??
                  json['discountRs'] as num)
              .toDouble()
          : 100.0,
      monthlyCap: (json['monthlyCap'] ??
              json['monthly_cap'] ??
              json['monthlyRewardedCap']) is num
          ? (json['monthlyCap'] ??
                  json['monthly_cap'] ??
                  json['monthlyRewardedCap'] as num)
              .toInt()
          : 20,
      lifetimeRewardCapRs: (json['lifetimeRewardCapRs'] ??
              json['lifetimeRewardCap'] ??
              json['lifetime_reward_cap_rs'] ??
              json['lifetimeCapRs']) is num
          ? (json['lifetimeRewardCapRs'] ??
                  json['lifetimeRewardCap'] ??
                  json['lifetime_reward_cap_rs'] ??
                  json['lifetimeCapRs'] as num)
              .toDouble()
          : 5000.0,
      attributionWindowDays: (json['attributionWindowDays'] ??
              json['attribution_window_days'] ??
              json['attributionWindow']) is num
          ? (json['attributionWindowDays'] ??
                  json['attribution_window_days'] ??
                  json['attributionWindow'] as num)
              .toInt()
          : 30,
    );
  }

  Map<String, dynamic> toJson() => {
        'referrerRewardRs': referrerRewardRs,
        'refereeDiscountRs': refereeDiscountRs,
        'monthlyCap': monthlyCap,
        'lifetimeRewardCapRs': lifetimeRewardCapRs,
        'attributionWindowDays': attributionWindowDays,
      };
}

/// Represents the caps on monthly and lifetime referrals
class ReferralCap {
  /// Remaining rewarded referrals allowed in the current calendar month (default cap: 20)
  final int monthlyRemaining;

  /// Maximum rewarded referrals permitted per month (default: 20)
  final int monthlyCap;

  /// Server-provided lifetime remaining count (null if not explicitly returned by API)
  final int? lifetimeRemaining;

  /// Lifetime referral rewards cap in rupees (₹5,000 max rewards)
  final double lifetimeRewardCapRs;

  const ReferralCap({
    this.monthlyRemaining = 20,
    this.monthlyCap = 20,
    this.lifetimeRemaining,
    this.lifetimeRewardCapRs = 5000.0,
  });

  factory ReferralCap.fromJson(
    Map<String, dynamic> json, {
    ReferralConfig config = const ReferralConfig(),
  }) {
    final cap = (json['monthlyCap'] as num?)?.toInt() ??
        (json['monthly_cap'] as num?)?.toInt() ??
        config.monthlyCap;
    final remaining = (json['monthlyRemaining'] as num?)?.toInt() ??
        (json['monthly_remaining'] as num?)?.toInt() ??
        cap;

    return ReferralCap(
      monthlyRemaining: remaining,
      monthlyCap: cap,
      lifetimeRemaining: (json['lifetimeRemaining'] as num?)?.toInt() ??
          (json['lifetime_remaining'] as num?)?.toInt(),
      lifetimeRewardCapRs: (json['lifetimeRewardCapRs'] as num?)?.toDouble() ??
          (json['lifetime_cap_rs'] as num?)?.toDouble() ??
          (json['lifetimeRewardCap'] as num?)?.toDouble() ??
          config.lifetimeRewardCapRs,
    );
  }

  Map<String, dynamic> toJson() => {
        'monthlyRemaining': monthlyRemaining,
        'monthlyCap': monthlyCap,
        if (lifetimeRemaining != null) 'lifetimeRemaining': lifetimeRemaining,
        'lifetimeRewardCapRs': lifetimeRewardCapRs,
      };
}

/// Represents a customer's custom referral code request
class CustomCodeRequest {
  final String code;
  final String status; // 'pending_approval', 'approved', 'rejected'
  final String? requestedAt;
  final String? reviewedAt;
  final String? rejectionReason;

  const CustomCodeRequest({
    required this.code,
    required this.status,
    this.requestedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  bool get isPending => status == 'pending_approval';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory CustomCodeRequest.fromJson(Map<String, dynamic> json) {
    return CustomCodeRequest(
      code: json['code']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending_approval',
      requestedAt: json['requestedAt']?.toString() ?? json['requested_at']?.toString(),
      reviewedAt: json['reviewedAt']?.toString() ?? json['reviewed_at']?.toString(),
      rejectionReason: json['rejectionReason']?.toString() ?? json['rejection_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'status': status,
        if (requestedAt != null) 'requestedAt': requestedAt,
        if (reviewedAt != null) 'reviewedAt': reviewedAt,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };
}

/// Information returned by GET /consumer/referral/me
class ReferralProgramme {
  final String code;
  final String link;
  final double rewardRs;
  final double discountRs;
  final bool programmeActive;
  final ReferralStats stats;
  final ReferralCap cap;
  final ReferralConfig config;
  final CustomCodeRequest? customCodeRequest;
  final Map<String, String> shareTexts;

  const ReferralProgramme({
    required this.code,
    required this.link,
    required this.rewardRs,
    required this.discountRs,
    required this.programmeActive,
    required this.stats,
    required this.cap,
    this.config = const ReferralConfig(),
    this.customCodeRequest,
    this.shareTexts = const {},
  });

  factory ReferralProgramme.fromJson(Map<String, dynamic> json) {
    Map<String, String> shares = {};
    if (json['shareTexts'] is Map) {
      (json['shareTexts'] as Map).forEach((k, v) {
        if (k != null && v != null) {
          shares[k.toString()] = v.toString();
        }
      });
    }

    // Check for optional REFERRAL_CONFIG record that can override defaults
    final configJson = (json['REFERRAL_CONFIG'] is Map<String, dynamic>)
        ? json['REFERRAL_CONFIG'] as Map<String, dynamic>
        : ((json['referralConfig'] is Map<String, dynamic>)
            ? json['referralConfig'] as Map<String, dynamic>
            : ((json['config'] is Map<String, dynamic>)
                ? json['config'] as Map<String, dynamic>
                : null));

    final parsedConfig = configJson != null
        ? ReferralConfig.fromJson(configJson)
        : const ReferralConfig();

    final reward = (json['rewardRs'] as num?)?.toDouble() ??
        (json['referrerReward'] as num?)?.toDouble() ??
        parsedConfig.referrerRewardRs;

    final discount = (json['discountRs'] as num?)?.toDouble() ??
        (json['refereeDiscount'] as num?)?.toDouble() ??
        parsedConfig.refereeDiscountRs;

    final customReqJson = (json['customCodeRequest'] is Map<String, dynamic>)
        ? json['customCodeRequest'] as Map<String, dynamic>
        : ((json['custom_code_request'] is Map<String, dynamic>)
            ? json['custom_code_request'] as Map<String, dynamic>
            : null);
    final customCodeReq = customReqJson != null
        ? CustomCodeRequest.fromJson(customReqJson)
        : null;

    return ReferralProgramme(
      code: json['code']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      rewardRs: reward,
      discountRs: discount,
      programmeActive: json['programmeActive'] == true,
      stats: json['stats'] is Map<String, dynamic>
          ? ReferralStats.fromJson(json['stats'])
          : const ReferralStats(),
      cap: json['cap'] is Map<String, dynamic>
          ? ReferralCap.fromJson(json['cap'], config: parsedConfig)
          : ReferralCap(
              monthlyRemaining: parsedConfig.monthlyCap,
              monthlyCap: parsedConfig.monthlyCap,
              lifetimeRewardCapRs: parsedConfig.lifetimeRewardCapRs,
            ),
      config: parsedConfig,
      customCodeRequest: customCodeReq,
      shareTexts: shares,
    );
  }

  String getShareText({String medium = 'wa'}) {
    if (shareTexts.containsKey(medium) && shareTexts[medium]!.isNotEmpty) {
      return shareTexts[medium]!;
    }
    return 'Try PickleO and get ₹${discountRs.toInt()} off your first order: $link';
  }
}

/// Single referred friend item returned by GET /consumer/referral/list
class ReferralFriend {
  final String firstName;
  final String initials;
  final String state; // 'joined', 'ordered', 'rewarded', 'expired'
  final String? createdAt;

  const ReferralFriend({
    required this.firstName,
    required this.initials,
    required this.state,
    this.createdAt,
  });

  factory ReferralFriend.fromJson(Map<String, dynamic> json) {
    final fName = json['firstName']?.toString() ?? 'Friend';
    String inits = json['initials']?.toString() ?? '';
    if (inits.isEmpty && fName.isNotEmpty) {
      inits = fName.substring(0, 1).toUpperCase();
    }
    return ReferralFriend(
      firstName: fName,
      initials: inits,
      state: json['state']?.toString().toLowerCase() ?? 'joined',
      createdAt: json['createdAt']?.toString(),
    );
  }

  /// Status badge label and display colors
  String get statusLabel {
    switch (state) {
      case 'rewarded':
        return '₹100 earned';
      case 'ordered':
        return 'First jar ordered';
      case 'expired':
        return 'Expired';
      case 'joined':
      default:
        return 'Joined · yet to order';
    }
  }

  bool get isRewarded => state == 'rewarded';
  bool get isOrdered => state == 'ordered';
  bool get isPending => state == 'joined';
  bool get isExpired => state == 'expired';
}

/// Paginated referral list response from GET /consumer/referral/list
class ReferralListResponse {
  final List<ReferralFriend> items;
  final String? nextCursor;

  const ReferralListResponse({
    required this.items,
    this.nextCursor,
  });

  factory ReferralListResponse.fromJson(Map<String, dynamic> json) {
    final list = <ReferralFriend>[];
    if (json['items'] is List) {
      for (final item in json['items']) {
        if (item is Map<String, dynamic>) {
          list.add(ReferralFriend.fromJson(item));
        }
      }
    }
    return ReferralListResponse(
      items: list,
      nextCursor: json['nextCursor']?.toString(),
    );
  }
}

/// Result of public code validation: GET /consumer/referral/validate?code=CODE
class ReferralValidation {
  final bool valid;
  final String? referrerFirstName;
  final double? discountRs;
  final double? minOrder;

  const ReferralValidation({
    required this.valid,
    this.referrerFirstName,
    this.discountRs,
    this.minOrder,
  });

  factory ReferralValidation.fromJson(Map<String, dynamic> json) {
    return ReferralValidation(
      valid: json['valid'] == true,
      referrerFirstName: json['referrerFirstName']?.toString(),
      discountRs: (json['discountRs'] as num?)?.toDouble(),
      minOrder: (json['minOrder'] as num?)?.toDouble(),
    );
  }
}

/// Attribution outcome inside OTP verification: POST /consumer/auth/otp/verify
class ReferralAttribution {
  final bool accepted;
  final String? state; // 'joined'
  final String? couponCode; // e.g. 'REF-PRIYA100'
  final double? discountRs;
  final double? minOrder;
  final String? expiresAt;
  final String? referrerFirstName;
  final String? errorCode; // e.g. 'REF_ALREADY_CUSTOMER'
  final String? message;

  const ReferralAttribution({
    required this.accepted,
    this.state,
    this.couponCode,
    this.discountRs,
    this.minOrder,
    this.expiresAt,
    this.referrerFirstName,
    this.errorCode,
    this.message,
  });

  factory ReferralAttribution.fromJson(Map<String, dynamic> json) {
    return ReferralAttribution(
      accepted: json['accepted'] == true,
      state: json['state']?.toString(),
      couponCode: json['couponCode']?.toString(),
      discountRs: (json['discountRs'] as num?)?.toDouble(),
      minOrder: (json['minOrder'] as num?)?.toDouble(),
      expiresAt: json['expiresAt']?.toString(),
      referrerFirstName: json['referrerFirstName']?.toString(),
      errorCode: json['code']?.toString(),
      message: json['message']?.toString(),
    );
  }

  bool get isAlreadyCustomer => errorCode == 'REF_ALREADY_CUSTOMER';
}

/// Locally persisted pending referral info
class PendingReferral {
  final String code;
  final String medium; // 'wa', 'sms', 'manual', etc.
  final DateTime clickedAt;

  const PendingReferral({
    required this.code,
    required this.medium,
    required this.clickedAt,
  });

  factory PendingReferral.fromJson(Map<String, dynamic> json) {
    return PendingReferral(
      code: json['code']?.toString() ?? '',
      medium: json['medium']?.toString() ?? 'manual',
      clickedAt: DateTime.tryParse(json['clickedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'medium': medium,
        'clickedAt': clickedAt.toIso8601String(),
      };

  /// Returns true if the pending referral is older than 30 days
  bool get isExpired {
    final difference = DateTime.now().difference(clickedAt);
    return difference.inDays >= 30;
  }

  static PendingReferral? tryParse(String? jsonStr) {
    if (jsonStr == null || jsonStr.trim().isEmpty) return null;
    try {
      final map = jsonDecode(jsonStr);
      if (map is Map<String, dynamic>) {
        final item = PendingReferral.fromJson(map);
        if (item.code.isNotEmpty && !item.isExpired) {
          return item;
        }
      }
    } catch (_) {}
    return null;
  }
}

/// Wallet transaction ledger entry from GET /consumer/wallet
class WalletLedgerItem {
  final String id;
  final String type; // 'credit', 'debit', 'reversal'
  final double amount;
  final String title;
  final String? description;
  final String? createdAt;
  final String? orderId;

  const WalletLedgerItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.title,
    this.description,
    this.createdAt,
    this.orderId,
  });

  factory WalletLedgerItem.fromJson(Map<String, dynamic> json) {
    final rawAmt = json['amount'] ?? json['amountRs'] ?? json['amt'] ?? json['value'] ?? 0;
    final rawType = (json['type'] ?? json['transactionType'] ?? json['entryType'] ?? 'credit')
        .toString()
        .toLowerCase();
    final rawTitle = json['title'] ??
        json['description'] ??
        json['reason'] ??
        json['name'] ??
        (rawType.contains('referral') ? 'Referral Reward' : 'Wallet Activity');

    final rawDate = json['createdAt']?.toString() ??
        json['created_at']?.toString() ??
        json['timestamp']?.toString() ??
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

    return WalletLedgerItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? json['ledgerId']?.toString() ?? '',
      type: rawType,
      amount: (rawAmt as num?)?.toDouble() ?? 0.0,
      title: rawTitle.toString(),
      description: json['description']?.toString() ?? json['details']?.toString(),
      createdAt: friendlyDate,
      orderId: json['orderId']?.toString() ?? json['order_id']?.toString(),
    );
  }

  bool get isCredit =>
      type == 'credit' ||
      type.contains('reward') ||
      type.contains('cashback') ||
      type.contains('bonus') ||
      type.contains('topup') ||
      type.contains('voucher');
  bool get isDebit => type == 'debit' || type.contains('order');
  bool get isReversal => type == 'reversal' || type.contains('refund');
}

/// Complete response from GET /consumer/wallet
class WalletDetails {
  final double balance;
  final String currency;
  final List<WalletLedgerItem> ledger;

  const WalletDetails({
    required this.balance,
    this.currency = 'INR',
    this.ledger = const [],
  });

  factory WalletDetails.fromJson(Map<String, dynamic> json) {
    final map = (json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : (json['wallet'] is Map<String, dynamic>
            ? json['wallet'] as Map<String, dynamic>
            : json);

    final list = <WalletLedgerItem>[];
    final dynamic rawList = map['ledger'] ??
        map['transactions'] ??
        map['history'] ??
        map['entries'] ??
        map['items'] ??
        map['activity'] ??
        json['ledger'] ??
        json['transactions'];

    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          list.add(WalletLedgerItem.fromJson(item));
        }
      }
    }

    final dynamic rawBalance = map['balance'] ??
        map['walletBalance'] ??
        map['wallet_balance'] ??
        map['availableBalance'] ??
        map['available_balance'] ??
        json['balance'] ??
        0.0;

    return WalletDetails(
      balance: (rawBalance as num?)?.toDouble() ?? 0.0,
      currency: map['currency']?.toString() ?? json['currency']?.toString() ?? 'INR',
      ledger: list,
    );
  }
}


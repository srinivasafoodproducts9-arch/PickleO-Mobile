import 'coupon.dart';

/// Represents an offer or promotional deal returned by GET /consumer/offers
class OfferItem {
  final String id;
  final String title;
  final String code;
  final String description;
  final String offerType; // 'product', 'order', etc.
  final List<String> productIds;
  final String discountType; // 'flat', 'percentage', 'pct'
  final double discountValue;
  final double? discountPercent;
  final String status; // 'Active', etc.
  final double minimumOrderValue;
  final double? maxDiscountAmount;
  final int? totalRedemptionLimit;
  final int? perCustomerLimit;
  final bool flashBanner;
  final String? startsAt;
  final String? endsAt;
  final String imageKey;
  final String imageUrl;
  final String? createdAt;
  final String? updatedAt;

  const OfferItem({
    required this.id,
    required this.title,
    required this.code,
    this.description = '',
    this.offerType = 'order',
    this.productIds = const [],
    this.discountType = 'flat',
    this.discountValue = 0.0,
    this.discountPercent,
    this.status = 'Active',
    this.minimumOrderValue = 0.0,
    this.maxDiscountAmount,
    this.totalRedemptionLimit,
    this.perCustomerLimit,
    this.flashBanner = false,
    this.startsAt,
    this.endsAt,
    this.imageKey = '',
    this.imageUrl = '',
    this.createdAt,
    this.updatedAt,
  });

  /// Check if the offer is actively marked as Active
  bool get isActive => status.trim().toLowerCase() == 'active';

  /// Check if this is a percentage based discount
  bool get isPercentage {
    final dt = discountType.trim().toLowerCase();
    return dt == 'percentage' || dt == 'percent' || dt == 'pct';
  }

  /// Formatted discount badge string (e.g., '20% OFF' or 'Flat ₹20 OFF')
  String get discountBadgeText {
    if (isPercentage) {
      final pct = discountPercent ?? discountValue;
      final pctStr =
          pct % 1 == 0 ? pct.toInt().toString() : pct.toStringAsFixed(1);
      return '$pctStr% OFF';
    } else {
      final val = discountValue;
      final valStr =
          val % 1 == 0 ? val.toInt().toString() : val.toStringAsFixed(1);
      return 'Flat ₹$valStr OFF';
    }
  }

  /// Converts this OfferItem into a CouponOffer for seamless checkout and cart calculation
  CouponOffer toCouponOffer() {
    return CouponOffer(
      code: code.toUpperCase(),
      desc: title.isNotEmpty ? title : description,
      type: isPercentage ? 'pct' : 'flat',
      value: isPercentage ? (discountPercent ?? discountValue) : discountValue,
      minOrder: minimumOrderValue,
      cap: maxDiscountAmount,
    );
  }

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    final imageKey = json['imageKey']?.toString() ??
        json['image_key']?.toString() ??
        '';
    String imageUrl = json['imageUrl']?.toString() ??
        json['image_url']?.toString() ??
        '';
    if (imageUrl.isEmpty && imageKey.isNotEmpty) {
      imageUrl =
          'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$imageKey';
    }

    List<String> prodIds = [];
    if (json['productIds'] is List) {
      prodIds = (json['productIds'] as List)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (json['product_ids'] is List) {
      prodIds = (json['product_ids'] as List)
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    double parseNum(dynamic val, [double defaultVal = 0.0]) {
      if (val == null) return defaultVal;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? defaultVal;
    }

    int? parseInt(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString());
    }

    return OfferItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      code: (json['code']?.toString() ?? '').trim().toUpperCase(),
      description: json['description']?.toString() ?? '',
      offerType: json['offerType']?.toString() ??
          json['offer_type']?.toString() ??
          'order',
      productIds: prodIds,
      discountType: json['discountType']?.toString() ??
          json['discount_type']?.toString() ??
          'flat',
      discountValue: parseNum(json['discountValue'] ?? json['discount_value']),
      discountPercent: (json['discountPercent'] != null ||
              json['discount_percent'] != null)
          ? parseNum(json['discountPercent'] ?? json['discount_percent'])
          : null,
      status: json['status']?.toString() ?? 'Active',
      minimumOrderValue: parseNum(
          json['minimumOrderValue'] ?? json['minimum_order_value']),
      maxDiscountAmount: (json['maxDiscountAmount'] != null ||
              json['max_discount_amount'] != null)
          ? parseNum(
              json['maxDiscountAmount'] ?? json['max_discount_amount'])
          : null,
      totalRedemptionLimit: parseInt(
          json['totalRedemptionLimit'] ?? json['total_redemption_limit']),
      perCustomerLimit: parseInt(
          json['perCustomerLimit'] ?? json['per_customer_limit']),
      flashBanner: json['flashBanner'] == true ||
          json['flash_banner'] == true ||
          json['flashBanner']?.toString().toLowerCase() == 'true',
      startsAt: json['startsAt']?.toString() ?? json['starts_at']?.toString(),
      endsAt: json['endsAt']?.toString() ?? json['ends_at']?.toString(),
      imageKey: imageKey,
      imageUrl: imageUrl,
      createdAt:
          json['createdAt']?.toString() ?? json['created_at']?.toString(),
      updatedAt:
          json['updatedAt']?.toString() ?? json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'code': code,
      'description': description,
      'offerType': offerType,
      'productIds': productIds,
      'discountType': discountType,
      'discountValue': discountValue,
      'discountPercent': discountPercent,
      'status': status,
      'minimumOrderValue': minimumOrderValue,
      'maxDiscountAmount': maxDiscountAmount,
      'totalRedemptionLimit': totalRedemptionLimit,
      'perCustomerLimit': perCustomerLimit,
      'flashBanner': flashBanner,
      'startsAt': startsAt,
      'endsAt': endsAt,
      'imageKey': imageKey,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}

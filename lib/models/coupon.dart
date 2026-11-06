class CouponOffer {
  final String code;
  final String desc;
  final String type; // 'flat' or 'pct'
  final double value;
  final double minOrder;
  final double? cap;

  const CouponOffer({
    required this.code,
    required this.desc,
    required this.type,
    required this.value,
    this.minOrder = 0.0,
    this.cap,
  });

  bool isEligible(double subtotal) => subtotal >= minOrder;

  double calculateDiscount(double subtotal) {
    if (!isEligible(subtotal)) return 0.0;
    if (type == 'pct') {
      final disc = (subtotal * value / 100.0).roundToDouble();
      if (cap != null && disc > cap!) {
        return cap!;
      }
      return disc;
    } else {
      return value > subtotal ? subtotal : value;
    }
  }

  String get valueLabel {
    if (type == 'pct') {
      final capStr = cap != null ? ' up to ₹${cap!.toInt()}' : '';
      return '${value.toInt()}% off$capStr';
    }
    return '₹${value.toInt()} off';
  }

  String get minLabel {
    if (minOrder > 0) {
      return 'On orders above ₹${minOrder.toInt()}';
    }
    return 'No minimum order';
  }

  static List<CouponOffer> get defaultCoupons => const [
        CouponOffer(
          code: 'PICKLEFIRST',
          desc: '₹100 off your first pantry order',
          type: 'flat',
          value: 100.0,
          minOrder: 0.0,
        ),
        CouponOffer(
          code: 'TRADITION20',
          desc: '20% off on jars & combos above ₹499',
          type: 'pct',
          value: 20.0,
          minOrder: 499.0,
          cap: 150.0,
        ),
        CouponOffer(
          code: 'FREEPACK',
          desc: 'Cushion packaging on us',
          type: 'flat',
          value: 15.0,
          minOrder: 0.0,
        ),
      ];
}

class CouponApplyResult {
  final bool success;
  final String message;
  final double discountAmount;

  const CouponApplyResult({
    required this.success,
    required this.message,
    this.discountAmount = 0.0,
  });
}


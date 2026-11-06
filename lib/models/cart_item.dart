import 'product.dart';

class CartItem {
  final Product product;
  final String selectedWeight;
  final String? variantId;
  final ProductVariant? variant;
  int quantity;
  final int availableQuantity;
  final bool inStock;
  final double lineTotal;

  CartItem({
    required this.product,
    required this.selectedWeight,
    this.variantId,
    this.variant,
    this.quantity = 1,
    this.availableQuantity = 0,
    this.inStock = true,
    this.lineTotal = 0.0,
  });

  String get effectiveVariantId =>
      (variantId != null && variantId!.isNotEmpty)
          ? variantId!
          : (variant?.id.isNotEmpty == true ? variant!.id : product.id);

  double get unitPrice =>
      variant != null && variant!.price > 0
          ? variant!.price
          : (product.pricesByWeight[selectedWeight] ?? product.basePrice);

  double get totalPrice =>
      lineTotal > 0 ? lineTotal : unitPrice * quantity;

  String get itemKey =>
      (variantId != null && variantId!.isNotEmpty)
          ? '${product.id}_$variantId'
          : '${product.id}_$selectedWeight';

  CartItem copyWith({
    Product? product,
    String? selectedWeight,
    String? variantId,
    ProductVariant? variant,
    int? quantity,
    int? availableQuantity,
    bool? inStock,
    double? lineTotal,
  }) {
    return CartItem(
      product: product ?? this.product,
      selectedWeight: selectedWeight ?? this.selectedWeight,
      variantId: variantId ?? this.variantId,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      inStock: inStock ?? this.inStock,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': product.id,
    'variantId': variantId ?? variant?.id,
    'name': product.name,
    'weight': selectedWeight,
    'quantity': quantity,
    'price': unitPrice,
    'lineTotal': totalPrice,
  };

  Map<String, dynamic> toCacheJson() => {
    'productId': product.id,
    'variantId': variantId ?? variant?.id,
    'weight': selectedWeight,
    'quantity': quantity,
    'availableQuantity': availableQuantity,
    'inStock': inStock,
    'lineTotal': lineTotal,
  };
}

/// Model representing the response from PUT /consumer/cart/{variantId}
class CartItemResponse {
  final String productId;
  final String? variantId;
  final int quantity;
  final int availableQuantity;

  const CartItemResponse({
    required this.productId,
    this.variantId,
    required this.quantity,
    this.availableQuantity = 0,
  });

  factory CartItemResponse.fromJson(Map<String, dynamic> json) {
    return CartItemResponse(
      productId: json['productId']?.toString() ?? json['variantId']?.toString() ?? '',
      variantId: json['variantId']?.toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      availableQuantity: (json['availableQuantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    if (variantId != null) 'variantId': variantId,
    'quantity': quantity,
    'availableQuantity': availableQuantity,
  };
}

/// Model representing the response from DELETE /consumer/cart/{productId}
class CartItemDeleteResponse {
  final bool deleted;

  const CartItemDeleteResponse({this.deleted = true});

  factory CartItemDeleteResponse.fromJson(Map<String, dynamic> json) {
    return CartItemDeleteResponse(
      deleted: json['deleted'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'deleted': deleted,
  };
}

/// Model representing the response from DELETE /consumer/cart
class ClearCartResponse {
  final bool deleted;
  final int removedCount;

  const ClearCartResponse({
    this.deleted = true,
    this.removedCount = 0,
  });

  factory ClearCartResponse.fromJson(Map<String, dynamic> json) {
    return ClearCartResponse(
      deleted: json['deleted'] == true,
      removedCount: (json['removedCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'deleted': deleted,
    'removedCount': removedCount,
  };
}

/// Model representing an item from GET /consumer/cart
class ConsumerCartItem {
  final String productId;
  final String? variantId;
  final int quantity;
  final Product product;
  final ProductVariant? variant;
  final int availableQuantity;
  final bool inStock;
  final double lineTotal;

  const ConsumerCartItem({
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.product,
    this.variant,
    this.availableQuantity = 0,
    this.inStock = true,
    this.lineTotal = 0.0,
  });

  factory ConsumerCartItem.fromJson(Map<String, dynamic> json) {
    final rawProd = json['product'];
    final product = (rawProd is Map<String, dynamic>)
        ? Product.fromJson(rawProd)
        : (rawProd is Map
            ? Product.fromJson(Map<String, dynamic>.from(rawProd))
            : Product.fromJson({'id': json['productId']?.toString() ?? ''}));

    final String? prodIdStr = json['productId']?.toString();
    String? rawVariantId =
        json['variantId']?.toString() ?? json['skuId']?.toString();
    if ((rawVariantId == null || rawVariantId.isEmpty) &&
        prodIdStr != null &&
        prodIdStr.isNotEmpty &&
        prodIdStr != product.id) {
      rawVariantId = prodIdStr;
    }

    ProductVariant? matchedVariant;
    if (json['variant'] is Map) {
      matchedVariant =
          ProductVariant.fromJson(Map<String, dynamic>.from(json['variant']));
    } else if (rawVariantId != null &&
        rawVariantId.isNotEmpty &&
        product.variants.isNotEmpty) {
      matchedVariant =
          product.variants.where((v) => v.id == rawVariantId).firstOrNull;
    } else if (product.variants.isNotEmpty) {
      matchedVariant = product.variants
          .where((v) => v.id == prodIdStr || v.id == product.id)
          .firstOrNull;
    }

    return ConsumerCartItem(
      productId: prodIdStr ?? product.id,
      variantId: rawVariantId ?? matchedVariant?.id,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      product: product,
      variant: matchedVariant,
      availableQuantity: (json['availableQuantity'] as num?)?.toInt() ?? 0,
      inStock: json['inStock'] != false,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    if (variantId != null) 'variantId': variantId,
    'quantity': quantity,
    'availableQuantity': availableQuantity,
    'inStock': inStock,
    'lineTotal': lineTotal,
  };
}

/// Price breakdown from GET /consumer/cart → priceBreakdown
class CartPriceBreakdown {
  final String currency;
  final double itemsMrpTotal;
  final double productDiscount;
  final double couponDiscount;
  final double deliveryFee;
  final double standardDeliveryFee;
  final bool freeDelivery;
  final double cushionPackagingFee;
  final double? totalPayable;
  final bool taxesIncluded;

  const CartPriceBreakdown({
    this.currency = 'INR',
    this.itemsMrpTotal = 0.0,
    this.productDiscount = 0.0,
    this.couponDiscount = 0.0,
    this.deliveryFee = 0.0,
    this.standardDeliveryFee = 0.0,
    this.freeDelivery = false,
    this.cushionPackagingFee = 0.0,
    this.totalPayable,
    this.taxesIncluded = true,
  });

  factory CartPriceBreakdown.fromJson(Map<String, dynamic> json) {
    return CartPriceBreakdown(
      currency: json['currency']?.toString() ?? 'INR',
      itemsMrpTotal: (json['itemsMrpTotal'] as num?)?.toDouble() ?? 0.0,
      productDiscount: (json['productDiscount'] as num?)?.toDouble() ?? 0.0,
      couponDiscount: (json['couponDiscount'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      standardDeliveryFee:
          (json['standardDeliveryFee'] as num?)?.toDouble() ?? 0.0,
      freeDelivery: json['freeDelivery'] == true,
      cushionPackagingFee:
          (json['cushionPackagingFee'] as num?)?.toDouble() ?? 0.0,
      totalPayable: (json['totalPayable'] as num?)?.toDouble(),
      taxesIncluded: json['taxesIncluded'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'currency': currency,
    'itemsMrpTotal': itemsMrpTotal,
    'productDiscount': productDiscount,
    'couponDiscount': couponDiscount,
    'deliveryFee': deliveryFee,
    'standardDeliveryFee': standardDeliveryFee,
    'freeDelivery': freeDelivery,
    'cushionPackagingFee': cushionPackagingFee,
    if (totalPayable != null) 'totalPayable': totalPayable,
    'taxesIncluded': taxesIncluded,
  };
}

/// Applied promotion/coupon from GET /consumer/cart → appliedPromotion
class CartAppliedPromotion {
  final String id;
  final String code;
  final String title;
  final String offerType;
  final double discountAmount;

  const CartAppliedPromotion({
    this.id = '',
    this.code = '',
    this.title = '',
    this.offerType = '',
    this.discountAmount = 0.0,
  });

  factory CartAppliedPromotion.fromJson(Map<String, dynamic> json) {
    return CartAppliedPromotion(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      offerType: json['offerType']?.toString() ?? '',
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'title': title,
    'offerType': offerType,
    'discountAmount': discountAmount,
  };
}

/// Pricing issue entry from GET /consumer/cart → pricingIssues
class CartPricingIssue {
  final String code;
  final String message;
  final String? productId;

  const CartPricingIssue({
    required this.code,
    required this.message,
    this.productId,
  });

  factory CartPricingIssue.fromJson(Map<String, dynamic> json) {
    return CartPricingIssue(
      code: json['code']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      productId: json['productId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (productId != null) 'productId': productId,
  };
}

/// Model representing delivery information from GET /consumer/cart → delivery
class CartDeliveryInfo {
  final bool serviceable;
  final String pinCode;
  final List<String> slots;
  final bool codAvailable;
  final String sla;
  final double deliveryCharge;
  final bool minimumOrderMet;

  const CartDeliveryInfo({
    this.serviceable = true,
    this.pinCode = '',
    this.slots = const [],
    this.codAvailable = true,
    this.sla = '',
    this.deliveryCharge = 0.0,
    this.minimumOrderMet = true,
  });

  factory CartDeliveryInfo.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    final slotsList = <String>[];
    if (rawSlots is List) {
      for (final s in rawSlots) {
        if (s != null && s.toString().trim().isNotEmpty) {
          slotsList.add(s.toString().trim());
        }
      }
    }

    return CartDeliveryInfo(
      serviceable: json['serviceable'] != false,
      pinCode: json['pinCode']?.toString() ?? '',
      slots: slotsList,
      codAvailable: json['codAvailable'] != false,
      sla: json['sla']?.toString() ?? '',
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      minimumOrderMet: json['minimumOrderMet'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'serviceable': serviceable,
    'pinCode': pinCode,
    'slots': slots,
    'codAvailable': codAvailable,
    'sla': sla,
    'deliveryCharge': deliveryCharge,
    'minimumOrderMet': minimumOrderMet,
  };
}

/// Full response from GET /consumer/cart
class ConsumerCartResponse {
  final List<ConsumerCartItem> items;
  final int itemCount;
  final double subtotal;
  final CartPriceBreakdown? priceBreakdown;
  final CartAppliedPromotion? appliedPromotion;
  final String? addressId;
  final Map<String, dynamic>? delivery;
  final CartDeliveryInfo? deliveryInfo;
  final bool checkoutReady;
  final List<CartPricingIssue> pricingIssues;

  const ConsumerCartResponse({
    this.items = const [],
    this.itemCount = 0,
    this.subtotal = 0.0,
    this.priceBreakdown,
    this.appliedPromotion,
    this.addressId,
    this.delivery,
    this.deliveryInfo,
    this.checkoutReady = false,
    this.pricingIssues = const [],
  });

  factory ConsumerCartResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((m) => ConsumerCartItem.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <ConsumerCartItem>[];

    CartPriceBreakdown? breakdown;
    final rawBreakdown = json['priceBreakdown'];
    if (rawBreakdown is Map<String, dynamic>) {
      breakdown = CartPriceBreakdown.fromJson(rawBreakdown);
    } else if (rawBreakdown is Map) {
      breakdown =
          CartPriceBreakdown.fromJson(Map<String, dynamic>.from(rawBreakdown));
    }

    CartAppliedPromotion? promotion;
    final rawPromotion = json['appliedPromotion'];
    if (rawPromotion is Map<String, dynamic>) {
      promotion = CartAppliedPromotion.fromJson(rawPromotion);
    } else if (rawPromotion is Map) {
      promotion = CartAppliedPromotion.fromJson(
          Map<String, dynamic>.from(rawPromotion));
    }

    final rawIssues = json['pricingIssues'];
    final issuesList = (rawIssues is List)
        ? rawIssues
            .whereType<Map>()
            .map((m) =>
                CartPricingIssue.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <CartPricingIssue>[];

    Map<String, dynamic>? delivery;
    CartDeliveryInfo? deliveryInfo;
    final rawDelivery = json['delivery'];
    if (rawDelivery is Map<String, dynamic>) {
      delivery = rawDelivery;
      deliveryInfo = CartDeliveryInfo.fromJson(rawDelivery);
    } else if (rawDelivery is Map) {
      delivery = Map<String, dynamic>.from(rawDelivery);
      deliveryInfo = CartDeliveryInfo.fromJson(delivery);
    }

    return ConsumerCartResponse(
      items: itemsList,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? itemsList.length,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      priceBreakdown: breakdown,
      appliedPromotion: promotion,
      addressId: json['addressId']?.toString(),
      delivery: delivery,
      deliveryInfo: deliveryInfo,
      checkoutReady: json['checkoutReady'] == true,
      pricingIssues: issuesList,
    );
  }
}

import 'package:flutter/material.dart';

/// Feature flag for product reviews. Set to false for now, to be implemented later.
const bool showProductReviews = false;

/// Feature flag for product ratings. Set to false for now, to be implemented later.
const bool showProductRatings = false;

/// Represents a single SKU variant of a product (from GET /consumer/products variants)
class ProductVariant {
  final String id;
  final String sku;
  final String variantSize;
  final String label;
  final int serves;
  final String packaging;
  final int safetyStock;
  final bool bestValue;
  final int minOrderQty;
  final int maxOrderQty;
  final double mrp;
  final double price;
  final int stock;
  final String stockUnit;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  const ProductVariant({
    required this.id,
    this.sku = '',
    this.variantSize = '',
    this.label = '',
    this.serves = 0,
    this.packaging = '',
    this.safetyStock = 0,
    this.bestValue = false,
    this.minOrderQty = 1,
    this.maxOrderQty = 99,
    this.mrp = 0.0,
    this.price = 0.0,
    this.stock = 0,
    this.stockUnit = '',
    this.status = 'Active',
    this.createdAt,
    this.updatedAt,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    final num? rawPrice = json['price'] as num?;
    final num? rawMrp = json['mrp'] as num?;
    final double price = rawPrice?.toDouble() ?? 0.0;
    final double mrp = rawMrp?.toDouble() ?? (price > 0 ? price : 0.0);

    return ProductVariant(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      variantSize: json['variantSize']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      serves: (json['serves'] as num?)?.toInt() ?? 0,
      packaging: json['packaging']?.toString() ?? '',
      safetyStock: (json['safetyStock'] as num?)?.toInt() ?? 0,
      bestValue: json['bestValue'] == true,
      minOrderQty: (json['minOrderQty'] as num?)?.toInt() ?? 1,
      maxOrderQty: (json['maxOrderQty'] as num?)?.toInt() ?? 99,
      mrp: mrp,
      price: price > 0 ? price : mrp,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      stockUnit: json['stockUnit']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Active',
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sku': sku,
    'variantSize': variantSize,
    'label': label,
    'serves': serves,
    'packaging': packaging,
    'safetyStock': safetyStock,
    'bestValue': bestValue,
    'minOrderQty': minOrderQty,
    'maxOrderQty': maxOrderQty,
    'mrp': mrp,
    'price': price,
    'stock': stock,
    'stockUnit': stockUnit,
    'status': status,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  ProductVariant copyWith({
    String? id,
    String? sku,
    String? variantSize,
    String? label,
    int? serves,
    String? packaging,
    int? safetyStock,
    bool? bestValue,
    int? minOrderQty,
    int? maxOrderQty,
    double? mrp,
    double? price,
    int? stock,
    String? stockUnit,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      variantSize: variantSize ?? this.variantSize,
      label: label ?? this.label,
      serves: serves ?? this.serves,
      packaging: packaging ?? this.packaging,
      safetyStock: safetyStock ?? this.safetyStock,
      bestValue: bestValue ?? this.bestValue,
      minOrderQty: minOrderQty ?? this.minOrderQty,
      maxOrderQty: maxOrderQty ?? this.maxOrderQty,
      mrp: mrp ?? this.mrp,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      stockUnit: stockUnit ?? this.stockUnit,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Formats raw unit strings (e.g. "1000G" -> "1kg", "250G" -> "250g", "500G" -> "500g", "750 ml X 2" -> "750 ml X 2")
  static String formatUnitString(String raw, [String? stockUnitFallback]) {
    final clean = raw.trim();
    if (clean.isEmpty || clean.toLowerCase() == 'string') {
      if (stockUnitFallback != null &&
          stockUnitFallback.trim().isNotEmpty &&
          stockUnitFallback.toLowerCase() != 'string') {
        return formatUnitString(stockUnitFallback);
      }
      return '';
    }

    // Check for grams: e.g. "1000G", "1000 g", "1000gm", "250G", "500g"
    final gramMatch = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(g|gm|gms|grams?)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (gramMatch != null) {
      final val = double.tryParse(gramMatch.group(1)!) ?? 0;
      if (val >= 1000 && val % 1000 == 0) {
        return '${(val / 1000).toInt()}kg';
      } else if (val == val.toInt().toDouble()) {
        return '${val.toInt()}g';
      } else {
        return '${val}g';
      }
    }

    // Check for kg: e.g. "1KG", "1 kg", "1.5kg"
    final kgMatch = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(kg|kgs|kilograms?)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (kgMatch != null) {
      final val = double.tryParse(kgMatch.group(1)!) ?? 0;
      if (val == val.toInt().toDouble()) {
        return '${val.toInt()}kg';
      }
      return '${val}kg';
    }

    // Check for ml: e.g. "750ml", "750 ML", "500 ml"
    final mlMatch = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(ml|milliliters?)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (mlMatch != null) {
      final val = double.tryParse(mlMatch.group(1)!) ?? 0;
      if (val >= 1000 && val % 1000 == 0) {
        return '${(val / 1000).toInt()}L';
      } else if (val == val.toInt().toDouble()) {
        return '${val.toInt()}ml';
      }
      return '${val}ml';
    }

    // Check for litre: e.g. "1L", "1 litre"
    final lMatch = RegExp(
      r'^(\d+(?:\.\d+)?)\s*(l|litres?|liters?)$',
      caseSensitive: false,
    ).firstMatch(clean);
    if (lMatch != null) {
      final val = double.tryParse(lMatch.group(1)!) ?? 0;
      if (val == val.toInt().toDouble()) {
        return '${val.toInt()}L';
      }
      return '${val}L';
    }

    // Check for pure number: e.g. "250", "500", "1000"
    final numMatch = RegExp(r'^(\d+(?:\.\d+)?)$').firstMatch(clean);
    if (numMatch != null) {
      final val = double.tryParse(numMatch.group(1)!) ?? 0;
      if (val >= 1000 && val % 1000 == 0) {
        return '${(val / 1000).toInt()}kg';
      } else if (val == val.toInt().toDouble()) {
        return '${val.toInt()}g';
      } else {
        return '${val}g';
      }
    }

    return clean;
  }

  /// Formatted unit/weight representation (e.g. "250g", "500g", "1kg", "750 ml X 2")
  String get unitLabel {
    if (variantSize.trim().isNotEmpty &&
        variantSize.trim().toLowerCase() != 'string') {
      final formatted = formatUnitString(variantSize, stockUnit);
      if (formatted.isNotEmpty) return formatted;
    }

    // If variantSize is empty or invalid, check if label contains a unit (e.g. "Jar 250g")
    if (label.trim().isNotEmpty && label.trim().toLowerCase() != 'string') {
      final unitMatch = RegExp(
        r'(\d+(?:\.\d+)?)\s*(kg|kgs|g|gm|gms|ml|l|litre|liter)',
        caseSensitive: false,
      ).firstMatch(label);
      if (unitMatch != null) {
        return formatUnitString(unitMatch.group(0)!);
      }
      final lower = label.toLowerCase();
      if (!lower.contains('style') &&
          !lower.contains('traditional') &&
          !lower.contains('andhra')) {
        return label.trim();
      }
    }

    if (stockUnit.trim().isNotEmpty &&
        stockUnit.trim().toLowerCase() != 'string') {
      return formatUnitString(stockUnit);
    }

    return '250g';
  }

  String get displayLabel => unitLabel;

  double get discountAmount => (mrp - price).clamp(0.0, double.infinity);

  int get discountPercent =>
      mrp > price && mrp > 0 ? (((mrp - price) / mrp) * 100).round() : 0;

  bool get hasDiscount => mrp > price && (mrp - price) >= 1;

  String? get saveBadgeText {
    if (hasDiscount) {
      final amt = discountAmount.toInt();
      if (amt > 0) return 'Save ₹$amt';
    }
    if (bestValue) return 'Best Value';
    return null;
  }

  /// Calculates per-unit rate (e.g. "₹2.53/100ml" or "₹45/100g") matching Screenshot 2
  String? get unitPriceText {
    final str = '$variantSize $label'.toLowerCase();
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*(ml|l|g|kg|gm)').firstMatch(str);
    if (match != null && price > 0) {
      final numVal = double.tryParse(match.group(1)!) ?? 0.0;
      final unit = match.group(2)!;
      if (numVal > 0) {
        double multiplier = 1.0;
        final multiMatch = RegExp(r'(?:x|\*)\s*(\d+)').firstMatch(str);
        if (multiMatch != null) {
          multiplier = double.tryParse(multiMatch.group(1)!) ?? 1.0;
        }

        double totalInBaseUnit = numVal * multiplier;
        String baseUnit = 'g';
        if (unit == 'kg') {
          totalInBaseUnit *= 1000;
          baseUnit = 'g';
        } else if (unit == 'l') {
          totalInBaseUnit *= 1000;
          baseUnit = 'ml';
        } else if (unit == 'ml') {
          baseUnit = 'ml';
        }

        if (totalInBaseUnit > 0) {
          final rate = ((price / totalInBaseUnit) * 10000).truncate() / 100;
          return '₹${rate.toStringAsFixed(2)}/100$baseUnit';
        }
      }
    }

    if (serves > 0) {
      return 'Serves $serves';
    }
    if (packaging.isNotEmpty && packaging != 'string') {
      return packaging;
    }
    return null;
  }
}

class Product {
  final String id;
  final String name;
  final String categoryId;
  final String categoryName;
  final String maker;
  final String place;
  final String subtitle;
  final double basePrice;
  final double originalPrice;
  final double rating;
  final String reviewsDisplay;
  final int reviewCount;
  final String defaultWeight;
  final List<String> weightOptions;
  final Map<String, double> pricesByWeight;
  final int spiceLevel; // 1: Mild, 2: Medium Spicy, 3: Traditional Andhra Hot
  final String oilType;
  final String packaging;
  final bool isBestseller;
  final String description;
  final List<String> highlights;
  final List<String> ingredients;
  final String storyTitle;
  final String homemakerStory;
  final String? imageAsset;
  final String batchTag;
  final List<String> tags;
  final Color accentColor;
  final bool isVeg;

  final String? region;
  final double mrp;
  final double price;
  final int stock;
  final String? stockUnit;
  final int? lowStockThreshold;
  final int? unitsSold;
  final String? imageKey;
  final String? imageUrl;
  final List<Map<String, dynamic>> mediaItems;
  final String? createdAt;
  final String? updatedAt;

  // New fields from updated /consumer/products API
  final String? kitchenName;
  final String? rawSpiceLevel;
  final List<String> purityClaims;
  final String? sku;
  final String? variantSize;
  final String? label;
  final int serves;
  final int safetyStock;
  final bool bestValue;
  final int batchAgeDays;
  final int shelfLifeDays;
  final String? subcategory;
  final String? badge;
  final String? dietMark;
  final bool zeroPreservatives;
  final String? shortDescription;
  final String? featuredReviewName;
  final String? hsnCode;
  final double gstRate;
  final int minOrderQty;
  final int maxOrderQty;
  final String? deliveryPromise;
  final bool freeDelivery;
  final List<String> highlightTags;
  final List<String> searchKeywords;
  final String? seoTitle;
  final List<String> relatedProductIds;
  final List<String> frequentlyBoughtTogether;
  final String? catalogProductId;
  final String status;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    this.categoryName = 'Pickles & Achaar',
    this.region,
    required this.maker,
    required this.place,
    required this.subtitle,
    required this.basePrice,
    required this.originalPrice,
    required this.rating,
    required this.reviewsDisplay,
    required this.reviewCount,
    this.defaultWeight = '350g',
    required this.weightOptions,
    required this.pricesByWeight,
    required this.spiceLevel,
    this.oilType = 'Cold-Pressed Sesame Oil',
    this.packaging = 'Ceramic Martaban',
    this.isBestseller = true,
    required this.description,
    this.highlights = const [],
    this.ingredients = const [],
    required this.storyTitle,
    required this.homemakerStory,
    this.imageAsset,
    this.batchTag = "Grandma's Batch",
    this.tags = const [],
    this.accentColor = const Color(0xFF0F5132),
    this.isVeg = true,
    this.mrp = 0.0,
    this.price = 0.0,
    this.stock = 0,
    this.stockUnit,
    this.lowStockThreshold,
    this.unitsSold,
    this.imageKey,
    this.imageUrl,
    this.mediaItems = const [],
    this.createdAt,
    this.updatedAt,
    this.kitchenName,
    this.rawSpiceLevel,
    this.purityClaims = const [],
    this.sku,
    this.variantSize,
    this.label,
    this.serves = 0,
    this.safetyStock = 0,
    this.bestValue = false,
    this.batchAgeDays = 0,
    this.shelfLifeDays = 0,
    this.subcategory,
    this.badge,
    this.dietMark,
    this.zeroPreservatives = false,
    this.shortDescription,
    this.featuredReviewName,
    this.hsnCode,
    this.gstRate = 0.0,
    this.minOrderQty = 1,
    this.maxOrderQty = 99,
    this.deliveryPromise,
    this.freeDelivery = false,
    this.highlightTags = const [],
    this.searchKeywords = const [],
    this.seoTitle,
    this.relatedProductIds = const [],
    this.frequentlyBoughtTogether = const [],
    this.catalogProductId,
    this.status = 'Active',
    this.variants = const [],
  });

  bool get hasMultipleVariants => variants.length > 1;

  ProductVariant get defaultVariant => variants.isNotEmpty
      ? variants.first
      : ProductVariant(
          id: id,
          sku: sku ?? '',
          variantSize: defaultWeight,
          label: defaultWeight,
          packaging: packaging,
          mrp: originalPrice,
          price: basePrice,
          stock: stock,
          stockUnit: stockUnit ?? 'Jar',
          bestValue: bestValue,
          serves: serves,
          safetyStock: safetyStock,
          minOrderQty: minOrderQty,
          maxOrderQty: maxOrderQty,
          status: status,
        );

  String? get resolvedImageUrl {
    if (imageUrl != null &&
        imageUrl!.trim().isNotEmpty &&
        imageUrl != 'string' &&
        imageUrl != 'null') {
      final img = imageUrl!.trim();
      if (img.startsWith('http://') || img.startsWith('https://')) {
        return img;
      }
      if (!img.startsWith('assets/')) {
        return 'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$img';
      }
    }
    if (mediaItems.isNotEmpty) {
      final firstMedia = mediaItems.first;
      final mediaUrl = firstMedia['url']?.toString();
      if (mediaUrl != null &&
          mediaUrl.trim().isNotEmpty &&
          mediaUrl != 'string' &&
          mediaUrl != 'null') {
        final mUrl = mediaUrl.trim();
        if (mUrl.startsWith('http://') || mUrl.startsWith('https://')) {
          return mUrl;
        }
        if (!mUrl.startsWith('assets/')) {
          return 'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$mUrl';
        }
      }
    }
    if (imageKey != null &&
        imageKey!.trim().isNotEmpty &&
        imageKey != 'string' &&
        imageKey != 'null') {
      final key = imageKey!.trim();
      if (key.startsWith('http://') || key.startsWith('https://')) {
        return key;
      }
      return 'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$key';
    }
    return null;
  }

  List<String> get allImageUrls {
    final list = <String>[];
    if (resolvedImageUrl != null && resolvedImageUrl!.isNotEmpty) {
      list.add(resolvedImageUrl!);
    }
    for (final m in mediaItems) {
      final url = m['url']?.toString();
      if (url != null &&
          url.trim().isNotEmpty &&
          url != 'string' &&
          url != 'null' &&
          url.startsWith('http') &&
          !list.contains(url)) {
        list.add(url);
      }
    }
    return list;
  }

  String get resolvedDietMark {
    if (!isVeg) return 'Non-vegetarian';
    if (dietMark != null && dietMark!.trim().isNotEmpty && dietMark != 'string') {
      return dietMark!.trim();
    }
    return 'Vegetarian';
  }

  bool get hasValidNetworkImage =>
      resolvedImageUrl != null &&
      resolvedImageUrl!.trim().isNotEmpty &&
      resolvedImageUrl != 'string' &&
      resolvedImageUrl != 'null' &&
      (resolvedImageUrl!.startsWith('http://') ||
          resolvedImageUrl!.startsWith('https://'));

  bool get hasValidAssetImage =>
      imageAsset != null &&
      imageAsset!.trim().isNotEmpty &&
      imageAsset != 'string' &&
      imageAsset != 'null';

  bool get hasValidImage => hasValidNetworkImage || hasValidAssetImage;

  Product copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? categoryName,
    String? region,
    String? maker,
    String? place,
    String? subtitle,
    double? basePrice,
    double? originalPrice,
    double? rating,
    String? reviewsDisplay,
    int? reviewCount,
    String? defaultWeight,
    List<String>? weightOptions,
    Map<String, double>? pricesByWeight,
    int? spiceLevel,
    String? oilType,
    String? packaging,
    bool? isBestseller,
    String? description,
    List<String>? highlights,
    List<String>? ingredients,
    String? storyTitle,
    String? homemakerStory,
    String? imageAsset,
    String? batchTag,
    List<String>? tags,
    Color? accentColor,
    bool? isVeg,
    double? mrp,
    double? price,
    int? stock,
    String? stockUnit,
    int? lowStockThreshold,
    int? unitsSold,
    String? imageKey,
    String? imageUrl,
    List<Map<String, dynamic>>? mediaItems,
    String? createdAt,
    String? updatedAt,
    String? kitchenName,
    String? rawSpiceLevel,
    List<String>? purityClaims,
    String? sku,
    String? variantSize,
    String? label,
    int? serves,
    int? safetyStock,
    bool? bestValue,
    int? batchAgeDays,
    int? shelfLifeDays,
    String? subcategory,
    String? badge,
    String? dietMark,
    bool? zeroPreservatives,
    String? shortDescription,
    String? featuredReviewName,
    String? hsnCode,
    double? gstRate,
    int? minOrderQty,
    int? maxOrderQty,
    String? deliveryPromise,
    bool? freeDelivery,
    List<String>? highlightTags,
    List<String>? searchKeywords,
    String? seoTitle,
    List<String>? relatedProductIds,
    List<String>? frequentlyBoughtTogether,
    String? catalogProductId,
    String? status,
    List<ProductVariant>? variants,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      region: region ?? this.region,
      maker: maker ?? this.maker,
      place: place ?? this.place,
      subtitle: subtitle ?? this.subtitle,
      basePrice: basePrice ?? this.basePrice,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      reviewsDisplay: reviewsDisplay ?? this.reviewsDisplay,
      reviewCount: reviewCount ?? this.reviewCount,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      weightOptions: weightOptions ?? this.weightOptions,
      pricesByWeight: pricesByWeight ?? this.pricesByWeight,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      oilType: oilType ?? this.oilType,
      packaging: packaging ?? this.packaging,
      isBestseller: isBestseller ?? this.isBestseller,
      description: description ?? this.description,
      highlights: highlights ?? this.highlights,
      ingredients: ingredients ?? this.ingredients,
      storyTitle: storyTitle ?? this.storyTitle,
      homemakerStory: homemakerStory ?? this.homemakerStory,
      imageAsset: imageAsset ?? this.imageAsset,
      batchTag: batchTag ?? this.batchTag,
      tags: tags ?? this.tags,
      accentColor: accentColor ?? this.accentColor,
      isVeg: isVeg ?? this.isVeg,
      mrp: mrp ?? this.mrp,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      stockUnit: stockUnit ?? this.stockUnit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      unitsSold: unitsSold ?? this.unitsSold,
      imageKey: imageKey ?? this.imageKey,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaItems: mediaItems ?? this.mediaItems,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      kitchenName: kitchenName ?? this.kitchenName,
      rawSpiceLevel: rawSpiceLevel ?? this.rawSpiceLevel,
      purityClaims: purityClaims ?? this.purityClaims,
      sku: sku ?? this.sku,
      variantSize: variantSize ?? this.variantSize,
      label: label ?? this.label,
      serves: serves ?? this.serves,
      safetyStock: safetyStock ?? this.safetyStock,
      bestValue: bestValue ?? this.bestValue,
      batchAgeDays: batchAgeDays ?? this.batchAgeDays,
      shelfLifeDays: shelfLifeDays ?? this.shelfLifeDays,
      subcategory: subcategory ?? this.subcategory,
      badge: badge ?? this.badge,
      dietMark: dietMark ?? this.dietMark,
      zeroPreservatives: zeroPreservatives ?? this.zeroPreservatives,
      shortDescription: shortDescription ?? this.shortDescription,
      featuredReviewName: featuredReviewName ?? this.featuredReviewName,
      hsnCode: hsnCode ?? this.hsnCode,
      gstRate: gstRate ?? this.gstRate,
      minOrderQty: minOrderQty ?? this.minOrderQty,
      maxOrderQty: maxOrderQty ?? this.maxOrderQty,
      deliveryPromise: deliveryPromise ?? this.deliveryPromise,
      freeDelivery: freeDelivery ?? this.freeDelivery,
      highlightTags: highlightTags ?? this.highlightTags,
      searchKeywords: searchKeywords ?? this.searchKeywords,
      seoTitle: seoTitle ?? this.seoTitle,
      relatedProductIds: relatedProductIds ?? this.relatedProductIds,
      frequentlyBoughtTogether: frequentlyBoughtTogether ?? this.frequentlyBoughtTogether,
      catalogProductId: catalogProductId ?? this.catalogProductId,
      status: status ?? this.status,
      variants: variants ?? this.variants,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ??
            json['productId'] ??
            json['_id'] ??
            json['catalogProductId'])
        ?.toString() ??
        '';
    final name = json['name']?.toString() ?? '';
    final category = json['category']?.toString() ?? 'Pickle & Achaar';
    final region = json['region']?.toString();
    final rawKitchen = json['kitchen']?.toString();
    final String? kitchenName = (rawKitchen != null &&
            rawKitchen.trim().isNotEmpty &&
            rawKitchen != 'string' &&
            rawKitchen != 'null')
        ? rawKitchen.trim()
        : null;

    final rawTags = json['tags'];
    final tags = (rawTags is List)
        ? rawTags
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    final rawPurity = json['purityClaims'];
    final purityClaims = (rawPurity is List)
        ? rawPurity
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e != 'string')
            .toList()
        : <String>[];

    final rawHighlightTags = json['highlightTags'];
    final highlightTags = (rawHighlightTags is List)
        ? rawHighlightTags
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e != 'string')
            .toList()
        : <String>[];

    final rawSearchKeywords = json['searchKeywords'];
    final searchKeywords = (rawSearchKeywords is List)
        ? rawSearchKeywords
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty && e != 'string')
            .toList()
        : <String>[];

    final rawRelated = json['relatedProductIds'] ??
        json['related_product_ids'] ??
        json['relatedProducts'] ??
        json['related_products'];
    final relatedProductIds = (rawRelated is List)
        ? rawRelated
            .map((e) => e is Map
                ? (e['id'] ?? e['productId'] ?? e['_id'] ?? '').toString()
                : e.toString().trim())
            .where((e) => e.isNotEmpty && e != 'string' && e != 'null')
            .toList()
        : <String>[];

    final rawFbt = json['frequentlyBoughtTogether'] ??
        json['frequently_bought_together'] ??
        json['pairedProductIds'] ??
        json['paired_product_ids'] ??
        json['fbt'] ??
        json['companionProductIds'];
    final frequentlyBoughtTogether = (rawFbt is List)
        ? rawFbt
            .map((e) => e is Map
                ? (e['id'] ?? e['productId'] ?? e['_id'] ?? '').toString()
                : e.toString().trim())
            .where((e) => e.isNotEmpty && e != 'string' && e != 'null')
            .toList()
        : <String>[];

    final rawDiet = json['dietMark']?.toString();
    final String? dietMark = (rawDiet != null &&
            rawDiet.trim().isNotEmpty &&
            rawDiet != 'string' &&
            rawDiet != 'null')
        ? rawDiet.trim()
        : null;

    final num? rawPrice = json['price'] as num?;
    final num? rawMrp = json['mrp'] as num?;
    final double price = rawPrice?.toDouble() ?? 0.0;
    final double mrp = rawMrp?.toDouble() ?? (price > 0 ? price : 0.0);
    final double basePrice = price > 0 ? price : (mrp > 0 ? mrp : 199.0);
    final double originalPrice = mrp > 0 ? mrp : basePrice;

    final int stock = (json['stock'] as num?)?.toInt() ?? 0;
    final String? stockUnit = json['stockUnit']?.toString();
    final int? lowStockThreshold = (json['lowStockThreshold'] as num?)?.toInt();
    final int? unitsSold = (json['unitsSold'] as num?)?.toInt();
    final String? imageKey = json['imageKey']?.toString();
    final String? imageUrl = json['imageUrl']?.toString();
    final String? rawAsset = json['imageAsset']?.toString();
    final String? imageAsset = (rawAsset != null &&
            rawAsset.trim().isNotEmpty &&
            rawAsset.trim() != 'assets/images/avakaya.png')
        ? rawAsset.trim()
        : null;
    final mediaRaw = json['mediaItems'];
    final mediaItems = (mediaRaw is List)
        ? mediaRaw
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
        : <Map<String, dynamic>>[];

    final String? sku = json['sku']?.toString();
    final String? variantSize = json['variantSize']?.toString();
    final String? label = json['label']?.toString();
    final int serves = (json['serves'] as num?)?.toInt() ?? 0;
    final String packaging = (json['packaging'] != null &&
            json['packaging'].toString().isNotEmpty &&
            json['packaging'] != 'string')
        ? json['packaging'].toString()
        : (stockUnit ?? 'Ceramic Martaban');
    final int safetyStock = (json['safetyStock'] as num?)?.toInt() ?? 0;
    final bool bestValue = json['bestValue'] == true;
    final int batchAgeDays = (json['batchAgeDays'] as num?)?.toInt() ?? 0;
    final int shelfLifeDays = (json['shelfLifeDays'] as num?)?.toInt() ?? 0;
    final String? subcategory = json['subcategory']?.toString();
    final String? badge = (json['badge'] != null &&
            json['badge'].toString().isNotEmpty &&
            json['badge'] != 'string')
        ? json['badge'].toString()
        : null;
    final bool zeroPreservatives = json['zeroPreservatives'] == true;
    final String? shortDescription = (json['shortDescription'] != null &&
            json['shortDescription'].toString().isNotEmpty &&
            json['shortDescription'] != 'string')
        ? json['shortDescription'].toString()
        : null;
    final String? rawStoryTitle = json['storyTitle']?.toString();
    final String? rawDescription = json['description']?.toString();
    final String? featuredReviewName = json['featuredReviewName']?.toString();
    final int reviewCount =
        (json['reviewCount'] as num?)?.toInt() ?? (unitsSold ?? 142);
    final String? hsnCode = json['hsnCode']?.toString();
    final double gstRate = (json['gstRate'] as num?)?.toDouble() ?? 0.0;
    final int minOrderQty = (json['minOrderQty'] as num?)?.toInt() ?? 1;
    final int maxOrderQty = (json['maxOrderQty'] as num?)?.toInt() ?? 99;
    final String? deliveryPromise = (json['deliveryPromise'] != null &&
            json['deliveryPromise'].toString().isNotEmpty &&
            json['deliveryPromise'] != 'string')
        ? json['deliveryPromise'].toString()
        : null;
    final bool freeDelivery = json['freeDelivery'] == true;
    final String? seoTitle = json['seoTitle']?.toString();
    final String? catalogProductId = json['catalogProductId']?.toString();
    final String status = (json['status'] != null &&
            json['status'].toString().trim().isNotEmpty &&
            json['status'] != 'string')
        ? json['status'].toString().trim()
        : 'Active';

    // Parse Variants from API
    final rawVariants = json['variants'];
    final variants = <ProductVariant>[];
    if (rawVariants is List) {
      for (final v in rawVariants) {
        if (v is Map<String, dynamic>) {
          variants.add(ProductVariant.fromJson(v));
        } else if (v is Map) {
          variants.add(ProductVariant.fromJson(Map<String, dynamic>.from(v)));
        }
      }
    }

    // Determine default variant, basePrice, originalPrice, and weightOptions
    final double finalBasePrice;
    final double finalOriginalPrice;
    final String finalDefaultWeight;
    final List<String> weightOptions;
    final Map<String, double> pricesByWeight;
    final double finalPrice;
    final double finalMrp;
    final int finalStock;

    if (variants.isNotEmpty) {
      final firstVariant = variants.first;
      finalBasePrice = firstVariant.price > 0
          ? firstVariant.price
          : (basePrice > 0 ? basePrice : 199.0);
      finalOriginalPrice = firstVariant.mrp > 0
          ? firstVariant.mrp
          : (originalPrice > 0 ? originalPrice : finalBasePrice);
      finalDefaultWeight = firstVariant.displayLabel.isNotEmpty
          ? firstVariant.displayLabel
          : ((variantSize != null && variantSize.isNotEmpty && variantSize != 'string')
              ? ProductVariant.formatUnitString(variantSize)
              : '250g');
      weightOptions = variants.map((v) => v.displayLabel).toSet().toList();
      pricesByWeight = {
        for (final v in variants) v.displayLabel: v.price
      };
      finalPrice = firstVariant.price > 0 ? firstVariant.price : price;
      finalMrp = firstVariant.mrp > 0 ? firstVariant.mrp : (mrp > 0 ? mrp : finalPrice);
      finalStock = firstVariant.stock > 0 ? firstVariant.stock : stock;
    } else {
      finalDefaultWeight = (variantSize != null &&
              variantSize.trim().isNotEmpty &&
              variantSize != 'string')
          ? ProductVariant.formatUnitString(variantSize.trim())
          : ((stockUnit != null && stockUnit.trim().isNotEmpty)
              ? ProductVariant.formatUnitString(stockUnit.trim())
              : '250g');
      finalBasePrice = basePrice;
      finalOriginalPrice = originalPrice;
      weightOptions = [finalDefaultWeight, '500g', '1kg'];
      pricesByWeight = {
        finalDefaultWeight: basePrice,
        '500g': (basePrice * 1.8).roundToDouble(),
        '1kg': (basePrice * 3.4).roundToDouble(),
      };
      finalPrice = price;
      finalMrp = mrp;
      finalStock = stock;

      // Synthesize a single default variant
      variants.add(ProductVariant(
        id: id,
        sku: sku ?? '',
        variantSize: finalDefaultWeight,
        label: label ?? finalDefaultWeight,
        packaging: packaging,
        mrp: finalOriginalPrice,
        price: finalBasePrice,
        stock: stock,
        stockUnit: stockUnit ?? '',
        bestValue: bestValue,
        serves: serves,
        safetyStock: safetyStock,
        minOrderQty: minOrderQty,
        maxOrderQty: maxOrderQty,
        status: status,
      ));
    }

    // Spice calculation
    int spiceLevel = 1;
    final rawSpice = json['spiceLevel']?.toString().trim();
    if (rawSpice != null && rawSpice.isNotEmpty && rawSpice != 'string') {
      final parsed = int.tryParse(rawSpice);
      if (parsed != null && parsed >= 1 && parsed <= 3) {
        spiceLevel = parsed;
      } else {
        final lower = rawSpice.toLowerCase();
        if (lower.contains('hot') ||
            lower.contains('fiery') ||
            lower.contains('high') ||
            lower == '3') {
          spiceLevel = 3;
        } else if (lower.contains('med') || lower == '2') {
          spiceLevel = 2;
        } else {
          spiceLevel = 1;
        }
      }
    } else {
      final lowerTags = tags.map((t) => t.toLowerCase()).toList();
      if (lowerTags.any((t) =>
          t.contains('very spice') || t.contains('hot') || t.contains('fiery'))) {
        spiceLevel = 3;
      } else if (lowerTags
          .any((t) => t.contains('spicy') || t.contains('medium'))) {
        spiceLevel = 2;
      }
    }

    final categoryId =
        category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
    final maker = (kitchenName != null && kitchenName.isNotEmpty)
        ? kitchenName
        : ((region != null && region.trim().isNotEmpty)
            ? '$region Kitchen'
            : 'Artisanal Kitchen');
    final place = (region != null && region.trim().isNotEmpty)
        ? region
        : 'South India';

    // Veg / Non-veg calculation
    final d = (dietMark ??
            json['foodType'] ??
            json['dietType'] ??
            json['diet'] ??
            '')
        .toString()
        .toLowerCase()
        .trim();
    final combined =
        '${name.toLowerCase()} ${category.toLowerCase()} ${tags.join(' ').toLowerCase()}';

    // Comprehensive check for non-veg indicators in name, tags, or category
    final bool hasNonVegKeywords = combined.contains('fish') ||
        combined.contains('chicken') ||
        combined.contains('mutton') ||
        combined.contains('prawn') ||
        combined.contains('meat') ||
        combined.contains('seafood') ||
        combined.contains('crab') ||
        combined.contains('egg') ||
        combined.contains('keema') ||
        combined.contains('paya') ||
        combined.contains('boti') ||
        combined.contains('lamb') ||
        combined.contains('pork') ||
        combined.contains('beef') ||
        combined.contains('non-veg') ||
        combined.contains('non_veg') ||
        combined.contains('nonveg') ||
        combined.contains('non vegetarian') ||
        combined.contains('non-vegetarian');

    // Comprehensive check for non-veg diet markings
    final bool isNonVegDiet = d.contains('non') ||
        d.contains('non-veg') ||
        d.contains('nonveg') ||
        d.contains('non_veg') ||
        d.contains('non vegetarian') ||
        d.contains('non-vegetarian') ||
        d == 'nv';

    bool isVeg;
    if (hasNonVegKeywords || isNonVegDiet || json['isVeg'] == false) {
      isVeg = false;
    } else if (json['isVeg'] is bool) {
      isVeg = json['isVeg'] as bool;
    } else if (d.contains('veg') || d == 'v') {
      isVeg = true;
    } else {
      isVeg = true;
    }

    final String finalStoryTitle = (rawStoryTitle != null &&
            rawStoryTitle.isNotEmpty &&
            rawStoryTitle != 'string')
        ? rawStoryTitle
        : (region != null
            ? '$region Homemade Tradition'
            : 'Authentic Homemade Tradition');

    final String finalDescription = (rawDescription != null &&
            rawDescription.isNotEmpty &&
            rawDescription != 'string')
        ? rawDescription
        : 'Authentic handmade $name crafted using traditional home recipes, pure natural ingredients, and authentic regional techniques.';

    final String finalSubtitle = (shortDescription != null &&
            shortDescription.isNotEmpty &&
            shortDescription != 'string')
        ? shortDescription
        : (highlightTags.isNotEmpty
            ? highlightTags.join(' • ')
            : (tags.isNotEmpty ? tags.join(' • ') : category));

    final List<String> finalHighlights = highlightTags.isNotEmpty
        ? highlightTags
        : (purityClaims.isNotEmpty
            ? purityClaims
            : const [
                '100% Homemade',
                'Preservative Free',
                'Traditional Kitchen Recipe',
                'Small Batch Prepared',
              ]);

    final String batchTag = (badge != null && badge.isNotEmpty)
        ? badge
        : ((stockUnit != null && stockUnit.isNotEmpty)
            ? stockUnit
            : "Grandma's Batch");

    final bool isBestseller = (badge != null &&
            badge.toLowerCase().contains('bestseller')) ||
        json['isBestseller'] == true ||
        bestValue;

    return Product(
      id: id,
      name: name,
      categoryId: categoryId,
      categoryName: category,
      region: region,
      maker: maker,
      place: place,
      subtitle: finalSubtitle,
      basePrice: finalBasePrice,
      originalPrice: finalOriginalPrice,
      rating: 4.8,
      reviewsDisplay: unitsSold != null && unitsSold > 0 ? '$unitsSold' : '1.2k',
      reviewCount: reviewCount,
      defaultWeight: finalDefaultWeight,
      weightOptions: weightOptions,
      pricesByWeight: pricesByWeight,
      spiceLevel: spiceLevel,
      oilType: 'Traditional Cold-Pressed Oil',
      packaging: packaging,
      isBestseller: isBestseller,
      description: finalDescription,
      highlights: finalHighlights,
      ingredients: const [
        'Farm-fresh ingredients',
        'Cold-Pressed Oil',
        'Stone-ground Spices',
        'Rock Salt',
      ],
      storyTitle: finalStoryTitle,
      homemakerStory: finalDescription,
      imageAsset: imageAsset,
      batchTag: batchTag,
      tags: tags,
      accentColor: isVeg ? const Color(0xFF0F5132) : const Color(0xFFC0392B),
      isVeg: isVeg,
      mrp: finalMrp,
      price: finalPrice,
      stock: finalStock,
      stockUnit: stockUnit,
      lowStockThreshold: lowStockThreshold,
      unitsSold: unitsSold,
      imageKey: imageKey,
      imageUrl: imageUrl,
      mediaItems: mediaItems,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
      kitchenName: kitchenName,
      rawSpiceLevel: rawSpice,
      purityClaims: purityClaims,
      sku: sku,
      variantSize: variantSize,
      label: label,
      serves: serves,
      safetyStock: safetyStock,
      bestValue: bestValue,
      batchAgeDays: batchAgeDays,
      shelfLifeDays: shelfLifeDays,
      subcategory: subcategory,
      badge: badge,
      dietMark: dietMark,
      zeroPreservatives: zeroPreservatives,
      shortDescription: shortDescription,
      featuredReviewName: featuredReviewName,
      hsnCode: hsnCode,
      gstRate: gstRate,
      minOrderQty: minOrderQty,
      maxOrderQty: maxOrderQty,
      deliveryPromise: deliveryPromise,
      freeDelivery: freeDelivery,
      highlightTags: highlightTags,
      searchKeywords: searchKeywords,
      seoTitle: seoTitle,
      relatedProductIds: relatedProductIds,
      frequentlyBoughtTogether: frequentlyBoughtTogether,
      catalogProductId: catalogProductId,
      status: status,
      variants: variants,
    );
  }

  String get kitchen {
    if (kitchenName != null &&
        kitchenName!.trim().isNotEmpty &&
        kitchenName != 'string') {
      return kitchenName!.trim();
    }
    return '$maker • $place';
  }

  String get chillies => '🌶' * spiceLevel;
  String get spiceLabel {
    switch (spiceLevel) {
      case 1:
        return 'Mild';
      case 2:
        return 'Medium Spicy';
      case 3:
      default:
        return 'Traditional Andhra Hot';
    }
  }

  int get discountPercent =>
      (((originalPrice - basePrice) / originalPrice) * 100).round();

  String get image => imageAsset ?? 'assets/images/avakaya.png';
  String get weight => defaultWeight;
  static List<Product> get all => ProductData.products;

  double priceForWeight(String weight) {
    if (pricesByWeight.containsKey(weight)) {
      return pricesByWeight[weight]!;
    }
    if (weight == '500g') return (basePrice * 1.8).roundToDouble();
    if (weight == '1kg') return (basePrice * 3.4).roundToDouble();
    return basePrice;
  }
}

class ProductListResponse {
  final List<Product> items;
  final String? nextToken;
  final bool hasMore;

  const ProductListResponse({
    required this.items,
    this.nextToken,
    this.hasMore = false,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    final list = json['items'] as List? ?? [];
    final items = list
        .whereType<Map<String, dynamic>>()
        .map((m) => Product.fromJson(m))
        .where((p) => p.status.toLowerCase() == 'active')
        .toList();
    return ProductListResponse(
      items: items,
      nextToken: json['nextToken']?.toString(),
      hasMore: json['hasMore'] == true,
    );
  }
}

class ProductDetailsResponse {
  final List<Product> items;
  final List<String> missingIds;

  const ProductDetailsResponse({
    this.items = const [],
    this.missingIds = const [],
  });

  factory ProductDetailsResponse.fromJson(dynamic json) {
    final List<Product> items = [];
    final List<String> missing = [];

    if (json is List) {
      for (final m in json) {
        if (m is Map) {
          try {
            final p = Product.fromJson(Map<String, dynamic>.from(m));
            if (p.status.toLowerCase() == 'active') items.add(p);
          } catch (_) {}
        }
      }
      return ProductDetailsResponse(items: items);
    }
    if (json is Map) {
      final map = Map<String, dynamic>.from(json);
      final rawList = map['items'] ?? map['products'] ?? map['data'];
      if (rawList is List) {
        for (final m in rawList) {
          if (m is Map) {
            try {
              final p = Product.fromJson(Map<String, dynamic>.from(m));
              if (p.status.toLowerCase() == 'active') items.add(p);
            } catch (_) {}
          }
        }
      }
      final rawMissing = map['missingIds'];
      if (rawMissing is List) {
        missing.addAll(rawMissing.map((e) => e.toString()));
      }
      return ProductDetailsResponse(items: items, missingIds: missing);
    }
    return const ProductDetailsResponse();
  }
}

class ProductData {
  static const List<Product> products = [
    Product(
      id: 'avakaya',
      name: 'Andhra Avakaya Raw Mango Pickle',
      categoryId: 'pickles',
      categoryName: 'Mango & Avakaya',
      maker: 'Sri Lakshmi Kitchens',
      place: 'Guntur',
      subtitle: 'Sun-matured with cold-pressed pure sesame oil & stone-ground Guntur Teja chillies.',
      basePrice: 249,
      originalPrice: 299,
      rating: 4.8,
      reviewsDisplay: '1.2k',
      reviewCount: 312,
      defaultWeight: '350g',
      weightOptions: ['250g', '500g', '1kg'],
      pricesByWeight: {
        '250g': 249,
        '500g': 448,
        '1kg': 847,
      },
      spiceLevel: 3,
      oilType: 'Cold-Pressed Sesame (Gingelly) Oil',
      packaging: 'Ceramic Martaban',
      isBestseller: true,
      batchTag: "Grandma's Batch",
      tags: ['Sun-Dried', 'Gingelly Oil'],
      description:
          'Crafted following a 70-year-old heirloom family recipe from Guntur, Andhra Pradesh. Crisp, sour Ramkela and Totapuri raw mangoes are handpicked at dawn, slow-marinated in wood-pressed gingelly oil with whole red Guntur chillies, cracked mustard and sea salt, then sun-matured for 14 days in glazed porcelain martabans.',
      highlights: [
        'Sun-matured in porcelain martabans',
        'Cold-pressed pure sesame oil',
        'Zero artificial preservatives or vinegar',
        'Authentic grandmother recipe',
      ],
      ingredients: [
        'Raw Mango Cubes',
        'Cold-Pressed Sesame Oil',
        'Guntur Red Chilli Powder',
        'Cracked Mustard Seeds',
        'Fenugreek Seeds',
        'Pink Himalayan Rock Salt',
        'Turmeric',
        'Asafoetida (Hing)'
      ],
      storyTitle: "Grandmother's Guntur Heritage",
      homemakerStory:
          'Crafted following a 70-year-old heirloom family recipe from Guntur, Andhra Pradesh. Crisp, sour Ramkela and Totapuri raw mangoes are handpicked at dawn, slow-marinated in wood-pressed gingelly oil with whole red Guntur chillies, cracked mustard and sea salt, then sun-matured for 14 days in glazed porcelain martabans.',
      imageAsset: 'assets/images/avakaya.png',
      accentColor: Color(0xFFC0392B),
    ),
    Product(
      id: 'gongura',
      name: 'Authentic Andhra Gongura Pachadi',
      categoryId: 'pickles',
      categoryName: 'Gongura',
      maker: 'Godavari Kitchens',
      place: 'Rajahmundry',
      subtitle: 'Tangy roselle leaves tempered with garlic, fenugreek and dried red chillies.',
      basePrice: 219,
      originalPrice: 260,
      rating: 4.9,
      reviewsDisplay: '840',
      reviewCount: 188,
      defaultWeight: '300g',
      weightOptions: ['250g', '500g', '1kg'],
      pricesByWeight: {
        '250g': 219,
        '500g': 394,
        '1kg': 745,
      },
      spiceLevel: 2,
      oilType: 'Pure Wood-Pressed Sesame Oil',
      packaging: 'Glass Jar',
      isBestseller: true,
      batchTag: 'Tangy & Fiery',
      tags: ['Clay Pot Aged'],
      description:
          'Gongura grows wild along the Godavari banks after the monsoon. The leaves are wilted on low flame, pounded with roasted chillies and garlic, and aged two weeks in clay pots so the sourness mellows into the oil.',
      highlights: [
        'Rich in natural iron & antioxidants',
        'Slow simmered in sesame oil',
        'Signature tart & spicy kick',
      ],
      ingredients: [
        'Fresh Red Gongura Leaves',
        'Cold-Pressed Sesame Oil',
        'Guntur Red Chillies',
        'Garlic Pods',
        'Cumin',
        'Mustard Seeds',
        'Rock Salt'
      ],
      storyTitle: 'Leaves from the Godavari Delta',
      homemakerStory:
          'Gongura grows wild along the Godavari banks after the monsoon. The leaves are wilted on low flame, pounded with roasted chillies and garlic, and aged two weeks in clay pots so the sourness mellows into the oil.',
      imageAsset: 'assets/images/gongura.png',
      accentColor: Color(0xFF0F5132),
    ),
    Product(
      id: 'murukku',
      name: 'Butter Murukku & Ribbon Pakoda',
      categoryId: 'snacks',
      categoryName: 'Snacks',
      maker: 'Madurai Snacks Co',
      place: 'Tamil Nadu',
      subtitle: 'Hand-pressed rice and urad flour spirals fried in small batches with white butter.',
      basePrice: 149,
      originalPrice: 180,
      rating: 4.7,
      reviewsDisplay: '620',
      reviewCount: 140,
      defaultWeight: '200g',
      weightOptions: ['250g', '500g', '1kg'],
      pricesByWeight: {
        '250g': 149,
        '500g': 268,
        '1kg': 507,
      },
      spiceLevel: 1,
      oilType: 'Fresh Ghee Roast & Groundnut Oil',
      packaging: 'Eco Craft Pouch',
      isBestseller: true,
      batchTag: 'Crunchy Guaranteed',
      tags: ['Fresh Ghee Roast'],
      description:
          'Pressed through brass moulds the way Madurai households have done for generations, each batch is fried for exactly four minutes so the spirals stay airy and shatter at first bite.',
      highlights: [
        '100% Maida-Free & Palm-Oil-Free',
        'Desi butter and carom infusion',
        'Vacuum sealed for ultra-fresh crunch',
      ],
      ingredients: [
        'Raw Rice Flour',
        'Roasted Bengal Gram',
        'Desi Butter',
        'Ajwain (Carom)',
        'Sesame Seeds',
        'Groundnut Oil',
        'Sea Salt'
      ],
      storyTitle: 'Evening Chai Companion',
      homemakerStory:
          'Pressed through brass moulds the way Madurai households have done for generations, each batch is fried for exactly four minutes so the spirals stay airy and shatter at first bite.',
      imageAsset: 'assets/images/murukku.png',
      accentColor: Color(0xFFFC820C),
    ),
    Product(
      id: 'mixed',
      name: 'Veda Mixed Vegetable Achaar',
      categoryId: 'pickles',
      categoryName: 'Mixed',
      maker: 'Veda Achaar',
      place: 'Jaipur',
      subtitle: 'Carrot, cauliflower, green chilli and lime in pungent cold-pressed mustard oil.',
      basePrice: 199,
      originalPrice: 240,
      rating: 4.6,
      reviewsDisplay: '410',
      reviewCount: 96,
      defaultWeight: '400g',
      weightOptions: ['250g', '500g', '1kg'],
      pricesByWeight: {
        '250g': 199,
        '500g': 358,
        '1kg': 677,
      },
      spiceLevel: 2,
      oilType: 'Cold-Pressed Mustard Oil',
      packaging: 'Glass Jar',
      isBestseller: true,
      batchTag: 'Pahadi Style',
      tags: ['Mustard Oil'],
      description:
          'A winter ritual: vegetables are sun-dried for a day to remove moisture, then tossed with split mustard, fennel and nigella and left on the terrace until the oil turns amber.',
      highlights: [
        'Sun-dried winter vegetables',
        'Pure pungent mustard oil',
        'Traditional Rajasthan terrace curing',
      ],
      ingredients: [
        'Seasonal Vegetables',
        'Mustard Oil',
        'Fennel Seeds',
        'Nigella (Kalonji)',
        'Turmeric',
        'Rock Salt'
      ],
      storyTitle: 'Winter Pantry of Rajasthan',
      homemakerStory:
          'A winter ritual: vegetables are sun-dried for a day to remove moisture, then tossed with split mustard, fennel and nigella and left on the terrace until the oil turns amber.',
      imageAsset: 'assets/images/banner.png',
      accentColor: Color(0xFF964900),
    ),
    Product(
      id: 'chicken',
      name: 'Nellore Boneless Chicken Pickle',
      categoryId: 'pickles',
      categoryName: 'Non-Veg',
      maker: 'Nellore Home Kitchens',
      place: 'Nellore',
      subtitle: 'Slow-fried boneless chicken in cold-pressed gingelly oil with Guntur chilli and curry leaf.',
      basePrice: 349,
      originalPrice: 399,
      rating: 4.8,
      reviewsDisplay: '530',
      reviewCount: 121,
      defaultWeight: '250g',
      weightOptions: ['250g', '500g'],
      pricesByWeight: {
        '250g': 349,
        '500g': 679,
      },
      spiceLevel: 3,
      oilType: 'Cold-Pressed Gingelly Oil',
      packaging: 'Glass Jar',
      isBestseller: true,
      batchTag: 'Non-Veg Special',
      tags: ['Boneless', 'Gingelly Oil'],
      isVeg: false,
      description:
          'Country chicken is marinated overnight in ginger-garlic and lime, fried till the edges crisp, then rested in hot tempered oil so the masala seeps into every piece. Keep refrigerated after opening.',
      highlights: [
        '100% Boneless Country Chicken',
        'Cold-pressed pure gingelly oil',
        'Guntur Teja chilli marinade',
        'Preserved naturally without artificial additives',
      ],
      ingredients: [
        'Boneless Chicken Pieces',
        'Gingelly Oil',
        'Guntur Red Chilli',
        'Ginger-Garlic Paste',
        'Fresh Curry Leaves',
        'Lemon Juice',
        'Salt'
      ],
      storyTitle: 'Sunday Kitchens of Nellore',
      homemakerStory:
          'Country chicken is marinated overnight in ginger-garlic and lime, fried till the edges crisp, then rested in hot tempered oil so the masala seeps into every piece. Keep refrigerated after opening.',
      imageAsset: 'assets/images/avakaya.png',
      accentColor: Color(0xFFC0392B),
    ),
    Product(
      id: 'prawn',
      name: 'Kakinada Royyala (Prawn) Pickle',
      categoryId: 'pickles',
      categoryName: 'Non-Veg',
      maker: 'Coastal Kitchens',
      place: 'Kakinada',
      subtitle: 'Fresh coastal prawns sun-dried and pickled in tamarind, red chilli and gingelly oil.',
      basePrice: 399,
      originalPrice: 460,
      rating: 4.7,
      reviewsDisplay: '310',
      reviewCount: 74,
      defaultWeight: '250g',
      weightOptions: ['250g', '500g'],
      pricesByWeight: {
        '250g': 399,
        '500g': 749,
      },
      spiceLevel: 3,
      oilType: 'Cold-Pressed Gingelly Oil',
      packaging: 'Glass Jar',
      isBestseller: true,
      batchTag: 'Non-Veg Special',
      tags: ['Coastal', 'Tamarind'],
      isVeg: false,
      description:
          'Prawns landed at dawn are cleaned, salted and sun-dried for a day before being pickled in a tamarind-chilli masala, the way fishing families along the Godavari coast have preserved their catch for generations.',
      highlights: [
        'Wild caught Godavari sea prawns',
        'Sun-dried & pan-crisped',
        'Tamarind & red chilli coastal blend',
        'Zero artificial preservatives',
      ],
      ingredients: [
        'Fresh Sea Prawns',
        'Tamarind Pulp',
        'Cold-Pressed Gingelly Oil',
        'Guntur Chilli Powder',
        'Mustard Seeds',
        'Curry Leaves',
        'Rock Salt'
      ],
      storyTitle: 'From the Kakinada Shore',
      homemakerStory:
          'Prawns landed at dawn are cleaned, salted and sun-dried for a day before being pickled in a tamarind-chilli masala, the way fishing families along the Godavari coast have preserved their catch for generations.',
      imageAsset: 'assets/images/gongura.png',
      accentColor: Color(0xFFC0392B),
    ),
  ];

  static List<Product> get all => products;

  static Product findById(String id) {
    // Also support older ids
    if (id == 'andhra-avakaya') id = 'avakaya';
    if (id == 'andhra-gongura') id = 'gongura';
    if (id == 'butter-murukku') id = 'murukku';

    return products.firstWhere(
      (p) => p.id == id,
      orElse: () => products.first,
    );
  }

  static Product? tryFind(String id, [String? name]) {
    final cleanId = id.trim().toLowerCase();
    final cleanName = name?.trim().toLowerCase() ?? '';
    for (final p in products) {
      if (cleanId.isNotEmpty && (p.id.toLowerCase() == cleanId || p.id.toLowerCase() == 'andhra-$cleanId')) {
        return p;
      }
      if (cleanName.isNotEmpty && p.name.toLowerCase() == cleanName) {
        return p;
      }
      if (cleanId.isNotEmpty && (p.id.toLowerCase().contains(cleanId) || cleanId.contains(p.id.toLowerCase()))) {
        return p;
      }
      if (cleanName.isNotEmpty && (p.name.toLowerCase().contains(cleanName) || cleanName.contains(p.name.toLowerCase()))) {
        return p;
      }
    }
    return null;
  }
}

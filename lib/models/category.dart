import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final String chip;
  final IconData icon;
  final Color color;
  final Color tint;
  final String count;
  final String sub;
  final String badge;
  final Color badgeBg;
  final String? imageKey;
  final String? imageUrl;
  final String? assetImage;
  final String? createdAt;
  final String entityType;
  final String? createdBy;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.chip,
    this.icon = Icons.category_outlined,
    this.color = const Color(0xFF964900),
    this.tint = const Color(0xFFFFE9E3),
    this.count = 'Fresh Batches',
    this.sub = 'Authentic artisanal pantry staples',
    this.badge = '',
    this.badgeBg = const Color(0xFFFC820C),
    this.imageKey,
    this.imageUrl,
    this.assetImage,
    this.createdAt,
    this.entityType = 'CATEGORY',
    this.createdBy,
  });

  /// Returns a valid resolved image URL from either imageUrl or imageKey
  String? get resolvedImageUrl {
    if (imageUrl != null &&
        imageUrl!.trim().isNotEmpty &&
        imageUrl != 'string' &&
        imageUrl != 'null') {
      final u = imageUrl!.trim();
      if (u.startsWith('http://') || u.startsWith('https://')) return u;
      return 'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$u';
    }
    if (imageKey != null &&
        imageKey!.trim().isNotEmpty &&
        imageKey != 'string' &&
        imageKey != 'null') {
      final k = imageKey!.trim();
      return 'https://pickleo-uat-productmediabucket-crczhrxw5sj3.s3.ap-south-1.amazonaws.com/$k';
    }
    return null;
  }

  /// True if the imageUrl is a valid web URL or can be resolved
  bool get hasValidImage => resolvedImageUrl != null;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    final imageKey = json['imageKey']?.toString() ??
        json['image_key']?.toString() ??
        json['mediaKey']?.toString() ??
        json['media_key']?.toString();
    final imageUrl = json['imageUrl']?.toString() ??
        json['image_url']?.toString() ??
        json['mediaUrl']?.toString() ??
        json['media_url']?.toString() ??
        json['image']?.toString();
    final createdAt =
        json['createdAt']?.toString() ?? json['created_at']?.toString();
    final entityType = json['entityType']?.toString() ??
        json['entity_type']?.toString() ??
        'CATEGORY';
    final createdBy = json['createdBy']?.toString() ??
        json['created_by']?.toString();

    // Match with curated metadata if available for rich theming
    final meta = CategoryData.findMetadata(name, id);

    // Compute chip
    final chip = json['chip']?.toString() ??
        (meta != null
            ? meta.chip
            : (name.toLowerCase().contains('pickle') ? 'All Pickles' : name));

    return CategoryItem(
      id: id,
      name: name,
      chip: chip,
      icon: meta?.icon ?? Icons.soup_kitchen_outlined,
      color: meta?.color ?? const Color(0xFF964900),
      tint: meta?.tint ?? const Color(0xFFFFE9E3),
      count: meta?.count ?? 'Fresh Batches',
      sub: meta?.sub ?? 'Authentic artisanal batches made by hand',
      badge: json['badge']?.toString() ?? '',
      badgeBg: const Color(0xFFFC820C),
      imageKey: (imageKey != null &&
              imageKey.trim().isNotEmpty &&
              imageKey != 'string' &&
              imageKey != 'null')
          ? imageKey.trim()
          : null,
      imageUrl: (imageUrl != null &&
              imageUrl.trim().isNotEmpty &&
              imageUrl != 'string' &&
              imageUrl != 'null')
          ? imageUrl.trim()
          : null,
      assetImage: meta?.assetImage,
      createdAt: createdAt,
      entityType: entityType,
      createdBy: createdBy,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chip': chip,
      'imageKey': imageKey,
      'imageUrl': imageUrl,
      'assetImage': assetImage,
      'createdAt': createdAt,
      'count': count,
      'sub': sub,
      'badge': badge,
      'entityType': entityType,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}

class RegionItem {
  final String name;
  final String sub;
  const RegionItem({required this.name, required this.sub});
}

class CategoryData {
  static const List<CategoryItem> categories = [
    CategoryItem(
      id: 'pickles',
      name: 'Pickles & Achaar',
      chip: 'All Pickles',
      icon: Icons.liquor_outlined,
      color: Color(0xFF964900),
      tint: Color(0xFFFFE9E3),
      count: '24 batches',
      sub: 'Sun-cured in cold-pressed mustard & sesame oil',
      badge: 'Top',
      badgeBg: Color(0xFFFC820C),
      assetImage: 'assets/images/cat2-pickles.png',
    ),
    CategoryItem(
      id: 'chutneys',
      name: 'Chutneys',
      chip: 'Chutneys',
      icon: Icons.soup_kitchen_outlined,
      color: Color(0xFF0F5132),
      tint: Color(0xFFDFF3E6),
      count: '11 batches',
      sub: 'Stone-ground, tempered fresh every week',
      assetImage: 'assets/images/cat2-chutneys.png',
    ),
    CategoryItem(
      id: 'podis',
      name: 'Podis & Powders',
      chip: 'Podis',
      icon: Icons.grain_outlined,
      color: Color(0xFF755B00),
      tint: Color(0xFFFFDF90),
      count: '9 batches',
      sub: 'Roasted lentil and spice powders for hot rice',
      assetImage: 'assets/images/cat2-podis.png',
    ),
    CategoryItem(
      id: 'snacks',
      name: 'Snacks & Murukku',
      chip: 'Snacks',
      icon: Icons.bakery_dining_outlined,
      color: Color(0xFFFC820C),
      tint: Color(0xFFFFE2DA),
      count: '16 batches',
      sub: 'Hand-pressed, fried in small batches',
      badge: 'Crispy',
      badgeBg: Color(0xFF0F5132),
      assetImage: 'assets/images/cat2-snacks.png',
    ),
    CategoryItem(
      id: 'spices',
      name: 'Spices & Masalas',
      chip: 'Spices',
      icon: Icons.local_florist_outlined,
      color: Color(0xFFC0392B),
      tint: Color(0xFFFFDAD6),
      count: '14 batches',
      sub: 'Whole and freshly pounded, no fillers',
      assetImage: 'assets/images/cat2-spices.png',
    ),
    CategoryItem(
      id: 'sweets',
      name: 'Sweets',
      chip: 'Sweets',
      icon: Icons.cookie_outlined,
      color: Color(0xFF755B00),
      tint: Color(0xFFFFDF90),
      count: '8 batches',
      sub: 'Jaggery and ghee, made the slow way',
      assetImage: 'assets/images/cat2-sweets.png',
    ),
    CategoryItem(
      id: 'millets',
      name: 'Millets',
      chip: 'Millets',
      icon: Icons.eco_outlined,
      color: Color(0xFF0F5132),
      tint: Color(0xFFDFF3E6),
      count: '7 batches',
      sub: 'Ragi, jowar and foxtail from dryland farms',
      assetImage: 'assets/images/cat2-millets.png',
    ),
    CategoryItem(
      id: 'ready',
      name: 'Ready to Eat',
      chip: 'Ready',
      icon: Icons.dinner_dining_outlined,
      color: Color(0xFF964900),
      tint: Color(0xFFFFE9E3),
      count: '6 batches',
      sub: 'Heat and serve regional meals',
      assetImage: 'assets/images/cat2-ready.png',
    ),
    CategoryItem(
      id: 'combos',
      name: 'Combos & Gifts',
      chip: 'Combos',
      icon: Icons.card_giftcard_outlined,
      color: Color(0xFFFC820C),
      tint: Color(0xFFFFE2DA),
      count: '5 sets',
      sub: 'Curated jar sets for festivals and gifting',
      assetImage: 'assets/images/cat2-combos.png',
    ),
  ];

  static CategoryItem? findMetadata(String name, String id) {
    final lowerName = name.toLowerCase().trim();
    final lowerId = id.toLowerCase().trim();

    for (final item in categories) {
      final itemName = item.name.toLowerCase();
      final itemId = item.id.toLowerCase();

      if (itemId == lowerId ||
          itemName == lowerName ||
          itemName.contains(lowerName) ||
          lowerName.contains(itemName) ||
          (lowerName.contains('pickle') && itemName.contains('pickle')) ||
          (lowerName.contains('chutney') && itemName.contains('chutney')) ||
          (lowerName.contains('podi') && itemName.contains('podi')) ||
          (lowerName.contains('powder') && itemName.contains('powder')) ||
          (lowerName.contains('snack') && itemName.contains('snack')) ||
          (lowerName.contains('muruk') && itemName.contains('muruk')) ||
          (lowerName.contains('spice') && itemName.contains('spice')) ||
          (lowerName.contains('masala') && itemName.contains('masala')) ||
          (lowerName.contains('price') && itemName.contains('masala')) ||
          (lowerName.contains('sweet') && itemName.contains('sweet')) ||
          (lowerName.contains('millet') && itemName.contains('millet')) ||
          (lowerName.contains('combo') && itemName.contains('combo')) ||
          (lowerName.contains('gift') && itemName.contains('gift')) ||
          (lowerName.contains('ready') && itemName.contains('ready'))) {
        return item;
      }
    }
    return null;
  }

  static const List<RegionItem> regions = [
    RegionItem(name: 'Andhra', sub: 'Avakaya, Gongura'),
    RegionItem(name: 'Kerala', sub: 'Coconut, Kadumanga'),
    RegionItem(name: 'Tamil Nadu', sub: 'Murukku, Podi'),
    RegionItem(name: 'Karnataka', sub: 'Uppinakayi'),
    RegionItem(name: 'Rajasthan', sub: 'Ker Sangri, Mixed'),
    RegionItem(name: 'Punjab', sub: 'Aam, Gajar-Gobhi'),
  ];
}

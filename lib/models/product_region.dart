class ProductRegion {
  final String id;
  final String name;
  final bool legacy;
  final String description;
  final String? imageKey;
  final String? imageUrl;

  const ProductRegion({
    required this.id,
    required this.name,
    this.legacy = false,
    this.description = '',
    this.imageKey,
    this.imageUrl,
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

  /// Region icon/emoji
  String get icon {
    final lower = name.toLowerCase();
    if (lower.contains('andhra')) return '🌶️';
    if (lower.contains('kerala')) return '🥥';
    if (lower.contains('telangana')) return '🧅';
    if (lower.contains('tamil')) return '🫓';
    if (lower.contains('karnataka')) return '🍃';
    if (lower.contains('gujarat')) return '🌾';
    if (lower.contains('rajasthan')) return '☀️';
    if (lower.contains('punjab')) return '🌾';
    if (lower.contains('bengal') || lower.contains('kolkata')) return '🐟';
    if (lower.contains('maharashtra') || lower.contains('mumbai')) return '🥭';
    return '🏺';
  }

  /// Subtitle or regional speciality description
  String get sub {
    if (description.trim().isNotEmpty) return description.trim();
    final lower = name.toLowerCase();
    if (lower.contains('andhra')) return 'Avakaya, Gongura';
    if (lower.contains('kerala')) return 'Coconut, Kadumanga';
    if (lower.contains('telangana')) return 'Pachadi, Podi';
    if (lower.contains('tamil')) return 'Murukku, Podi';
    if (lower.contains('karnataka')) return 'Uppinakayi';
    if (lower.contains('gujarat')) return 'Chhunda, Methi Sambhariya';
    if (lower.contains('rajasthan')) return 'Ker Sangri, Mixed';
    if (lower.contains('punjab')) return 'Aam, Gajar-Gobhi';
    return 'Authentic regional recipes';
  }

  factory ProductRegion.fromJson(Map<String, dynamic> json) {
    return ProductRegion(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      legacy: json['legacy'] == true || json['legacy'] == 'true',
      description: json['description']?.toString() ?? '',
      imageKey:
          json['imageKey']?.toString() ?? json['image_key']?.toString(),
      imageUrl:
          json['imageUrl']?.toString() ?? json['image_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'legacy': legacy,
      'description': description,
      'imageKey': imageKey,
      'imageUrl': imageUrl,
    };
  }

  /// Default fallback regions if offline or waiting for API
  static const List<ProductRegion> defaultRegions = [
    ProductRegion(
      id: 'andhra',
      name: 'Andhra',
      legacy: true,
      description: 'Avakaya, Gongura',
    ),
    ProductRegion(
      id: 'kerala',
      name: 'Kerala',
      legacy: true,
      description: 'Coconut, Kadumanga',
    ),
    ProductRegion(
      id: 'telangana',
      name: 'Telangana',
      legacy: true,
      description: 'Pachadi, Podi',
    ),
    ProductRegion(
      id: 'tamil_nadu',
      name: 'Tamil Nadu',
      legacy: true,
      description: 'Murukku, Podi',
    ),
    ProductRegion(
      id: 'karnataka',
      name: 'Karnataka',
      legacy: true,
      description: 'Uppinakayi',
    ),
    ProductRegion(
      id: 'gujarat',
      name: 'Gujarat',
      legacy: true,
      description: 'Chhunda, Methi Sambhariya',
    ),
    ProductRegion(
      id: 'rajasthan',
      name: 'Rajasthan',
      legacy: true,
      description: 'Ker Sangri, Mixed',
    ),
    ProductRegion(
      id: 'punjab',
      name: 'Punjab',
      legacy: true,
      description: 'Aam, Gajar-Gobhi',
    ),
  ];
}

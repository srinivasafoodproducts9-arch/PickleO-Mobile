class ProductTag {
  final String id;
  final String name;
  final String? slug;
  final String? description;
  final String? icon;
  final String? imageKey;
  final String? imageUrl;
  final int sortOrder;

  const ProductTag({
    required this.id,
    required this.name,
    this.slug,
    this.description,
    this.icon,
    this.imageKey,
    this.imageUrl,
    this.sortOrder = 0,
  });

  /// True if imageUrl is a valid web URL
  bool get hasValidImage =>
      imageUrl != null &&
      imageUrl!.trim().isNotEmpty &&
      (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));

  factory ProductTag.fromJson(Map<String, dynamic> json) {
    return ProductTag(
      id: json['id']?.toString() ??
          json['tagId']?.toString() ??
          json['tag_id']?.toString() ??
          '',
      name: json['name']?.toString() ??
          json['tagName']?.toString() ??
          json['tag_name']?.toString() ??
          json['title']?.toString() ??
          json['label']?.toString() ??
          '',
      slug: json['slug']?.toString(),
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
      imageKey: json['imageKey']?.toString() ?? json['image_key']?.toString(),
      imageUrl: json['imageUrl']?.toString() ?? json['image_url']?.toString(),
      sortOrder: json['sortOrder'] is int
          ? json['sortOrder'] as int
          : (int.tryParse(json['sortOrder']?.toString() ?? '') ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'imageKey': imageKey,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
    };
  }

  /// Default fallback tags if offline or waiting for API
  static const List<ProductTag> defaultTags = [
    ProductTag(id: 'spicy', name: 'Spicy'),
    ProductTag(id: 'tangy', name: 'Tangy'),
    ProductTag(id: 'no_preservatives', name: 'No Preservatives'),
    ProductTag(id: 'mild', name: 'Mild'),
    ProductTag(id: 'oil_free', name: 'Oil-Free'),
  ];
}

import 'product.dart';

/// Model representing a wishlisted item from GET /consumer/wishlist
class ConsumerWishlistItem {
  final String productId;
  final DateTime? addedAt;
  final Product product;

  const ConsumerWishlistItem({
    required this.productId,
    this.addedAt,
    required this.product,
  });

  factory ConsumerWishlistItem.fromJson(Map<String, dynamic> json) {
    final rawProd = json['product'];
    final product = (rawProd is Map<String, dynamic>)
        ? Product.fromJson(rawProd)
        : (rawProd is Map
            ? Product.fromJson(Map<String, dynamic>.from(rawProd))
            : Product.fromJson({'id': json['productId']?.toString() ?? ''}));

    DateTime? parsedAddedAt;
    if (json['addedAt'] != null) {
      parsedAddedAt = DateTime.tryParse(json['addedAt'].toString());
    }

    return ConsumerWishlistItem(
      productId: json['productId']?.toString() ?? product.id,
      addedAt: parsedAddedAt,
      product: product,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'addedAt': addedAt?.toIso8601String(),
  };
}

/// Response payload for GET /consumer/wishlist
class ConsumerWishlistResponse {
  final List<ConsumerWishlistItem> items;

  const ConsumerWishlistResponse({
    this.items = const [],
  });

  factory ConsumerWishlistResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final itemsList = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((m) =>
                ConsumerWishlistItem.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <ConsumerWishlistItem>[];

    return ConsumerWishlistResponse(
      items: itemsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
  };
}

/// Model representing response from PUT /consumer/wishlist/{productId}
class AddToWishlistResponse {
  final String productId;
  final bool added;

  const AddToWishlistResponse({
    required this.productId,
    this.added = true,
  });

  factory AddToWishlistResponse.fromJson(Map<String, dynamic> json) {
    return AddToWishlistResponse(
      productId: json['productId']?.toString() ?? '',
      added: json['added'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'added': added,
  };
}

/// Model representing response from DELETE /consumer/wishlist/{productId}
class RemoveFromWishlistResponse {
  final bool deleted;

  const RemoveFromWishlistResponse({
    this.deleted = true,
  });

  factory RemoveFromWishlistResponse.fromJson(Map<String, dynamic> json) {
    return RemoveFromWishlistResponse(
      deleted: json['deleted'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'deleted': deleted,
  };
}

import 'cart_item.dart';
import 'product.dart';
import 'loyalty.dart';
import '../services/location_service.dart';

class DeliveryAddress {
  final String id;
  String label; // 'Home', 'Work', 'Other'
  String receiverName;
  String phone;
  String flatHouseBuilding;
  String streetArea;
  String city;
  String postalCode;
  bool isDefault;
  double? latitude;
  double? longitude;
  String? createdAt;
  String? updatedAt;

  DeliveryAddress({
    dynamic id,
    required this.label,
    String? receiverName,
    String? recipientName,
    String? phone,
    String? phoneNumber,
    String? flatHouseBuilding,
    String? flat,
    String? streetArea,
    String? street,
    required this.city,
    String? postalCode,
    String? pinCode,
    this.isDefault = false,
    this.latitude = 12.9716,
    this.longitude = 77.5946,
    this.createdAt,
    this.updatedAt,
  })  : id = id?.toString() ?? '',
        receiverName = receiverName ?? recipientName ?? '',
        phone = phone ?? phoneNumber ?? '',
        flatHouseBuilding = flatHouseBuilding ?? flat ?? '',
    streetArea = sanitizeStreet(streetArea ?? street ?? ''),
    postalCode = postalCode ?? pinCode ?? '';

  static String sanitizeStreet(String raw) {
    var cleaned = raw.trim();
    final prefixes = [
      RegExp(r'^(asia\s*/\s*[a-z_]+)\s*[,/–-]?\s*', caseSensitive: false),
      RegExp(r'^(asia|india|indian subcontinent)\s*[,/–-]\s*', caseSensitive: false),
      RegExp(r'^(asia|india|indian subcontinent)\s+', caseSensitive: false),
    ];
    for (final p in prefixes) {
      cleaned = cleaned.replaceAll(p, '').trim();
    }
    if (cleaned.toLowerCase() == 'asia' || cleaned.toLowerCase() == 'india') {
      return '';
    }
    return cleaned;
  }

  // Compatibility aliases
  String get recipientName => receiverName;
  set recipientName(String val) => receiverName = val;

  String get phoneNumber => phone;
  set phoneNumber(String val) => phone = val;

  String get flat => flatHouseBuilding;
  set flat(String val) => flatHouseBuilding = val;

  String get street => streetArea;
  set street(String val) => streetArea = val;

  String get pinCode => postalCode;
  set pinCode(String val) => postalCode = val;

  String get fullAddress =>
      '$flatHouseBuilding, $streetArea, $city – $postalCode';
  String get shortAddress {
    final streetShort = streetArea.split(',').last.trim();
    return '$streetShort, $city $postalCode';
  }

  bool get isServiceable => LocationService.isServiceablePin(postalCode);

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Home',
      receiverName: json['receiverName']?.toString() ??
          json['recipientName']?.toString() ??
          '',
      phone: json['phone']?.toString() ??
          json['phoneNumber']?.toString() ??
          '',
      flatHouseBuilding: json['flatHouseBuilding']?.toString() ??
          json['flat']?.toString() ??
          '',
      streetArea: sanitizeStreet(json['streetArea']?.toString() ??
          json['street']?.toString() ??
          ''),
      city: json['city']?.toString() ?? '',
      postalCode: json['postalCode']?.toString() ??
          json['pinCode']?.toString() ??
          '',
      isDefault: json['isDefault'] == true,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 12.9716,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 77.5946,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  factory DeliveryAddress.fallback() {
    return DeliveryAddress(
      id: '',
      label: 'Home',
      receiverName: '',
      phone: '',
      flatHouseBuilding: 'No saved address',
      streetArea: 'Tap to add an address',
      city: '',
      postalCode: '',
      isDefault: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'receiverName': receiverName,
      'phone': phone,
      'flatHouseBuilding': flatHouseBuilding,
      'streetArea': streetArea,
      'city': city,
      'postalCode': postalCode,
      'isDefault': isDefault,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  Map<String, dynamic> toLocalJson() {
    final map = toJson();
    if (id.isNotEmpty) map['id'] = id;
    if (createdAt != null) map['createdAt'] = createdAt;
    if (updatedAt != null) map['updatedAt'] = updatedAt;
    return map;
  }

  DeliveryAddress copyWith({
    String? id,
    String? label,
    String? receiverName,
    String? phone,
    String? flatHouseBuilding,
    String? streetArea,
    String? city,
    String? postalCode,
    bool? isDefault,
    double? latitude,
    double? longitude,
    String? createdAt,
    String? updatedAt,
  }) {
    return DeliveryAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      receiverName: receiverName ?? this.receiverName,
      phone: phone ?? this.phone,
      flatHouseBuilding: flatHouseBuilding ?? this.flatHouseBuilding,
      streetArea: streetArea ?? this.streetArea,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TrackingStep {
  final String title;
  final String time;
  final String sub;
  final String state; // 'done', 'now', 'todo'

  const TrackingStep({
    required this.title,
    required this.time,
    required this.sub,
    required this.state,
  });
}

class OrderStatusHistory {
  final String status;
  final DateTime changedAt;

  const OrderStatusHistory({
    required this.status,
    required this.changedAt,
  });

  factory OrderStatusHistory.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    final rawDate = json['changedAt'] ??
        json['createdAt'] ??
        json['timestamp'] ??
        json['date'];
    if (rawDate != null) {
      try {
        parsedDate = DateTime.parse(rawDate.toString());
      } catch (_) {
        parsedDate = DateTime.now();
      }
    } else {
      parsedDate = DateTime.now();
    }

    return OrderStatusHistory(
      status: json['status']?.toString() ?? '',
      changedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status,
    'changedAt': changedAt.toUtc().toIso8601String(),
  };
}

/// Live delivery tracking snapshot from carriers like Pidge.
/// Matches GET /consumer/orders/{orderId} and POST /consumer/orders/{orderId}/tracking/refresh
class DeliveryTracking {
  final String provider; // e.g. "Pidge"
  final String shipmentId; // e.g. "example-pidge-shipment"
  final String orderStatus; // e.g. "fulfilled", "pending", "completed", "cancelled"
  final String fulfillmentStatus; // e.g. "OUT_FOR_DELIVERY", "DELIVERED", etc.
  final String trackingCode; // e.g. "example-code"
  final String trackingUrl; // e.g. "https://tracking.pidge.in/?t=example-code"
  final DateTime? updatedAt; // Upstream carrier update timestamp
  final DateTime? checkedAt; // Backend check timestamp
  final String? source; // "webhook" when saved by callback worker
  final DateTime? receivedAt; // Timestamp when callback was ingested
  final String? attemptType; // Provider attempt type (e.g. forward vs reverse)

  const DeliveryTracking({
    this.provider = '',
    this.shipmentId = '',
    this.orderStatus = '',
    this.fulfillmentStatus = '',
    this.trackingCode = '',
    this.trackingUrl = '',
    this.updatedAt,
    this.checkedAt,
    this.source,
    this.receivedAt,
    this.attemptType,
  });

  /// True if snapshot was ingested via carrier webhook
  bool get isFromWebhook => source?.trim().toLowerCase() == 'webhook';

  /// Display fulfillmentStatus when present; otherwise display orderStatus.
  /// Do not confuse parent order status with fulfillment status.
  String get displayStatus {
    if (fulfillmentStatus.trim().isNotEmpty) {
      return fulfillmentStatus.trim();
    }
    if (orderStatus.trim().isNotEmpty) {
      return orderStatus.trim();
    }
    return '';
  }

  /// Formatted status title (e.g. "OUT_FOR_DELIVERY" -> "Out for Delivery")
  String get formattedDisplayStatus {
    final raw = displayStatus;
    if (raw.isEmpty) return '';

    // Standard Pidge status mappings
    final upper = raw.toUpperCase().replaceAll('-', '_');
    switch (upper) {
      case 'CREATED':
        return 'Shipment Created';
      case 'OUT_FOR_PICKUP':
        return 'Out for Pickup';
      case 'REACHED_PICKUP':
        return 'Reached Pickup';
      case 'PICKED_UP':
        return 'Picked Up';
      case 'IN_TRANSIT':
        return 'In Transit';
      case 'OUT_FOR_DELIVERY':
        return 'Out for Delivery';
      case 'REACHED_DELIVERY':
        return 'Reached Delivery';
      case 'DELIVERED':
        return 'Delivered';
      case 'UNDELIVERED':
        return 'Undelivered';
      case 'RTO_OUT_FOR_DELIVERY':
        return 'RTO: Out for Delivery';
      case 'RTO_UNDELIVERED':
        return 'RTO: Undelivered';
      case 'RTO_DELIVERED':
        return 'RTO: Returned to Hub';
      case 'CANCELLED':
        return 'Cancelled';
      case 'DISPOSED':
        return 'Disposed';
      case 'LOST':
        return 'Shipment Lost';
      case 'DAMAGED':
        return 'Damaged';
      case 'PENDING':
        return 'Pending Allocation';
      case 'FULFILLED':
        return 'Fulfilled';
      case 'COMPLETED':
        return 'Completed';
    }

    // Fallback for unknown statuses: capitalize words without hardcoding
    return raw.split(RegExp(r'[_\s]+')).map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  /// True if trackingUrl is non-empty HTTPS URL
  bool get hasValidTrackingUrl {
    final clean = trackingUrl.trim().toLowerCase();
    return clean.startsWith('https://');
  }

  /// Is Pidge courier
  bool get isPidge =>
      provider.trim().toLowerCase() == 'pidge' ||
      trackingUrl.toLowerCase().contains('pidge.in');

  /// True if status indicates delivered or completed
  bool get isDelivered {
    final s = displayStatus.toUpperCase();
    return s == 'DELIVERED' || s == 'COMPLETED';
  }

  /// True if status indicates out for delivery
  bool get isOutForDelivery {
    final s = displayStatus.toUpperCase();
    return s == 'OUT_FOR_DELIVERY';
  }

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    final rawTrackingUrl =
        (json['trackingUrl'] ?? json['tracking_url'])?.toString().trim() ?? '';
    final safeTrackingUrl =
        rawTrackingUrl.toLowerCase().startsWith('https://') ? rawTrackingUrl : '';

    return DeliveryTracking(
      provider: (json['provider'] ?? json['carrier'])?.toString().trim() ?? '',
      shipmentId: (json['shipmentId'] ??
              json['shipment_id'] ??
              json['trackingNumber'] ??
              json['tracking_number'])
          ?.toString()
          .trim() ??
          '',
      orderStatus: (json['orderStatus'] ?? json['order_status'])
          ?.toString()
          .trim() ??
          '',
      fulfillmentStatus: (json['fulfillmentStatus'] ??
              json['fulfillment_status'])
          ?.toString()
          .trim() ??
          '',
      trackingCode: (json['trackingCode'] ?? json['tracking_code'])
          ?.toString()
          .trim() ??
          '',
      trackingUrl: safeTrackingUrl,
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
      checkedAt: parseDate(json['checkedAt'] ?? json['checked_at']),
      source: json['source']?.toString().trim(),
      receivedAt: parseDate(json['receivedAt'] ?? json['received_at']),
      attemptType: json['attemptType']?.toString().trim() ??
          json['attempt_type']?.toString().trim(),
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'shipmentId': shipmentId,
    'orderStatus': orderStatus,
    'fulfillmentStatus': fulfillmentStatus,
    'trackingCode': trackingCode,
    'trackingUrl': trackingUrl,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    if (checkedAt != null) 'checkedAt': checkedAt!.toUtc().toIso8601String(),
    if (source != null && source!.isNotEmpty) 'source': source,
    if (receivedAt != null) 'receivedAt': receivedAt!.toUtc().toIso8601String(),
    if (attemptType != null && attemptType!.isNotEmpty) 'attemptType': attemptType,
  };
}

class OrderRating {
  final String orderId;
  final int rating;
  final List<String> tags;
  final String? feedback;
  final String? photoKey;
  final String? photoUrl;
  final int rewardPoints;
  final DateTime? createdAt;

  const OrderRating({
    required this.orderId,
    required this.rating,
    this.tags = const [],
    this.feedback,
    this.photoKey,
    this.photoUrl,
    this.rewardPoints = 0,
    this.createdAt,
  });

  factory OrderRating.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final List<String> tagsList = [];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t != null &&
            t.toString().trim().isNotEmpty &&
            t.toString().trim().toLowerCase() != 'string') {
          tagsList.add(t.toString().trim());
        }
      }
    }

    final rawFeedback = json['feedback']?.toString().trim();
    final cleanFeedback = (rawFeedback != null &&
            rawFeedback.isNotEmpty &&
            rawFeedback.toLowerCase() != 'string')
        ? rawFeedback
        : null;

    final rawPhotoUrl = json['photoUrl']?.toString().trim();
    final cleanPhotoUrl = (rawPhotoUrl != null &&
            rawPhotoUrl.isNotEmpty &&
            rawPhotoUrl.toLowerCase() != 'string')
        ? rawPhotoUrl
        : null;

    final rawPhotoKey = json['photoKey']?.toString().trim();
    final cleanPhotoKey = (rawPhotoKey != null &&
            rawPhotoKey.isNotEmpty &&
            rawPhotoKey.toLowerCase() != 'string')
        ? rawPhotoKey
        : null;

    DateTime? createdAt;
    if (json['createdAt'] != null) {
      try {
        createdAt = DateTime.parse(json['createdAt'].toString());
      } catch (_) {}
    }

    return OrderRating(
      orderId: json['orderId']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      tags: tagsList,
      feedback: cleanFeedback,
      photoKey: cleanPhotoKey,
      photoUrl: cleanPhotoUrl,
      rewardPoints: (json['rewardPoints'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'rating': rating,
    'tags': tags,
    if (feedback != null) 'feedback': feedback,
    if (photoKey != null) 'photoKey': photoKey,
    if (photoUrl != null) 'photoUrl': photoUrl,
    'rewardPoints': rewardPoints,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
  };
}

class UserOrder {
  final String id;
  final DateTime orderDate;
  final String dateDisplay;
  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double packagingFee;
  final double total;
  final String paymentMethod;
  final String paymentMethodId; // 'gpay', 'phonepe', 'card', etc.
  final DeliveryAddress deliveryAddress;
  final String status; // 'Pending', 'Confirmed', 'Processing', 'Packed', 'Ready for Dispatch', 'Shipped', 'Delivered', 'Cancelled', 'Returned'
  final bool? _explicitIsLiveActive;
  final String courierName;
  final String courierCompany;
  final String courierPhone;
  final double courierRating;
  final String carrier;
  final String trackingNumber;
  final String trackingUrl;
  final DeliveryTracking? deliveryTracking;
  final int orderStep;
  final bool _explicitIsCancelled;
  final String? cancelReason;
  final String deliverySlot;
  final List<String> deliveryInstructions;
  final int spicePointsEarned;
  final String displayId;
  final String fulfilmentCentre;
  final String paymentStatus;
  final DateTime? deliveredAt;
  final OrderRating? rating;
  final OrderPointsLot? pointsLot;
  final double walletUsed;
  final double gatewayAmount;
  final List<OrderStatusHistory> statusHistory;

  UserOrder({
    required this.id,
    String? displayId,
    this.fulfilmentCentre = '',
    this.paymentStatus = 'Paid',
    required this.orderDate,
    required this.dateDisplay,
    required this.items,
    required this.subtotal,
    this.discount = 100.0,
    this.deliveryFee = 0.0,
    this.packagingFee = 15.0,
    required this.total,
    required this.paymentMethod,
    this.paymentMethodId = 'gpay',
    required this.deliveryAddress,
    this.status = 'Pending',
    bool? isLiveActive,
    this.courierName = '',
    this.courierCompany = '',
    this.courierPhone = '',
    this.courierRating = 0.0,
    this.carrier = '',
    this.trackingNumber = '',
    this.trackingUrl = '',
    this.deliveryTracking,
    this.orderStep = 0,
    bool isCancelled = false,
    this.cancelReason,
    this.deliverySlot = 'Tomorrow, 2:00 PM – 4:00 PM',
    this.deliveryInstructions = const ['Call on arrival'],
    this.spicePointsEarned = 46,
    this.deliveredAt,
    this.rating,
    this.pointsLot,
    this.walletUsed = 0.0,
    this.gatewayAmount = 0.0,
    this.statusHistory = const [],
  })  : displayId = displayId ?? id,
        _explicitIsLiveActive = isLiveActive,
        _explicitIsCancelled = isCancelled;

  bool get isCancelled =>
      _explicitIsCancelled ||
      status.trim().toLowerCase() == 'cancelled' ||
      status.trim().toLowerCase().contains('cancel');

  bool get isReturned =>
      status.trim().toLowerCase() == 'returned' ||
      status.trim().toLowerCase().contains('return');

  bool get isOutForDelivery {
    final s = status.trim().toLowerCase();
    if (s == 'out for delivery' ||
        s.contains('out for delivery') ||
        s == 'out_for_delivery' ||
        s.contains('out_for_delivery')) {
      return true;
    }
    if (deliveryTracking?.isOutForDelivery == true) {
      return true;
    }
    return false;
  }

  bool get isDelivered =>
      !isOutForDelivery &&
      (status.trim().toLowerCase() == 'delivered' ||
          (status.trim().toLowerCase().contains('deliver') &&
              !status.trim().toLowerCase().contains('out for delivery')) ||
          orderStep >= 6 ||
          deliveryTracking?.isDelivered == true);

  bool get isLiveActive =>
      !isCancelled && !isReturned && !isDelivered && (_explicitIsLiveActive ?? true);

  /// True if trackingUrl is non-empty HTTPS URL (either on deliveryTracking or top-level)
  bool get hasValidTrackingUrl =>
      (deliveryTracking?.hasValidTrackingUrl == true) ||
      (trackingUrl.trim().toLowerCase().startsWith('https://'));

  /// Returns valid HTTPS tracking URL from backend, never constructed locally
  String? get effectiveTrackingUrl {
    if (deliveryTracking?.hasValidTrackingUrl == true) {
      return deliveryTracking!.trackingUrl.trim();
    }
    if (trackingUrl.trim().toLowerCase().startsWith('https://')) {
      return trackingUrl.trim();
    }
    return null;
  }

  String get deliveryPartner {
    if (deliveryTracking?.provider.trim().isNotEmpty == true) {
      return deliveryTracking!.provider.trim();
    }
    if (carrier.trim().isNotEmpty) return carrier.trim();
    if (courierCompany.trim().isNotEmpty) return courierCompany.trim();
    if (courierName.trim().isNotEmpty &&
        courierName.trim().toLowerCase() != 'string' &&
        courierName.trim().toLowerCase() != 'null') {
      return courierName.trim();
    }
    return '';
  }

  bool get hasCourierAssigned =>
      (courierName.trim().isNotEmpty &&
          courierName.trim().toLowerCase() != 'string' &&
          courierName.trim().toLowerCase() != 'null') ||
      carrier.trim().isNotEmpty ||
      trackingNumber.trim().isNotEmpty ||
      deliveryTracking != null ||
      hasValidTrackingUrl;

  /// Returns a clean, user-friendly order number.
  /// If displayId is a clean ID like "SFPKLO104" or "ORD-1234", returns it.
  /// If it is a raw 20+ character hex hash / UUID / ObjectId, shortens to 10 uppercase chars.
  String get shortOrderNumber {
    final clean = displayId.trim();
    if (clean.isNotEmpty && clean.length <= 16 && !RegExp(r'^[a-fA-F0-9]{20,}$').hasMatch(clean)) {
      return clean;
    }
    final raw = clean.isNotEmpty ? clean : id.trim();
    if (raw.length > 12) {
      return raw.substring(0, 10).toUpperCase();
    }
    return raw.toUpperCase();
  }

  factory UserOrder.placeholder(String orderId) {
    return UserOrder(
      id: orderId,
      displayId: orderId,
      orderDate: DateTime.now(),
      dateDisplay: 'Today',
      items: const [],
      subtotal: 0.0,
      total: 0.0,
      paymentMethod: 'Online',
      deliveryAddress: DeliveryAddress.fallback(),
      status: 'Processing',
    );
  }

  factory UserOrder.fromJson(
    Map<String, dynamic> json, {
    DeliveryAddress? fallbackAddress,
  }) {
    final rawItems = json['items'];
    final parsedItems = <CartItem>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          final itemMap = Map<String, dynamic>.from(it);

          // 1. Extract product map: could be nested under itemMap['product']
          final Map<String, dynamic> prodJson = {};
          if (itemMap['product'] is Map) {
            prodJson.addAll(Map<String, dynamic>.from(itemMap['product'] as Map));
          }
          // Overlay outer fields into prodJson if not present
          for (final e in itemMap.entries) {
            if (e.key != 'product' && e.value != null && e.value.toString().isNotEmpty) {
              prodJson.putIfAbsent(e.key, () => e.value);
            }
          }

          final prodId = prodJson['id']?.toString() ??
              itemMap['productId']?.toString() ??
              prodJson['productId']?.toString() ??
              '';
          prodJson['id'] = prodId;

          final prodName = prodJson['name']?.toString() ??
              itemMap['name']?.toString() ??
              '';
          prodJson['name'] = prodName;

          final pWeight = itemMap['weight']?.toString() ??
              itemMap['variantSize']?.toString() ??
              prodJson['variantSize']?.toString() ??
              prodJson['defaultWeight']?.toString() ??
              '250g';

          final pQty = (itemMap['quantity'] as num?)?.toInt() ??
              int.tryParse(itemMap['qty']?.toString() ?? '1') ??
              1;

          final pPrice = (itemMap['price'] as num?)?.toDouble() ??
              (prodJson['price'] as num?)?.toDouble() ??
              (prodJson['basePrice'] as num?)?.toDouble() ??
              0.0;
          if (!prodJson.containsKey('price') && pPrice > 0) {
            prodJson['price'] = pPrice;
          }
          if (!prodJson.containsKey('basePrice') && pPrice > 0) {
            prodJson['basePrice'] = pPrice;
          }

          final lineTot = (itemMap['lineTotal'] as num?)?.toDouble() ??
              (pPrice > 0 ? pPrice * pQty : 0.0);

          var product = Product.fromJson(prodJson);


          parsedItems.add(
            CartItem(
              product: product,
              selectedWeight: pWeight,
              quantity: pQty,
              lineTotal: lineTot,
            ),
          );
        }
      }
    }

    final id = json['id']?.toString() ?? '';
    final displayId = (json['displayId'] ??
            json['display_id'] ??
            json['orderNumber'] ??
            json['order_number'] ??
            json['orderId'] ??
            json['order_id'])
        ?.toString() ??
        id;
    final status = json['status']?.toString() ?? 'Pending';
    final paymentMethod = json['paymentMethod']?.toString() ?? 'Online';
    final paymentStatus = json['paymentStatus']?.toString() ?? 'Paid';
    final deliverySlot = json['deliverySlot']?.toString() ?? '9 AM - 12 PM';
    final fulfilmentCentre = json['fulfilmentCentre']?.toString() ?? '';

    final subtotal = (json['subtotal'] as num?)?.toDouble() ?? 0.0;
    final couponDiscount = (json['couponDiscount'] as num?)?.toDouble() ??
        (json['priceBreakdown']?['couponDiscount'] as num?)?.toDouble() ??
        (json['appliedPromotion']?['discountAmount'] as num?)?.toDouble() ??
        0.0;
    final deliveryFee = (json['deliveryFee'] as num?)?.toDouble() ??
        (json['priceBreakdown']?['deliveryFee'] as num?)?.toDouble() ??
        0.0;
    final packagingFee = (json['packagingFee'] as num?)?.toDouble() ??
        (json['priceBreakdown']?['cushionPackagingFee'] as num?)?.toDouble() ??
        15.0;
    final total = (json['total'] as num?)?.toDouble() ??
        (json['amount'] as num?)?.toDouble() ??
        (json['priceBreakdown']?['totalPayable'] as num?)?.toDouble() ??
        (subtotal - couponDiscount + deliveryFee + packagingFee);

    final rawStatusHistory = json['statusHistory'];
    final List<OrderStatusHistory> parsedStatusHistory = [];
    if (rawStatusHistory is List) {
      for (final h in rawStatusHistory) {
        if (h is Map) {
          parsedStatusHistory.add(
            OrderStatusHistory.fromJson(Map<String, dynamic>.from(h)),
          );
        }
      }
    }

    DateTime orderDate;
    if (json['createdAt'] != null) {
      try {
        orderDate = DateTime.parse(json['createdAt'].toString());
      } catch (_) {
        orderDate = DateTime.now();
      }
    } else {
      final pendingEntry = parsedStatusHistory.where((h) {
        final s = h.status.trim().toLowerCase();
        return s == 'pending' || s.contains('place') || s.contains('created');
      }).firstOrNull;
      orderDate = pendingEntry?.changedAt ?? DateTime.now();
    }

    final localOrderDate = orderDate.toLocal();
    final dateDisplay = json['dateDisplay']?.toString() ??
        '${localOrderDate.day} ${_monthName(localOrderDate.month)} ${localOrderDate.year}';

    DeliveryAddress deliveryAddr;
    if (fallbackAddress != null) {
      deliveryAddr = fallbackAddress;
    } else if (json['address'] is Map) {
      deliveryAddr = DeliveryAddress.fromJson(
        Map<String, dynamic>.from(json['address'] as Map),
      );
    } else {
      deliveryAddr = DeliveryAddress(
        id: json['addressId']?.toString() ?? '',
        label: 'Selected Address',
        city: 'Hyderabad',
        flatHouseBuilding: 'Doorstep',
        streetArea: 'Selected Address',
        postalCode: '',
      );
    }

    final statusLower = status.toLowerCase().trim();
    final bool isCancelled =
        statusLower == 'cancelled' || statusLower.contains('cancel');
    final bool isReturned =
        statusLower == 'returned' || statusLower.contains('return');
    final bool isOutForDelivery =
        statusLower == 'out for delivery' ||
        statusLower.contains('out for delivery') ||
        statusLower == 'out_for_delivery' ||
        statusLower.contains('out_for_delivery');
    final bool isDelivered = !isOutForDelivery &&
        (statusLower == 'delivered' || statusLower.contains('deliver'));
    final bool isLive = !isCancelled && !isDelivered && !isReturned;

    int orderStep = 0;
    if (isDelivered) {
      orderStep = 6;
    } else if (statusLower == 'shipped' ||
        statusLower.contains('transit') ||
        statusLower.contains('out for delivery') ||
        statusLower.contains('courier')) {
      orderStep = 5;
    } else if (statusLower == 'ready for dispatch' ||
        statusLower.contains('dispatch')) {
      orderStep = 4;
    } else if (statusLower == 'packed' ||
        statusLower.contains('packing')) {
      orderStep = 3;
    } else if (statusLower == 'processing' ||
        statusLower.contains('process')) {
      orderStep = 2;
    } else if (statusLower == 'confirmed' ||
        statusLower.contains('confirm')) {
      orderStep = 1;
    } else {
      orderStep = 0;
    }

    if (orderStep == 0 &&
        !isCancelled &&
        !isReturned &&
        parsedStatusHistory.isNotEmpty) {
      for (final h in parsedStatusHistory) {
        final s = h.status.trim().toLowerCase();
        int? sStep;
        if (s == 'delivered' ||
            (s.contains('deliver') &&
                !s.contains('out for delivery') &&
                !s.contains('out_for_delivery'))) {
          sStep = 6;
        } else if (s == 'shipped' ||
            s.contains('transit') ||
            s.contains('out for delivery') ||
            s.contains('courier')) {
          sStep = 5;
        } else if (s == 'ready for dispatch' || s.contains('dispatch')) {
          sStep = 4;
        } else if (s == 'packed' || s.contains('pack')) {
          sStep = 3;
        } else if (s == 'processing' || s.contains('process')) {
          sStep = 2;
        } else if (s == 'confirmed' || s.contains('confirm')) {
          sStep = 1;
        }
        if (sStep != null && sStep > orderStep) {
          orderStep = sStep;
        }
      }
    }

    DeliveryTracking? deliveryTracking;
    if (json['deliveryTracking'] is Map) {
      deliveryTracking = DeliveryTracking.fromJson(
        Map<String, dynamic>.from(json['deliveryTracking'] as Map),
      );
    } else if (json['delivery_tracking'] is Map) {
      deliveryTracking = DeliveryTracking.fromJson(
        Map<String, dynamic>.from(json['delivery_tracking'] as Map),
      );
    }

    final rawTrackingUrl = (json['trackingUrl'] ??
            json['tracking_url'] ??
            deliveryTracking?.trackingUrl)
        ?.toString()
        .trim();
    final trackingUrl = (rawTrackingUrl != null &&
            rawTrackingUrl.toLowerCase().startsWith('https://'))
        ? rawTrackingUrl
        : (deliveryTracking?.hasValidTrackingUrl == true
            ? deliveryTracking!.trackingUrl
            : '');

    final rawCarrier = (json['carrier'] ??
            json['courierCompany'] ??
            json['courier']?['carrier'] ??
            json['courier']?['company'] ??
            json['deliveryPartner']?['carrier'] ??
            json['deliveryPartner']?['name'] ??
            json['deliveryPartner']?['company'])
        ?.toString()
        .trim();
    final carrier = (rawCarrier != null &&
            rawCarrier.isNotEmpty &&
            rawCarrier.toLowerCase() != 'null' &&
            rawCarrier.toLowerCase() != 'string')
        ? rawCarrier
        : (deliveryTracking?.provider.isNotEmpty == true
            ? deliveryTracking!.provider
            : '');

    final rawTrackingNumber = (json['trackingNumber'] ??
            json['tracking_number'] ??
            json['trackingId'] ??
            json['tracking_id'] ??
            json['awb'] ??
            json['awbNumber'] ??
            json['awb_number'] ??
            json['courier']?['trackingNumber'] ??
            json['courier']?['tracking_number'] ??
            json['courier']?['trackingId'] ??
            json['courier']?['awb'] ??
            json['deliveryPartner']?['trackingNumber'] ??
            json['deliveryPartner']?['tracking_number'] ??
            json['deliveryPartner']?['trackingId'])
        ?.toString()
        .trim();
    final trackingNumber = (rawTrackingNumber != null &&
            rawTrackingNumber.isNotEmpty &&
            rawTrackingNumber.toLowerCase() != 'null' &&
            rawTrackingNumber.toLowerCase() != 'string')
        ? rawTrackingNumber
        : (deliveryTracking?.shipmentId.isNotEmpty == true
            ? deliveryTracking!.shipmentId
            : '');

    final courierName = json['courierName']?.toString() ??
        json['courier']?['name']?.toString() ??
        json['deliveryPartner']?['name']?.toString() ??
        json['assignedDriver']?['name']?.toString() ??
        json['driver']?['name']?.toString() ??
        json['deliveryPerson']?['name']?.toString() ??
        '';
    final courierCompany = json['courierCompany']?.toString() ??
        json['courier']?['company']?.toString() ??
        json['deliveryPartner']?['company']?.toString() ??
        carrier;
    final courierPhone = json['courierPhone']?.toString() ??
        json['courier']?['phone']?.toString() ??
        json['deliveryPartner']?['phone']?.toString() ??
        json['assignedDriver']?['phone']?.toString() ??
        json['driver']?['phone']?.toString() ??
        '';
    final courierRating = (json['courierRating'] as num?)?.toDouble() ??
        (json['courier']?['rating'] as num?)?.toDouble() ??
        (json['deliveryPartner']?['rating'] as num?)?.toDouble() ??
        0.0;

    DateTime? deliveredAt;
    final rawDeliveredAt = json['deliveredAt'] ?? json['deliveryAt'];
    if (rawDeliveredAt != null) {
      try {
        deliveredAt = DateTime.parse(rawDeliveredAt.toString());
      } catch (_) {}
    }
    if (deliveredAt == null) {
      for (final h in parsedStatusHistory) {
        final hs = h.status.trim().toLowerCase();
        if (hs == 'delivered' ||
            (hs.contains('deliver') &&
                !hs.contains('out for delivery') &&
                !hs.contains('out_for_delivery'))) {
          deliveredAt = h.changedAt;
          break;
        }
      }
    }

    OrderRating? rating;
    if (json['rating'] is Map) {
      rating = OrderRating.fromJson(
        Map<String, dynamic>.from(json['rating'] as Map),
      );
    }

    OrderPointsLot? pointsLot;
    if (json['pointsLot'] is Map) {
      pointsLot = OrderPointsLot.fromJson(
        Map<String, dynamic>.from(json['pointsLot'] as Map),
      );
    } else if (json['points_lot'] is Map) {
      pointsLot = OrderPointsLot.fromJson(
        Map<String, dynamic>.from(json['points_lot'] as Map),
      );
    }

    final parsedSpicePoints = pointsLot != null
        ? pointsLot.points
        : ((json['spicePointsEarned'] ?? json['spice_points_earned'] as num?)?.toInt() ??
            (total / 10).floor().clamp(0, 2000));

    final walletUsed = (json['walletUsed'] ?? json['wallet_used'] as num?)?.toDouble() ?? 0.0;
    final gatewayAmount = (json['gatewayAmount'] ?? json['gateway_amount'] as num?)?.toDouble() ?? 0.0;

    return UserOrder(
      id: id,
      displayId: displayId,
      fulfilmentCentre: fulfilmentCentre,
      paymentStatus: paymentStatus,
      orderDate: orderDate,
      dateDisplay: dateDisplay,
      items: parsedItems,
      subtotal: subtotal,
      discount: couponDiscount,
      deliveryFee: deliveryFee,
      packagingFee: packagingFee,
      total: total,
      paymentMethod:
          paymentMethod == 'COD' ? 'Cash on Delivery (COD)' : paymentMethod,
      paymentMethodId: paymentMethod.toLowerCase(),
      deliveryAddress: deliveryAddr,
      status: status,
      isLiveActive: isLive,
      courierName: courierName,
      courierCompany: courierCompany,
      courierPhone: courierPhone,
      courierRating: courierRating,
      carrier: carrier,
      trackingNumber: trackingNumber,
      trackingUrl: trackingUrl,
      deliveryTracking: deliveryTracking,
      isCancelled: isCancelled,
      orderStep: orderStep,
      deliverySlot: deliverySlot,
      deliveredAt: deliveredAt,
      rating: rating,
      spicePointsEarned: parsedSpicePoints,
      pointsLot: pointsLot,
      walletUsed: walletUsed,
      gatewayAmount: gatewayAmount,
      statusHistory: parsedStatusHistory,
    );
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }

  String get addressId => deliveryAddress.id;

  int get totalJars => items.fold(0, (sum, i) => sum + i.quantity);

  String get summaryDescription {
    if (items.isEmpty) return '0 jars';
    if (items.length == 1) {
      return '${items.first.product.name.split(' ').take(2).join(' ')} × ${items.first.quantity}';
    }
    return '$totalJars jars';
  }

  bool get canCancel {
    if (isCancelled || isReturned || isDelivered) return false;
    final s = status.trim().toLowerCase();
    // If already packed or beyond, no cancellation
    if (s == 'packed' ||
        s == 'ready for dispatch' ||
        s == 'shipped' ||
        s.contains('dispatch') ||
        s.contains('transit') ||
        s.contains('courier') ||
        s.contains('out for delivery')) {
      return false;
    }
    if (s == 'pending' || s == 'confirmed' || s == 'processing') {
      return true;
    }
    return orderStep < 3;
  }

  bool get cancelClosed =>
      !isCancelled && !isReturned && !isDelivered && !canCancel;

  DateTime? getHistoryTimeForStep(int stepIndex) {
    if (stepIndex == 6 && deliveredAt != null) {
      return deliveredAt;
    }
    for (final entry in statusHistory) {
      final s = entry.status.trim().toLowerCase();
      switch (stepIndex) {
        case 0:
          if (s == 'pending' || s.contains('place') || s.contains('created')) {
            return entry.changedAt;
          }
          break;
        case 1:
          if (s == 'confirmed' || s.contains('confirm') || s.contains('accept')) {
            return entry.changedAt;
          }
          break;
        case 2:
          if (s == 'processing' || s.contains('process') || s.contains('jarring')) {
            return entry.changedAt;
          }
          break;
        case 3:
          if (s == 'packed' || s.contains('pack')) {
            return entry.changedAt;
          }
          break;
        case 4:
          if (s == 'ready for dispatch' || s.contains('dispatch') || s.contains('staged')) {
            return entry.changedAt;
          }
          break;
        case 5:
          if (s == 'shipped' ||
              s.contains('transit') ||
              s.contains('out for delivery') ||
              s.contains('courier')) {
            return entry.changedAt;
          }
          break;
        case 6:
          if (s == 'delivered' ||
              (s.contains('deliver') &&
                  !s.contains('out for delivery') &&
                  !s.contains('out_for_delivery'))) {
            return entry.changedAt;
          }
          break;
      }
    }
    if (stepIndex == 0) {
      return orderDate;
    }
    if (stepIndex == 6 && deliveredAt != null) {
      return deliveredAt;
    }
    return null;
  }

  String get deliveredDateFormatted {
    final effectiveDeliveredAt = deliveredAt ?? getHistoryTimeForStep(6);
    if (effectiveDeliveredAt != null) {
      final dt = effectiveDeliveredAt.toLocal();
      return '${dt.day} ${_monthName(dt.month)} ${dt.year}, ${_formatTime(dt)}';
    }
    return deliverySlot.isNotEmpty ? deliverySlot : 'Delivered';
  }

  String get deliveredTimeShort {
    final effectiveDeliveredAt = deliveredAt ?? getHistoryTimeForStep(6);
    if (effectiveDeliveredAt != null) {
      final dt = effectiveDeliveredAt.toLocal();
      return '${dt.day} ${_monthName(dt.month)}, ${_formatTime(dt)}';
    }
    return deliverySlot.isNotEmpty ? deliverySlot : 'Delivered';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  static String _formatStepTime(DateTime dt, DateTime refDate) {
    final local = dt.toLocal();
    final timeStr = _formatTime(local);
    final refLocal = refDate.toLocal();
    if (local.year != refLocal.year ||
        local.month != refLocal.month ||
        local.day != refLocal.day) {
      return '${local.day} ${_monthName(local.month)}, $timeStr';
    }
    return timeStr;
  }

  List<TrackingStep> get trackingSteps {
    final stepTitles = [
      {
        'title': 'Order Placed',
        'sub': 'Awaiting seller & kitchen confirmation',
      },
      {
        'title': 'Order Confirmed',
        'sub': 'Kitchen received traditional recipe batch ticket',
      },
      {
        'title': 'Processing & Jarring',
        'sub': 'Traditional spices & cold-pressed oils blending',
      },
      {
        'title': 'Freshly Packed in Ceramic Martaban',
        'sub': 'Double vacuum-sealed & cushioned for glass jar safety',
      },
      {
        'title': 'Ready for Dispatch',
        'sub': 'Transit Hub: Staged at central dispatch dock',
      },
      {
        'title': isOutForDelivery ? 'Out for Delivery' : 'Shipped & In Transit',
        'sub': isOutForDelivery
            ? (deliveryPartner.isNotEmpty
                ? 'Shipment out for delivery with $deliveryPartner'
                : 'Courier partner moving shipment towards delivery address')
            : 'Courier partner moving shipment towards delivery address',
      },
      {
        'title': 'Delivered to Doorstep',
        'sub': 'Fresh authentic aromas ready for your pantry',
      },
    ];

    const fallbackOffsets = [
      Duration.zero,
      Duration(minutes: 10),
      Duration(minutes: 25),
      Duration(minutes: 45),
      Duration(hours: 1, minutes: 15),
      Duration(hours: 2),
      Duration(hours: 3),
    ];

    return List.generate(stepTitles.length, (i) {
      final st = stepTitles[i];
      String state;
      if (isCancelled || isReturned) {
        state = i == 0 ? 'done' : 'todo';
      } else if (i < orderStep) {
        state = 'done';
      } else if (i == orderStep) {
        state = isDelivered ? 'done' : 'now';
      } else {
        state = 'todo';
      }

      String stepTime;
      if (state == 'todo') {
        stepTime = 'Pending';
      } else {
        final historyTime = getHistoryTimeForStep(i);
        if (historyTime != null) {
          if (i == stepTitles.length - 1) {
            stepTime = deliveredTimeShort;
          } else {
            stepTime = _formatStepTime(historyTime, orderDate);
          }
        } else {
          if (i == stepTitles.length - 1) {
            stepTime = isDelivered ? deliveredTimeShort : 'Pending';
          } else if (i == 0) {
            stepTime = _formatStepTime(orderDate, orderDate);
          } else {
            stepTime =
                _formatStepTime(orderDate.add(fallbackOffsets[i]), orderDate);
          }
        }
      }

      return TrackingStep(
        title: st['title']!,
        sub: st['sub']!,
        time: stepTime,
        state: state,
      );
    });
  }

  UserOrder copyWith({
    String? id,
    DateTime? orderDate,
    String? dateDisplay,
    List<CartItem>? items,
    double? subtotal,
    double? discount,
    double? deliveryFee,
    double? packagingFee,
    double? total,
    String? paymentMethod,
    String? paymentMethodId,
    DeliveryAddress? deliveryAddress,
    String? status,
    bool? isLiveActive,
    String? courierName,
    String? courierCompany,
    String? courierPhone,
    double? courierRating,
    String? carrier,
    String? trackingNumber,
    String? trackingUrl,
    DeliveryTracking? deliveryTracking,
    int? orderStep,
    bool? isCancelled,
    String? cancelReason,
    String? deliverySlot,
    List<String>? deliveryInstructions,
    int? spicePointsEarned,
    String? displayId,
    String? fulfilmentCentre,
    String? paymentStatus,
    DateTime? deliveredAt,
    OrderRating? rating,
    OrderPointsLot? pointsLot,
    double? walletUsed,
    double? gatewayAmount,
    List<OrderStatusHistory>? statusHistory,
  }) {
    return UserOrder(
      id: id ?? this.id,
      displayId: displayId ?? this.displayId,
      fulfilmentCentre: fulfilmentCentre ?? this.fulfilmentCentre,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      orderDate: orderDate ?? this.orderDate,
      dateDisplay: dateDisplay ?? this.dateDisplay,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      packagingFee: packagingFee ?? this.packagingFee,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      status: status ?? this.status,
      isLiveActive: isLiveActive ?? this.isLiveActive,
      courierName: courierName ?? this.courierName,
      courierCompany: courierCompany ?? this.courierCompany,
      courierPhone: courierPhone ?? this.courierPhone,
      courierRating: courierRating ?? this.courierRating,
      carrier: carrier ?? this.carrier,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      deliveryTracking: deliveryTracking ?? this.deliveryTracking,
      orderStep: orderStep ?? this.orderStep,
      isCancelled: isCancelled ?? this.isCancelled,
      cancelReason: cancelReason ?? this.cancelReason,
      deliverySlot: deliverySlot ?? this.deliverySlot,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      spicePointsEarned: spicePointsEarned ?? this.spicePointsEarned,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      rating: rating ?? this.rating,
      pointsLot: pointsLot ?? this.pointsLot,
      walletUsed: walletUsed ?? this.walletUsed,
      gatewayAmount: gatewayAmount ?? this.gatewayAmount,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayId': displayId,
    'status': status,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'deliverySlot': deliverySlot,
    'fulfilmentCentre': fulfilmentCentre,
    'subtotal': subtotal,
    'discount': discount,
    'deliveryFee': deliveryFee,
    'packagingFee': packagingFee,
    'amount': total,
    'createdAt': orderDate.toUtc().toIso8601String(),
    if (deliveredAt != null) 'deliveredAt': deliveredAt!.toUtc().toIso8601String(),
    'statusHistory': statusHistory.map((h) => h.toJson()).toList(),
    if (rating != null) 'rating': rating!.toJson(),
    if (pointsLot != null) 'pointsLot': pointsLot!.toJson(),
    if (walletUsed > 0) 'walletUsed': walletUsed,
    if (gatewayAmount > 0) 'gatewayAmount': gatewayAmount,
    'items': items.map((i) => i.toJson()).toList(),
    'address': deliveryAddress.toJson(),
    if (carrier.isNotEmpty) 'carrier': carrier,
    if (trackingNumber.isNotEmpty) 'trackingNumber': trackingNumber,
    if (trackingUrl.isNotEmpty) 'trackingUrl': trackingUrl,
    if (deliveryTracking != null) 'deliveryTracking': deliveryTracking!.toJson(),
    if (courierName.isNotEmpty) 'courierName': courierName,
    if (courierCompany.isNotEmpty) 'courierCompany': courierCompany,
    if (courierPhone.isNotEmpty) 'courierPhone': courierPhone,
  };

  // GST Calculation for Invoice
  double get fees => packagingFee;
  double get taxableValue => ((total - fees) / 1.12).roundToDouble();
  double get gstTotal => total - fees - taxableValue;
  double get cgst => (gstTotal / 2).roundToDouble();
  double get sgst => (gstTotal / 2).roundToDouble();
}

/// Response model for GET /consumer/orders
class ConsumerOrderListResponse {
  final List<UserOrder> items;
  final String? nextToken;

  const ConsumerOrderListResponse({
    this.items = const [],
    this.nextToken,
  });

  factory ConsumerOrderListResponse.fromJson(
    Map<String, dynamic> json, {
    DeliveryAddress? fallbackAddress,
  }) {
    final rawItems = json['items'];
    final parsedOrders = <UserOrder>[];

    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          parsedOrders.add(
            UserOrder.fromJson(
              Map<String, dynamic>.from(item),
              fallbackAddress: fallbackAddress,
            ),
          );
        }
      }
    }

    return ConsumerOrderListResponse(
      items: parsedOrders,
      nextToken: json['nextToken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'items': items.map((o) => {
      'id': o.id,
      'displayId': o.displayId,
      'status': o.status,
      'paymentMethod': o.paymentMethod,
      'paymentStatus': o.paymentStatus,
      'subtotal': o.subtotal,
      'deliveryFee': o.deliveryFee,
      'packagingFee': o.packagingFee,
      'amount': o.total,
      'deliverySlot': o.deliverySlot,
      'fulfilmentCentre': o.fulfilmentCentre,
      if (o.carrier.isNotEmpty) 'carrier': o.carrier,
      if (o.trackingNumber.isNotEmpty) 'trackingNumber': o.trackingNumber,
      if (o.trackingUrl.isNotEmpty) 'trackingUrl': o.trackingUrl,
      if (o.deliveryTracking != null) 'deliveryTracking': o.deliveryTracking!.toJson(),
    }).toList(),
    if (nextToken != null) 'nextToken': nextToken,
  };
}


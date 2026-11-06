class DeliveryEstimate {
  final bool serviceable;
  final String pinCode;
  final String? city;
  final String? fulfilmentCentre;
  final double deliveryCharge;
  final double standardDeliveryFee;
  final double freeDeliveryAbove;
  final double minimumOrderValue;
  final bool minimumOrderMet;
  final List<String> slots;
  final String? sla;
  final bool codAvailable;

  const DeliveryEstimate({
    required this.serviceable,
    required this.pinCode,
    this.city,
    this.fulfilmentCentre,
    this.deliveryCharge = 0.0,
    this.standardDeliveryFee = 0.0,
    this.freeDeliveryAbove = 0.0,
    this.minimumOrderValue = 0.0,
    this.minimumOrderMet = true,
    this.slots = const [],
    this.sla,
    this.codAvailable = true,
  });

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) {
    return DeliveryEstimate(
      serviceable: json['serviceable'] == true,
      pinCode: json['pinCode']?.toString() ?? '',
      city: json['city']?.toString(),
      fulfilmentCentre: json['fulfilmentCentre']?.toString(),
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0.0,
      standardDeliveryFee:
          (json['standardDeliveryFee'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryAbove:
          (json['freeDeliveryAbove'] as num?)?.toDouble() ?? 0.0,
      minimumOrderValue:
          (json['minimumOrderValue'] as num?)?.toDouble() ?? 0.0,
      minimumOrderMet: json['minimumOrderMet'] != false,
      slots: (json['slots'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      sla: json['sla']?.toString(),
      codAvailable: json['codAvailable'] != false,
    );
  }

  bool get isFreeDelivery => deliveryCharge <= 0;

  String get deliveryChargeText =>
      isFreeDelivery ? 'free delivery' : '₹${deliveryCharge.toInt()} delivery';
}

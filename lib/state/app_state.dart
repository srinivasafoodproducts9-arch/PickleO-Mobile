import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/banner.dart';
import '../models/category.dart';
import '../models/product_region.dart';
import '../models/product_tag.dart';
import '../models/wishlist_item.dart';
import '../models/coupon.dart';
import '../models/offer.dart';
import '../models/delivery_estimate.dart';
import '../models/loyalty.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  // Authentication & Profile State
  bool _isLoggedIn;
  String _userId = '';
  String _userName;
  String _phoneNumber;
  String _userEmail;
  String _dob;
  String _gender;
  String? _avatarKey;
  String? _avatarUrl;
  Uint8List? _localAvatarBytes;

  // Diet Filter State
  bool _dietVegOn = false;
  bool _dietNonVegOn = false;

  bool get dietVegOn => _dietVegOn;
  bool get dietNonVegOn => _dietNonVegOn;

  String get dietNote {
    if (_dietVegOn && _dietNonVegOn) return 'Veg & non-veg';
    if (_dietVegOn) return 'Veg only';
    if (_dietNonVegOn) return 'Non-veg only';
    return 'Showing all jars';
  }

  String? get resolvedDietMark {
    if (_dietVegOn && _dietNonVegOn) return 'Vegetarian,Non-vegetarian';
    if (_dietVegOn) return 'Vegetarian';
    if (_dietNonVegOn) return 'Non-vegetarian';
    return null;
  }

  void toggleDietVeg() {
    _dietVegOn = !_dietVegOn;
    notifyListeners();
    fetchBestsellers(forceRefresh: true);
  }

  void toggleDietNonVeg() {
    _dietNonVegOn = !_dietNonVegOn;
    notifyListeners();
    fetchBestsellers(forceRefresh: true);
  }

  List<Product> get dietFilteredBestsellers {
    final list = _bestsellerProducts;
    return list.where((p) {
      if (p.status.toLowerCase() != 'active') return false;
      if (!_dietVegOn && !_dietNonVegOn) return true;
      if (_dietVegOn && p.isVeg) return true;
      if (_dietNonVegOn && !p.isVeg) return true;
      return false;
    }).toList();
  }

  AppState({bool initialLoggedIn = false})
      : _isLoggedIn = initialLoggedIn,
        _userName = '',
        _phoneNumber = '',
        _userEmail = '',
        _dob = '',
        _gender = '',
        _walletBalance = 0.0,
        _spicePoints = 0 {
    initSession();
  }

  // Taste Profile
  String _spiceTolerance = 'Medium'; // 'Mild', 'Medium', 'Fiery'
  bool _isVegetarianOnly = false;
  bool _excludeGarlic = false;
  final Set<String> _preferredRegions = {};

  // Wallet & Loyalty
  double _walletBalance = 0.0;
  int _spicePoints = 0;
  LoyaltyAccount? _loyaltyAccount;
  List<LoyaltyTierPerk> _loyaltyTiers = [];

  // Delivery Addresses & Location State
  final List<DeliveryAddress> _addresses = [];
  DeliveryAddress? _activeDeliveryAddress;
  DeliveryAddress? _nearestSavedAddress;
  double? _nearestSavedDistanceMeters;
  GeoAddress? _currentGpsAddress;
  Position? _currentGpsPosition;
  bool _isNearSavedAddress = false;
  bool _isDetectingLocation = false;
  bool _hasDetectedLocation = false;
  bool _isManualAddressSelected = false;

  // Banners State
  final List<HomeBanner> _banners = [];
  bool _isLoadingBanners = false;
  bool _hasLoadedBanners = false;

  // Categories State
  final List<CategoryItem> _categories = [];
  bool _isLoadingCategories = false;
  bool _hasLoadedCategories = false;

  // Product Regions State
  final List<ProductRegion> _productRegions = [];
  bool _isLoadingProductRegions = false;
  bool _hasLoadedProductRegions = false;

  // Product Tags State
  final List<ProductTag> _productTags = [];
  bool _isLoadingProductTags = false;
  bool _hasLoadedProductTags = false;

  // Offers State
  final List<OfferItem> _offers = [];
  bool _isLoadingOffers = false;
  bool _hasLoadedOffers = false;

  // Bestseller Products State (GET /consumer/products)
  final List<Product> _bestsellerProducts = [];
  final Map<String, Product> _detailedProductsCache = {};
  bool _isLoadingBestsellers = false;
  bool _hasLoadedBestsellers = false;
  String? _currentBestsellerRegion;
  String? _currentBestsellerTag;
  String? _bestsellerError;

  // Wishlist
  final Set<String> _wishlist = {};
  final Map<String, Product> _wishlistProducts = {};
  bool _hasLoadedWishlist = false;

  // Search History State (Recent searches based on user typings)
  final List<String> _recentSearches = [];
  List<String> get recentSearches => List.unmodifiable(_recentSearches);

  // Cart State
  final Map<String, CartItem> _cartItems = {};
  final List<CouponOffer> _coupons = [];
  String? _appliedCoupon;
  double _couponDiscount = 0.0;

  // API-sourced cart pricing (populated by loadCartFromApi)
  CartPriceBreakdown? _apiPriceBreakdown;
  CartAppliedPromotion? _apiAppliedPromotion;
  Map<String, dynamic>? _cartDeliveryInfo;
  CartDeliveryInfo? _parsedDeliveryInfo;
  String? _selectedDeliverySlot;
  String? _cartAddressId;
  bool _checkoutReady = false;
  List<CartPricingIssue> _pricingIssues = [];
  final Set<String> _deliveryInstructions = {'Call on arrival'};
  String _deliveryInstruction = 'Call on arrival';

  // Orders State
  final List<UserOrder> _orders = [];
  UserOrder? _activeOrder;
  String? _activeCheckoutRequestId;
  String? get activeCheckoutRequestId => _activeCheckoutRequestId;

  bool _isLoadingOrders = false;
  bool _hasLoadedOrders = false;
  String? _ordersNextToken;

  bool get isLoadingOrders => _isLoadingOrders;
  bool get hasLoadedOrders => _hasLoadedOrders;
  String? get ordersNextToken => _ordersNextToken;
  bool get hasMoreOrders =>
      _ordersNextToken != null && _ordersNextToken!.isNotEmpty;

  // Shipment Tracking State (Pidge integration)
  final Map<String, DateTime> _lastTrackingRefreshTimes = {};
  final Set<String> _refreshingTrackingOrderIds = {};

  bool isTrackingRefreshing(String orderId) =>
      _refreshingTrackingOrderIds.contains(orderId);

  DateTime? lastTrackingRefreshTime(String orderId) =>
      _lastTrackingRefreshTimes[orderId];



  // Getters - Auth & Profile
  bool get isLoggedIn => _isLoggedIn;
  UserProfile? get userProfile => AuthService().cachedProfile;
  String get userId => _userId;
  String get userName => _userName;
  String get phoneNumber => _phoneNumber;
  String get userEmail => _userEmail;
  String get dob => _dob;
  String get gender => _gender;
  String? get avatarKey => _avatarKey;
  String? get avatarUrl => _avatarUrl;
  Uint8List? get localAvatarBytes => _localAvatarBytes;

  // Taste Profile Getters
  String get spiceTolerance => _spiceTolerance;
  bool get isVegetarianOnly => _isVegetarianOnly;
  bool get excludeGarlic => _excludeGarlic;
  Set<String> get preferredRegions => _preferredRegions;

  // Wallet & Loyalty
  double get walletBalance => _walletBalance;
  int get spicePoints => _loyaltyAccount?.balance ?? _spicePoints;
  int get pendingSpicePoints => _loyaltyAccount?.pending ?? 0;
  LoyaltyAccount? get loyaltyAccount => _loyaltyAccount;
  List<LoyaltyTierPerk> get loyaltyTiers => _loyaltyTiers;

  void addWalletCash(double amount) {
    _walletBalance += amount;
    notifyListeners();
  }

  void addSpicePoints(int points) {
    _spicePoints += points;
    notifyListeners();
  }

  void redeemPoints(int points, double cash) {
    if (_spicePoints >= points) {
      _spicePoints -= points;
      _walletBalance += cash;
      notifyListeners();
    }
  }

  // Addresses
  List<DeliveryAddress> get addresses => List.unmodifiable(_addresses);
  DeliveryAddress get defaultAddress {
    if (_addresses.isEmpty) {
      return DeliveryAddress.fallback();
    }
    return _addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => _addresses.first,
    );
  }

  /// Returns selected delivery address ID, prioritizing active selection then default
  String? get selectedAddressId {
    if (_activeDeliveryAddress != null && _activeDeliveryAddress!.id.isNotEmpty) {
      return _activeDeliveryAddress!.id;
    }
    if (_addresses.isNotEmpty) {
      final def = defaultAddress;
      if (def.id.isNotEmpty) return def.id;
    }
    return null;
  }

  /// Whether a valid delivery address is selected / available (mandatory for checkout)
  bool get hasValidDeliveryAddress =>
      selectedAddressId != null && selectedAddressId!.isNotEmpty;

  List<Product> get allProducts => _bestsellerProducts.isNotEmpty
      ? List.unmodifiable(_bestsellerProducts)
      : List.unmodifiable(_detailedProductsCache.values);

  // Delivery Location Getters
  DeliveryAddress? get activeDeliveryAddress => _activeDeliveryAddress;
  DeliveryAddress? get nearestSavedAddress => _nearestSavedAddress;
  double? get nearestSavedDistanceMeters => _nearestSavedDistanceMeters;
  GeoAddress? get currentGpsAddress => _currentGpsAddress;
  Position? get currentGpsPosition => _currentGpsPosition;
  bool get isNearSavedAddress => _isNearSavedAddress;
  bool get isDetectingLocation => _isDetectingLocation;
  bool get hasDetectedLocation => _hasDetectedLocation;
  bool get isManualAddressSelected => _isManualAddressSelected;

  /// Top title for dashboard: e.g. "Deliver to • Home" or "Deliver to"
  String get deliveryHeaderTitle {
    if (_isNearSavedAddress && _nearestSavedAddress != null) {
      final label = _nearestSavedAddress!.label.trim();
      return label.isNotEmpty ? 'Deliver to • $label' : 'Deliver to';
    }
    if (_isManualAddressSelected && _activeDeliveryAddress != null) {
      final label = _activeDeliveryAddress!.label.trim();
      return label.isNotEmpty ? 'Deliver to • $label' : 'Deliver to';
    }
    return 'Deliver to';
  }

  /// Subtitle for dashboard:
  /// If current location is near (< 1 km) to any of the saved addresses -> show that saved address!
  /// Else -> show current location!
  String get deliveryHeaderSubtitle {
    if (_isDetectingLocation &&
        !_hasDetectedLocation &&
        _currentGpsAddress == null &&
        _nearestSavedAddress == null &&
        _activeDeliveryAddress == null) {
      return 'Locating...';
    }

    // 1. If near a saved address (< 1 km) -> show that saved address!
    if (_isNearSavedAddress && _nearestSavedAddress != null) {
      return formatAddressSubtitle(_nearestSavedAddress!);
    }

    // 2. If user manually selected a saved address
    if (_isManualAddressSelected && _activeDeliveryAddress != null) {
      return formatAddressSubtitle(_activeDeliveryAddress!);
    }

    // 3. Otherwise show current location from GPS reverse geocoding
    if (_currentGpsAddress != null) {
      return formatGeoAddressSubtitle(_currentGpsAddress!);
    }

    // 4. Fallback to default saved address if available
    if (_addresses.isNotEmpty) {
      return formatAddressSubtitle(defaultAddress);
    }

    // 5. Default fallback
    return 'Indiranagar, 560038';
  }

  static String formatAddressSubtitle(DeliveryAddress addr) {
    final area = addr.streetArea.trim();
    final city = addr.city.trim();
    final pin = addr.postalCode.trim();

    String mainPart = area.isNotEmpty ? area : city;
    if (mainPart.contains(',')) {
      final parts = mainPart
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        mainPart = parts.length > 1
            ? '${parts[parts.length - 2]}, ${parts.last}'
            : parts.first;
      }
    }

    if (mainPart.isNotEmpty && pin.isNotEmpty) {
      if (mainPart.contains(pin)) return mainPart;
      return '$mainPart, $pin';
    } else if (mainPart.isNotEmpty) {
      return mainPart;
    } else if (pin.isNotEmpty) {
      return pin;
    }
    return addr.label.isNotEmpty ? addr.label : 'Select Location';
  }

  static String formatGeoAddressSubtitle(GeoAddress geo) {
    final locality = geo.locality.trim();
    final street = geo.street.trim();
    final city = geo.city.trim();
    final pin = geo.postalCode.trim();

    String mainPart = locality.isNotEmpty
        ? locality
        : (street.isNotEmpty ? street : city);

    if (mainPart.contains(',')) {
      final parts = mainPart
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        mainPart = parts.length > 1
            ? '${parts[parts.length - 2]}, ${parts.last}'
            : parts.first;
      }
    }

    if (mainPart.isNotEmpty && pin.isNotEmpty) {
      if (mainPart.contains(pin)) return mainPart;
      return '$mainPart, $pin';
    } else if (mainPart.isNotEmpty) {
      return mainPart;
    } else if (city.isNotEmpty && pin.isNotEmpty) {
      return '$city, $pin';
    } else if (city.isNotEmpty) {
      return city;
    }
    return 'Current Location';
  }

  /// Calculates distance in meters from current GPS position to a given address (if available)
  double? getDistanceToAddress(DeliveryAddress address) {
    if (_currentGpsPosition == null ||
        address.latitude == null ||
        address.longitude == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _currentGpsPosition!.latitude,
      _currentGpsPosition!.longitude,
      address.latitude!,
      address.longitude!,
    );
  }

  void setSelectedAddress(DeliveryAddress address) {
    _activeDeliveryAddress = address;
    _isManualAddressSelected = true;
    _isNearSavedAddress = false;
    _nearestSavedAddress = null;
    notifyListeners();
    if (_isLoggedIn) {
      loadCartFromApi(addressId: address.id);
    }
  }

  void _evaluateNearbyAddress(Position position) {
    final nearest = LocationService().findNearestSavedAddress(
      currentLatitude: position.latitude,
      currentLongitude: position.longitude,
      addresses: _addresses,
      thresholdMeters: 1000.0,
    );

    if (nearest != null) {
      _isNearSavedAddress = true;
      _nearestSavedAddress = nearest.address;
      _nearestSavedDistanceMeters = nearest.distanceMeters;
      _activeDeliveryAddress = nearest.address;
    } else {
      _isNearSavedAddress = false;
      _nearestSavedAddress = null;
      _nearestSavedDistanceMeters = null;
    }
    notifyListeners();
  }

  Future<void> detectAndApplyLocation({bool forceGps = false}) async {
    _isDetectingLocation = true;
    notifyListeners();

    try {
      final position = await LocationService().getCurrentPosition();
      if (position != null) {
        _currentGpsPosition = position;

        // Check if near any saved address (< 1 km / 1000 meters)
        final nearest = LocationService().findNearestSavedAddress(
          currentLatitude: position.latitude,
          currentLongitude: position.longitude,
          addresses: _addresses,
          thresholdMeters: 1000.0,
        );

        if (nearest != null) {
          // Current location is near (< 1 km) to a saved address -> show that saved address!
          _isNearSavedAddress = true;
          _nearestSavedAddress = nearest.address;
          _nearestSavedDistanceMeters = nearest.distanceMeters;
          _activeDeliveryAddress = nearest.address;
          _isManualAddressSelected = false;
        } else {
          // Current location is NOT near any saved address -> show current location!
          _isNearSavedAddress = false;
          _nearestSavedAddress = null;
          _nearestSavedDistanceMeters = null;
          _isManualAddressSelected = false;

          final geo = await LocationService().reverseGeocode(
            position.latitude,
            position.longitude,
          );
          _currentGpsAddress = geo;
        }
      } else {
        if (_addresses.isNotEmpty) {
          _activeDeliveryAddress = defaultAddress;
        }
      }
    } catch (e) {
      debugPrint('Error in detectAndApplyLocation: $e');
    } finally {
      _isDetectingLocation = false;
      _hasDetectedLocation = true;
      notifyListeners();
    }
  }

  // Banners Getters & Actions
  List<HomeBanner> get banners => List.unmodifiable(_banners);
  bool get isLoadingBanners => _isLoadingBanners;
  bool get hasLoadedBanners => _hasLoadedBanners;

  Future<void> fetchBanners({bool forceRefresh = false}) async {
    if (_isLoadingBanners) return;
    if (_hasLoadedBanners && !forceRefresh && _banners.isNotEmpty) return;

    _isLoadingBanners = true;
    notifyListeners();

    try {
      final response = await AuthService().getBanners();
      if (response.success && response.data != null) {
        _banners.clear();
        _banners.addAll(response.data!);
        _saveBannersToCache();
      }
    } catch (e) {
      debugPrint('Error fetching banners: $e');
    } finally {
      _isLoadingBanners = false;
      _hasLoadedBanners = true;
      notifyListeners();
    }
  }

  Future<void> _saveBannersToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _banners.map((b) => b.toJson()).toList();
      await prefs.setString('home_banners', jsonEncode(list));
    } catch (_) {}
  }

  // Categories Getters & Actions
  List<CategoryItem> get categories {
    final seen = <String>{};
    final unique = <CategoryItem>[];
    for (final c in _categories) {
      final name = c.name.trim().toLowerCase();
      // Normalize any variation of millets (e.g. 'millet', 'millets', 'millet foods', 'millets foods')
      final key = name.startsWith('millet') ? 'millets' : name;
      if (seen.add(key)) {
        unique.add(c);
      }
    }
    return List.unmodifiable(unique);
  }
  List<CategoryItem> get apiCategories => categories;
  bool get isLoadingCategories => _isLoadingCategories;
  bool get hasLoadedCategories => _hasLoadedCategories;

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (_isLoadingCategories) return;
    if (_hasLoadedCategories && !forceRefresh && _categories.isNotEmpty) return;

    _isLoadingCategories = true;
    notifyListeners();

    try {
      final response = await AuthService().getCategories();
      if (response.success && response.data != null) {
        _categories.clear();
        _categories.addAll(response.data!);
        _saveCategoriesToCache();
        _hasLoadedCategories = true;
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> _saveCategoriesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _categories.map((c) => c.toJson()).toList();
      await prefs.setString('cached_categories', jsonEncode(list));
    } catch (_) {}
  }

  List<ProductRegion> get productRegions => List.unmodifiable(_productRegions);
  List<ProductRegion> get apiProductRegions => List.unmodifiable(_productRegions);
  bool get isLoadingProductRegions => _isLoadingProductRegions;
  bool get hasLoadedProductRegions => _hasLoadedProductRegions;

  Future<void> fetchProductRegions({bool forceRefresh = false}) async {
    if (_isLoadingProductRegions) return;
    if (_hasLoadedProductRegions && !forceRefresh && _productRegions.isNotEmpty) return;

    _isLoadingProductRegions = true;
    notifyListeners();

    try {
      final response = await AuthService().getProductRegions();
      if (response.success && response.data != null) {
        _productRegions.clear();
        _productRegions.addAll(response.data!);
        _saveProductRegionsToCache();
        _hasLoadedProductRegions = true;
      }
    } catch (e) {
      debugPrint('Error fetching product regions: $e');
    } finally {
      _isLoadingProductRegions = false;
      notifyListeners();
    }
  }

  Future<void> _saveProductRegionsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _productRegions.map((r) => r.toJson()).toList();
      await prefs.setString('cached_product_regions', jsonEncode(list));
    } catch (_) {}
  }

  // Product Tags Getters & Actions
  List<ProductTag> get productTags => List.unmodifiable(_productTags);
  List<ProductTag> get apiProductTags => List.unmodifiable(_productTags);
  bool get isLoadingProductTags => _isLoadingProductTags;
  bool get hasLoadedProductTags => _hasLoadedProductTags;

  Future<void> fetchProductTags({bool forceRefresh = false}) async {
    if (_isLoadingProductTags) return;
    if (_hasLoadedProductTags && !forceRefresh && _productTags.isNotEmpty) return;

    _isLoadingProductTags = true;
    notifyListeners();

    try {
      final response = await AuthService().getProductTags();
      if (response.success && response.data != null && response.data!.isNotEmpty) {
        _productTags.clear();
        _productTags.addAll(response.data!);
        _saveProductTagsToCache();
        _hasLoadedProductTags = true;
      }
    } catch (e) {
      debugPrint('Error fetching product tags: $e');
    } finally {
      _isLoadingProductTags = false;
      notifyListeners();
    }
  }

  Future<void> _saveProductTagsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _productTags.map((t) => t.toJson()).toList();
      await prefs.setString('cached_product_tags', jsonEncode(list));
    } catch (_) {}
  }

  // Offers Getters & Actions
  List<OfferItem> get offers => List.unmodifiable(_offers);
  bool get isLoadingOffers => _isLoadingOffers;
  bool get hasLoadedOffers => _hasLoadedOffers;

  Future<void> fetchOffers({bool forceRefresh = false}) async {
    if (_isLoadingOffers) return;
    if (_hasLoadedOffers && !forceRefresh && _offers.isNotEmpty) return;

    _isLoadingOffers = true;
    notifyListeners();

    try {
      final response = await AuthService().getOffers();
      if (response.success && response.data != null) {
        _offers.clear();
        _offers.addAll(response.data!);
        _saveOffersToCache();

        // Sync available API offers into coupons list exclusively
        _coupons.clear();
        for (final offer in _offers) {
          _coupons.add(offer.toCouponOffer());
        }
      }
    } catch (e) {
      debugPrint('Error fetching offers: $e');
    } finally {
      _isLoadingOffers = false;
      _hasLoadedOffers = true;
      notifyListeners();
    }
  }

  Future<void> _saveOffersToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _offers.map((o) => o.toJson()).toList();
      await prefs.setString('cached_offers', jsonEncode(list));
    } catch (_) {}
  }

  // Bestsellers Getters & Actions
  List<Product> get bestsellerProducts => List.unmodifiable(_bestsellerProducts);
  bool get isLoadingBestsellers => _isLoadingBestsellers;
  bool get hasLoadedBestsellers => _hasLoadedBestsellers;
  String? get bestsellerError => _bestsellerError;
  String? get currentBestsellerRegion => _currentBestsellerRegion;
  String? get currentBestsellerTag => _currentBestsellerTag;

  @visibleForTesting
  void setBestsellersForTesting(List<Product> products, {String? region, String? tag}) {
    _bestsellerProducts.clear();
    _bestsellerProducts.addAll(products);
    _hasLoadedBestsellers = true;
    _isLoadingBestsellers = false;
    final defaultRegion = region ?? (productRegions.isNotEmpty ? productRegions.first.name : null);
    final defaultTag = tag ?? (productTags.isNotEmpty ? productTags.first.name : null);
    _currentBestsellerRegion = defaultRegion;
    _currentBestsellerTag = defaultTag;
    _hasLoadedProductRegions = true;
    _hasLoadedProductTags = true;
    notifyListeners();
  }

  @visibleForTesting
  void setOffersForTesting(List<OfferItem> offers) {
    _offers.clear();
    _offers.addAll(offers);
    _hasLoadedOffers = true;
    _isLoadingOffers = false;
    notifyListeners();
  }

  @visibleForTesting
  void setCategoriesForTesting(List<CategoryItem> categories) {
    _categories.clear();
    _categories.addAll(categories);
    _hasLoadedCategories = true;
    _isLoadingCategories = false;
    notifyListeners();
  }

  @visibleForTesting
  void setProductRegionsForTesting(List<ProductRegion> regions) {
    _productRegions.clear();
    _productRegions.addAll(regions);
    _hasLoadedProductRegions = true;
    _isLoadingProductRegions = false;
    notifyListeners();
  }

  Future<void> fetchBestsellers({
    String? region,
    String? tag,
    String? dietMark,
    bool forceRefresh = false,
  }) async {
    final effectiveDiet = dietMark ?? resolvedDietMark;
    if (!forceRefresh &&
        _hasLoadedBestsellers &&
        _currentBestsellerRegion == region &&
        _currentBestsellerTag == tag) {
      return;
    }

    _isLoadingBestsellers = true;
    _bestsellerError = null;
    notifyListeners();

    try {
      final response = await AuthService().getProducts(
        region: region,
        tags: tag,
        dietMark: effectiveDiet,
        limit: 20,
      );

      if (response.success && response.data != null && response.data!.items.isNotEmpty) {
        _bestsellerProducts.clear();
        _bestsellerProducts.addAll(response.data!.items);
        _enrichOrdersWithCatalogProducts();
        _currentBestsellerRegion = region;
        _currentBestsellerTag = tag;
        _hasLoadedBestsellers = true;
        _bestsellerError = null;
      } else {
        _bestsellerProducts.clear();
        _currentBestsellerRegion = region;
        _currentBestsellerTag = tag;
        _hasLoadedBestsellers = true;
        _bestsellerError = response.message ?? 'No products found';
      }
    } catch (e) {
      debugPrint('Error fetching bestsellers: $e');
      _bestsellerProducts.clear();
      _currentBestsellerRegion = region;
      _currentBestsellerTag = tag;
      _hasLoadedBestsellers = true;
      _bestsellerError = e.toString();
    } finally {
      _isLoadingBestsellers = false;
      notifyListeners();
    }
  }

  // Search History Actions (Recent searches based on user typings)
  Future<void> loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('pickleo_recent_searches');
      if (saved != null) {
        _recentSearches.clear();
        _recentSearches.addAll(saved);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> addRecentSearch(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _recentSearches.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    _recentSearches.insert(0, query);

    if (_recentSearches.length > 10) {
      _recentSearches.removeRange(10, _recentSearches.length);
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pickleo_recent_searches', _recentSearches);
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  Future<void> removeRecentSearch(String query) async {
    _recentSearches.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pickleo_recent_searches', _recentSearches);
    } catch (e) {
      debugPrint('Error removing recent search: $e');
    }
  }

  Future<void> clearRecentSearches() async {
    _recentSearches.clear();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pickleo_recent_searches');
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  /// General product fetcher for category/region/search
  Future<ProductListResponse?> fetchProductsByFilter({
    String? category,
    String? region,
    String? dietMark,
    dynamic tags,
    String? search,
    int limit = 20,
    String? nextToken,
  }) async {
    try {
      final response = await AuthService().getProducts(
        category: category,
        region: region,
        dietMark: dietMark ?? resolvedDietMark,
        tags: tags,
        search: search,
        limit: limit,
        nextToken: nextToken,
      );
      if (response.success) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error in fetchProductsByFilter: $e');
      return null;
    }
  }

  /// Batch fetch details for 1-30 product IDs via POST /consumer/products/details
  Future<List<Product>> fetchProductDetails(List<String> productIds) async {
    final cleanIds = productIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != 'string' && e != 'null')
        .toSet()
        .take(30)
        .toList();
    if (cleanIds.isEmpty) return [];

    final auth = AuthService();
    final res = await auth.getProductDetails(cleanIds);
    if (res.success && res.data != null) {
      final items = res.data!.items;
      for (final item in items) {
        if (item.id.isNotEmpty) _detailedProductsCache[item.id] = item;
        if (item.catalogProductId != null && item.catalogProductId!.isNotEmpty) {
          _detailedProductsCache[item.catalogProductId!] = item;
        }
        for (final v in item.variants) {
          if (v.id.isNotEmpty) _detailedProductsCache[v.id] = item;
          if (v.sku.isNotEmpty) _detailedProductsCache[v.sku] = item;
        }
      }
      notifyListeners();
      return items;
    }
    return [];
  }

  /// Manually cache a product record in the details cache
  void cacheDetailedProduct(Product product) {
    if (product.id.isNotEmpty) _detailedProductsCache[product.id] = product;
    if (product.catalogProductId != null && product.catalogProductId!.isNotEmpty) {
      _detailedProductsCache[product.catalogProductId!] = product;
    }
    for (final v in product.variants) {
      if (v.id.isNotEmpty) _detailedProductsCache[v.id] = product;
      if (v.sku.isNotEmpty) _detailedProductsCache[v.sku] = product;
    }
    notifyListeners();
  }

  /// Find product by ID strictly from live API products or API details cache (no static catalog)
  Product? findLiveProductById(String id) {
    final cleanId = id.trim().toLowerCase();
    if (cleanId.isEmpty) return null;
    if (_detailedProductsCache.containsKey(id.trim())) {
      return _detailedProductsCache[id.trim()];
    }
    for (final entry in _detailedProductsCache.entries) {
      if (entry.key.toLowerCase() == cleanId) return entry.value;
    }
    for (final p in _detailedProductsCache.values) {
      if (p.id.toLowerCase() == cleanId ||
          (p.catalogProductId != null &&
              p.catalogProductId!.toLowerCase() == cleanId) ||
          p.variants.any((v) =>
              v.id.toLowerCase() == cleanId ||
              (v.sku.isNotEmpty && v.sku.toLowerCase() == cleanId))) {
        return p;
      }
    }
    for (final p in _bestsellerProducts) {
      if (p.id.toLowerCase() == cleanId ||
          (p.catalogProductId != null &&
              p.catalogProductId!.toLowerCase() == cleanId) ||
          p.variants.any((v) =>
              v.id.toLowerCase() == cleanId ||
              (v.sku.isNotEmpty && v.sku.toLowerCase() == cleanId))) {
        return p;
      }
    }
    for (final p in _wishlistProducts.values) {
      if (p.id.toLowerCase() == cleanId ||
          (p.catalogProductId != null &&
              p.catalogProductId!.toLowerCase() == cleanId) ||
          p.variants.any((v) =>
              v.id.toLowerCase() == cleanId ||
              (v.sku.isNotEmpty && v.sku.toLowerCase() == cleanId))) {
        return p;
      }
    }
    for (final item in _cartItems.values) {
      final p = item.product;
      if (p.id.toLowerCase() == cleanId ||
          (p.catalogProductId != null &&
              p.catalogProductId!.toLowerCase() == cleanId) ||
          p.variants.any((v) =>
              v.id.toLowerCase() == cleanId ||
              (v.sku.isNotEmpty && v.sku.toLowerCase() == cleanId))) {
        return p;
      }
    }
    return null;
  }

  /// Find product by ID or variant ID across loaded live products and details cache
  Product? findProductById(String id) {
    return findLiveProductById(id);
  }

  // Wishlist
  Set<String> get wishlist => _isLoggedIn ? _wishlist : const {};
  Set<String> get favoriteProductIds => _isLoggedIn ? _wishlist : const {};
  bool isWishlisted(String productId) =>
      _isLoggedIn && _wishlist.contains(productId);
  bool isFavorite(String productId) => isWishlisted(productId);
  List<Product> get wishlistProductList =>
      _isLoggedIn ? _wishlistProducts.values.toList() : const [];
  bool _isLoadingWishlist = false;
  bool get isLoadingWishlist => _isLoadingWishlist;
  bool get hasLoadedWishlist => _hasLoadedWishlist;

  // Cart
  Map<String, CartItem> get cartItems => _cartItems;
  List<CartItem> get cartList => _cartItems.values.toList();
  int get cartCount => _cartItems.values.fold(0, (sum, i) => sum + i.quantity);
  bool get hasCart => cartCount > 0;
  String? get appliedCoupon => _appliedCoupon;
  String get deliveryInstruction => _deliveryInstruction;
  Set<String> get deliveryInstructionsSet => _deliveryInstructions;
  bool hasDeliveryInstruction(String instr) => _deliveryInstructions.contains(instr);
  String get deliveryInstructionsSummary =>
      _deliveryInstructions.isEmpty ? 'none selected' : _deliveryInstructions.join(' · ');

  List<Product> get products => _bestsellerProducts.isNotEmpty
      ? List.unmodifiable(_bestsellerProducts)
      : List.unmodifiable(_detailedProductsCache.values);

  // Delivery Estimate State
  final Map<String, DeliveryEstimate> _deliveryEstimatesCache = {};

  DeliveryEstimate? getCachedDeliveryEstimate(String pinCode) =>
      _deliveryEstimatesCache[pinCode.trim()];

  void cacheDeliveryEstimate(DeliveryEstimate estimate) {
    _deliveryEstimatesCache[estimate.pinCode.trim()] = estimate;
    notifyListeners();
  }

  Future<DeliveryEstimate?> checkDeliveryEstimate({
    required String pinCode,
    num? subtotal,
  }) async {
    final cleanPin = pinCode.trim();
    if (cleanPin.isEmpty) return null;

    final auth = AuthService();
    final res = await auth.getDeliveryEstimate(
      pinCode: cleanPin,
      subtotal: subtotal,
    );

    if (res.success && res.data != null) {
      _deliveryEstimatesCache[cleanPin] = res.data!;
      notifyListeners();
      return res.data;
    }
    return null;
  }

  // Serviceability Getters
  bool isPinServiceable(String? pin) {
    if (pin != null && _deliveryEstimatesCache.containsKey(pin.trim())) {
      return _deliveryEstimatesCache[pin.trim()]!.serviceable;
    }
    return LocationService.isServiceablePin(pin);
  }

  bool isAddressServiceable(DeliveryAddress? address) {
    if (address == null) return false;
    return isPinServiceable(address.postalCode);
  }

  bool get isActiveAddressServiceable =>
      isAddressServiceable(_activeDeliveryAddress ?? defaultAddress);

  bool get isDefaultAddressServiceable =>
      isAddressServiceable(defaultAddress);

  // Coupon Getters
  List<CouponOffer> get coupons {
    if (_offers.isNotEmpty) {
      return List.unmodifiable(_offers.map((o) => o.toCouponOffer()));
    }
    return List.unmodifiable(_coupons);
  }

  CouponOffer? get selectedCouponOffer =>
      coupons.where((c) => c.code == _appliedCoupon).firstOrNull;

  double get subtotal =>
      _cartItems.values.fold(0.0, (sum, i) => sum + i.totalPrice);

  double get mrpTotal =>
      _apiPriceBreakdown != null && _apiPriceBreakdown!.itemsMrpTotal > 0
          ? _apiPriceBreakdown!.itemsMrpTotal
          : _cartItems.values.fold(0.0, (sum, i) {
              final mrpRatio = i.product.originalPrice / i.product.basePrice;
              return sum + (i.unitPrice * mrpRatio * i.quantity);
            });

  double get productDiscount =>
      _apiPriceBreakdown != null && _apiPriceBreakdown!.productDiscount > 0
          ? _apiPriceBreakdown!.productDiscount
          : (mrpTotal - subtotal).clamp(0.0, double.infinity);

  double get couponDiscount {
    if (_apiPriceBreakdown != null && _apiPriceBreakdown!.couponDiscount > 0) {
      return _apiPriceBreakdown!.couponDiscount;
    }
    if (_appliedCoupon != null) {
      final offer = coupons.where((c) => c.code == _appliedCoupon).firstOrNull;
      if (offer != null) {
        if (offer.isEligible(subtotal)) {
          return offer.calculateDiscount(subtotal);
        }
        return 0.0;
      }
      return _couponDiscount;
    }
    return 0.0;
  }

  double get deliveryFee =>
      _apiPriceBreakdown != null ? _apiPriceBreakdown!.deliveryFee : 0.0;

  double get standardDeliveryFee =>
      _apiPriceBreakdown != null
          ? _apiPriceBreakdown!.standardDeliveryFee
          : 40.0;

  double get packagingFee =>
      _apiPriceBreakdown != null && _apiPriceBreakdown!.cushionPackagingFee > 0
          ? _apiPriceBreakdown!.cushionPackagingFee
          : (hasCart ? 15.0 : 0.0);

  bool get isFreeDelivery =>
      _apiPriceBreakdown?.freeDelivery ?? (deliveryFee == 0);

  // API cart pricing getters
  CartPriceBreakdown? get apiPriceBreakdown => _apiPriceBreakdown;
  CartAppliedPromotion? get apiAppliedPromotion => _apiAppliedPromotion;
  Map<String, dynamic>? get cartDeliveryInfo => _cartDeliveryInfo;
  CartDeliveryInfo? get parsedDeliveryInfo => _parsedDeliveryInfo;
  String? get selectedDeliverySlot => _selectedDeliverySlot;

  List<String> get deliverySlots {
    if (_parsedDeliveryInfo != null && _parsedDeliveryInfo!.slots.isNotEmpty) {
      return _parsedDeliveryInfo!.slots;
    }
    final raw = _cartDeliveryInfo?['slots'];
    if (raw is List) {
      return raw
          .map((s) => s?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  bool get hasDeliverySlots => deliverySlots.isNotEmpty;
  bool get isDeliverySlotSelected =>
      _selectedDeliverySlot != null && _selectedDeliverySlot!.trim().isNotEmpty;

  void selectDeliverySlot(String slot) {
    _selectedDeliverySlot = slot.trim();
    notifyListeners();
  }

  String? get cartAddressId => _cartAddressId;
  bool get checkoutReady => _checkoutReady;
  List<CartPricingIssue> get pricingIssues => List.unmodifiable(_pricingIssues);

  /// User-friendly reason from pricingIssues when totalPayable is null or delivery cannot be priced
  String? get pricingIssuesReason {
    if (_pricingIssues.isNotEmpty) {
      final msgs = _pricingIssues
          .map((i) => i.message.trim())
          .where((m) => m.isNotEmpty)
          .toList();
      if (msgs.isNotEmpty) return msgs.join(' • ');
    }
    return null;
  }

  /// Whether backend price breakdown returned null for totalPayable
  bool get isTotalPayableNull =>
      _apiPriceBreakdown != null && _apiPriceBreakdown!.totalPayable == null;

  double get grandTotal {
    if (!hasCart) return 0.0;
    // Calculate dynamically from the current cart items so it updates immediately on any quantity change
    return (subtotal - couponDiscount + deliveryFee + packagingFee)
        .clamp(0.0, double.infinity);
  }

  double get cartTotal => grandTotal;

  double get totalSaved =>
      productDiscount + couponDiscount + (isFreeDelivery ? standardDeliveryFee : 0.0);

  // Orders
  List<UserOrder> get orders => List.unmodifiable(_orders);
  UserOrder? get activeOrder => _activeOrder;

  // Cart Actions
  Future<ApiResponse<CartItemResponse>?> addToCart(
    Product product,
    String weight, {
    ProductVariant? variant,
    int qty = 1,
  }) async {
    final normalizedWeight = weight.trim().toLowerCase().replaceAll(' ', '');
    final effectiveVariant = variant ??
        (product.variants.isNotEmpty
            ? product.variants.where((v) {
                final vLabel = v.displayLabel.trim().toLowerCase().replaceAll(' ', '');
                return vLabel == normalizedWeight || v.id == weight;
              }).firstOrNull ??
                product.variants.first
            : null);
    final variantId = effectiveVariant?.id;
    final displayWeight = effectiveVariant?.displayLabel ?? weight;
    final key = variantId != null && variantId.isNotEmpty
        ? '${product.id}_$variantId'
        : '${product.id}_$displayWeight';

    final int previousQty = _cartItems[key]?.quantity ?? 0;
    final auth = AuthService();
    final bool isLoggedIn = auth.authToken != null && auth.authToken!.isNotEmpty;

    if (isLoggedIn) {
      final syncId = (variantId != null && variantId.isNotEmpty) ? variantId : product.id;
      final targetQty = (previousQty + qty).clamp(1, 99);
      final res = await syncCartItemToApi(syncId, targetQty, productId: product.id);

      if (res != null && !res.success) {
        // Backend rejected (e.g. 409 Only 0 units available).
        // Cart and cache were NEVER polluted!
        return res;
      }

      // Backend accepted the item!
      if (_cartItems.containsKey(key)) {
        _cartItems[key]!.quantity = targetQty;
      } else {
        _cartItems[key] = CartItem(
          product: product,
          selectedWeight: displayWeight,
          variantId: variantId,
          variant: effectiveVariant,
          quantity: targetQty,
        );
      }
      _detailedProductsCache[product.id] = product;
      _apiPriceBreakdown = null;
      notifyListeners();
      _saveCartToCache();
      return res;
    } else {
      // Guest/offline mode:
      if (_cartItems.containsKey(key)) {
        final cur = _cartItems[key]!.quantity;
        _cartItems[key]!.quantity = (cur + qty).clamp(1, 99);
      } else {
        _cartItems[key] = CartItem(
          product: product,
          selectedWeight: displayWeight,
          variantId: variantId,
          variant: effectiveVariant,
          quantity: qty.clamp(1, 99),
        );
      }
      _detailedProductsCache[product.id] = product;
      _apiPriceBreakdown = null;
      notifyListeners();
      _saveCartToCache();
      return null;
    }
  }

  /// Asynchronous add-to-cart that awaits the PUT /consumer/cart/{variantId} call
  Future<ApiResponse<CartItemResponse>?> addToCartWithApi(
    Product product,
    String weight, {
    ProductVariant? variant,
    int qty = 1,
  }) {
    return addToCart(product, weight, variant: variant, qty: qty);
  }

  Future<ApiResponse<CartItemResponse>?> updateQuantity(String key, int delta) async {
    CartItem? item = _cartItems[key];
    String effectiveKey = key;

    if (item == null) {
      // Find matching item by key substring or effective variant
      for (final entry in _cartItems.entries) {
        if (entry.key == key ||
            entry.value.itemKey == key ||
            entry.value.effectiveVariantId == key ||
            '${entry.value.product.id}_${entry.value.variantId}' == key ||
            '${entry.value.product.id}_${entry.value.selectedWeight}' == key) {
          effectiveKey = entry.key;
          item = entry.value;
          break;
        }
      }
    }
    if (item == null) return null;

    final syncId = item.effectiveVariantId;
    final prodId = item.product.id;
    final int previousQty = item.quantity;
    final newQty = previousQty + delta;

    final auth = AuthService();
    final bool isLoggedIn = auth.authToken != null && auth.authToken!.isNotEmpty;

    if (isLoggedIn) {
      if (newQty <= 0) {
        final res = await deleteCartItemFromApi(syncId, productId: prodId);
        if (!res.success) {
          return ApiResponse.error(res.message ?? 'Failed to delete cart item', statusCode: res.statusCode ?? 400);
        }
        _cartItems.remove(effectiveKey);
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return null;
      } else {
        final res = await syncCartItemToApi(syncId, newQty.clamp(1, 99), productId: prodId);
        if (res != null && !res.success) {
          // Reject update, local state untouched
          return res;
        }
        item.quantity = newQty.clamp(1, 99);
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return res;
      }
    } else {
      if (newQty <= 0) {
        _cartItems.remove(effectiveKey);
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return null;
      } else {
        item.quantity = newQty.clamp(1, 99);
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return null;
      }
    }
  }

  /// Updates quantity of a specific variant or creates it if not yet in cart
  Future<ApiResponse<CartItemResponse>?> updateVariantQuantity(
    String productId,
    String variantId,
    int delta, {
    String? weight,
  }) async {
    final cleanWeight = weight?.trim().toLowerCase().replaceAll(' ', '');
    for (final entry in _cartItems.entries) {
      final item = entry.value;
      final matchesProduct = item.product.id == productId ||
          item.product.id == variantId ||
          item.effectiveVariantId == variantId;
      if (!matchesProduct) continue;

      if (item.variantId == variantId ||
          item.variant?.id == variantId ||
          item.effectiveVariantId == variantId ||
          (cleanWeight != null &&
           (item.selectedWeight.toLowerCase().replaceAll(' ', '') == cleanWeight ||
            item.variant?.displayLabel.toLowerCase().replaceAll(' ', '') == cleanWeight))) {
        return await updateQuantity(entry.key, delta);
      }
    }

    final keyWithVariant = '${productId}_$variantId';
    if (_cartItems.containsKey(keyWithVariant)) {
      return await updateQuantity(keyWithVariant, delta);
    }
    if (weight != null) {
      final keyWithWeight = '${productId}_$weight';
      if (_cartItems.containsKey(keyWithWeight)) {
        return await updateQuantity(keyWithWeight, delta);
      }
    }

    if (delta > 0) {
      final p = findProductById(productId);
      if (p != null) {
        final v = p.variants.where((va) => va.id == variantId).firstOrNull;
        return await addToCart(p, weight ?? v?.displayLabel ?? p.defaultWeight, variant: v, qty: delta);
      }
    }
    return null;
  }

  Future<ApiResponse<CartItemResponse>?> setProductQty(Product product, int qty, {ProductVariant? variant}) async {
    final effectiveVariant = variant ??
        (product.variants.isNotEmpty ? product.variants.first : null);
    final variantId = effectiveVariant?.id;
    final displayWeight = effectiveVariant?.displayLabel ?? product.defaultWeight;
    final key = variantId != null && variantId.isNotEmpty
        ? '${product.id}_$variantId'
        : '${product.id}_$displayWeight';

    final syncId = (variantId != null && variantId.isNotEmpty)
        ? variantId
        : product.id;

    final auth = AuthService();
    final bool isLoggedIn = auth.authToken != null && auth.authToken!.isNotEmpty;

    if (isLoggedIn) {
      if (qty <= 0) {
        final res = await deleteCartItemFromApi(syncId, productId: product.id);
        if (!res.success) {
          return ApiResponse.error(res.message ?? 'Failed to delete cart item', statusCode: res.statusCode ?? 400);
        }
        _cartItems.remove(key);
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return null;
      } else {
        final res = await syncCartItemToApi(syncId, qty.clamp(1, 99), productId: product.id);
        if (res != null && !res.success) {
          return res;
        }
        if (_cartItems.containsKey(key)) {
          _cartItems[key]!.quantity = qty.clamp(1, 99);
        } else {
          _cartItems[key] = CartItem(
            product: product,
            selectedWeight: displayWeight,
            variantId: variantId,
            variant: effectiveVariant,
            quantity: qty.clamp(1, 99),
          );
        }
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return res;
      }
    } else {
      if (qty <= 0) {
        _cartItems.remove(key);
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return null;
      } else {
        if (_cartItems.containsKey(key)) {
          _cartItems[key]!.quantity = qty.clamp(1, 99);
        } else {
          _cartItems[key] = CartItem(
            product: product,
            selectedWeight: displayWeight,
            variantId: variantId,
            variant: effectiveVariant,
            quantity: qty.clamp(1, 99),
          );
        }
        _apiPriceBreakdown = null;
        notifyListeners();
        _saveCartToCache();
        return null;
      }
    }
  }

  int getProductQty(String productId) {
    int total = 0;
    for (final item in _cartItems.values) {
      if (item.product.id == productId || item.effectiveVariantId == productId) {
        total += item.quantity;
      }
    }
    return total;
  }

  int getVariantQty(String productId, String variantId, [String? variantWeight]) {
    final cleanWeight = variantWeight?.trim().toLowerCase().replaceAll(' ', '');
    for (final item in _cartItems.values) {
      final matchesProduct = item.product.id == productId ||
          item.product.id == variantId ||
          item.effectiveVariantId == variantId;
      if (!matchesProduct) continue;

      if (item.variantId == variantId ||
          item.variant?.id == variantId ||
          item.effectiveVariantId == variantId) {
        return item.quantity;
      }

      if (cleanWeight != null && cleanWeight.isNotEmpty &&
          (item.selectedWeight.toLowerCase().replaceAll(' ', '') == cleanWeight ||
           item.variant?.displayLabel.toLowerCase().replaceAll(' ', '') == cleanWeight)) {
        return item.quantity;
      }
    }
    return 0;
  }

  void removeItem(String key) {
    CartItem? item = _cartItems[key];
    String effectiveKey = key;
    if (item == null) {
      for (final entry in _cartItems.entries) {
        if (entry.key == key ||
            entry.value.itemKey == key ||
            entry.value.effectiveVariantId == key) {
          item = entry.value;
          effectiveKey = entry.key;
          break;
        }
      }
    }
    if (item != null) {
      final syncId = item.effectiveVariantId;
      final prodId = item.product.id;
      _cartItems.remove(effectiveKey);
      _apiPriceBreakdown = null;
      notifyListeners();
      _saveCartToCache();
      deleteCartItemFromApi(syncId, productId: prodId);
    }
  }

  void clearCart() {
    _cartItems.clear();
    _apiPriceBreakdown = null;
    _apiAppliedPromotion = null;
    _cartDeliveryInfo = null;
    _parsedDeliveryInfo = null;
    _selectedDeliverySlot = null;
    _cartAddressId = null;
    _checkoutReady = false;
    _pricingIssues = [];
    notifyListeners();
    _saveCartToCache();
    clearCartOnApi();
  }

  Future<void> _saveCartToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _cartItems.values.map((item) => item.toCacheJson()).toList();
      await prefs.setString('cached_cart_items', jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _loadCartFromCache() async {
    try {
      if (_cartItems.isNotEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      final cachedCartJson = prefs.getString('cached_cart_items');
      if (cachedCartJson != null && cachedCartJson.isNotEmpty) {
        final decoded = jsonDecode(cachedCartJson);
        if (decoded is List) {
          if (_cartItems.isNotEmpty) return;
          for (final map in decoded) {
            if (map is Map<String, dynamic>) {
              final pid = map['productId'] as String? ?? '';
              final vid = map['variantId'] as String?;
              final weight = map['weight'] as String? ?? '500g';
              final qty = (map['quantity'] as num?)?.toInt() ?? 1;
              if (pid.isNotEmpty) {
                Product? prod = findProductById(pid);
                if (prod == null && map['product'] is Map<String, dynamic>) {
                  try {
                    prod = Product.fromJson(map['product'] as Map<String, dynamic>);
                  } catch (_) {}
                }
                if (prod != null) {
                  final v = prod.variants.where((va) => va.id == vid || va.displayLabel == weight).firstOrNull;
                  final key = (vid != null && vid.isNotEmpty) ? '${prod.id}_$vid' : '${prod.id}_$weight';
                  _cartItems[key] = CartItem(
                    product: prod,
                    selectedWeight: weight,
                    variantId: vid,
                    variant: v,
                    quantity: qty.clamp(1, 99),
                  );
                }
              }
            }
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Clears the signed-in consumer's entire cart via DELETE /consumer/cart
  Future<ApiResponse<ClearCartResponse>?> clearCartOnApi() async {
    final auth = AuthService();
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      return await auth.clearCart();
    }
    return null;
  }

  /// Syncs an individual variant/product quantity to backend via PUT /consumer/cart/{variantId}
  Future<ApiResponse<CartItemResponse>?> syncCartItemToApi(
    String productIdOrVariantId,
    int quantity, {
    String? productId,
  }) async {
    final auth = AuthService();
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      if (quantity <= 0) {
        await auth.deleteCartItem(variantId: productIdOrVariantId, productId: productId);
        loadCartFromApi();
        return ApiResponse.success(
          CartItemResponse(
            productId: productId ?? productIdOrVariantId,
            variantId: productIdOrVariantId,
            quantity: 0,
          ),
          message: 'Cart item removed',
        );
      }
      final res = await auth.setCartItemQuantity(
        variantId: productIdOrVariantId,
        productId: productId,
        quantity: quantity,
      );
      if (res.success) {
        loadCartFromApi();
      }
      return res;
    }
    return null;
  }

  /// Delete a variant/product completely from the backend cart via DELETE /consumer/cart/{variantId}
  Future<ApiResponse<CartItemDeleteResponse>> deleteCartItemFromApi(
    String productIdOrVariantId, {
    String? productId,
  }) async {
    final auth = AuthService();
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      final res = await auth.deleteCartItem(
        variantId: productIdOrVariantId,
        productId: productId,
      );
      if (res.success) {
        loadCartFromApi();
      }
      return res;
    }
    return ApiResponse.success(const CartItemDeleteResponse(deleted: true));
  }

  /// Syncs all local cart items to the backend upon login
  Future<void> syncAllCartItemsToApi() async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) return;

    for (final item in _cartItems.values) {
      await auth.setCartItemQuantity(
        variantId: item.effectiveVariantId,
        quantity: item.quantity,
      );
    }
  }

  bool _isLoadingCart = false;
  bool get isLoadingCart => _isLoadingCart;

  /// Load the signed-in consumer's cart from GET /consumer/cart
  /// Passes the active delivery address ID (mandatory for delivery pricing) and applied coupon code
  Future<ApiResponse<ConsumerCartResponse>> loadCartFromApi({
    String? addressId,
    String? couponCode,
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('User not logged in', statusCode: 401);
    }

    // Ensure saved addresses are loaded if not loaded yet
    if (!_hasLoadedAddresses && _addresses.isEmpty && !_isLoadingAddresses) {
      await loadAddressesFromApi();
    }

    // Address is mandatory for backend delivery pricing
    final targetAddressId = addressId ?? selectedAddressId;

    _isLoadingCart = true;
    notifyListeners();
    try {
      final targetCoupon = couponCode ?? _appliedCoupon;
      final response = await auth.getCart(
        addressId: targetAddressId,
        couponCode: targetCoupon,
      );
      if (response.success && response.data != null) {
        _populateCartFromResponse(response.data!, targetAddressId, targetCoupon: targetCoupon);
        _saveCartToCache();
      } else {
        // If an explicit or previously applied coupon was rejected by the API
        if (targetCoupon != null && targetCoupon.trim().isNotEmpty) {
          _appliedCoupon = null;
          _couponDiscount = 0.0;
          _apiAppliedPromotion = null;
          // Re-fetch cart cleanly WITHOUT the rejected coupon so cart data, address, and fees remain valid
          final fallback = await auth.getCart(
            addressId: targetAddressId,
            couponCode: null,
          );
          if (fallback.success && fallback.data != null) {
            _populateCartFromResponse(fallback.data!, targetAddressId, targetCoupon: null);
            _saveCartToCache();
          }
        }
      }
      return response;
    } finally {
      _isLoadingCart = false;
      notifyListeners();
    }
  }

  void _populateCartFromResponse(
    ConsumerCartResponse data,
    String? targetAddressId, {
    String? targetCoupon,
  }) {
    final existingSnapshot = Map<String, CartItem>.from(_cartItems);

    // If server returns empty items, clear local cart state completely so stale/purchased items are deleted
    if (data.items.isEmpty) {
      _cartItems.clear();
      _apiPriceBreakdown = data.priceBreakdown;
      _apiAppliedPromotion = data.appliedPromotion;
      _cartAddressId = data.addressId ?? targetAddressId;
      _cartDeliveryInfo = data.delivery;
      _parsedDeliveryInfo = data.deliveryInfo ??
          (data.delivery != null ? CartDeliveryInfo.fromJson(data.delivery!) : null);
      _checkoutReady = data.checkoutReady;
      _pricingIssues = List.of(data.pricingIssues);
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _selectedDeliverySlot = null;
      return;
    }

    _cartItems.clear();
    final processedLocalKeys = <String>{};

    for (final item in data.items) {
      if (item.quantity <= 0) continue;

      // 1. Find richest Product metadata with variants
      Product effectiveProduct = item.product;
      Product? richProduct = findProductById(item.product.id) ??
          findProductById(item.productId);

      if (richProduct == null || richProduct.variants.isEmpty) {
        for (final p in _bestsellerProducts) {
          if (p.id == item.product.id ||
              p.id == item.productId ||
              p.variants.any((v) =>
                  v.id == item.productId ||
                  v.id == item.variantId ||
                  (item.variant != null && v.id == item.variant!.id))) {
            richProduct = p;
            break;
          }
        }
      }
      if (richProduct == null || richProduct.variants.isEmpty) {
        for (final p in _detailedProductsCache.values) {
          if (p.id == item.product.id ||
              p.id == item.productId ||
              p.variants.any((v) =>
                  v.id == item.productId ||
                  v.id == item.variantId ||
                  (item.variant != null && v.id == item.variant!.id))) {
            richProduct = p;
            break;
          }
        }
      }
      if (richProduct == null || richProduct.variants.isEmpty) {
        for (final existing in existingSnapshot.values) {
          if (existing.product.id == item.product.id ||
              existing.product.id == item.productId ||
              existing.variantId == item.productId ||
              existing.variant?.id == item.productId) {
            richProduct = existing.product;
            break;
          }
        }
      }
      if (richProduct == null || richProduct.variants.isEmpty) {
        final live = findLiveProductById(item.productId);
        if (live != null && live.variants.isNotEmpty) {
          richProduct = live;
        }
      }

      if (richProduct != null && richProduct.variants.isNotEmpty) {
        effectiveProduct = richProduct;
      }

      // 2. Resolve matching ProductVariant
      ProductVariant? effectiveVariant = item.variant;

      // Match against existingSnapshot
      CartItem? matchingExisting;
      for (final existingEntry in existingSnapshot.entries) {
        final existing = existingEntry.value;
        if (existing.variant != null &&
            (existing.variantId == item.productId ||
             existing.variantId == item.variantId ||
             existing.variant?.id == item.productId ||
             existing.variant?.id == item.variantId ||
             (existing.product.id == effectiveProduct.id &&
              (existing.variantId == item.variantId ||
               existing.variant?.id == item.productId)))) {
          matchingExisting = existing;
          processedLocalKeys.add(existingEntry.key);
          break;
        }
      }
      if (matchingExisting == null) {
        for (final existingEntry in existingSnapshot.entries) {
          final existing = existingEntry.value;
          if (existing.product.id == effectiveProduct.id && existing.variant != null) {
            matchingExisting = existing;
            processedLocalKeys.add(existingEntry.key);
            break;
          }
        }
      }

      if (effectiveVariant == null && matchingExisting?.variant != null) {
        effectiveVariant = matchingExisting!.variant;
      }

      if (effectiveVariant == null && effectiveProduct.variants.isNotEmpty) {
        final targetIds = [
          if (item.variantId != null && item.variantId!.isNotEmpty) item.variantId!,
          if (item.productId.isNotEmpty && item.productId != effectiveProduct.id) item.productId,
          if (item.productId.isNotEmpty) item.productId,
        ];
        for (final tid in targetIds) {
          effectiveVariant = effectiveProduct.variants
              .where((v) => v.id == tid)
              .firstOrNull;
          if (effectiveVariant != null) break;
        }
      }

      if (effectiveVariant == null && effectiveProduct.variants.isNotEmpty) {
        final unitPrice = item.lineTotal > 0 && item.quantity > 0
            ? (item.lineTotal / item.quantity).roundToDouble()
            : 0.0;
        if (unitPrice > 0) {
          effectiveVariant = effectiveProduct.variants
              .where((v) => (v.price - unitPrice).abs() < 1.0)
              .firstOrNull;
        }
      }

      if (effectiveVariant == null && matchingExisting != null && effectiveProduct.variants.isNotEmpty) {
        effectiveVariant = effectiveProduct.variants
            .where((v) => v.displayLabel.toLowerCase().trim() ==
                matchingExisting!.selectedWeight.toLowerCase().trim())
            .firstOrNull;
      }

      if (effectiveVariant == null && effectiveProduct.variants.isNotEmpty) {
        effectiveVariant = effectiveProduct.variants.first;
      }

      final variantId = effectiveVariant?.id ??
          item.variantId ??
          (item.productId != effectiveProduct.id ? item.productId : null);
      final weight = effectiveVariant?.displayLabel ??
          matchingExisting?.selectedWeight ??
          effectiveProduct.defaultWeight;

      final key = variantId != null && variantId.isNotEmpty
          ? '${effectiveProduct.id}_$variantId'
          : '${effectiveProduct.id}_$weight';

      _cartItems[key] = CartItem(
        product: effectiveProduct,
        selectedWeight: weight,
        variantId: variantId,
        variant: effectiveVariant,
        quantity: item.quantity,
        availableQuantity: item.availableQuantity,
        inStock: item.inStock,
        lineTotal: item.lineTotal > 0
            ? item.lineTotal
            : (effectiveVariant != null && effectiveVariant.price > 0
                ? effectiveVariant.price * item.quantity
                : 0.0),
      );
    }
    // Sync API pricing and checkout state
    _apiPriceBreakdown = data.priceBreakdown;
    _apiAppliedPromotion = data.appliedPromotion;
    _cartAddressId = data.addressId ?? targetAddressId;
    _cartDeliveryInfo = data.delivery;
    _parsedDeliveryInfo = data.deliveryInfo ??
        (data.delivery != null ? CartDeliveryInfo.fromJson(data.delivery!) : null);
    _checkoutReady = data.checkoutReady;
    _pricingIssues = List.of(data.pricingIssues);

    // If currently selected delivery slot is no longer in valid slots, reset it
    final validSlots = deliverySlots;
    if (_selectedDeliverySlot != null &&
        validSlots.isNotEmpty &&
        !validSlots.contains(_selectedDeliverySlot)) {
      _selectedDeliverySlot = null;
    }

    // Sync coupon discount from API if a coupon is applied
    if (data.appliedPromotion != null &&
        data.appliedPromotion!.discountAmount > 0) {
      _appliedCoupon = data.appliedPromotion!.code;
      _couponDiscount = data.appliedPromotion!.discountAmount;
    } else if (data.priceBreakdown?.couponDiscount != null &&
        data.priceBreakdown!.couponDiscount > 0) {
      _couponDiscount = data.priceBreakdown!.couponDiscount;
      if (_appliedCoupon == null && targetCoupon != null && targetCoupon.trim().isNotEmpty) {
        _appliedCoupon = targetCoupon.trim().toUpperCase();
      }
    } else {
      // Backend returned 0 coupon discount or no promotion
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _apiAppliedPromotion = null;
    }
  }

  @visibleForTesting
  void populateCartFromResponseForTesting(
    ConsumerCartResponse data, {
    String? targetAddressId,
    String? targetCoupon,
  }) {
    _populateCartFromResponse(data, targetAddressId, targetCoupon: targetCoupon);
    notifyListeners();
  }

  void setDeliveryInstruction(String instr) {
    _deliveryInstruction = instr;
    _deliveryInstructions.clear();
    if (instr.isNotEmpty) {
      _deliveryInstructions.add(instr);
    }
    notifyListeners();
  }

  void toggleDeliveryInstruction(String instr) {
    if (_deliveryInstructions.contains(instr)) {
      _deliveryInstructions.remove(instr);
    } else {
      // Mutual exclusion for conflicting delivery instructions:
      // "Ring the bell" and "Don't ring bell" are mutually exclusive
      if (instr.toLowerCase().contains("don't ring") || instr.toLowerCase().contains("dont ring")) {
        _deliveryInstructions.removeWhere((i) => i.toLowerCase().contains("ring the bell") || i.toLowerCase() == "ring bell");
      } else if (instr.toLowerCase().contains("ring the bell") || instr.toLowerCase() == "ring bell") {
        _deliveryInstructions.removeWhere((i) => i.toLowerCase().contains("don't ring") || i.toLowerCase().contains("dont ring"));
      }
      _deliveryInstructions.add(instr);
    }
    _deliveryInstruction = _deliveryInstructions.join(', ');
    notifyListeners();
  }

  Future<CouponApplyResult> applyCoupon(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) {
      return const CouponApplyResult(
        success: false,
        message: 'Please enter a valid coupon code',
      );
    }

    final offer = coupons.where((c) => c.code == clean).firstOrNull;
    if (offer != null && !offer.isEligible(subtotal)) {
      final needed = (offer.minOrder - subtotal).clamp(0.0, double.infinity);
      return CouponApplyResult(
        success: false,
        message:
            'Add ₹${needed.toInt()} more to use $clean (Minimum order: ₹${offer.minOrder.toInt()})',
      );
    }

    if (_isLoggedIn) {
      final response = await loadCartFromApi(couponCode: clean);
      if (response.success && response.data != null) {
        final data = response.data!;
        final promo = data.appliedPromotion;
        final hasPromo = (promo != null && promo.discountAmount > 0) ||
            ((data.priceBreakdown?.couponDiscount ?? 0) > 0);

        if (hasPromo) {
          final disc = (promo != null && promo.discountAmount > 0)
              ? promo.discountAmount
              : data.priceBreakdown!.couponDiscount;
          _appliedCoupon = promo?.code ?? clean;
          _couponDiscount = disc;
          notifyListeners();
          return CouponApplyResult(
            success: true,
            message: 'Offer $clean applied! Saved ₹${disc.toInt()}',
            discountAmount: disc,
          );
        } else {
          // Backend returned 200 but didn't apply promotion
          _appliedCoupon = null;
          _couponDiscount = 0.0;
          _apiAppliedPromotion = null;
          notifyListeners();
          return CouponApplyResult(
            success: false,
            message: 'Offer $clean could not be applied to the items in your cart',
          );
        }
      } else {
        // Backend rejected coupon (e.g., 400 "This promotion does not apply to the products in your cart.")
        _appliedCoupon = null;
        _couponDiscount = 0.0;
        _apiAppliedPromotion = null;
        notifyListeners();
        final errorMsg = (response.message != null && response.message!.trim().isNotEmpty)
            ? response.message!
            : 'Offer $clean could not be applied';
        return CouponApplyResult(
          success: false,
          message: errorMsg,
        );
      }
    }

    // Fallback for offline / guest
    final discount = offer != null
        ? offer.calculateDiscount(subtotal)
        : (subtotal * 0.1).clamp(0.0, 100.0);
    _appliedCoupon = clean;
    _couponDiscount = discount;
    _apiPriceBreakdown = null;
    notifyListeners();
    return CouponApplyResult(
      success: true,
      message: 'Offer $clean applied! Saved ₹${discount.toInt()}',
      discountAmount: discount,
    );
  }

  void addOrUpdateCoupon(CouponOffer offer) {
    final idx = _coupons.indexWhere((c) => c.code == offer.code);
    if (idx != -1) {
      _coupons[idx] = offer;
    } else {
      _coupons.add(offer);
    }
    if (_appliedCoupon == offer.code) {
      _couponDiscount = offer.calculateDiscount(subtotal);
    }
    notifyListeners();
  }

  void deleteCoupon(String code) {
    _coupons.removeWhere((c) => c.code == code);
    if (_appliedCoupon == code) {
      removeCoupon();
    } else {
      notifyListeners();
    }
  }

  void removeCoupon() {
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    _apiAppliedPromotion = null;
    _apiPriceBreakdown = null;
    notifyListeners();
    if (_isLoggedIn) {
      loadCartFromApi(couponCode: '');
    }
  }

  // Wishlist Actions
  void toggleWishlist(String productId, {Product? product}) {
    if (_wishlist.contains(productId)) {
      _wishlist.remove(productId);
      _wishlistProducts.remove(productId);
      removeFromWishlistApi(productId);
    } else {
      _wishlist.add(productId);
      if (product != null) {
        _wishlistProducts[productId] = product;
      }
      addToWishlistApi(productId);
    }
    notifyListeners();
  }

  void toggleFavorite(String productId, {Product? product}) =>
      toggleWishlist(productId, product: product);

  /// Add product to wishlist via PUT /consumer/wishlist/{productId}
  Future<ApiResponse<AddToWishlistResponse>?> addToWishlistApi(
    String productId,
  ) async {
    final auth = AuthService();
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      return await auth.addToWishlist(productId: productId);
    }
    return null;
  }

  /// Remove product from wishlist via DELETE /consumer/wishlist/{productId}
  Future<ApiResponse<RemoveFromWishlistResponse>?> removeFromWishlistApi(
    String productId,
  ) async {
    final auth = AuthService();
    if (auth.authToken != null && auth.authToken!.isNotEmpty) {
      return await auth.removeFromWishlist(productId: productId);
    }
    return null;
  }

  /// Fetch the signed-in consumer's wishlist from GET /consumer/wishlist
  Future<ApiResponse<ConsumerWishlistResponse>> loadWishlistFromApi() async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('User not logged in', statusCode: 401);
    }

    _isLoadingWishlist = true;
    notifyListeners();
    try {
      final response = await auth.getWishlist();
      if (response.success && response.data != null) {
        _wishlist.clear();
        _wishlistProducts.clear();
        for (final item in response.data!.items) {
          _wishlist.add(item.productId);
          _wishlistProducts[item.productId] = item.product;
        }
        _hasLoadedWishlist = true;
      }
      return response;
    } finally {
      _isLoadingWishlist = false;
      notifyListeners();
    }
  }

  // Address Actions
  bool _isLoadingAddresses = false;
  bool get isLoadingAddresses => _isLoadingAddresses;
  bool _hasLoadedAddresses = false;
  bool get hasLoadedAddresses => _hasLoadedAddresses;
  bool _isSavingAddress = false;
  bool get isSavingAddress => _isSavingAddress;
  String? _deletingAddressId;
  String? get deletingAddressId => _deletingAddressId;

  Future<void> _saveAddressesToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _addresses.map((a) => a.toLocalJson()).toList();
      await prefs.setString('user_addresses', jsonEncode(list));
    } catch (_) {}
  }

  Future<ApiResponse<List<DeliveryAddress>>> loadAddressesFromApi() async {
    if (AuthService().authToken != null &&
        AuthService().authToken!.isNotEmpty) {
      _isLoadingAddresses = true;
      notifyListeners();
      final response = await AuthService().getAddresses();
      _isLoadingAddresses = false;
      if (response.success && response.data != null) {
        if (response.data!.isNotEmpty) {
          _addresses.clear();
          _addresses.addAll(response.data!);
          await _saveAddressesToCache();
          if (_currentGpsPosition != null && !_isManualAddressSelected) {
            _evaluateNearbyAddress(_currentGpsPosition!);
          } else {
            _activeDeliveryAddress ??= defaultAddress;
          }
        }
        _hasLoadedAddresses = true;
      }
      notifyListeners();
      return response;
    }
    return ApiResponse.success(_addresses);
  }

  void setDefaultAddress(dynamic id) {
    final strId = id.toString();
    for (final a in _addresses) {
      a.isDefault = (a.id == strId);
    }
    final matched = _addresses.where((a) => a.id == strId).firstOrNull;
    if (matched != null) {
      _activeDeliveryAddress = matched;
      _isManualAddressSelected = true;
    }
    _saveAddressesToCache();
    notifyListeners();
    if (_isLoggedIn && AuthService().authToken != null) {
      AuthService().updateAddress(id: strId, isDefault: true);
      loadCartFromApi(addressId: strId);
    }
  }

  void addAddress(DeliveryAddress addr) {
    if (addr.isDefault) {
      for (final a in _addresses) {
        a.isDefault = false;
      }
    }
    _addresses.add(addr);
    _saveAddressesToCache();
    if (_currentGpsPosition != null && !_isManualAddressSelected) {
      _evaluateNearbyAddress(_currentGpsPosition!);
    }
    notifyListeners();
  }

  Future<ApiResponse<DeliveryAddress>> addAddressViaApi(
      DeliveryAddress addr) async {
    _isSavingAddress = true;
    notifyListeners();
    try {
      if (AuthService().authToken != null &&
          AuthService().authToken!.isNotEmpty) {
        final response = await AuthService().addAddress(addr);
        if (response.success && response.data != null) {
          final created = response.data!;
          if (created.isDefault) {
            for (final a in _addresses) {
              a.isDefault = false;
            }
          }
          _addresses.add(created);
          await _saveAddressesToCache();
        }
        return response;
      } else {
        addAddress(addr);
        return ApiResponse.success(addr, message: 'Address saved locally');
      }
    } finally {
      _isSavingAddress = false;
      notifyListeners();
    }
  }

  void updateAddress(DeliveryAddress updated) {
    final index = _addresses.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      if (updated.isDefault) {
        for (final a in _addresses) {
          a.isDefault = false;
        }
      }
      _addresses[index] = updated;
      _saveAddressesToCache();
      notifyListeners();
    }
  }

  Future<ApiResponse<DeliveryAddress>> updateAddressViaApi(
      DeliveryAddress updated) async {
    _isSavingAddress = true;
    notifyListeners();
    try {
      if (AuthService().authToken != null &&
          AuthService().authToken!.isNotEmpty) {
        final response = await AuthService().updateAddress(
          id: updated.id,
          label: updated.label,
          receiverName: updated.receiverName,
          phone: updated.phone,
          flatHouseBuilding: updated.flatHouseBuilding,
          streetArea: updated.streetArea,
          city: updated.city,
          postalCode: updated.postalCode,
          isDefault: updated.isDefault,
          latitude: updated.latitude,
          longitude: updated.longitude,
        );
        if (response.success && response.data != null) {
          final saved = response.data!;
          final index = _addresses.indexWhere((a) => a.id == saved.id);
          if (index != -1) {
            if (saved.isDefault) {
              for (final a in _addresses) {
                a.isDefault = false;
              }
            }
            _addresses[index] = saved;
            await _saveAddressesToCache();
          }
        }
        return response;
      } else {
        updateAddress(updated);
        return ApiResponse.success(updated, message: 'Address updated locally');
      }
    } finally {
      _isSavingAddress = false;
      notifyListeners();
    }
  }

  void deleteAddress(dynamic id) {
    final strId = id.toString();
    _addresses.removeWhere((a) => a.id == strId);
    if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
      _addresses.first.isDefault = true;
    }
    _saveAddressesToCache();
    notifyListeners();
  }

  Future<ApiResponse<bool>> deleteAddressViaApi(dynamic id) async {
    final strId = id.toString();
    _deletingAddressId = strId;
    notifyListeners();
    try {
      if (AuthService().authToken != null &&
          AuthService().authToken!.isNotEmpty) {
        final response = await AuthService().deleteAddress(strId);
        if (response.success) {
          deleteAddress(strId);
        }
        return response;
      } else {
        deleteAddress(strId);
        return ApiResponse.success(true, message: 'Address deleted locally');
      }
    } finally {
      _deletingAddressId = null;
      notifyListeners();
    }
  }

  // Profile Actions
  void updateProfile({
    String? name,
    String? email,
    String? dob,
    String? gender,
    String? spiceTolerance,
    bool? isVegetarianOnly,
    bool? excludeGarlic,
    List<String>? preferredRegions,
  }) {
    if (name != null && name.isNotEmpty) _userName = name;
    if (email != null && email.isNotEmpty) _userEmail = email;
    if (dob != null && dob.isNotEmpty) _dob = dob;
    if (gender != null && gender.isNotEmpty) _gender = gender;
    if (spiceTolerance != null) _spiceTolerance = spiceTolerance;
    if (isVegetarianOnly != null) _isVegetarianOnly = isVegetarianOnly;
    if (excludeGarlic != null) _excludeGarlic = excludeGarlic;
    if (preferredRegions != null) {
      _preferredRegions.clear();
      _preferredRegions.addAll(preferredRegions);
    }
    notifyListeners();
  }

  void setSpiceTolerance(String level) {
    _spiceTolerance = level;
    notifyListeners();
    if (_isLoggedIn) {
      updateProfileViaApi(spiceTolerance: level);
    }
  }

  void toggleVegetarianOnly() {
    _isVegetarianOnly = !_isVegetarianOnly;
    notifyListeners();
    if (_isLoggedIn) {
      updateProfileViaApi(vegetarianOnly: _isVegetarianOnly);
    }
  }

  void toggleExcludeGarlic() {
    _excludeGarlic = !_excludeGarlic;
    notifyListeners();
    if (_isLoggedIn) {
      updateProfileViaApi(excludeGarlic: _excludeGarlic);
    }
  }

  void togglePreferredRegion(String region) {
    if (_preferredRegions.contains(region)) {
      _preferredRegions.remove(region);
    } else {
      _preferredRegions.add(region);
    }
    notifyListeners();
    if (_isLoggedIn) {
      updateProfileViaApi(preferredRegionalStyles: _preferredRegions.toList());
    }
  }

  /// Generates RFC4122 version 4 UUID
  static String generateUuidV4() {
    final random = math.Random();
    String hex(int len) =>
        List.generate(len, (_) => random.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${(8 + random.nextInt(4)).toRadixString(16)}${hex(3)}-${hex(12)}';
  }

  /// Reset the active checkout requestId
  void resetCheckoutRequestId() {
    _activeCheckoutRequestId = null;
  }

  /// Places a COD order using backend API: POST /consumer/orders
  ///
  /// - paymentMethod: 'COD'
  /// - addressId: consumer's delivery address ID
  /// - deliverySlot: exact configured delivery slot from backend or fallback
  /// - couponCode: omitted if no offer is applied
  /// - requestId: UUID v4 generated once per order attempt, reused for retries
  Future<ApiResponse<UserOrder>> placeCodOrder({
    String? deliverySlot,
    bool isRetry = false,
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('Please login to place an order', statusCode: 401);
    }

    final addrId = selectedAddressId;
    if (addrId == null || addrId.isEmpty) {
      return ApiResponse.error('Please select a valid delivery address');
    }

    // Reuse requestId on retry, otherwise generate fresh UUID v4
    if (!isRetry || _activeCheckoutRequestId == null || _activeCheckoutRequestId!.isEmpty) {
      _activeCheckoutRequestId = generateUuidV4();
    }

    // Resolve exact configured delivery slot (mandatory)
    final resolvedSlot = (deliverySlot != null && deliverySlot.trim().isNotEmpty)
        ? deliverySlot.trim()
        : (_selectedDeliverySlot != null && _selectedDeliverySlot!.trim().isNotEmpty)
            ? _selectedDeliverySlot!.trim()
            : (deliverySlots.isEmpty ? 'Standard Delivery' : null);

    if (resolvedSlot == null || resolvedSlot.isEmpty) {
      return ApiResponse.error('Please select a delivery slot to proceed');
    }

    // Omit couponCode if no offer is applied
    final promoCode = (_appliedCoupon != null && _appliedCoupon!.trim().isNotEmpty)
        ? _appliedCoupon!.trim()
        : null;

    final response = await auth.createOrder(
      requestId: _activeCheckoutRequestId!,
      addressId: addrId,
      paymentMethod: 'COD',
      deliverySlot: resolvedSlot,
      couponCode: promoCode,
    );

    if (response.success && response.data != null) {
      // Order placed successfully: reset requestId for the next order
      _activeCheckoutRequestId = null;

      final fallbackAddr = activeDeliveryAddress ?? defaultAddress;
      final order = UserOrder.fromJson(
        response.data!,
        fallbackAddress: fallbackAddr,
      );

      _activeOrder = order;
      _orders.insert(0, order);

      // Award spice points
      final pts = (order.total / 10).floor();
      _spicePoints += pts;

      // Clear local cart and cart pricing state
      _cartItems.clear();
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _apiAppliedPromotion = null;
      _apiPriceBreakdown = null;
      _cartDeliveryInfo = null;
      _parsedDeliveryInfo = null;
      _selectedDeliverySlot = null;

      notifyListeners();
      return ApiResponse.success(
        order,
        message: response.message ?? 'Order placed successfully',
        statusCode: response.statusCode ?? 200,
      );
    } else {
      return ApiResponse.error(
        response.message ?? 'Failed to place order',
        statusCode: response.statusCode ?? 400,
      );
    }
  }

  /// Initiates an online order placement with the backend.
  /// Calls POST /consumer/payments/razorpay/order with paymentMethod ('Online' or 'Wallet').
  /// Returns the backend-generated order details (containing backend order ID,
  /// Razorpay order ID if present, amount in paise, currency, keyId, requestId, walletUsed, gatewayAmount).
  Future<ApiResponse<Map<String, dynamic>>> initiateOnlineOrder({
    String? deliverySlot,
    bool isRetry = false,
    String paymentMethod = 'Online',
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('Please login to place an order', statusCode: 401);
    }

    final addrId = selectedAddressId;
    if (addrId == null || addrId.isEmpty) {
      return ApiResponse.error('Please select a valid delivery address');
    }

    // Reuse requestId on retry, otherwise generate fresh UUID v4
    if (!isRetry || _activeCheckoutRequestId == null || _activeCheckoutRequestId!.isEmpty) {
      _activeCheckoutRequestId = generateUuidV4();
    }

    // Resolve exact configured delivery slot (mandatory)
    final resolvedSlot = (deliverySlot != null && deliverySlot.trim().isNotEmpty)
        ? deliverySlot.trim()
        : (_selectedDeliverySlot != null && _selectedDeliverySlot!.trim().isNotEmpty)
            ? _selectedDeliverySlot!.trim()
            : (deliverySlots.isEmpty ? 'Standard Delivery' : null);

    if (resolvedSlot == null || resolvedSlot.isEmpty) {
      return ApiResponse.error('Please select a delivery slot to proceed');
    }

    // Omit couponCode if no offer is applied
    final promoCode = (_appliedCoupon != null && _appliedCoupon!.trim().isNotEmpty)
        ? _appliedCoupon!.trim()
        : null;

    final response = await auth.createRazorpayOrder(
      requestId: _activeCheckoutRequestId!,
      addressId: addrId,
      deliverySlot: resolvedSlot,
      couponCode: promoCode,
      paymentMethod: paymentMethod,
    );

    return response;
  }

  /// Finalizes an online order after Razorpay Checkout completes successfully.
  /// Verifies payment with the backend (POST /consumer/payments/razorpay/verify),
  /// updates local state, clears cart, and records UserOrder.
  Future<UserOrder> completeOnlineOrder({
    required Map<String, dynamic> orderData,
    required String razorpayPaymentId,
    required String razorpayOrderId,
    required String razorpaySignature,
  }) async {
    final auth = AuthService();
    final fallbackAddr = activeDeliveryAddress ?? defaultAddress;

    // Snapshot cart items and pricing state before any async operations
    final cartItemsSnapshot = _cartItems.values.map((it) => it.toJson()).toList();
    final currentSubtotal = subtotal;
    final currentGrandTotal = grandTotal;

    final reqId = orderData['requestId']?.toString() ??
        _activeCheckoutRequestId ??
        generateUuidV4();

    final backendOrderId = orderData['orderId']?.toString() ??
        orderData['razorpayOrderId']?.toString() ??
        orderData['id']?.toString() ??
        orderData['displayId']?.toString() ??
        razorpayOrderId;

    // Reset requestId now that checkout was initiated/completed
    _activeCheckoutRequestId = null;

    // Fire verification to backend
    Map<String, dynamic>? verifiedOrderPayload;
    try {
      final verifyResp = await auth.verifyRazorpayPayment(
        requestId: reqId,
        razorpayOrderId: razorpayOrderId.isNotEmpty ? razorpayOrderId : backendOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );
      if (verifyResp.success && verifyResp.data != null && verifyResp.data!.isNotEmpty) {
        verifiedOrderPayload = verifyResp.data;
      }
    } catch (e) {
      debugPrint('Online payment verification error: $e');
    }

    final updatedJson = Map<String, dynamic>.from(orderData);
    if (verifiedOrderPayload != null) {
      updatedJson.addAll(verifiedOrderPayload);
    }
    updatedJson['paymentStatus'] = 'Paid';
    updatedJson['status'] = 'Confirmed';
    final origMethod = verifiedOrderPayload?['paymentMethod']?.toString() ??
        orderData['paymentMethod']?.toString() ??
        'Online';
    updatedJson['paymentMethod'] = origMethod == 'Wallet'
        ? 'PickleO Wallet + Online'
        : 'Razorpay Online';

    if (!updatedJson.containsKey('id') || updatedJson['id'] == null || updatedJson['id'].toString().isEmpty) {
      updatedJson['id'] = backendOrderId;
    }
    if (!updatedJson.containsKey('displayId') || updatedJson['displayId'] == null || updatedJson['displayId'].toString().isEmpty) {
      updatedJson['displayId'] = backendOrderId;
    }
    if (!updatedJson.containsKey('items') || updatedJson['items'] == null || (updatedJson['items'] is List && (updatedJson['items'] as List).isEmpty)) {
      updatedJson['items'] = cartItemsSnapshot;
    }
    double resolvedTotal;
    if (updatedJson.containsKey('total') && updatedJson['total'] != null) {
      resolvedTotal = (updatedJson['total'] as num).toDouble();
    } else if (orderData.containsKey('amount') && orderData['amount'] != null) {
      final amt = (orderData['amount'] as num).toDouble();
      if (orderData.containsKey('keyId') || orderData['currency'] == 'INR' || amt >= 10000) {
        resolvedTotal = amt / 100.0;
      } else {
        resolvedTotal = amt;
      }
    } else {
      resolvedTotal = currentGrandTotal;
    }
    updatedJson['total'] = resolvedTotal;
    updatedJson['amount'] = resolvedTotal;
    if (!updatedJson.containsKey('subtotal') || updatedJson['subtotal'] == null) {
      updatedJson['subtotal'] = currentSubtotal;
    }
    if (!updatedJson.containsKey('deliveryAddress') || updatedJson['deliveryAddress'] == null) {
      updatedJson['deliveryAddress'] = fallbackAddr.toJson();
    }
    if (!updatedJson.containsKey('deliverySlot') || updatedJson['deliverySlot'] == null) {
      updatedJson['deliverySlot'] = _selectedDeliverySlot ?? 'Standard Delivery';
    }

    final order = UserOrder.fromJson(
      updatedJson,
      fallbackAddress: fallbackAddr,
    );

    _activeOrder = order;
    _orders.removeWhere((o) => o.id == order.id);
    _orders.insert(0, order);

    // Refresh authoritative server balances for wallet and loyalty (pointsLot is pending until delivery)
    loadWalletFromApi();
    loadLoyaltyFromApi();

    // Clear local cart and cart pricing state
    _cartItems.clear();
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    _apiAppliedPromotion = null;
    _apiPriceBreakdown = null;
    _cartDeliveryInfo = null;
    _parsedDeliveryInfo = null;
    _selectedDeliverySlot = null;

    notifyListeners();
    return order;
  }

  /// Fetch the signed-in consumer's placed orders via GET /consumer/orders
  Future<ApiResponse<ConsumerOrderListResponse>> fetchOrders({
    bool forceRefresh = false,
    int limit = 20,
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('User not logged in', statusCode: 401);
    }

    if (_isLoadingOrders) {
      return ApiResponse.success(
        ConsumerOrderListResponse(
          items: List.from(_orders),
          nextToken: _ordersNextToken,
        ),
      );
    }

    if (_hasLoadedOrders && !forceRefresh && _orders.isNotEmpty) {
      return ApiResponse.success(
        ConsumerOrderListResponse(
          items: List.from(_orders),
          nextToken: _ordersNextToken,
        ),
      );
    }

    _isLoadingOrders = true;
    notifyListeners();

    try {
      final response = await auth.getOrders(limit: limit);
      if (response.success && response.data != null) {
        _orders.clear();
        _orders.addAll(response.data!.items);
        _ordersNextToken = response.data!.nextToken;
        _hasLoadedOrders = true;

        _enrichOrdersWithCatalogProducts();

        // Sync active live order if present
        final active = _orders.where((o) => o.isLiveActive).firstOrNull;
        if (active != null) {
          _activeOrder = active;
        } else if (_orders.isNotEmpty && _activeOrder == null) {
          _activeOrder = _orders.first;
        }
      }
      return response;
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  /// Load more orders with pagination token from previous response
  Future<ApiResponse<ConsumerOrderListResponse>> loadMoreOrders({
    int limit = 20,
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('User not logged in', statusCode: 401);
    }

    if (_isLoadingOrders ||
        _ordersNextToken == null ||
        _ordersNextToken!.isEmpty) {
      return ApiResponse.success(
        ConsumerOrderListResponse(
          items: List.from(_orders),
          nextToken: _ordersNextToken,
        ),
      );
    }

    _isLoadingOrders = true;
    notifyListeners();

    try {
      final response = await auth.getOrders(
        limit: limit,
        nextToken: _ordersNextToken,
      );
      if (response.success && response.data != null) {
        for (final newOrder in response.data!.items) {
          if (!_orders.any((o) => o.id == newOrder.id)) {
            _orders.add(newOrder);
          }
        }
        _ordersNextToken = response.data!.nextToken;
        _enrichOrdersWithCatalogProducts();
      }
      return response;
    } finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }

  /// Enrich orders with product images and details from available catalog
  void _enrichOrdersWithCatalogProducts() {
    final catalog = [
      ..._bestsellerProducts,
      ..._detailedProductsCache.values,
    ];
    if (catalog.isEmpty || _orders.isEmpty) return;

    for (int i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      bool changed = false;
      final newItems = <CartItem>[];

      for (final item in order.items) {
        if (!item.product.hasValidImage) {
          final prodId = item.product.id.toLowerCase().trim();
          final prodName = item.product.name.toLowerCase().trim();
          final match = catalog.where((p) {
            final pId = p.id.toLowerCase().trim();
            final pName = p.name.toLowerCase().trim();
            if (prodId.isNotEmpty &&
                (pId == prodId ||
                    pId == 'andhra-$prodId' ||
                    prodId.contains(pId) ||
                    pId.contains(prodId))) {
              return true;
            }
            if (prodName.isNotEmpty &&
                (pName == prodName ||
                    prodName.contains(pName) ||
                    pName.contains(prodName))) {
              return true;
            }
            return false;
          }).firstOrNull;

          if (match != null && match.hasValidImage) {
            final enriched = item.product.copyWith(
              imageUrl: match.imageUrl,
              imageAsset: match.imageAsset,
              imageKey: match.imageKey,
              mediaItems: match.mediaItems,
            );
            newItems.add(item.copyWith(product: enriched));
            changed = true;
            continue;
          }
        }
        newItems.add(item);
      }

      if (changed) {
        _orders[i] = order.copyWith(items: newItems);
        if (_activeOrder?.id == order.id ||
            (_activeOrder?.displayId.isNotEmpty == true &&
                _activeOrder?.displayId == order.displayId)) {
          _activeOrder = _orders[i];
        }
      }
    }
  }

  /// Fetch single order details via GET /consumer/orders/{orderId}
  /// Note: Pass the backend 'id' returned by order placement/history, or displayId fallback.
  Future<ApiResponse<UserOrder>> fetchOrderDetails(
    String orderId, {
    String? displayId,
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('User not logged in', statusCode: 401);
    }

    var response = await auth.getOrderDetails(orderId: orderId);
    if (!response.success &&
        displayId != null &&
        displayId.isNotEmpty &&
        displayId != orderId) {
      final fallbackResponse = await auth.getOrderDetails(orderId: displayId);
      if (fallbackResponse.success && fallbackResponse.data != null) {
        response = fallbackResponse;
      }
    }

    if (response.success && response.data != null) {
      var updated = response.data!;
      if (updated.addressId.isNotEmpty) {
        final matchingAddr =
            _addresses.where((a) => a.id == updated.addressId).firstOrNull;
        if (matchingAddr != null) {
          updated = updated.copyWith(deliveryAddress: matchingAddr);
        }
      }
      final idx = _orders.indexWhere((o) =>
          o.id == updated.id ||
          (updated.displayId.isNotEmpty && o.displayId == updated.displayId) ||
          (orderId.isNotEmpty && (o.id == orderId || o.displayId == orderId)));
      if (idx != -1) {
        _orders[idx] = updated;
      } else {
        _orders.insert(0, updated);
      }
      if (_activeOrder?.id == updated.id ||
          (updated.displayId.isNotEmpty &&
              _activeOrder?.displayId == updated.displayId) ||
          (orderId.isNotEmpty &&
              (_activeOrder?.id == orderId ||
                  _activeOrder?.displayId == orderId))) {
        _activeOrder = updated;
      }
      _enrichOrdersWithCatalogProducts();
      notifyListeners();
    }
    return response;
  }

  /// Refresh live delivery tracking snapshot from Pidge via POST /consumer/orders/{orderId}/tracking/refresh
  ///
  /// Spacing recommendation: At least 30 seconds apart, prevents overlapping requests.
  Future<ApiResponse<UserOrder>> refreshOrderTracking(
    String orderId, {
    bool force = false,
  }) async {
    final auth = AuthService();
    if (auth.authToken == null || auth.authToken!.isEmpty) {
      return ApiResponse.error('User not logged in', statusCode: 401);
    }

    // Per spec: "Use the order's id (64 lowercase hexadecimal characters), not its human-readable displayId, Pidge shipment ID or tracking code."
    String targetId = orderId.trim();
    final existingOrder = _orders.where((o) =>
        o.id == targetId || (targetId.isNotEmpty && o.displayId == targetId)).firstOrNull;
    if (existingOrder != null && existingOrder.id.isNotEmpty) {
      targetId = existingOrder.id;
    }

    // Prevent overlapping requests
    if (_refreshingTrackingOrderIds.contains(targetId)) {
      return ApiResponse.error(
        'Tracking refresh already in progress',
        statusCode: 429,
      );
    }

    // Client recommendation: space refreshes at least 30 seconds apart
    final lastRefresh = _lastTrackingRefreshTimes[targetId];
    if (!force && lastRefresh != null) {
      final diff = DateTime.now().difference(lastRefresh).inSeconds;
      if (diff < 30) {
        return ApiResponse.error(
          'Tracking was refreshed recently. Please wait ${30 - diff}s before refreshing again.',
          statusCode: 429,
        );
      }
    }

    _refreshingTrackingOrderIds.add(targetId);
    notifyListeners();

    try {
      final response = await auth.refreshOrderTracking(orderId: targetId);
      if (response.success && response.data != null) {
        _lastTrackingRefreshTimes[targetId] = DateTime.now();
        var updated = response.data!;
        if (updated.addressId.isNotEmpty) {
          final matchingAddr =
              _addresses.where((a) => a.id == updated.addressId).firstOrNull;
          if (matchingAddr != null) {
            updated = updated.copyWith(deliveryAddress: matchingAddr);
          }
        }
        final idx = _orders.indexWhere((o) =>
            o.id == updated.id ||
            (updated.displayId.isNotEmpty && o.displayId == updated.displayId) ||
            (targetId.isNotEmpty && (o.id == targetId || o.displayId == targetId)));
        if (idx != -1) {
          _orders[idx] = updated;
        } else {
          _orders.insert(0, updated);
        }
        if (_activeOrder?.id == updated.id ||
            (updated.displayId.isNotEmpty &&
                _activeOrder?.displayId == updated.displayId) ||
            (targetId.isNotEmpty &&
                (_activeOrder?.id == targetId ||
                    _activeOrder?.displayId == targetId))) {
          _activeOrder = updated;
        }
        _enrichOrdersWithCatalogProducts();
      }
      return response;
    } finally {
      _refreshingTrackingOrderIds.remove(targetId);
      notifyListeners();
    }
  }

  // Order Placement (Local/Offline)
  UserOrder placeOrder({
    required String paymentMethod,
    required String paymentMethodId,
    String? deliverySlot,
    List<String>? deliveryInstructions,
  }) {
    final orderId = 'PKL-${89400 + (DateTime.now().millisecond % 500)}';
    final pts = (grandTotal / 10).floor();
    final order = UserOrder(
      id: orderId,
      orderDate: DateTime.now(),
      dateDisplay: 'Placed Today, 4:15 PM',
      items: List.from(cartList),
      subtotal: subtotal,
      discount: couponDiscount,
      deliveryFee: deliveryFee,
      packagingFee: packagingFee,
      total: grandTotal,
      paymentMethod: paymentMethod,
      paymentMethodId: paymentMethodId,
      deliveryAddress: defaultAddress,
      status: 'Order Placed Successfully!',
      isLiveActive: true,
      orderStep: 0,
      isCancelled: false,
      spicePointsEarned: pts,
      deliverySlot: deliverySlot ?? 'Tomorrow, 2:00 PM – 4:00 PM',
      deliveryInstructions: deliveryInstructions ??
          (_deliveryInstructions.isNotEmpty
              ? _deliveryInstructions.toList()
              : const ['Call on arrival']),
    );

    _activeOrder = order;
    _orders.insert(0, order);
    _spicePoints += pts;
    clearCart();
    removeCoupon();
    notifyListeners();
    return order;
  }

  Future<ApiResponse<Map<String, dynamic>>> cancelOrder(
    String orderId, {
    String? reason,
  }) async {
    final effectiveReason = (reason != null && reason.trim().isNotEmpty)
        ? reason.trim()
        : 'Ordered by mistake';

    final resp = await AuthService().cancelOrder(
      orderId: orderId,
      reason: effectiveReason,
    );

    if (resp.success) {
      _applyOrderCancellationLocally(orderId, effectiveReason);
    } else {
      final msg = resp.message?.toLowerCase() ?? '';
      // If server returned 200 or message indicating it was already cancelled
      if (resp.statusCode == 200 ||
          (msg.contains('already') && msg.contains('cancel'))) {
        _applyOrderCancellationLocally(orderId, effectiveReason);
      } else if (msg.contains('network') || resp.statusCode == 0) {
        // Fallback for offline demo mode
        _applyOrderCancellationLocally(orderId, effectiveReason);
      }
    }
    return resp;
  }

  void _applyOrderCancellationLocally(String orderId, String reason) {
    if (_activeOrder != null &&
        (_activeOrder!.id == orderId || _activeOrder!.displayId == orderId)) {
      _activeOrder = _activeOrder!.copyWith(
        isCancelled: true,
        cancelReason: reason,
        status: 'Order Cancelled',
      );
      _spicePoints =
          (_spicePoints - _activeOrder!.spicePointsEarned).clamp(0, 999999);
    }
    final index = _orders
        .indexWhere((o) => o.id == orderId || o.displayId == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        isCancelled: true,
        cancelReason: reason,
        status: 'Order Cancelled',
      );
    }
    notifyListeners();
  }

  void setActiveOrder(UserOrder order) {
    _activeOrder = order;
    final idx = _orders.indexWhere((o) => o.id == order.id);
    if (idx != -1) {
      _orders[idx] = order;
    } else {
      _orders.insert(0, order);
    }
    notifyListeners();
  }

  void setOrderRating(String orderId, OrderRating rating) {
    final idx = _orders.indexWhere(
        (o) => o.id == orderId || o.displayId == orderId);
    if (idx != -1) {
      _orders[idx] = _orders[idx].copyWith(rating: rating);
    }
    if (_activeOrder != null &&
        (_activeOrder!.id == orderId || _activeOrder!.displayId == orderId)) {
      _activeOrder = _activeOrder!.copyWith(rating: rating);
    }
    notifyListeners();
  }

  /// Submit rating to server (POST /consumer/orders/{orderId}/rating)
  Future<ApiResponse<OrderRating>> rateOrder({
    required String orderId,
    required int rating,
    List<String> tags = const [],
    String? feedback,
    String? photoKey,
    List<int>? photoBytes,
    String photoContentType = 'image/jpeg',
  }) => submitRating(
    orderId: orderId,
    rating: rating,
    tags: tags,
    feedback: feedback,
    photoKey: photoKey,
    photoBytes: photoBytes,
    photoContentType: photoContentType,
  );

  /// Submit rating to server (POST /consumer/orders/{orderId}/rating)
  /// with optional photo upload (POST /consumer/orders/{orderId}/rating/photo-upload-url)
  Future<ApiResponse<OrderRating>> submitRating({
    required String orderId,
    required int rating,
    List<String> tags = const [],
    String? feedback,
    String? photoKey,
    List<int>? photoBytes,
    String photoContentType = 'image/jpeg',
  }) async {
    String? resolvedPhotoKey = photoKey;

    // If photo bytes provided, upload to presigned S3 url first
    if (photoBytes != null && photoBytes.isNotEmpty) {
      try {
        final uploadResp = await AuthService().getOrderRatingPhotoUploadUrl(
          orderId: orderId,
          contentType: photoContentType,
          contentLength: photoBytes.length,
        );

        if (uploadResp.success && uploadResp.data != null) {
          final uploadUrl = uploadResp.data!['uploadUrl']?.toString() ?? '';
          final key = uploadResp.data!['key']?.toString() ??
              uploadResp.data!['photoKey']?.toString();
          final signedHeaders = (uploadResp.data!['headers'] is Map)
              ? Map<String, String>.from(uploadResp.data!['headers'] as Map)
              : null;
          if (uploadUrl.isNotEmpty) {
            final s3Resp = await AuthService().uploadImageToPresignedUrl(
              uploadUrl: uploadUrl,
              imageBytes: photoBytes,
              contentType: photoContentType,
              extraHeaders: signedHeaders,
            );
            if (s3Resp.success && key != null && key.isNotEmpty) {
              resolvedPhotoKey = key;
            }
          }
        }
      } catch (e) {
        debugPrint('Error uploading rating photo: $e');
      }
    }

    final resp = await AuthService().submitOrderRating(
      orderId: orderId,
      rating: rating,
      tags: tags,
      feedback: feedback,
      photoKey: resolvedPhotoKey,
    );

    if (resp.success && resp.data != null) {
      setOrderRating(orderId, resp.data!);
      if (resp.statusCode == 201) {
        final pointsToAdd =
            resp.data!.rewardPoints > 0 ? resp.data!.rewardPoints : 50;
        addSpicePoints(pointsToAdd);
      }
      loadLoyaltyFromApi();
    } else {
      // Local fallback for offline/preview
      final fallbackRating = OrderRating(
        orderId: orderId,
        rating: rating,
        tags: tags,
        feedback: feedback,
        photoKey: resolvedPhotoKey,
        rewardPoints: 50,
        createdAt: DateTime.now(),
      );
      setOrderRating(orderId, fallbackRating);
      addSpicePoints(50);
    }

    notifyListeners();
    return resp;
  }

  Future<void> deleteAccountPermanently() async {
    _cartItems.clear();
    _orders.clear();
    _activeOrder = null;
    _wishlist.clear();
    _wishlistProducts.clear();
    _addresses.clear();
    _hasLoadedWishlist = false;
    _hasLoadedAddresses = false;
    _walletBalance = 0.0;
    _spicePoints = 0;
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    _isLoggedIn = false;
    _userId = '';
    _userName = '';
    _phoneNumber = '';
    _userEmail = '';
    _localAvatarBytes = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    AuthService().logout();
    notifyListeners();
  }

  Future<void> reorder(UserOrder order) async {
    for (final item in order.items) {
      await addToCart(item.product, item.selectedWeight, qty: item.quantity);
    }
  }

  // Sync internal state with UserProfile from server
  void _syncWithProfile(UserProfile profile) {
    _userId = profile.userId;
    _phoneNumber = profile.phone;
    _userName = profile.fullName;
    _userEmail = profile.email;
    _dob = profile.dateOfBirth;
    _gender = profile.gender;
    _spiceTolerance = profile.spiceTolerance;
    _isVegetarianOnly = profile.vegetarianOnly;
    _excludeGarlic = profile.excludeGarlic;
    _preferredRegions.clear();
    _preferredRegions.addAll(profile.preferredRegionalStyles);
    _avatarKey = profile.avatarKey;
    _avatarUrl = profile.avatarUrl;
    _spicePoints = profile.spicePoints;
    _walletBalance = profile.walletBalance;
    _isLoggedIn = true;
  }

  // Restore stored session and fetch live profile if available
  Future<void> initSession() async {
    AuthService().onSessionExpired = () {
      logout();
    };

    // 1. Immediately restore cached data from SharedPreferences to make UI instant
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedToken = prefs.getString('auth_token');
      final bool hasToken =
          storedToken != null && storedToken.trim().isNotEmpty;

      if (hasToken) {
        _isLoggedIn = true;

        // Restore avatar
        final savedAvatar = prefs.getString('user_avatar_base64');
        if (savedAvatar != null && savedAvatar.isNotEmpty) {
          _localAvatarBytes = base64Decode(savedAvatar);
        }

        // Restore cached user profile
        final profileStr = prefs.getString('user_profile');
        if (profileStr != null && profileStr.isNotEmpty) {
          try {
            final profile = UserProfile.fromJson(jsonDecode(profileStr));
            _syncWithProfile(profile);
          } catch (_) {}
        }

        // Restore cached addresses immediately
        final addressesStr = prefs.getString('user_addresses');
        if (addressesStr != null && addressesStr.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(addressesStr);
            final cachedAddresses = decoded
                .whereType<Map<String, dynamic>>()
                .map((m) => DeliveryAddress.fromJson(m))
                .toList();
            if (cachedAddresses.isNotEmpty) {
              _addresses.clear();
              _addresses.addAll(cachedAddresses);
            }
          } catch (_) {}
        }
      } else if (!_isLoggedIn) {
        // No stored auth token and not logged in -> Guest state
        _userId = '';
        _userName = '';
        _phoneNumber = '';
        _userEmail = '';
        _dob = '';
        _walletBalance = 0.0;
        _spicePoints = 0;
        _localAvatarBytes = null;
        _avatarKey = null;
        _avatarUrl = null;
        _addresses.clear();
        _wishlist.clear();
        _wishlistProducts.clear();
        _cartItems.clear();
        _appliedCoupon = null;
        _couponDiscount = 0.0;
      }

      // Restore cached banners immediately if URLs are still valid
      final bannersStr = prefs.getString('home_banners');
      if (bannersStr != null && bannersStr.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(bannersStr);
          final cached = decoded
              .whereType<Map<String, dynamic>>()
              .map((m) => HomeBanner.fromJson(m))
              .toList();
          final processed = HomeBanner.processBanners(cached);
          final hasExpired =
              processed.any((b) => HomeBanner.isUrlExpired(b.mediaUrl));
          if (processed.isNotEmpty && !hasExpired) {
            _banners.clear();
            _banners.addAll(processed);
          } else {
            prefs.remove('home_banners');
          }
        } catch (_) {}
      }

      // Restore cached categories if available
      final cachedCategoriesJson = prefs.getString('cached_categories');
      if (cachedCategoriesJson != null) {
        try {
          final decoded = jsonDecode(cachedCategoriesJson);
          if (decoded is List) {
            final cached = decoded
                .whereType<Map<String, dynamic>>()
                .map((m) => CategoryItem.fromJson(m))
                .toList();
            if (cached.isNotEmpty) {
              _categories.clear();
              _categories.addAll(cached);
              _hasLoadedCategories = true;
            }
          }
        } catch (_) {}
      }

      // Restore cached product regions if available
      final cachedRegionsJson = prefs.getString('cached_product_regions');
      if (cachedRegionsJson != null) {
        try {
          final decoded = jsonDecode(cachedRegionsJson);
          if (decoded is List) {
            final cached = decoded
                .whereType<Map<String, dynamic>>()
                .map((m) => ProductRegion.fromJson(m))
                .toList();
            if (cached.isNotEmpty) {
              _productRegions.clear();
              _productRegions.addAll(cached);
              _hasLoadedProductRegions = true;
            }
          }
        } catch (_) {}
      }

      // Restore cached product tags if available
      final cachedTagsJson = prefs.getString('cached_product_tags');
      if (cachedTagsJson != null) {
        try {
          final decoded = jsonDecode(cachedTagsJson);
          if (decoded is List) {
            final cached = decoded
                .whereType<Map<String, dynamic>>()
                .map((m) => ProductTag.fromJson(m))
                .toList();
            if (cached.isNotEmpty) {
              _productTags.clear();
              _productTags.addAll(cached);
              _hasLoadedProductTags = true;
            }
          }
        } catch (_) {}
      }

      // Restore cached offers if available
      final cachedOffersJson = prefs.getString('cached_offers');
      if (cachedOffersJson != null) {
        try {
          final decoded = jsonDecode(cachedOffersJson);
          if (decoded is List) {
            final cached = decoded
                .whereType<Map<String, dynamic>>()
                .map((m) => OfferItem.fromJson(m))
                .where((o) => o.isActive)
                .toList();
            if (cached.isNotEmpty) {
              _offers.clear();
              _offers.addAll(cached);
              _hasLoadedOffers = true;
              _coupons.clear();
              for (final offer in _offers) {
                _coupons.add(offer.toCouponOffer());
              }
            }
          }
        } catch (_) {}
      }

      // Restore recent searches based on user typings
      final savedRecent = prefs.getStringList('pickleo_recent_searches');
      if (savedRecent != null && savedRecent.isNotEmpty) {
        _recentSearches.clear();
        _recentSearches.addAll(savedRecent);
      }

      // Restore cached cart items
      await _loadCartFromCache();

      notifyListeners();

      // Fetch fresh banners, categories, product regions, product tags, and offers from server
      fetchBanners(forceRefresh: true);
      fetchCategories();
      fetchProductRegions();
      fetchProductTags();
      fetchOffers();
    } catch (_) {}

    // 2. Initialize token in AuthService and sync with live server
    final token = await AuthService().initToken();
    if (token != null && token.isNotEmpty) {
      _isLoggedIn = true;
      if (AuthService().cachedProfile != null) {
        _syncWithProfile(AuthService().cachedProfile!);
      }
      notifyListeners();

      // Fetch live data from backend in background
      loadProfileFromApi();
      loadAddressesFromApi();
      loadCartFromApi();
      loadWishlistFromApi();
      fetchOrders();
      fetchCategories(forceRefresh: true);
      fetchProductRegions(forceRefresh: true);
      fetchProductTags(forceRefresh: true);
    }
  }

  // Auth Actions
  void login(String phone) {
    _phoneNumber = phone.startsWith('+91') ? phone : '+91 $phone';
    _isLoggedIn = true;
    fetchCategories(forceRefresh: true);
    fetchProductRegions(forceRefresh: true);
    fetchProductTags(forceRefresh: true);
    notifyListeners();
  }

  // Profile Loading States
  bool _isLoadingProfile = false;
  bool get isLoadingProfile => _isLoadingProfile;
  bool _isUpdatingProfile = false;
  bool get isUpdatingProfile => _isUpdatingProfile;

  /// Direct API Login using AuthService verify OTP
  Future<ApiResponse<UserProfile>> loginWithOtp({
    required String phone,
    required String otp,
    String? fullName,
    String? referralCode,
    String? referralMedium,
  }) async {
    final pushCreds = await NotificationService.instance.getPushCredentials();
    final response = await AuthService().verifyOtp(
      phone: phone,
      otp: otp,
      fullName: fullName,
      referralCode: referralCode,
      referralMedium: referralMedium,
      fcmToken: pushCreds?['fcmToken'],
      deviceId: pushCreds?['deviceId'],
      platform: pushCreds?['platform'],
    );
    if (response.success && response.data != null) {
      _syncWithProfile(response.data!);

      // If attribution returned an accepted referral coupon, preselect it in cart/checkout
      if (response.referralAttribution?.accepted == true &&
          response.referralAttribution?.couponCode != null &&
          response.referralAttribution!.couponCode!.isNotEmpty) {
        _appliedCoupon = response.referralAttribution!.couponCode!;
        _couponDiscount = response.referralAttribution!.discountRs ?? 100.0;
      }

      await loadAddressesFromApi();
      await fetchCategories(forceRefresh: true);
      await fetchProductRegions(forceRefresh: true);
      await fetchProductTags(forceRefresh: true);
      await syncAllCartItemsToApi();
      await loadCartFromApi();
      await loadWishlistFromApi();
      await fetchOrders(forceRefresh: true);
      await loadWalletFromApi();
      notifyListeners();
    } else {
      // Local fallback for seamless prototype testing
      login(phone);
    }
    return response;
  }

  /// Fetch Wallet balance & ledger from GET /consumer/wallet
  Future<void> loadWalletFromApi() async {
    try {
      final res = await AuthService().getConsumerWallet();
      if (res.success && res.data != null) {
        _walletBalance = res.data!.balance;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Fetch loyalty account & tier details from GET /consumer/loyalty/account and /tiers
  Future<void> loadLoyaltyFromApi({bool notify = true}) async {
    try {
      final accountRes = await AuthService().getLoyaltyAccount();
      if (accountRes.success && accountRes.data != null) {
        _loyaltyAccount = accountRes.data;
        _spicePoints = accountRes.data!.balance;
      }
      final tiersRes = await AuthService().getLoyaltyTiers();
      if (tiersRes.success && tiersRes.data != null) {
        _loyaltyTiers = tiersRes.data!.items;
      }
      if (notify) {
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Redeem Spice Points in whole 400-point blocks: POST /consumer/loyalty/redeem
  ///
  /// Each 400 points debited credits ₹40 into PickleO Wallet.
  Future<ApiResponse<LoyaltyRedeemResult>> redeemLoyaltyBlocks(int blocks) async {
    final requestId = generateUuidV4();
    final res = await AuthService().redeemSpicePoints(
      blocks: blocks,
      requestId: requestId,
    );
    if (res.success && res.data != null) {
      _spicePoints = res.data!.balance;
      _walletBalance = res.data!.walletBalance;
      await loadLoyaltyFromApi(notify: false);
      await loadWalletFromApi();
      notifyListeners();
    }
    return res;
  }


  /// Fetch User Profile via GET /consumer/profile
  Future<ApiResponse<UserProfile>> loadProfileFromApi() async {
    _isLoadingProfile = true;
    notifyListeners();
    try {
      final response = await AuthService().getProfile();
      if (response.success && response.data != null) {
        _syncWithProfile(response.data!);
      }
      return response;
    } finally {
      _isLoadingProfile = false;
      notifyListeners();
    }
  }

  /// Asynchronous profile update via backend API (PATCH /consumer/profile)
  Future<ApiResponse<UserProfile>> updateProfileViaApi({
    String? fullName,
    String? name,
    String? email,
    String? dateOfBirth,
    String? dob,
    String? gender,
    String? spiceTolerance,
    List<String>? preferredRegionalStyles,
    bool? vegetarianOnly,
    bool? isVegetarianOnly,
    bool? excludeGarlic,
    String? avatarKey,
  }) async {
    final effectiveName = fullName ?? name ?? _userName;
    final effectiveEmail = email ?? _userEmail;
    final effectiveDob = dateOfBirth ?? dob ?? _dob;
    final effectiveGender = gender ?? _gender;
    final effectiveSpice = spiceTolerance ?? _spiceTolerance;
    final effectiveRegions =
        preferredRegionalStyles ?? _preferredRegions.toList();
    final effectiveVeg =
        vegetarianOnly ?? isVegetarianOnly ?? _isVegetarianOnly;
    final effectiveGarlic = excludeGarlic ?? _excludeGarlic;
    final effectiveAvatarKey = avatarKey ?? _avatarKey;

    _isUpdatingProfile = true;
    notifyListeners();
    try {
      if (AuthService().authToken != null) {
        final response = await AuthService().updateProfile(
          fullName: effectiveName,
          email: effectiveEmail,
          dateOfBirth: effectiveDob,
          gender: effectiveGender,
          spiceTolerance: effectiveSpice,
          preferredRegionalStyles: effectiveRegions,
          vegetarianOnly: effectiveVeg,
          excludeGarlic: effectiveGarlic,
          avatarKey: effectiveAvatarKey,
        );
        if (response.success && response.data != null) {
          _syncWithProfile(response.data!);
        }
        return response;
      } else {
        _userName = effectiveName;
        _userEmail = effectiveEmail;
        _dob = effectiveDob;
        _gender = effectiveGender;
        _spiceTolerance = effectiveSpice;
        _preferredRegions.clear();
        _preferredRegions.addAll(effectiveRegions);
        _isVegetarianOnly = effectiveVeg;
        _excludeGarlic = effectiveGarlic;
        _avatarKey = effectiveAvatarKey;
        return ApiResponse.success(
          UserProfile(
            userId: _userId,
            phone: _phoneNumber,
            fullName: _userName,
            email: _userEmail,
            dateOfBirth: _dob,
            gender: _gender,
            spiceTolerance: _spiceTolerance,
            preferredRegionalStyles: _preferredRegions.toList(),
            vegetarianOnly: _isVegetarianOnly,
            excludeGarlic: _excludeGarlic,
            avatarKey: _avatarKey,
            avatarUrl: _avatarUrl,
            spicePoints: _spicePoints,
            walletBalance: _walletBalance,
          ),
          message: 'Profile updated locally',
        );
      }
    } finally {
      _isUpdatingProfile = false;
      notifyListeners();
    }
  }

  /// Upload user avatar via S3 presigned URL
  Future<ApiResponse<Map<String, dynamic>>> uploadAvatar(
    List<int> imageBytes, {
    String contentType = 'image/jpeg',
  }) async {
    final urlResp =
        await AuthService().getAvatarUploadUrl(contentType: contentType);
    if (!urlResp.success || urlResp.data == null) {
      return ApiResponse.error(urlResp.message ?? 'Failed to get upload URL');
    }

    final uploadUrl = urlResp.data!['uploadUrl']?.toString() ?? '';
    final key = urlResp.data!['key']?.toString();

    if (uploadUrl.isEmpty) {
      return ApiResponse.error('Invalid upload URL');
    }

    final uploadResp = await AuthService().uploadImageToPresignedUrl(
      uploadUrl: uploadUrl,
      imageBytes: imageBytes,
      contentType: contentType,
    );

    if (uploadResp.success) {
      // Store avatar bytes locally so photo renders immediately and persists across app restarts
      _localAvatarBytes = Uint8List.fromList(imageBytes);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar_base64', base64Encode(imageBytes));
      } catch (_) {}

      if (key != null) {
        _avatarKey = key;
        await AuthService().updateProfile(avatarKey: key);
      }
      await loadProfileFromApi();
      notifyListeners();
      return ApiResponse.success({
        'key': key,
        'uploadUrl': uploadUrl,
      }, message: 'Profile photo updated successfully');
    } else {
      return ApiResponse.error(uploadResp.message ?? 'Failed to upload image');
    }
  }

  void logout() {
    _isLoggedIn = false;
    _userId = '';
    _userName = '';
    _phoneNumber = '';
    _userEmail = '';
    _dob = '';
    _gender = 'Female';
    _spiceTolerance = 'Medium';
    _isVegetarianOnly = false;
    _excludeGarlic = false;
    _preferredRegions.clear();
    _avatarKey = null;
    _avatarUrl = null;
    _localAvatarBytes = null;
    try {
      SharedPreferences.getInstance().then((p) {
        p.remove('user_avatar_base64');
        p.remove('user_addresses');
      });
    } catch (_) {}
    _walletBalance = 0.0;
    _spicePoints = 0;
    _addresses.clear();
    _cartItems.clear();
    _wishlist.clear();
    _wishlistProducts.clear();
    _hasLoadedWishlist = false;
    _hasLoadedAddresses = false;
    _orders.clear();
    _ordersNextToken = null;
    _hasLoadedOrders = false;
    _activeOrder = null;
    _appliedCoupon = null;
    _couponDiscount = 0.0;
    AuthService().logout();
    notifyListeners();
  }
}

class AppStateProvider extends InheritedNotifier<AppState> {
  const AppStateProvider({
    super.key,
    required AppState appState,
    required super.child,
  }) : super(notifier: appState);

  static AppState of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppStateProvider>();
    assert(provider != null, 'No AppStateProvider found in context');
    return provider!.notifier!;
  }
}

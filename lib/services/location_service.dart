import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/order.dart';

class NearestSavedAddressResult {
  final DeliveryAddress address;
  final double distanceMeters;

  NearestSavedAddressResult({
    required this.address,
    required this.distanceMeters,
  });
}

class GeoAddress {
  final double latitude;
  final double longitude;
  final String street;
  final String locality;
  final String city;
  final String state;
  final String postalCode;
  final String formattedAddress;

  GeoAddress({
    required this.latitude,
    required this.longitude,
    required this.street,
    required this.locality,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.formattedAddress,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Google Maps Platform API Key
  static const String googleApiKey =
      'AIzaSyBvzv4a8LD36X5U1ZSiA3J1FD8R_R3jwFg';

  /// Serviceable PIN codes regex matching the PickleO prototype
  /// Serviceable regions: 11, 12, 20, 30, 38, 40, 41, 50, 52, 53, 56, 57, 60, 62, 68, 69, 70
  static final RegExp serviceablePinRegex = RegExp(
    r'^(11|12|20|30|38|40|41|50|52|53|56|57|60|62|68|69|70)\d{4}$',
  );

  /// Validates whether a given PIN code is serviceable for dispatch
  static bool isServiceablePin(String? pin) {
    if (pin == null) return false;
    final clean = pin.trim().replaceAll(RegExp(r'\D'), '');
    return serviceablePinRegex.hasMatch(clean);
  }

  /// Finds nearest saved address within [thresholdMeters] (defaults to 1000m / 1 km).
  /// If multiple addresses are within the threshold, returns the closest one.
  /// Returns null if no address is within [thresholdMeters].
  NearestSavedAddressResult? findNearestSavedAddress({
    required double currentLatitude,
    required double currentLongitude,
    required List<DeliveryAddress> addresses,
    double thresholdMeters = 1000.0,
  }) {
    NearestSavedAddressResult? nearest;

    for (final addr in addresses) {
      if (addr.latitude != null && addr.longitude != null) {
        final distance = Geolocator.distanceBetween(
          currentLatitude,
          currentLongitude,
          addr.latitude!,
          addr.longitude!,
        );

        if (distance < thresholdMeters) {
          if (nearest == null || distance < nearest.distanceMeters) {
            nearest = NearestSavedAddressResult(
              address: addr,
              distanceMeters: distance,
            );
          }
        }
      }
    }

    return nearest;
  }

  /// Request device permission and fetch real GPS location
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever.');
        return null;
      }

      // Try high accuracy first
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
        return position;
      } catch (_) {
        // Fallback to last known position or medium accuracy
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) return lastKnown;

        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  static bool _isInvalidAreaName(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.isEmpty) return true;
    const forbidden = {
      'asia',
      'india',
      'europe',
      'africa',
      'north america',
      'south america',
      'antarctica',
      'australia',
      'oceania',
      'indian subcontinent',
      'mainland india',
      'southern zonal council',
      'south central railway',
      'selected location',
      'asia/kolkata',
    };
    if (forbidden.contains(lower)) return true;
    if (lower.contains('continent') ||
        lower.contains('time zone') ||
        lower.contains('timezone') ||
        lower.contains('zonal council') ||
        lower.contains('railway') ||
        lower.contains('/')) {
      return true;
    }
    // Filter numeric postal codes like 522600
    if (RegExp(r'^\d{5,6}$').hasMatch(lower)) return true;
    return false;
  }

  /// Sanitizes address line by removing continent/country prefixes and forbidden tokens
  static String cleanAddressLine(String text) {
    if (text.trim().isEmpty) return '';
    var cleaned = text.trim();

    // 1. Remove prefixes like "Asia / Kolkata, ", "Asia, ", "India, ", "Asia - "
    final leadingPrefixes = [
      RegExp(r'^(asia\s*/\s*[a-z_]+)\s*[,/–-]?\s*', caseSensitive: false),
      RegExp(r'^(asia|india|indian subcontinent)\s*[,/–-]\s*', caseSensitive: false),
      RegExp(r'^(asia|india|indian subcontinent)\s+', caseSensitive: false),
    ];
    for (final p in leadingPrefixes) {
      cleaned = cleaned.replaceAll(p, '').trim();
    }

    // 2. Split by comma and filter out forbidden/empty/postal tokens
    final rawParts = cleaned.split(',').map((s) => s.trim()).toList();
    final validParts = <String>[];
    for (final part in rawParts) {
      if (part.isNotEmpty &&
          !_isInvalidAreaName(part) &&
          !RegExp(r'^\d{5,6}$').hasMatch(part)) {
        if (!validParts.any((v) => v.toLowerCase() == part.toLowerCase())) {
          validParts.add(part);
        }
      }
    }

    return validParts.join(', ');
  }

  /// Reverse geocode coordinates to street (full Address Line 1), locality, city, state and postalCode.
  /// Tier 1: Google Geocoding API (if enabled with billing)
  /// Tier 2: OpenStreetMap Nominatim (High-precision street, suburb & residential)
  /// Tier 3: BigDataCloud Reverse Geocoding (with continent/country filtering)
  Future<GeoAddress?> reverseGeocode(double latitude, double longitude) async {
    // 1. Primary: Google Geocoding API
    try {
      final googleUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$latitude,$longitude&key=$googleApiKey',
      );
      final response =
          await http.get(googleUrl).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' &&
            data['results'] is List &&
            (data['results'] as List).isNotEmpty) {
          final results = data['results'] as List;
          final bestResult = results[0] as Map<String, dynamic>;
          final formatted = bestResult['formatted_address']?.toString() ?? '';

          String streetNumber = '';
          String premise = '';
          String subpremise = '';
          String route = '';
          String neighborhood = '';
          String sublocality3 = '';
          String sublocality2 = '';
          String sublocality1 = '';
          String sublocality = '';
          String locality = '';
          String adminArea = '';
          String postalCode = '';

          final components =
              bestResult['address_components'] as List<dynamic>? ?? [];
          for (final comp in components) {
            final types = (comp['types'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];
            final longName = comp['long_name']?.toString() ?? '';

            if (types.contains('street_number')) streetNumber = longName;
            if (types.contains('premise')) premise = longName;
            if (types.contains('subpremise')) subpremise = longName;
            if (types.contains('route')) route = longName;
            if (types.contains('neighborhood')) neighborhood = longName;
            if (types.contains('sublocality_level_3')) sublocality3 = longName;
            if (types.contains('sublocality_level_2')) sublocality2 = longName;
            if (types.contains('sublocality_level_1')) sublocality1 = longName;
            if (types.contains('sublocality')) sublocality = longName;
            if (types.contains('locality')) locality = longName;
            if (types.contains('administrative_area_level_1')) {
              adminArea = longName;
            }
            if (types.contains('postal_code')) postalCode = longName;
          }

          final candidates = [
            if (subpremise.isNotEmpty) subpremise,
            if (premise.isNotEmpty && premise != subpremise) premise,
            if (streetNumber.isNotEmpty) streetNumber,
            if (route.isNotEmpty) route,
            if (sublocality3.isNotEmpty) sublocality3,
            if (sublocality2.isNotEmpty) sublocality2,
            if (sublocality1.isNotEmpty) sublocality1,
            if (sublocality.isNotEmpty) sublocality,
            if (neighborhood.isNotEmpty) neighborhood,
          ];

          final streetParts = <String>[];
          for (final c in candidates) {
            final cleaned = cleanAddressLine(c);
            if (cleaned.isNotEmpty &&
                !_isInvalidAreaName(cleaned) &&
                cleaned.toLowerCase() != locality.toLowerCase() &&
                cleaned.toLowerCase() != adminArea.toLowerCase() &&
                !streetParts.any((p) => p.toLowerCase() == cleaned.toLowerCase())) {
              streetParts.add(cleaned);
            }
          }

          // If candidates are empty, extract detailed leading segments from formatted_address
          if (streetParts.isEmpty && formatted.isNotEmpty) {
            final segments = formatted.split(',').map((s) => s.trim()).toList();
            for (final seg in segments) {
              if (seg.isEmpty) continue;
              final segLower = seg.toLowerCase();
              if (_isInvalidAreaName(seg)) continue;
              if (segLower == locality.toLowerCase() ||
                  segLower == adminArea.toLowerCase() ||
                  segLower == 'india' ||
                  RegExp(r'^\d{5,6}$').hasMatch(seg)) {
                break;
              }
              if (!streetParts.any((p) => p.toLowerCase() == segLower)) {
                streetParts.add(seg);
              }
            }
          }

          final rawStreet = streetParts.isNotEmpty
              ? streetParts.join(', ')
              : (sublocality1.isNotEmpty
                  ? sublocality1
                  : (sublocality.isNotEmpty ? sublocality : formatted.split(',').first.trim()));

          final street = cleanAddressLine(rawStreet);
          final city = locality.isNotEmpty
              ? locality
              : (sublocality.isNotEmpty ? sublocality : adminArea);

          return GeoAddress(
            latitude: latitude,
            longitude: longitude,
            street: street.isNotEmpty ? street : city,
            locality: sublocality1.isNotEmpty
                ? sublocality1
                : (sublocality.isNotEmpty ? sublocality : locality),
            city: city,
            state: adminArea,
            postalCode: postalCode,
            formattedAddress: formatted,
          );
        }
      }
    } catch (_) {}

    // 2. High-precision Secondary: OpenStreetMap Nominatim
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?lat=$latitude&lon=$longitude&format=jsonv2&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'PickleoGrocery/1.0 (support@pickleo.com)'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final houseNumber = (address['house_number'] ??
                  address['house_name'] ??
                  address['building'] ??
                  address['amenity'] ??
                  address['shop'] ??
                  '')
              .toString()
              .trim();
          final road = (address['road'] ??
                  address['street'] ??
                  address['pedestrian'] ??
                  address['footway'] ??
                  address['path'] ??
                  '')
              .toString()
              .trim();
          final neighbourhood =
              (address['neighbourhood'] ?? '').toString().trim();
          final suburb = (address['suburb'] ?? '').toString().trim();
          final residential =
              (address['residential'] ?? '').toString().trim();
          final subdistrict = (address['subdistrict'] ??
                  address['quarter'] ??
                  address['hamlet'] ??
                  '')
              .toString()
              .trim();
          final city = (address['city'] ??
                  address['town'] ??
                  address['village'] ??
                  address['municipality'] ??
                  address['county'] ??
                  address['state_district'] ??
                  '')
              .toString()
              .trim();
          final state = (address['state'] ?? '').toString().trim();
          final postCode = (address['postcode'] ?? '').toString().trim();

          // Construct candidate components in order of granularity for Address Line 1
          final candidates = [
            if (houseNumber.isNotEmpty) houseNumber,
            if (road.isNotEmpty) road,
            if (neighbourhood.isNotEmpty) neighbourhood,
            if (suburb.isNotEmpty) suburb,
            if (residential.isNotEmpty) residential,
            if (subdistrict.isNotEmpty && subdistrict != city) subdistrict,
          ];

          final streetParts = <String>[];
          for (final c in candidates) {
            final cleaned = cleanAddressLine(c);
            if (cleaned.isNotEmpty &&
                !_isInvalidAreaName(cleaned) &&
                cleaned.toLowerCase() != city.toLowerCase() &&
                cleaned.toLowerCase() != state.toLowerCase() &&
                !streetParts.any((p) => p.toLowerCase() == cleaned.toLowerCase())) {
              streetParts.add(cleaned);
            }
          }

          // Also extract prominent locality/subdistrict segments from display_name if not already present
          final displayName = (data['display_name'] ?? '').toString();
          if (displayName.isNotEmpty) {
            final segments =
                displayName.split(',').map((s) => s.trim()).toList();
            for (final seg in segments) {
              if (seg.isEmpty) continue;
              final segLower = seg.toLowerCase();
              if (_isInvalidAreaName(seg)) continue;
              if (segLower.contains('corporation') ||
                  segLower.contains('municipal') ||
                  segLower.contains('zone') ||
                  segLower.contains('mandal') ||
                  segLower.contains('district') ||
                  segLower.contains('ward') ||
                  segLower == city.toLowerCase() ||
                  segLower == state.toLowerCase() ||
                  segLower == 'india' ||
                  RegExp(r'^\d{5,6}$').hasMatch(seg)) {
                continue;
              }
              if (!streetParts.any((p) => p.toLowerCase() == segLower)) {
                streetParts.add(seg);
              }
            }
          }

          final rawStreet = streetParts.isNotEmpty
              ? streetParts.join(', ')
              : (suburb.isNotEmpty && !_isInvalidAreaName(suburb)
                  ? suburb
                  : (residential.isNotEmpty && !_isInvalidAreaName(residential)
                      ? residential
                      : (city.isNotEmpty ? city : 'Selected Location')));

          final street = cleanAddressLine(rawStreet);

          return GeoAddress(
            latitude: latitude,
            longitude: longitude,
            street: street.isNotEmpty ? street : city,
            locality: streetParts.isNotEmpty
                ? streetParts.last
                : (suburb.isNotEmpty ? suburb : city),
            city: city,
            state: state,
            postalCode: postCode,
            formattedAddress: displayName.isNotEmpty
                ? displayName
                : (city.isNotEmpty ? '$street, $city' : street),
          );
        }
      }
    } catch (_) {}

    // 3. Tertiary Fallback: BigDataCloud Reverse Geocoding
    try {
      final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$latitude&longitude=$longitude&localityLanguage=en',
      );
      final response =
          await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final city = (data['city'] ??
                data['locality'] ??
                data['principalSubdivision'] ??
                '')
            .toString()
            .trim();
        final state = (data['principalSubdivision'] ?? '').toString().trim();
        final postalCode = (data['postcode'] ?? '').toString().trim();

        final streetParts = <String>[];
        final localityInfo = data['localityInfo'];
        if (localityInfo is Map) {
          final items = [
            if (localityInfo['informative'] is List)
              ...(localityInfo['informative'] as List),
            if (localityInfo['administrative'] is List)
              ...(localityInfo['administrative'] as List),
          ];

          for (final item in items) {
            if (item is Map) {
              final order = item['order'] as int? ?? 0;
              final name = (item['name'] ?? '').toString().trim();
              final desc = (item['description'] ?? '').toString().toLowerCase();

              // Strictly skip continent, country, timezone, railway, council, region
              if (order < 8 ||
                  desc.contains('continent') ||
                  desc.contains('time zone') ||
                  desc.contains('country') ||
                  desc.contains('railway') ||
                  desc.contains('council') ||
                  desc.contains('region')) {
                continue;
              }

              if (order >= 10 &&
                  !_isInvalidAreaName(name) &&
                  name.toLowerCase() != city.toLowerCase() &&
                  name.toLowerCase() != state.toLowerCase() &&
                  !streetParts.any((p) => p.toLowerCase() == name.toLowerCase())) {
                streetParts.add(name);
              }
            }
          }
        }

        final rawStreet = streetParts.isNotEmpty
            ? streetParts.join(', ')
            : (city.isNotEmpty ? city : 'Selected Location');

        final street = cleanAddressLine(rawStreet);

        return GeoAddress(
          latitude: latitude,
          longitude: longitude,
          street: street.isNotEmpty ? street : city,
          locality: streetParts.isNotEmpty ? streetParts.first : city,
          city: city,
          state: state,
          postalCode: postalCode,
          formattedAddress: city.isNotEmpty && street != city
              ? '$street, $city'
              : street,
        );
      }
    } catch (_) {}

    return null;
  }

  /// Search places by keyword query.
  /// Tier 1: Google Places API (New) - places:searchText
  /// Tier 2: Google Places API (Legacy) - place/textsearch/json
  /// Tier 3: Photon Fast OpenStreetMap Search Engine (Compound keywords & typo-tolerant)
  /// Tier 4: OpenStreetMap Nominatim Search
  Future<List<Map<String, dynamic>>> searchPlaces(
    String query, {
    double? lat,
    double? lon,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // 1. Google Places API (New) - Search Text
    try {
      final googleNewPlacesUrl =
          Uri.parse('https://places.googleapis.com/v1/places:searchText');
      final bodyMap = <String, dynamic>{
        'textQuery': cleanQuery,
        'languageCode': 'en',
        'regionCode': 'IN',
        if (lat != null && lon != null)
          'locationBias': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lon},
              'radius': 50000.0,
            },
          },
      };

      final response = await http.post(
        googleNewPlacesUrl,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googleApiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.addressComponents',
        },
        body: jsonEncode(bodyMap),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>? ?? [];
        if (places.isNotEmpty) {
          final results = <Map<String, dynamic>>[];
          for (final p in places) {
            if (p is! Map<String, dynamic>) continue;
            final loc = p['location'] as Map<String, dynamic>? ?? {};
            final pLat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
            final pLng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
            final displayName = p['displayName']?['text']?.toString() ?? '';
            final formatted = p['formattedAddress']?.toString() ?? displayName;

            String street = '';
            String city = '';
            String pin = '';

            final comps = p['addressComponents'] as List<dynamic>? ?? [];
            for (final c in comps) {
              if (c is! Map<String, dynamic>) continue;
              final types = (c['types'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              final name = c['longText']?.toString() ?? '';
              if (types.contains('route') || types.contains('sublocality')) {
                street = name;
              }
              if (types.contains('locality')) city = name;
              if (types.contains('postal_code')) pin = name;
            }

            final primaryName = cleanAddressLine(
                displayName.isNotEmpty ? displayName : formatted.split(',').first.trim());

            results.add({
              'name': primaryName,
              'street': cleanAddressLine(street.isNotEmpty ? street : primaryName),
              'city': city,
              'pin': pin,
              'lat': pLat,
              'lng': pLng,
              'type': 'Google Place',
            });
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      debugPrint('Google Places API (New) error: $e');
    }

    // 2. Google Places API (Legacy) / TextSearch
    try {
      final legacyUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(cleanQuery)}&region=in&key=$googleApiKey',
      );
      final response =
          await http.get(legacyUrl).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['status'] == 'OK' && data['results'] is List) {
          final list = data['results'] as List;
          if (list.isNotEmpty) {
            return list.map((item) {
              final loc = item['geometry']?['location'] ?? {};
              final pLat = (loc['lat'] as num?)?.toDouble() ?? 0.0;
              final pLng = (loc['lng'] as num?)?.toDouble() ?? 0.0;
              final name = item['name']?.toString() ?? '';
              final formatted = item['formatted_address']?.toString() ?? name;

              return {
                'name': cleanAddressLine(name),
                'street': cleanAddressLine(name.isNotEmpty ? name : formatted.split(',').first),
                'city': formatted.contains(',')
                    ? formatted.split(',').last.trim()
                    : '',
                'pin': '',
                'lat': pLat,
                'lng': pLng,
                'type': 'Google Place',
              };
            }).toList();
          }
        }
      }
    } catch (_) {}

    // 3. Photon Fast OpenStreetMap Search Engine (Zero-config, fast compound word matching)
    try {
      final photonUrl = Uri.parse(
        'https://photon.komoot.io/api/?q=${Uri.encodeComponent(cleanQuery)}&limit=6${lat != null && lon != null ? '&lat=$lat&lon=$lon' : ''}',
      );
      final response = await http.get(
        photonUrl,
        headers: {'User-Agent': 'Pickleo/1.0 (contact@pickleo.com)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final features = (data['features'] as List?) ?? [];
        if (features.isNotEmpty) {
          final results = <Map<String, dynamic>>[];
          for (final f in features) {
            final props = f['properties'] as Map<String, dynamic>? ?? {};
            final geom = f['geometry'] as Map<String, dynamic>? ?? {};
            final coords = geom['coordinates'] as List<dynamic>?;
            if (coords == null || coords.length < 2) continue;

            final pLng = (coords[0] as num).toDouble();
            final pLat = (coords[1] as num).toDouble();

            final rawName = props['name']?.toString() ??
                props['street']?.toString() ??
                cleanQuery;
            final road = props['street']?.toString() ??
                props['locality']?.toString() ??
                rawName;
            final city = props['city']?.toString() ??
                props['district']?.toString() ??
                props['state']?.toString() ??
                '';
            final pin = props['postcode']?.toString() ?? '';

            final name = cleanAddressLine(rawName);
            final street = cleanAddressLine(road);

            results.add({
              'name': name.isNotEmpty ? name : cleanQuery,
              'street': street.isNotEmpty ? street : name,
              'city': city,
              'pin': pin,
              'lat': pLat,
              'lng': pLng,
              'type': 'Location',
            });
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (_) {}

    // 4. Nominatim Places Autocomplete Search
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&addressdetails=1&limit=6&countrycodes=in',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'PickleoApp/1.0 (contact@pickleo.com)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List;
        if (list.isNotEmpty) {
          return list.map((item) {
            final pLat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
            final pLon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final rawName = item['name']?.toString() ??
                item['display_name']?.toString() ??
                cleanQuery;
            final city = addr['city'] ??
                addr['town'] ??
                addr['state_district'] ??
                addr['county'] ??
                '';
            final pin = addr['postcode'] ?? '';
            final road = addr['road'] ?? addr['suburb'] ?? rawName;

            final name = cleanAddressLine(rawName.split(',').first.trim());
            final street = cleanAddressLine(road);

            return {
              'name': name.isNotEmpty ? name : (street.isNotEmpty ? street : cleanQuery),
              'street': street.isNotEmpty ? street : name,
              'city': city,
              'pin': pin,
              'lat': pLat,
              'lng': pLon,
              'type': 'Address',
            };
          }).toList();
        }
      }
    } catch (_) {}

    return [];
  }
}

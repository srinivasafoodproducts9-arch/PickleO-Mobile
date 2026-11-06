import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../services/location_service.dart';

class MapLocationResult {
  final double latitude;
  final double longitude;
  final String area;
  final String city;
  final String postalCode;

  MapLocationResult({
    required this.latitude,
    required this.longitude,
    required this.area,
    required this.city,
    required this.postalCode,
  });
}

class MapPickerScreen extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String? initialArea;
  final String? initialCity;
  final String? initialPin;

  const MapPickerScreen({
    super.key,
    this.initialLatitude = 16.2259,
    this.initialLongitude = 80.0517,
    this.initialArea,
    this.initialCity,
    this.initialPin,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with SingleTickerProviderStateMixin {
  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();
  GoogleMapController? _mapController;

  late double _currentLat;
  late double _currentLng;
  late String _currentArea;
  late String _currentCity;
  late String _currentPin;

  bool _isLocating = false;
  bool _isReverseGeocoding = false;
  Timer? _debounceGeocodeTimer;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _currentLat = widget.initialLatitude;
    _currentLng = widget.initialLongitude;
    _currentArea = (widget.initialArea != null && widget.initialArea!.trim().isNotEmpty)
        ? LocationService.cleanAddressLine(widget.initialArea!)
        : '';
    _currentCity = (widget.initialCity != null && widget.initialCity!.trim().isNotEmpty)
        ? widget.initialCity!.trim()
        : '';
    _currentPin = (widget.initialPin != null && widget.initialPin!.trim().isNotEmpty)
        ? widget.initialPin!.trim()
        : '';

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    // Automatically trigger device GPS to lock onto real current position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectLiveGps(silent: true);
    });
  }

  @override
  void dispose() {
    _debounceGeocodeTimer?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  /// Acquire real device GPS position via LocationService and animate camera
  Future<void> _detectLiveGps({bool silent = false}) async {
    setState(() => _isLocating = true);

    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;

      if (pos != null) {
        _currentLat = pos.latitude;
        _currentLng = pos.longitude;

        // Animate Google Map camera to the user's exact GPS coordinates
        if (_mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(pos.latitude, pos.longitude),
                zoom: 17.0,
              ),
            ),
          );
        }

        // Perform reverse geocoding to obtain real street and city
        final addr =
            await LocationService().reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) return;

        setState(() {
          _isLocating = false;
          if (addr != null) {
            _currentArea = LocationService.cleanAddressLine(addr.street);
            _currentCity = addr.city;
            _currentPin = addr.postalCode;
          }
        });

        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Color(0xFF95D4AC), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS Centered: ${_currentArea.isNotEmpty ? "$_currentArea, " : ""}$_currentCity',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.textPrimary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        setState(() => _isLocating = false);
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Could not acquire live GPS location. Please check device location settings.'),
              backgroundColor: AppColors.chilliRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Triggered whenever user drags map pin to a new position
  void _onCameraMove(CameraPosition position) {
    _currentLat = position.target.latitude;
    _currentLng = position.target.longitude;
  }

  /// Triggered when camera motion stops: reverse geocode with debouncing
  void _onCameraIdle() {
    _debounceGeocodeTimer?.cancel();
    _debounceGeocodeTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      setState(() => _isReverseGeocoding = true);

      final addr =
          await LocationService().reverseGeocode(_currentLat, _currentLng);
      if (!mounted) return;

      setState(() {
        _isReverseGeocoding = false;
        if (addr != null) {
          _currentArea = LocationService.cleanAddressLine(addr.street);
          _currentCity = addr.city;
          _currentPin = addr.postalCode;
        }
      });
    });
  }

  /// Search places by keyword query
  Future<void> _onSearchQueryChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _filteredSuggestions = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await LocationService().searchPlaces(
      query,
      lat: _currentLat,
      lon: _currentLng,
    );
    if (!mounted) return;

    setState(() {
      _isSearching = false;
      _filteredSuggestions = results;
    });
  }

  /// Jump map camera to a chosen search result
  Future<void> _selectSearchResult(Map<String, dynamic> item) async {
    final lat = item['lat'] as double?;
    final lng = item['lng'] as double?;
    if (lat != null && lng != null) {
      _searchController.clear();
      FocusScope.of(context).unfocus();

      setState(() {
        _currentLat = lat;
        _currentLng = lng;
        _currentArea = LocationService.cleanAddressLine(
            item['street']?.toString() ?? item['name']?.toString() ?? '');
        _currentCity = item['city']?.toString() ?? '';
        _currentPin = item['pin']?.toString() ?? '';
        _filteredSuggestions = [];
      });

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lat, lng),
              zoom: 17.0,
            ),
          ),
        );
      }
    }
  }

  Future<void> _zoomIn() async {
    if (_mapController != null) {
      await _mapController!.animateCamera(CameraUpdate.zoomIn());
    }
  }

  Future<void> _zoomOut() async {
    if (_mapController != null) {
      await _mapController!.animateCamera(CameraUpdate.zoomOut());
    }
  }

  String get _displayArea {
    final clean = LocationService.cleanAddressLine(_currentArea);
    if (clean.isNotEmpty) return clean;
    return _currentCity.isNotEmpty ? _currentCity : 'Selected Location';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Google Map View
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(_currentLat, _currentLng),
                zoom: 16.5,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              mapToolbarEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                if (!_controllerCompleter.isCompleted) {
                  _controllerCompleter.complete(controller);
                }
              },
              onCameraMove: _onCameraMove,
              onCameraIdle: _onCameraIdle,
            ),
          ),

          // 2. Fixed Center Pin Marker with Pulsing Target
          Center(
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Floating Tooltip Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xE62A140B),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF66BB6A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Deliver pickles here',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Pin & Pulsing Circle Stack
                  SizedBox(
                    width: 70,
                    height: 70,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Animated pulse circle on the ground
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 36 * _pulseAnimation.value,
                              height: 36 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.pickleOrange.withValues(
                                  alpha: (1.6 - _pulseAnimation.value).clamp(0.0, 0.5),
                                ),
                              ),
                            );
                          },
                        ),
                        // Drop Shadow on ground
                        Positioned(
                          bottom: 12,
                          child: Container(
                            width: 14,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        // Sharp Pin Icon pointing at center
                        Positioned(
                          top: 4,
                          child: const Icon(
                            Icons.location_on_rounded,
                            size: 46,
                            color: AppColors.chilliRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Offset by half pin height so pin tip aligns with center
                  const SizedBox(height: 38),
                ],
              ),
            ),
          ),

          // 3. Top Floating Search Bar & Back Navigation
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme: const InputDecorationTheme(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: _onSearchQueryChanged,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search locality, street, or landmark...',
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: AppColors.textTertiary,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ),
                          if (_isSearching)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.pickleOrange,
                                ),
                              ),
                            )
                          else if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _filteredSuggestions = []);
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Icon(Icons.search_rounded,
                                  color: AppColors.pickleOrange, size: 22),
                            ),
                        ],
                      ),
                    ),

                    // Search Suggestions Dropdown Overlay
                    if (_filteredSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x24000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: _filteredSuggestions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Color(0xFFF0F0F0)),
                          itemBuilder: (ctx, idx) {
                            final s = _filteredSuggestions[idx];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              leading: const Icon(Icons.location_on_outlined,
                                  color: AppColors.pickleOrange, size: 18),
                              title: Text(
                                s['name']?.toString() ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${s['street'] ?? ''} ${s['city'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              onTap: () => _selectSearchResult(s),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Floating Action Controls (Zoom Controls & Icon-only Current Location Button)
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Zoom Controls
                Container(
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1E000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildMapControlBtn(icon: Icons.add, onTap: _zoomIn),
                      Container(width: 24, height: 1, color: const Color(0xFFEEEEEE)),
                      _buildMapControlBtn(icon: Icons.remove, onTap: _zoomOut),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Current Location Button (Icon only, 44x44, aligned with zoom controls)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1E000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _isLocating ? null : () => _detectLiveGps(),
                      borderRadius: BorderRadius.circular(12),
                      child: Center(
                        child: _isLocating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.leafGreen),
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                size: 22,
                                color: AppColors.leafGreen,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Bottom Location Card (No Popular Hubs)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x2A000000),
                    blurRadius: 18,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle Indicator
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDDDDD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Location Details Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDE8),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.pin_drop_rounded,
                              size: 24,
                              color: AppColors.pickleOrange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isReverseGeocoding
                                      ? 'Detecting street location...'
                                      : _displayArea,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(Icons.bolt,
                                        size: 15, color: AppColors.leafGreen),
                                    const SizedBox(width: 2),
                                    Expanded(
                                      child: Text(
                                        _currentCity.isNotEmpty
                                            ? '$_currentCity${_currentPin.isNotEmpty ? ' • $_currentPin' : ''} • Express Delivery'
                                            : 'Move pin or use GPS to set accurate location',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.leafGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Confirm Delivery Location CTA Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(
                              MapLocationResult(
                                latitude: _currentLat,
                                longitude: _currentLng,
                                area: _displayArea,
                                city: _currentCity,
                                postalCode: _currentPin,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.pickleOrange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 20, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Confirm Delivery Location',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../models/order.dart';
import '../state/app_state.dart';
import 'map_picker_screen.dart';
import '../services/location_service.dart';

class AddressEditScreen extends StatefulWidget {
  final DeliveryAddress? addressToEdit;

  const AddressEditScreen({super.key, this.addressToEdit});

  @override
  State<AddressEditScreen> createState() => _AddressEditScreenState();
}

class _AddressEditScreenState extends State<AddressEditScreen> {
  late String _label;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _flatController;
  late TextEditingController _streetController;
  late TextEditingController _cityController;
  late TextEditingController _pinController;
  late bool _isDefault;
  late double _latitude;
  late double _longitude;

  @override
  void initState() {
    super.initState();
    final a = widget.addressToEdit;
    _label = a?.label ?? 'Home';
    _nameController = TextEditingController(text: a?.recipientName ?? '');
    _phoneController = TextEditingController(text: a?.phoneNumber ?? '');
    _flatController = TextEditingController(text: a?.flat ?? '');
    final rawStreet = a?.street ?? '';
    _streetController =
        TextEditingController(text: LocationService.cleanAddressLine(rawStreet));
    _cityController = TextEditingController(text: a?.city ?? '');
    _pinController = TextEditingController(text: a?.pinCode ?? '');
    _isDefault = a?.isDefault ?? false;
    _latitude = a?.latitude ?? 12.9716;
    _longitude = a?.longitude ?? 77.5946;
  }

  bool _didAutoPopulate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoPopulate && widget.addressToEdit == null) {
      _didAutoPopulate = true;
      final appState = AppStateProvider.of(context);
      if (_nameController.text.trim().isEmpty &&
          appState.userName.isNotEmpty &&
          appState.userName != 'PickleO Foodie') {
        _nameController.text = appState.userName;
      }
      if (_phoneController.text.trim().isEmpty &&
          appState.phoneNumber.isNotEmpty) {
        _phoneController.text = appState.phoneNumber;
      }

      // Auto-detect location via GPS if city is empty
      if (_cityController.text.trim().isEmpty) {
        _detectGpsLocation(silent: true);
      }
    } else if (!_didAutoPopulate && widget.addressToEdit != null) {
      _didAutoPopulate = true;
      // If previously saved address had invalid continent/Asia or empty street, fetch real address line 1
      final rawStreet = widget.addressToEdit?.street ?? '';
      if (rawStreet.toLowerCase().contains('asia') ||
          rawStreet.toLowerCase().contains('continent') ||
          _streetController.text.trim().isEmpty) {
        LocationService().reverseGeocode(_latitude, _longitude).then((addr) {
          if (mounted && addr != null) {
            setState(() {
              final cleanStreet = LocationService.cleanAddressLine(addr.street);
              if (cleanStreet.isNotEmpty) {
                _streetController.text = cleanStreet;
              }
              if (_cityController.text.trim().isEmpty && addr.city.isNotEmpty) {
                _cityController.text = addr.city;
              }
              if (_pinController.text.trim().isEmpty && addr.postalCode.isNotEmpty) {
                _pinController.text = addr.postalCode;
              }
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _flatController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _save(AppState appState) async {
    final flat = _flatController.text.trim();
    final street = LocationService.cleanAddressLine(_streetController.text.trim());
    final pin = _pinController.text.trim();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Receiver Name'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(name) || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Receiver Name (letters and spaces only, min 2 characters)'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    if (cleanPhone.isEmpty || !phoneRegex.hasMatch(cleanPhone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid mobile number (e.g. +91 9876543210 or 10-digit number)'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    if (flat.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Flat / House / Building details'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    if (street.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter Street / Area / Landmark'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    if (city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter City'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    final cityRegex = RegExp(r"^[a-zA-Z\s]+$");
    if (!cityRegex.hasMatch(city)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('City should only contain letters and spaces'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    if (pin.isEmpty || pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit PIN code'),
          backgroundColor: AppColors.chilliRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final defaultUserName =
        appState.userName.isNotEmpty ? appState.userName : 'Recipient';
    final defaultUserPhone =
        appState.phoneNumber.isNotEmpty ? appState.phoneNumber : '';

    String formattedPhone = cleanPhone;
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      formattedPhone = '+91${cleanPhone.substring(1)}';
    } else if (!formattedPhone.startsWith('+')) {
      if (formattedPhone.length == 10) {
        formattedPhone = '+91$formattedPhone';
      } else {
        formattedPhone = '+$formattedPhone';
      }
    }

    if (widget.addressToEdit != null) {
      final updated = DeliveryAddress(
        id: widget.addressToEdit!.id,
        label: _label,
        receiverName: name.isNotEmpty ? name : defaultUserName,
        phone: formattedPhone.isNotEmpty ? formattedPhone : defaultUserPhone,
        flatHouseBuilding: flat,
        streetArea: street,
        city: city,
        postalCode: pin,
        isDefault: _isDefault,
        latitude: _latitude,
        longitude: _longitude,
      );

      final res = await appState.updateAddressViaApi(updated);
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ??
              (res.success
                  ? 'Address updated successfully!'
                  : 'Failed to update address')),
          backgroundColor:
              res.success ? AppColors.leafGreen : AppColors.chilliRed,
        ),
      );

      if (res.success) {
        Navigator.of(context).pop();
      }
    } else {
      final newAddr = DeliveryAddress(
        id: '',
        label: _label,
        receiverName: name.isNotEmpty ? name : defaultUserName,
        phone: formattedPhone.isNotEmpty ? formattedPhone : defaultUserPhone,
        flatHouseBuilding: flat,
        streetArea: street,
        city: city,
        postalCode: pin,
        isDefault: _isDefault,
        latitude: _latitude,
        longitude: _longitude,
      );

      final res = await appState.addAddressViaApi(newAddr);
      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message ??
              (res.success
                  ? 'Address saved successfully!'
                  : 'Failed to save address')),
          backgroundColor:
              res.success ? AppColors.leafGreen : AppColors.chilliRed,
        ),
      );

      if (res.success) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<MapLocationResult>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          initialArea: _streetController.text.isNotEmpty
              ? _streetController.text
              : null,
          initialCity: _cityController.text.isNotEmpty
              ? _cityController.text
              : null,
          initialPin: _pinController.text.isNotEmpty
              ? _pinController.text
              : null,
        ),
      ),
    );

    if (result != null) {
      final cleanArea = LocationService.cleanAddressLine(result.area);
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
        if (cleanArea.isNotEmpty) _streetController.text = cleanArea;
        if (result.city.isNotEmpty) _cityController.text = result.city;
        if (result.postalCode.isNotEmpty) _pinController.text = result.postalCode;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle,
                  color: Color(0xFF95D4AC), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Location set: ${_streetController.text.isNotEmpty ? "${_streetController.text}, " : ""}${result.city}',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isDetectingGps = false;

  Future<void> _detectGpsLocation({bool silent = false}) async {
    setState(() => _isDetectingGps = true);
    try {
      final pos = await LocationService().getCurrentPosition();
      if (!mounted) return;

      if (pos != null) {
        final addr =
            await LocationService().reverseGeocode(pos.latitude, pos.longitude);
        if (!mounted) return;

        final cleanStreet = LocationService.cleanAddressLine(addr?.street ?? '');
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          if (cleanStreet.isNotEmpty) _streetController.text = cleanStreet;
          if (addr != null) {
            if (addr.city.isNotEmpty) _cityController.text = addr.city;
            if (addr.postalCode.isNotEmpty) _pinController.text = addr.postalCode;
          }
        });

        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF95D4AC), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GPS Located: ${_cityController.text.isNotEmpty ? _cityController.text : _streetController.text}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.textPrimary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please enable GPS / Location permissions in device settings.'),
              backgroundColor: AppColors.chilliRed,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final isEditing = widget.addressToEdit != null;

    final labels = [
      {'name': 'Home', 'icon': Icons.home_outlined},
      {'name': 'Work', 'icon': Icons.work_outline},
      {'name': 'Other', 'icon': Icons.location_on_outlined},
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Address' : 'Add New Address',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: _isSaving
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceContainer,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.pickleOrange),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Interactive Map Preview & Selector Card
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderCard),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Interactive Map Preview Area
                  InkWell(
                    onTap: _openMapPicker,
                    child: SizedBox(
                      width: double.infinity,
                      height: 155,
                      child: Stack(
                        children: [
                          // Vector Map Background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: RichVectorMapPainter(
                                panOffset: Offset(_longitude * 10, _latitude * 10),
                                scale: 1.1,
                              ),
                            ),
                          ),

                          // Target Center Delivery Pin & Radar Ripple
                          Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing delivery radius ring
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.leafGreen.withValues(alpha: 0.16),
                                    border: Border.all(
                                      color: AppColors.leafGreen.withValues(alpha: 0.45),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                // Ground pin contact shadow
                                Container(
                                  width: 10,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.28),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                // Location Pin Icon
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 24),
                                  child: Icon(
                                    Icons.location_on,
                                    size: 40,
                                    color: AppColors.chilliRed,
                                  ),
                                ),
                              ],
                            ),
                          ),



                          // Tap to Select on Map Badge (Top Right)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.pickleOrange,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x28FF6E40),
                                    blurRadius: 5,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.map_rounded,
                                      size: 13, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Select on Map',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Detect GPS button (Bottom Left)
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: GestureDetector(
                              onTap: _isDetectingGps ? null : _detectGpsLocation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x18000000),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isDetectingGps)
                                      const SizedBox(
                                        width: 13,
                                        height: 13,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  AppColors.leafGreen),
                                        ),
                                      )
                                    else
                                      const Icon(Icons.gps_fixed,
                                          size: 13, color: AppColors.leafGreen),
                                    const SizedBox(width: 5),
                                    Text(
                                      _isDetectingGps
                                          ? 'Locating...'
                                          : 'Detect GPS',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Location Details & Quick Change Action Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: Color(0xFFF0F0F0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDE8),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pin_drop_rounded,
                              color: AppColors.pickleOrange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _streetController.text.trim().isNotEmpty
                                    ? _streetController.text.trim()
                                    : 'Select location on map',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                _cityController.text.trim().isNotEmpty ||
                                        _pinController.text.trim().isNotEmpty
                                    ? '${_cityController.text.trim()}${_pinController.text.trim().isNotEmpty ? ' • ${_pinController.text.trim()}' : ''}'
                                    : 'Tap to pick your exact location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _openMapPicker,
                          icon: const Icon(Icons.map_outlined, size: 14),
                          label: const Text('Change'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.pickleOrange,
                            side: const BorderSide(
                                color: AppColors.pickleOrange, width: 1.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                            textStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Save as selector
            Text(
              'Save as',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: labels.map((l) {
                final name = l['name'] as String;
                final isSelected = _label == name;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _label = name),
                    child: Container(
                      height: 42,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.leafGreen
                            : AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            l['icon'] as IconData,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Form inputs
            _buildField('Receiver Name', _nameController,
                'Full name of person receiving the order (e.g. Priya Sharma)'),
            _buildField('Phone Number', _phoneController,
                'e.g. +91 9876543210 or 10-digit mobile number'),
            _buildField('Flat / House / Building', _flatController,
                'e.g. Flat 402, Heritage Palms / House No. 12'),
            _buildField('Street / Area / Landmark', _streetController,
                'e.g. 12th Main Rd, Near BDA Complex, Indiranagar'),
            _buildField('City', _cityController, 'e.g. Hyderabad, Bengaluru, Chennai'),
            _buildField('PIN Code', _pinController, '6-digit PIN code (e.g. 560038)'),

            const SizedBox(height: 10),

            // Make default address checkbox
            GestureDetector(
              onTap: () => setState(() => _isDefault = !_isDefault),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _isDefault
                            ? AppColors.leafGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isDefault
                              ? AppColors.leafGreen
                              : AppColors.borderCard,
                          width: 1.8,
                        ),
                      ),
                      child: _isDefault
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Make this my default address',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Save Address Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : () => _save(appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pickleOrange,
                  disabledBackgroundColor:
                      AppColors.pickleOrange.withValues(alpha: 0.6),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        isEditing ? 'Save Address' : 'Confirm Address',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildField(
      String label, TextEditingController controller, String placeholder) {
    TextInputType keyboardType = TextInputType.text;
    List<TextInputFormatter> formatters = [];

    if (label.contains('Receiver')) {
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
        LengthLimitingTextInputFormatter(50),
      ];
    } else if (label.contains('Phone')) {
      keyboardType = TextInputType.phone;
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
        LengthLimitingTextInputFormatter(20),
      ];
    } else if (label.contains('PIN')) {
      keyboardType = TextInputType.number;
      formatters = [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ];
    } else if (label.contains('City')) {
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
        LengthLimitingTextInputFormatter(50),
      ];
    } else if (label.contains('Flat') || label.contains('Street')) {
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s,.\-/#]")),
        LengthLimitingTextInputFormatter(100),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceHighest),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              enabled: !_isSaving,
              keyboardType: keyboardType,
              inputFormatters: formatters,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RichVectorMapPainter extends CustomPainter {
  final Offset panOffset;
  final double scale;

  RichVectorMapPainter({this.panOffset = Offset.zero, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final landPaint = Paint()..color = const Color(0xFFF3F2EC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    final greenPaint = Paint()..color = const Color(0xFFE2EED9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.35, size.height * 0.45),
        const Radius.circular(16),
      ),
      greenPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.65, size.height * 0.55, size.width * 0.3, size.height * 0.35),
        const Radius.circular(14),
      ),
      greenPaint,
    );

    final waterPaint = Paint()..color = const Color(0xFFD6EBF8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.72, size.height * 0.08, size.width * 0.24, size.height * 0.32),
        const Radius.circular(18),
      ),
      waterPaint,
    );

    final roadPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    final roadBorderPaint = Paint()
      ..color = const Color(0xFFE5E2D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round;

    final y1 = size.height * 0.35;
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), roadBorderPaint);
    canvas.drawLine(Offset(0, y1), Offset(size.width, y1), roadPaint);

    final y2 = size.height * 0.75;
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), roadBorderPaint);
    canvas.drawLine(Offset(0, y2), Offset(size.width, y2), roadPaint);

    final mainRoadBorder = Paint()
      ..color = const Color(0xFFF3D4A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0;
    final mainRoad = Paint()
      ..color = const Color(0xFFFFE0B2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0;

    final x1 = size.width * 0.52;
    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), mainRoadBorder);
    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), mainRoad);

    final x2 = size.width * 0.22;
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), roadBorderPaint);
    canvas.drawLine(Offset(x2, 0), Offset(x2, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant RichVectorMapPainter oldDelegate) =>
      oldDelegate.panOffset != panOffset || oldDelegate.scale != scale;
}


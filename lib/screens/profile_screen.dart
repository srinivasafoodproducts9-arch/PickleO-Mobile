import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../services/auth_service.dart';
import 'address_screen.dart';
import 'payment_methods_screen.dart';
import 'orders_screen.dart';
import 'wallet_screen.dart';
import 'rewards_screen.dart';
import 'refer_screen.dart';
import 'help_screen.dart';
import 'privacy_policy_screen.dart';
import 'auth_screen.dart';
import '../utils/auth_guard.dart';
import '../utils/app_upgrader.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;

  const ProfileScreen({super.key, this.isTab = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Feature flags for upcoming features (hidden for now, to be implemented later)
  static const bool _showLoyaltyTierCard = false;
  static const bool _showPaymentMethods = false;
  static const bool _showWalletAndCash = true;
  static const bool _showSpicePointsAndLoyalty = true;
  static const bool _showReferAFriend = true;

  bool _isEditing = false;
  bool _isSaving = false;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _dobController;
  late String _selectedGender;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _dobController = TextEditingController();
    _selectedGender = 'Female';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        if (!appState.hasLoadedProductRegions &&
            !appState.isLoadingProductRegions) {
          appState.fetchProductRegions();
        }
        if (appState.isLoggedIn) {
          appState.loadLoyaltyFromApi(notify: false);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = AppStateProvider.of(context);
    if (!_isEditing) {
      _nameController.text = appState.userName;
      _emailController.text = appState.userEmail;
      _dobController.text = UserProfile.isValidDateOfBirth(appState.dob)
          ? appState.dob
          : '';
      _selectedGender = appState.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(AppState appState) async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full Name is required'),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(name) || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid Full Name (letters and spaces only, min 2 characters)',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (name.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Full Name cannot exceed 50 characters'),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isNotEmpty &&
        (!emailRegex.hasMatch(email) || email.length > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid email address (max 100 characters)',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (dob.isNotEmpty) {
      final parsed = DateTime.tryParse(dob);
      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Date of Birth must be in YYYY-MM-DD format'),
            backgroundColor: AppColors.chilliRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (parsed.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Date of birth cannot be in the future'),
            backgroundColor: AppColors.chilliRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    final response = await appState.updateProfileViaApi(
      fullName: name,
      email: email,
      dateOfBirth: dob,
      gender: _selectedGender,
      spiceTolerance: appState.spiceTolerance,
      preferredRegionalStyles: appState.preferredRegions.toList(),
      vegetarianOnly: appState.isVegetarianOnly,
      excludeGarlic: appState.excludeGarlic,
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message ??
              (response.success
                  ? 'Profile updated successfully!'
                  : 'Failed to update profile'),
        ),
        backgroundColor: response.success
            ? AppColors.leafGreen
            : AppColors.chilliRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final defAddr = appState.defaultAddress;

    final spiceLevels = [
      {'name': 'Mild', 'sub': 'Sweet & Tangy'},
      {'name': 'Medium', 'sub': 'Authentic Kick'},
      {'name': 'Fiery', 'sub': 'Andhra Hot'},
    ];

    final regions = appState.productRegions.map((r) => r.name).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: widget.isTab
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          'Account',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom:
            (_isSaving ||
                appState.isLoadingProfile ||
                appState.isUpdatingProfile)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(
                  backgroundColor: AppColors.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.pickleOrange,
                  ),
                  minHeight: 3,
                ),
              )
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () => appState.loadProfileFromApi(),
        color: AppColors.pickleOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!appState.isLoggedIn)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderCard),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.surfaceContainer,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 26,
                              color: AppColors.orangeDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome to PickleO',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Log in for orders & rewards',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AuthScreen(isOptional: true),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.leafGreen,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Log In',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // User Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                requireAuth(
                                  context,
                                  onAuthenticated: () {
                                    _showAvatarOptions(context, appState);
                                  },
                                );
                              },
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(36),
                                    child: _buildUserAvatar(appState, 72),
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 26,
                                      height: 26,
                                      decoration: BoxDecoration(
                                        color: AppColors.leafGreen,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.surfaceLow,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.photo_camera,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          appState.isLoggedIn
                                              ? (appState.userName
                                                        .trim()
                                                        .isNotEmpty
                                                    ? appState.userName.trim()
                                                    : 'Pickle Lover')
                                              : 'Guest User',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (appState.isLoggedIn) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.verified,
                                          size: 18,
                                          color: AppColors.leafGreen,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    appState.isLoggedIn
                                        ? (appState.phoneNumber
                                                  .trim()
                                                  .isNotEmpty
                                              ? appState.phoneNumber
                                              : 'No phone linked')
                                        : 'Sign in to access your account',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (appState.isLoggedIn &&
                                      appState.userEmail.trim().isNotEmpty)
                                    Text(
                                      appState.userEmail.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  else if (appState.isLoggedIn)
                                    Text(
                                      'Tap Edit to add email address',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Loyalty Tier Card (hidden for now, to be implemented later)
                        if (_showLoyaltyTierCard) ...[
                          const SizedBox(height: 14),
                          Builder(
                            builder: (context) {
                              final points = appState.spicePoints;
                              final tier = points >= 1000
                                  ? 'TIER 3'
                                  : (points >= 200 ? 'TIER 2' : 'TIER 1');
                              final tierName = points >= 1000
                                  ? 'PickleO Legend'
                                  : (points >= 200
                                        ? 'PickleO Connoisseur'
                                        : 'PickleO Explorer');

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium,
                                      size: 22,
                                      color: AppColors.spiceYellow,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  tierName,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.textPrimary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  tier,
                                                  style: const TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '$points Spice Points earned',
                                            style: GoogleFonts.poppins(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.orangeDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'Benefits ›',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.leafGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Taste Profile & Spice Meter Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.restaurant,
                              size: 20,
                              color: AppColors.orangeDark,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Taste Profile & Spice Meter',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Spice Tolerance Level',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${appState.spiceTolerance} Spicy',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.chilliRed,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 3 Option Spice Tolerance Selector
                        Row(
                          children: spiceLevels.map((lvl) {
                            final name = lvl['name'] as String;
                            final isSelected = appState.spiceTolerance == name;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => appState.setSpiceTolerance(name),
                                child: Container(
                                  height: 68,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.pickleOrange
                                        : AppColors.surfaceLow,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        lvl['sub'] as String,
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          color: isSelected
                                              ? Colors.white.withValues(
                                                  alpha: 0.85,
                                                )
                                              : AppColors.textSecondary,
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

                        Text(
                          'Preferred Regional Styles',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          children: regions.map((r) {
                            final isSelected = appState.preferredRegions
                                .contains(r);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => appState.togglePreferredRegion(r),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.leafGreen
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.leafGreen
                                          : const Color(0xFFE2E8F0),
                                      width: 1.2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.leafGreen
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.03,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (isSelected) ...[
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 15,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        r,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
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

                        // 100% Vegetarian Only Toggle Card
                        GestureDetector(
                          onTap: () => appState.toggleVegetarianOnly(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: AppColors.leafGreen,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.leafGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '100% Vegetarian Only',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Exclude all garlic/non-veg batches',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: appState.isVegetarianOnly,
                                  activeColor: AppColors.leafGreen,
                                  onChanged: (_) =>
                                      appState.toggleVegetarianOnly(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Exclude Garlic (Satvik / Jain Options)
                        GestureDetector(
                          onTap: () => appState.toggleExcludeGarlic(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                      color: AppColors.orangeDark,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.orangeDark,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Exclude Garlic (Satvik / Jain)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Filter traditional garlic-free artisanal batches',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: appState.excludeGarlic,
                                  activeColor: AppColors.leafGreen,
                                  onChanged: (_) =>
                                      appState.toggleExcludeGarlic(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Personal Information Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderCard),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.badge_outlined,
                                    size: 20,
                                    color: AppColors.orangeDark,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Personal Information',
                                      style: GoogleFonts.poppins(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (!appState.isLoggedIn) {
                                  requireAuth(context);
                                  return;
                                }
                                if (_isEditing) {
                                  _nameController.text = appState.userName;
                                  _emailController.text = appState.userEmail;
                                  _dobController.text =
                                      UserProfile.isValidDateOfBirth(
                                        appState.dob,
                                      )
                                      ? appState.dob
                                      : '';
                                  _selectedGender = appState.gender;
                                }
                                setState(() => _isEditing = !_isEditing);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _isEditing
                                      ? AppColors.surfaceLow
                                      : AppColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isEditing
                                          ? Icons.close
                                          : Icons.edit_outlined,
                                      size: 14,
                                      color: _isEditing
                                          ? AppColors.textSecondary
                                          : AppColors.orangeDark,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _isEditing ? 'Cancel' : 'Edit',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _isEditing
                                            ? AppColors.textSecondary
                                            : AppColors.orangeDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Full Name
                        _buildProfileField(
                          'Full Name',
                          _nameController,
                          _isEditing,
                        ),
                        const SizedBox(height: 10),

                        // Mobile Number (Locked)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mobile Number',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.verified,
                                      size: 13,
                                      color: AppColors.leafGreen,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Verified',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.leafGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 46,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    appState.phoneNumber,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: AppColors.textTertiary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Email
                        _buildProfileField(
                          'Email Address',
                          _emailController,
                          _isEditing,
                        ),
                        const SizedBox(height: 10),

                        // DOB with Free Birthday Jar note
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Date of Birth',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.redeem,
                                      size: 13,
                                      color: AppColors.leafGreen,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Free Birthday Jar',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.leafGreen,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _isEditing
                                ? Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLow,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _dobController,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              focusedErrorBorder:
                                                  InputBorder.none,
                                              filled: false,
                                              contentPadding: EdgeInsets.zero,
                                              isDense: true,
                                              hintText:
                                                  'YYYY-MM-DD (e.g. 1995-08-15)',
                                              hintStyle: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.calendar_month,
                                            size: 18,
                                            color: AppColors.leafGreen,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () async {
                                            final now = DateTime.now();
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: DateTime(
                                                now.year - 20,
                                                now.month,
                                                now.day,
                                              ),
                                              firstDate: DateTime(1920),
                                              lastDate: DateTime(now.year - 5),
                                            );
                                            if (picked != null) {
                                              final y = picked.year
                                                  .toString()
                                                  .padLeft(4, '0');
                                              final m = picked.month
                                                  .toString()
                                                  .padLeft(2, '0');
                                              final d = picked.day
                                                  .toString()
                                                  .padLeft(2, '0');
                                              _dobController.text = '$y-$m-$d';
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  )
                                : InkWell(
                                    onTap: () {
                                      _nameController.text = appState.userName;
                                      _emailController.text =
                                          appState.userEmail;
                                      _dobController.text =
                                          UserProfile.isValidDateOfBirth(
                                            appState.dob,
                                          )
                                          ? appState.dob
                                          : '';
                                      _selectedGender = appState.gender;
                                      setState(() => _isEditing = true);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 46,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceLow,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.cake_outlined,
                                            size: 16,
                                            color:
                                                (appState.dob
                                                        .trim()
                                                        .isNotEmpty &&
                                                    UserProfile.isValidDateOfBirth(
                                                      appState.dob,
                                                    ))
                                                ? AppColors.leafGreen
                                                : AppColors.textTertiary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              (appState.dob.trim().isNotEmpty &&
                                                      UserProfile.isValidDateOfBirth(
                                                        appState.dob,
                                                      ))
                                                  ? appState.dob
                                                  : 'YYYY-MM-DD (e.g. 1995-08-15)',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13.5,
                                                fontWeight:
                                                    (appState.dob
                                                            .trim()
                                                            .isNotEmpty &&
                                                        UserProfile.isValidDateOfBirth(
                                                          appState.dob,
                                                        ))
                                                    ? FontWeight.w500
                                                    : FontWeight.w400,
                                                color:
                                                    (appState.dob
                                                            .trim()
                                                            .isNotEmpty &&
                                                        UserProfile.isValidDateOfBirth(
                                                          appState.dob,
                                                        ))
                                                    ? AppColors.textPrimary
                                                    : AppColors.textTertiary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Gender selector
                        Text(
                          'Gender',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: ['Female', 'Male', 'Other'].map((g) {
                            final isSel = _selectedGender == g;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_isEditing) {
                                    setState(() => _selectedGender = g);
                                  }
                                },
                                child: Container(
                                  height: 42,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AppColors.leafGreen
                                        : AppColors.surfaceLow,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    g,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isSel
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        // Save Changes button
                        if (_isEditing) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving
                                  ? null
                                  : () => _saveProfile(appState),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check, size: 18),
                              label: Text(
                                _isSaving
                                    ? 'Saving Changes...'
                                    : 'Save Changes',
                                style: GoogleFonts.poppins(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.pickleOrange,
                                disabledBackgroundColor: AppColors.pickleOrange
                                    .withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ACCOUNT HUB Header
                  Text(
                    'ACCOUNT HUB',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 5 Account Hub Items
                  _buildHubTile(
                    icon: Icons.location_on_outlined,
                    title: 'Saved Addresses',
                    subtitle: appState.addresses.isNotEmpty
                        ? '${defAddr.label} · ${defAddr.flat}, ${defAddr.street}'
                        : 'No saved address · Tap to add',
                    tag: '${appState.addresses.length}',
                    onTap: () {
                      requireAuth(
                        context,
                        onAuthenticated: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddressScreen(),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (_showPaymentMethods) ...[
                    const SizedBox(height: 10),
                    _buildHubTile(
                      icon: Icons.credit_card_outlined,
                      title: 'Payment Methods & UPI',
                      subtitle: 'Google Pay primary · 1 card saved',
                      onTap: () {
                        requireAuth(
                          context,
                          onAuthenticated: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PaymentMethodsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildHubTile(
                    icon: Icons.local_shipping_outlined,
                    title: 'My Orders & Invoices',
                    subtitle: appState.orders.isNotEmpty
                        ? '${appState.orders.length} order${appState.orders.length == 1 ? '' : 's'}'
                        : 'View order history & invoices',
                    tag: appState.activeOrder != null ? '1 Active' : '',
                    onTap: () {
                      requireAuth(
                        context,
                        onAuthenticated: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OrdersScreen(isTab: false),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (_showWalletAndCash) ...[
                    const SizedBox(height: 10),
                    _buildHubTile(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'PickleO Wallet & Cash',
                      subtitle: 'Available store credits',
                      valueText: '₹${appState.walletBalance.toInt()}',
                      onTap: () {
                        requireAuth(
                          context,
                          onAuthenticated: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WalletScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  if (_showSpicePointsAndLoyalty) ...[
                    const SizedBox(height: 10),
                    _buildHubTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Spice Points & Rewards',
                      subtitle: appState.loyaltyAccount != null
                          ? (appState.loyaltyAccount!.nextTier != null
                                ? '${appState.loyaltyAccount!.tier.name} · ${appState.loyaltyAccount!.pointsToGo} pts to ${appState.loyaltyAccount!.nextTier!.name}'
                                : '${appState.loyaltyAccount!.tier.name} · Top Tier Member')
                          : 'Redeem points for discounts & perks',
                      valueText: '${appState.spicePoints} pts',
                      onTap: () {
                        requireAuth(
                          context,
                          onAuthenticated: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RewardsScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  if (_showReferAFriend) ...[
                    const SizedBox(height: 10),
                    _buildHubTile(
                      icon: Icons.group_add_outlined,
                      title: 'Refer a Friend',
                      subtitle: 'Give ₹100, get ₹100 in wallet',
                      tag: 'Invite & Earn',
                      onTap: () {
                        requireAuth(
                          context,
                          onAuthenticated: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReferScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _buildHubTile(
                    icon: Icons.support_agent_outlined,
                    title: 'Help & Support',
                    subtitle: 'WhatsApp, call or browse FAQs',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildHubTile(
                    icon: Icons.shield_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How PickleO uses your information',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Auth Button (Log In or Log Out)
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        if (appState.isLoggedIn) {
                          _showLogoutConfirmDialog(context, appState);
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AuthScreen(isOptional: true),
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        appState.isLoggedIn ? Icons.logout : Icons.login,
                        size: 18,
                        color: appState.isLoggedIn
                            ? AppColors.chilliRed
                            : AppColors.leafGreen,
                      ),
                      label: Text(
                        appState.isLoggedIn
                            ? 'Log Out of PickleO'
                            : 'Log In to PickleO',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: appState.isLoggedIn
                              ? AppColors.chilliRed
                              : AppColors.leafGreen,
                        ),
                      ),
                    ),
                  ),
                  if (appState.isLoggedIn) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            _showDeleteAccountSheet(context, appState),
                        child: Text(
                          'Delete Account',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // App Version Footer & Store Link
                  Center(
                    child: InkWell(
                      onTap: () => AppUpgraderConfig.openStore(),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Text(
                          'PickleO App v1.0.3 • Check for Updates',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.pickleOrange,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileField(
    String label,
    TextEditingController controller,
    bool isEditing,
  ) {
    final effectiveHint = label.contains('Name')
        ? 'Enter full name (e.g. Priya Sharma)'
        : 'Enter email (e.g. priya@example.com)';
    final isEmpty = controller.text.trim().isEmpty;

    List<TextInputFormatter> formatters = [];
    TextInputType keyboardType = TextInputType.text;
    if (label.contains('Name')) {
      formatters = [
        FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
        LengthLimitingTextInputFormatter(50),
      ];
    } else if (label.contains('Email')) {
      keyboardType = TextInputType.emailAddress;
      formatters = [LengthLimitingTextInputFormatter(100)];
    }

    return Column(
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
        isEditing
            ? Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: formatters,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    hintText: effectiveHint,
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              )
            : Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  isEmpty ? effectiveHint : controller.text,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w500,
                    color: isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildUserAvatar(AppState appState, double size) {
    if (!appState.isLoggedIn) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFFFEDE8),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_outline_rounded,
          size: size * 0.55,
          color: const Color(0xFF964900),
        ),
      );
    }

    final localBytes = appState.localAvatarBytes;
    if (localBytes != null && localBytes.isNotEmpty) {
      return ClipOval(
        child: Image.memory(
          localBytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    final avatarUrl = appState.avatarUrl;
    if (avatarUrl != null &&
        avatarUrl.trim().isNotEmpty &&
        avatarUrl != 'string' &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'))) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildFallbackAvatar(appState.userName, size),
        ),
      );
    }
    return _buildFallbackAvatar(appState.userName, size);
  }

  Widget _buildFallbackAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDE8),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFBD1C4), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.55,
        color: const Color(0xFF964900),
      ),
    );
  }

  Widget _buildHubTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String tag = '',
    String valueText = '',
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderCard),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.orangeDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (tag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (valueText.isNotEmpty) ...[
              Text(
                valueText,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orangeDark,
                ),
              ),
              const SizedBox(width: 6),
            ],
            const Icon(Icons.chevron_right, size: 20, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log Out',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your PickleO account?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.chilliRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              appState.logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _viewProfilePhoto(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 320,
                  maxHeight: 320,
                ),
                color: Colors.white,
                child: _buildUserAvatar(appState, 300),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarOptions(BuildContext context, AppState appState) {
    if (!appState.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first to update your profile photo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isUploading = false;
        String uploadStatus = 'Uploading your profile photo...';

        Future<void> pickAndUpload(
          ImageSource source,
          StateSetter setModalState,
        ) async {
          try {
            final picker = ImagePicker();
            final XFile? pickedFile = await picker.pickImage(
              source: source,
              maxWidth: 1024,
              maxHeight: 1024,
              imageQuality: 85,
            );

            if (pickedFile == null) return;

            setModalState(() {
              isUploading = true;
              uploadStatus = 'Preparing and securing photo...';
            });

            final bytes = await pickedFile.readAsBytes();
            final String contentType =
                pickedFile.name.toLowerCase().endsWith('.png')
                ? 'image/png'
                : 'image/jpeg';

            setModalState(() {
              uploadStatus = 'Uploading to cloud storage...';
            });

            final res = await appState.uploadAvatar(
              bytes,
              contentType: contentType,
            );

            if (ctx.mounted) {
              Navigator.of(ctx).pop();
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        res.success ? Icons.check_circle : Icons.error_outline,
                        color: res.success
                            ? const Color(0xFF95D4AC)
                            : Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          res.message ??
                              (res.success
                                  ? 'Profile photo updated successfully!'
                                  : 'Failed to upload photo'),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: res.success
                      ? AppColors.textPrimary
                      : AppColors.chilliRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            setModalState(() => isUploading = false);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error selecting image: ${e.toString()}'),
                  backgroundColor: AppColors.chilliRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    children: [
                      _buildUserAvatar(appState, 44),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile Photo',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Choose a photo to personalize your account',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (isUploading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              color: AppColors.pickleOrange,
                              strokeWidth: 3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            uploadStatus,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Please keep the app open',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // View Profile Photo option if available
                    if ((appState.avatarUrl != null &&
                            appState.avatarUrl!.isNotEmpty &&
                            appState.avatarUrl != 'string' &&
                            appState.avatarUrl != 'null') ||
                        appState.localAvatarBytes != null) ...[
                      _buildPhotoActionTile(
                        icon: Icons.fullscreen_outlined,
                        iconBg: const Color(0xFFE8F5E9),
                        iconColor: AppColors.leafGreen,
                        title: 'View Profile Photo',
                        subtitle: 'Open and inspect full image',
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _viewProfilePhoto(context, appState);
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Gallery option
                    _buildPhotoActionTile(
                      icon: Icons.photo_library_outlined,
                      iconBg: const Color(0xFFFFF3E0),
                      iconColor: AppColors.pickleOrange,
                      title: 'Choose from Gallery',
                      subtitle: 'Select existing picture from your phone',
                      onTap: () =>
                          pickAndUpload(ImageSource.gallery, setModalState),
                    ),
                    const SizedBox(height: 10),

                    // Camera option
                    _buildPhotoActionTile(
                      icon: Icons.camera_alt_outlined,
                      iconBg: const Color(0xFFE8F5E9),
                      iconColor: AppColors.leafGreen,
                      title: 'Take a Photo',
                      subtitle: 'Use camera to take a new selfie',
                      onTap: () =>
                          pickAndUpload(ImageSource.camera, setModalState),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPhotoActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderCard),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.outline,
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountSheet(BuildContext context, AppState appState) {
    String selectedReason = 'Not ordering anymore';
    final confirmCtrl = TextEditingController();
    final reasons = [
      'Not ordering anymore',
      'Too many notifications',
      'Privacy concerns',
      'Moving out of India',
      'Other',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFFF8F6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDeleteReady =
                confirmCtrl.text.trim().toUpperCase() == 'DELETE';
            final mq = MediaQuery.of(context);
            final bottomInset = mq.viewInsets.bottom;
            final systemBottom = mq.padding.bottom;
            final effectiveBottom = bottomInset > 0
                ? (bottomInset + 16)
                : (systemBottom > 0 ? (systemBottom + 16) : 24.0);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: effectiveBottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC0C9C0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delete account?',
                        style: GoogleFonts.lora(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Warning Banner
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDAD6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Color(0xFF7A1F14),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This permanently deletes your PickleO account, saved addresses, order history, ₹${appState.walletBalance.toInt()} wallet balance and ${appState.spicePoints} Spice Points. This cannot be undone.',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: const Color(0xFF7A1F14),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Why are you leaving?',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reasons.map((r) {
                      final isSel = r == selectedReason;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedReason = r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0xFF2C160E)
                                : const Color(0xFFFFF1ED),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            r,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isSel
                                  ? Colors.white
                                  : const Color(0xFF2C160E),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'Type DELETE to confirm',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),

                  TextField(
                    controller: confirmCtrl,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: const Color(0xFF2C160E),
                    ),
                    decoration: InputDecoration(
                      hintText: 'DELETE',
                      hintStyle: GoogleFonts.poppins(
                        letterSpacing: 2,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFFFDBD0)),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0F5132)),
                              foregroundColor: const Color(0xFF0F5132),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Keep Account',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isDeleteReady
                                ? () {
                                    Navigator.pop(ctx);
                                    appState.deleteAccountPermanently();
                                    Navigator.of(context).pushAndRemoveUntil(
                                      MaterialPageRoute(
                                        builder: (_) => const AuthScreen(),
                                      ),
                                      (route) => false,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Account deleted · sorry to see you go',
                                        ),
                                        backgroundColor: Color(0xFF2C160E),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC0392B),
                              disabledBackgroundColor: const Color(
                                0xFFC0392B,
                              ).withValues(alpha: 0.5),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white.withValues(
                                alpha: 0.7,
                              ),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Delete Forever',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/pickleo_logo.dart';
import '../state/app_state.dart';
import 'main_navigation.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String phone;
  final VoidCallback? onSetupComplete;

  const ProfileSetupScreen({
    super.key,
    required this.phone,
    this.onSetupComplete,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String _gender = 'Female';
  String _spiceTolerance = 'Medium';
  bool _vegetarianOnly = false;
  bool _excludeGarlic = false;
  final Set<String> _preferredRegions = {};

  bool _isSaving = false;
  String? _nameError;
  String? _emailError;
  String? _dobError;
  String? _genderError;
  String? _spiceError;
  String? _regionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final appState = AppStateProvider.of(context);
        if (_preferredRegions.isEmpty && appState.preferredRegions.isNotEmpty) {
          setState(() {
            _preferredRegions.addAll(appState.preferredRegions);
          });
        }
        if (!appState.hasLoadedProductRegions &&
            !appState.isLoadingProductRegions) {
          appState.fetchProductRegions();
        }
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _submit(AppState appState) async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final dob = _dobController.text.trim();

    bool hasError = false;

    // 1. Full Name: Mandatory, at least 2 characters, letters only, max 50 chars
    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (name.isEmpty) {
      _nameError = 'Full Name is required';
      hasError = true;
    } else if (name.length < 2) {
      _nameError = 'Full Name must be at least 2 characters';
      hasError = true;
    } else if (name.length > 50) {
      _nameError = 'Full Name cannot exceed 50 characters';
      hasError = true;
    } else if (!nameRegex.hasMatch(name)) {
      _nameError = 'Full Name should only contain letters, spaces, and hyphens';
      hasError = true;
    } else {
      _nameError = null;
    }

    // 2. Email Address: Mandatory, valid email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty) {
      _emailError = 'Email Address is required';
      hasError = true;
    } else if (email.length > 100) {
      _emailError = 'Email Address cannot exceed 100 characters';
      hasError = true;
    } else if (!emailRegex.hasMatch(email)) {
      _emailError = 'Please enter a valid email address';
      hasError = true;
    } else {
      _emailError = null;
    }

    // 3. Date of Birth: Mandatory, format YYYY-MM-DD, cannot be in future
    final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    if (dob.isEmpty) {
      _dobError = 'Date of Birth is required';
      hasError = true;
    } else if (!dobRegex.hasMatch(dob) || DateTime.tryParse(dob) == null) {
      _dobError = 'Date of Birth must be in YYYY-MM-DD format (e.g. 1998-05-20)';
      hasError = true;
    } else {
      final parsed = DateTime.tryParse(dob)!;
      final now = DateTime.now();
      if (parsed.isAfter(now)) {
        _dobError = 'Date of birth cannot be in the future';
        hasError = true;
      } else if (parsed.isAfter(now.subtract(const Duration(days: 365 * 5)))) {
        _dobError = 'Date of birth must be a past date (at least 5 years ago)';
        hasError = true;
      } else if (parsed.year < 1920) {
        _dobError = 'Please enter a valid birth year';
        hasError = true;
      } else {
        _dobError = null;
      }
    }

    // 4. Gender: Mandatory
    if (_gender.trim().isEmpty) {
      _genderError = 'Please select your gender';
      hasError = true;
    } else {
      _genderError = null;
    }

    // 5. Spice Tolerance: Mandatory
    if (_spiceTolerance.trim().isEmpty) {
      _spiceError = 'Please select your spice tolerance';
      hasError = true;
    } else {
      _spiceError = null;
    }

    // 6. Preferred Regional Styles: Mandatory only if regions exist in the system
    if (appState.productRegions.isNotEmpty && _preferredRegions.isEmpty) {
      _regionError = 'Please select at least one preferred regional style';
      hasError = true;
    } else {
      _regionError = null;
    }

    if (hasError) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all mandatory fields to complete registration.'),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final response = await appState.updateProfileViaApi(
      fullName: name,
      email: email,
      dateOfBirth: dob,
      gender: _gender,
      spiceTolerance: _spiceTolerance,
      vegetarianOnly: _vegetarianOnly,
      excludeGarlic: _excludeGarlic,
      preferredRegionalStyles: _preferredRegions.toList(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (response.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF95D4AC), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Welcome to PickleO, $name!',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.leafGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        if (widget.onSetupComplete != null) {
          widget.onSetupComplete!();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message ?? 'Failed to save profile. Please try again.'),
            backgroundColor: AppColors.chilliRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showExitConfirmationDialog(AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel Setup?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        content: Text(
          'Your profile must be completed to finish signing in. If you leave now, you will remain signed out.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Continue Setup',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: AppColors.pickleOrange,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.chilliRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              appState.logout();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'Cancel & Sign Out',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);

    final spiceLevels = [
      {'id': 'Mild', 'label': 'Mild (Sweet & Tangy)'},
      {'id': 'Medium', 'label': 'Medium (Authentic)'},
      {'id': 'Fiery', 'label': 'Fiery (Andhra Hot)'},
    ];

    final genders = ['Female', 'Male', 'Other'];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _showExitConfirmationDialog(appState);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          automaticallyImplyLeading: false,
          title: Text(
            'Quick Profile Setup',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => _showExitConfirmationDialog(appState),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: _isSaving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    backgroundColor: AppColors.surfaceContainer,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.pickleOrange),
                    minHeight: 3,
                  ),
                )
              : null,
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const PickleOBrandBadge(),
              const SizedBox(height: 14),

              Text(
                'Welcome to PickleO Family!',
                textAlign: TextAlign.center,
                style: GoogleFonts.lora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Let our grandmas know who they are lovingly preparing batches for.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Verified Phone Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.orangeDark.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 16, color: AppColors.leafGreen),
                    const SizedBox(width: 6),
                    Text(
                      'Verified: +91 ${widget.phone}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Profile Form Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderCard),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A5D4037),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name (Mandatory)
                    Row(
                      children: [
                        Text(
                          'Full Name',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.chilliRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _nameError != null
                              ? AppColors.chilliRed
                              : (_nameController.text.trim().isNotEmpty
                                  ? AppColors.leafGreen
                                  : AppColors.surfaceHighest),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: TextField(
                        controller: _nameController,
                        enabled: !_isSaving,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-']")),
                          LengthLimitingTextInputFormatter(50),
                        ],
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: 'e.g. Priya Sharma',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: AppColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          if (_nameError != null && val.trim().isNotEmpty) {
                            setState(() => _nameError = null);
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    if (_nameError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _nameError!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.chilliRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Email Address (Mandatory)
                    Row(
                      children: [
                        Text(
                          'Email Address',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.chilliRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _emailError != null
                              ? AppColors.chilliRed
                              : (_emailController.text.trim().isNotEmpty
                                  ? AppColors.leafGreen
                                  : AppColors.surfaceHighest),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: TextField(
                        controller: _emailController,
                        enabled: !_isSaving,
                        keyboardType: TextInputType.emailAddress,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: 'e.g. priya@example.com',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 13.5,
                            color: AppColors.textTertiary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          if (_emailError != null) {
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (emailRegex.hasMatch(val.trim())) {
                              setState(() => _emailError = null);
                            }
                          } else {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    if (_emailError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _emailError!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.chilliRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Date of Birth (Mandatory)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Date of Birth',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '*',
                              style: TextStyle(
                                color: AppColors.chilliRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.redeem, size: 13, color: AppColors.leafGreen),
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
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _dobError != null
                              ? AppColors.chilliRed
                              : (_dobController.text.trim().isNotEmpty
                                  ? AppColors.leafGreen
                                  : AppColors.surfaceHighest),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dobController,
                              enabled: !_isSaving,
                              keyboardType: TextInputType.datetime,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
                                LengthLimitingTextInputFormatter(10),
                              ],
                              style: GoogleFonts.poppins(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hintText: 'YYYY-MM-DD (e.g. 1998-05-20)',
                                hintStyle: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  color: AppColors.textTertiary,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                if (_dobError != null) {
                                  final dobRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                                  if (dobRegex.hasMatch(val.trim())) {
                                    setState(() => _dobError = null);
                                  }
                                } else {
                                  setState(() {});
                                }
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_month,
                                size: 20, color: AppColors.leafGreen),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: _isSaving
                                ? null
                                : () async {
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime(
                                          now.year - 20, now.month, now.day),
                                      firstDate: DateTime(1920),
                                      lastDate: DateTime(now.year - 5),
                                    );
                                    if (picked != null) {
                                      final y = picked.year.toString().padLeft(4, '0');
                                      final m = picked.month.toString().padLeft(2, '0');
                                      final d = picked.day.toString().padLeft(2, '0');
                                      _dobController.text = '$y-$m-$d';
                                      setState(() {
                                        _dobError = null;
                                      });
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                    if (_dobError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _dobError!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.chilliRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Gender Chips (Mandatory)
                    Row(
                      children: [
                        Text(
                          'Gender',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.chilliRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: genders.map((g) {
                        final isSel = _gender == g;
                        return ChoiceChip(
                          label: Text(g),
                          selected: isSel,
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          selectedColor: AppColors.leafGreen,
                          backgroundColor: AppColors.surfaceLow,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                          ),
                          side: BorderSide(
                            color: isSel ? AppColors.leafGreen : AppColors.surfaceHighest,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: _isSaving
                              ? null
                              : (selected) {
                                  if (selected) {
                                    setState(() {
                                      _gender = g;
                                      _genderError = null;
                                    });
                                  }
                                },
                        );
                      }).toList(),
                    ),
                    if (_genderError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _genderError!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.chilliRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Spice Preference (Mandatory)
                    Row(
                      children: [
                        Text(
                          'Spice Tolerance',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '*',
                          style: TextStyle(
                            color: AppColors.chilliRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: spiceLevels.map((s) {
                        final isSel = _spiceTolerance == s['id'];
                        return ChoiceChip(
                          label: Text(s['label']!),
                          selected: isSel,
                          selectedColor: AppColors.pickleOrange,
                          backgroundColor: AppColors.surfaceLow,
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSel ? Colors.white : AppColors.textSecondary,
                          ),
                          side: BorderSide(
                            color: isSel ? AppColors.pickleOrange : AppColors.surfaceHighest,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          onSelected: _isSaving
                              ? null
                              : (selected) {
                                  if (selected) {
                                    setState(() {
                                      _spiceTolerance = s['id']!;
                                      _spiceError = null;
                                    });
                                  }
                                },
                        );
                      }).toList(),
                    ),
                    if (_spiceError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _spiceError!,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.chilliRed,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Dietary Preferences
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.eco, size: 18, color: AppColors.leafGreen),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Pure Vegetarian Only',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _vegetarianOnly,
                                activeColor: AppColors.leafGreen,
                                onChanged: _isSaving
                                    ? null
                                    : (val) => setState(() => _vegetarianOnly = val),
                              ),
                            ],
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.do_not_disturb_alt,
                                        size: 18, color: AppColors.orangeDark),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Exclude Garlic (Satvik)',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _excludeGarlic,
                                activeColor: AppColors.leafGreen,
                                onChanged: _isSaving
                                    ? null
                                    : (val) => setState(() => _excludeGarlic = val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Preferred Regional Styles (Mandatory when available)
                    if (appState.productRegions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Preferred Regional Styles',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(
                              color: AppColors.chilliRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select at least one regional flavor you love',
                        style: GoogleFonts.poppins(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 10,
                        children: appState.productRegions.map((r) {
                          final isSel = _preferredRegions.contains(r.name);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isSaving
                                  ? null
                                  : () {
                                      setState(() {
                                        if (isSel) {
                                          _preferredRegions.remove(r.name);
                                        } else {
                                          _preferredRegions.add(r.name);
                                          _regionError = null;
                                        }
                                        if (_preferredRegions.isEmpty) {
                                          _regionError =
                                              'Please select at least one regional style';
                                        }
                                      });
                                    },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? AppColors.leafGreen
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSel
                                        ? AppColors.leafGreen
                                        : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: isSel
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
                                            color: Colors.black
                                                .withValues(alpha: 0.03),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSel) ...[
                                      const Icon(
                                        Icons.check_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                    ],
                                    Text(
                                      r.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.5,
                                        fontWeight: isSel
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: isSel
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
                      if (_regionError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _regionError!,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.chilliRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                    ],

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : () => _submit(appState),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.pickleOrange,
                          disabledBackgroundColor:
                              AppColors.pickleOrange.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Complete Registration',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward,
                                        size: 18, color: Colors.white),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}
}

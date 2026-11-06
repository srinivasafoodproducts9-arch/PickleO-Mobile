import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_auth/smart_auth.dart';
import '../theme/app_theme.dart';
import '../widgets/pickleo_logo.dart';
import '../state/app_state.dart';
import '../services/auth_service.dart';
import '../models/referral.dart';
import 'main_navigation.dart';
import 'profile_setup_screen.dart';
import 'privacy_policy_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isOptional;
  final VoidCallback? onLoginSuccess;

  const AuthScreen({super.key, this.isOptional = true, this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  final SmartAuth _smartAuth = SmartAuth.instance;

  bool _isOtpStep = false;
  int _resendCountdown = 60;
  int _otpExpiresCountdown = 600;
  Timer? _timer;

  // Referral State
  ReferralValidation? _referralValidation;
  String? _activeReferralCode;
  String? _activeReferralMedium;
  bool _showReferralInput = false;
  bool _validatingReferral = false;

  @override
  void initState() {
    super.initState();
    _checkPendingReferral();
  }

  Future<void> _checkPendingReferral() async {
    final pending = await AuthService().getPendingReferral();
    if (pending != null && !pending.isExpired) {
      _activeReferralCode = pending.code;
      _activeReferralMedium = pending.medium;
      final val = await AuthService().validateReferralCode(pending.code);
      if (mounted) {
        setState(() {
          _referralValidation = val.data;
        });
      }
    }
  }

  Future<void> _validateManualReferralCode() async {
    final code = _referralCodeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _validatingReferral = true);
    final val = await AuthService().validateReferralCode(code);
    if (!mounted) return;
    setState(() {
      _validatingReferral = false;
      _referralValidation = val.data;
    });
    if (val.success && val.data?.valid == true) {
      _activeReferralCode = code;
      _activeReferralMedium = 'manual';
      await AuthService().savePendingReferral(code: code, medium: 'manual');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Referral code $code applied! ₹${val.data!.discountRs?.toInt() ?? 100} off on your first order.',
          ),
          backgroundColor: const Color(0xFF0F5132),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This referral code is no longer available or invalid.',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopSmsListener() async {
    try {
      await _smartAuth.removeUserConsentApiListener();
      await _smartAuth.removeSmsRetrieverApiListener();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stopSmsListener();
    _phoneController.dispose();
    _otpController.dispose();
    _referralCodeController.dispose();
    _otpFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  bool _isLoadingOtp = false;

  int _extractResendTime(Map<String, dynamic>? data) {
    if (data == null) return 60;

    // Direct check for retryAfter from consumer-login response (e.g. 60 seconds)
    final dynamic candidate =
        data['retryAfter'] ??
        data['retry_after'] ??
        data['time'] ??
        data['resendTime'] ??
        data['resend_time'] ??
        data['resendAfter'] ??
        data['resend_after'] ??
        data['cooldown'];

    if (candidate != null) {
      final parsed = _parseSeconds(candidate);
      if (parsed > 0) return parsed;
    }

    return 60;
  }

  int _extractExpiresTime(Map<String, dynamic>? data) {
    if (data == null) return 600;

    // Check expiresIn from consumer-login response (e.g. 600 seconds)
    final dynamic exp = data['expiresIn'] ?? data['expires_in'];
    if (exp != null) {
      final parsedExp = _parseSeconds(exp);
      if (parsedExp > 0) return parsedExp;
    }

    return 600;
  }

  int _parseSeconds(dynamic val) {
    if (val == null) return 0;
    if (val is num) return val.toInt();
    if (val is String) {
      final str = val.trim();
      if (str.contains(':')) {
        final parts = str.split(':');
        if (parts.length == 2) {
          final m = int.tryParse(parts[0]) ?? 0;
          final s = int.tryParse(parts[1]) ?? 0;
          return (m * 60) + s;
        }
      }
      return int.tryParse(str) ?? 0;
    }
    return 0;
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// Listens for incoming SMS via Android User Consent API / SMS Retriever
  void _listenForSmsOtp() async {
    try {
      await _stopSmsListener();
      final res = await _smartAuth.getSmsWithUserConsentApi(
        matcher: r'\b\d{6}\b',
      );

      if (!mounted || !_isOtpStep) return;

      if (res.hasData && res.data != null) {
        final smsData = res.data!;
        final rawCode = smsData.code ?? '';
        final match = RegExp(
          r'\b\d{6}\b',
        ).firstMatch(rawCode.isNotEmpty ? rawCode : smsData.sms);
        final extracted = match != null
            ? match.group(0)!
            : rawCode.replaceAll(RegExp(r'\D'), '');

        if (extracted.length == 6) {
          setState(() {
            _otpController.text = extracted;
            _otpController.selection = TextSelection.fromPosition(
              TextPosition(offset: extracted.length),
            );
          });

          // Automatically call verify OTP once auto-read
          if (!_isVerifyingOtp) {
            final appState = AppStateProvider.of(context);
            _verifyOtp(appState);
          }
        }
      }
    } catch (e) {
      debugPrint('SMS auto-read error: $e');
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a complete 10-digit mobile number.'),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid 10-digit mobile number starting with 6, 7, 8, or 9.',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoadingOtp = true);

    final response = await AuthService().sendOtp('+91$phone');

    if (!mounted) return;
    setState(() => _isLoadingOtp = false);

    if (response.success) {
      final resendTime = _extractResendTime(response.data);
      final expiresTime = _extractExpiresTime(response.data);
      _otpController.clear();
      setState(() {
        _isOtpStep = true;
        _resendCountdown = resendTime;
        _otpExpiresCountdown = expiresTime;
      });
      _startCountdown();
      _listenForSmsOtp();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _otpFocusNode.requestFocus();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF95D4AC),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  response.message ?? 'Verification code sent to +91 $phone',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message ?? 'Failed to send OTP. Please try again.',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    if (_isLoadingOtp || _isVerifyingOtp || _resendCountdown > 0) return;
    final phone = _phoneController.text.trim();
    if (phone.length != 10) return;

    setState(() => _isLoadingOtp = true);

    final response = await AuthService().resendOtp('+91$phone');

    if (!mounted) return;
    setState(() => _isLoadingOtp = false);

    if (response.success) {
      final resendTime = _extractResendTime(response.data);
      final expiresTime = _extractExpiresTime(response.data);
      _otpController.clear();
      setState(() {
        _resendCountdown = resendTime;
        _otpExpiresCountdown = expiresTime;
      });
      _startCountdown();
      _listenForSmsOtp();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF95D4AC),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  response.message ??
                      'New verification code sent to +91 $phone',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message ?? 'Failed to resend OTP. Please try again.',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        }
        if (_otpExpiresCountdown > 0) {
          _otpExpiresCountdown--;
        }
        if (_resendCountdown == 0 && _otpExpiresCountdown == 0) {
          timer.cancel();
        }
      });
    });
  }

  bool _isVerifyingOtp = false;

  Future<void> _verifyOtp(AppState appState) async {
    if (_isVerifyingOtp) return;
    if (_otpExpiresCountdown <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This OTP has expired. Please tap "Resend OTP" to request a new code.',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;

    _otpFocusNode.unfocus();
    setState(() => _isVerifyingOtp = true);

    final response = await appState.loginWithOtp(
      phone: phone,
      otp: otp,
      fullName: appState.userName.isNotEmpty ? appState.userName : null,
      referralCode: _activeReferralCode,
      referralMedium: _activeReferralMedium ?? 'manual',
    );

    if (!mounted) return;
    setState(() => _isVerifyingOtp = false);

    if (response.success) {
      TextInput.finishAutofillContext();
      _timer?.cancel();
      _stopSmsListener();

      if (response.referralAttribution?.accepted == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.celebration,
                  color: Color(0xFF95D4AC),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🎉 Referral offer applied! ₹${response.referralAttribution!.discountRs?.toInt() ?? 100} off coupon ready in cart.',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0F5132),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (response.referralAttribution?.isAlreadyCustomer == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.referralAttribution!.message ??
                  'This referral offer is for new customers.',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            backgroundColor: const Color(0xFF2C160E),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final profile = response.data;
      final bool isFirstTimeUser =
          profile == null ||
          profile.fullName.trim().isEmpty ||
          profile.fullName.trim() == 'PickleO Foodie';

      if (isFirstTimeUser) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileSetupScreen(
              phone: phone,
              onSetupComplete: widget.onLoginSuccess,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF95D4AC),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Welcome back, ${appState.userName}',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.textPrimary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainNavigation()),
            (route) => false,
          );
        }
      }
    } else {
      setState(() {
        _otpController.clear();
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _otpFocusNode.requestFocus();
          _listenForSmsOtp();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.message ??
                'Invalid verification code. Please check and try again.',
          ),
          backgroundColor: AppColors.chilliRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateProvider.of(context);
    final phoneText = _phoneController.text.trim();
    final bool is10Digits = phoneText.length == 10;
    final bool startsWithValidDigit =
        phoneText.isEmpty || RegExp(r'^[6-9]').hasMatch(phoneText);
    final bool isPhoneValid =
        is10Digits && RegExp(r'^[6-9]\d{9}$').hasMatch(phoneText);
    final otpText = _otpController.text.trim();
    final isOtpValid = otpText.length == 6;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 3),

            if (Navigator.of(context).canPop() || widget.isOptional)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Back',
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),

                        // PickleO App Icon & Wordmark matching prototype
                        const PickleOBrandBadge(size: 112, showWordmark: true),
                        const SizedBox(height: 16),

                        // Grandmas' Headline in Lora Serif
                        Text(
                          "Enter the world of Grandmas' Handcrafted Flavours",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lora(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          'Log in or sign up with your 10-digit mobile number to access exclusive artisanal batches',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Interactive Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderCard),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0F5D4037),
                                blurRadius: 14,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Segmented Stepper Tabs
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLow,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          if (_isOtpStep &&
                                              !_isLoadingOtp &&
                                              !_isVerifyingOtp) {
                                            _stopSmsListener();
                                            _timer?.cancel();
                                            _otpController.clear();
                                            setState(() => _isOtpStep = false);
                                          }
                                        },
                                        child: Container(
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: !_isOtpStep
                                                ? AppColors.leafGreen
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              9,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.phone,
                                                size: 16,
                                                color: !_isOtpStep
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '1. Phone Number',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: !_isOtpStep
                                                      ? Colors.white
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _isOtpStep
                                              ? AppColors.leafGreen
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.verified_user,
                                              size: 16,
                                              color: _isOtpStep
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '2. Enter OTP',
                                              style: GoogleFonts.poppins(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: _isOtpStep
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              if (!_isOtpStep) ...[
                                // Phone Number Step
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Mobile Number',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.local_shipping,
                                          size: 15,
                                          color: AppColors.orangeDark,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Delivers all across India',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.orangeDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Input Box with Indian Flag
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLow,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isPhoneValid
                                          ? AppColors.leafGreen
                                          : (phoneText.isNotEmpty &&
                                                    (!startsWithValidDigit ||
                                                        phoneText.length == 10)
                                                ? AppColors.chilliRed
                                                : AppColors.borderCard),
                                      width: isPhoneValid ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Indian Flag Strip
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(2),
                                        child: SizedBox(
                                          width: 20,
                                          height: 14,
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  color: const Color(
                                                    0xFFFF9933,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  color: const Color(
                                                    0xFF138808,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '+91',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _phoneController,
                                          enabled: !_isLoadingOtp,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                              10,
                                            ),
                                          ],
                                          maxLength: 10,
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                            color: AppColors.textPrimary,
                                          ),
                                          decoration: InputDecoration(
                                            filled: false,
                                            fillColor: Colors.transparent,
                                            counterText: '',
                                            hintText: 'Enter 10-digit number',
                                            hintStyle: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.textTertiary,
                                              letterSpacing: 0,
                                            ),
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      if (isPhoneValid)
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.leafGreen,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                                // Realtime Validation feedback helper
                                if (phoneText.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        isPhoneValid
                                            ? Icons.check_circle_rounded
                                            : (!startsWithValidDigit
                                                  ? Icons.error_outline_rounded
                                                  : Icons.info_outline_rounded),
                                        size: 14,
                                        color: isPhoneValid
                                            ? AppColors.leafGreen
                                            : (!startsWithValidDigit
                                                  ? AppColors.chilliRed
                                                  : AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          isPhoneValid
                                              ? 'Valid 10-digit mobile number'
                                              : (!startsWithValidDigit
                                                    ? 'Mobile number must start with 6, 7, 8, or 9'
                                                    : '${10 - phoneText.length} more digit${10 - phoneText.length == 1 ? '' : 's'} required (10 digits)'),
                                          style: GoogleFonts.poppins(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: isPhoneValid
                                                ? AppColors.leafGreen
                                                : (!startsWithValidDigit
                                                      ? AppColors.chilliRed
                                                      : AppColors
                                                            .textSecondary),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Referral Promotion Offer (if active pending referral exists)
                                if (_referralValidation != null &&
                                    _referralValidation!.valid) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDFF3E6),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF0F5132,
                                        ).withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.celebration,
                                          size: 20,
                                          color: Color(0xFF0F5132),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${_referralValidation!.referrerFirstName ?? 'Friend'} invited you!',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(
                                                    0xFF0F5132,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '₹${_referralValidation!.discountRs?.toInt() ?? 100} off your first order (min ₹${_referralValidation!.minOrder?.toInt() ?? 299}) with code $_activeReferralCode',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11.5,
                                                  color: const Color(
                                                    0xFF0F5132,
                                                  ),
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ] else ...[
                                  // Expandable manual referral code field
                                  GestureDetector(
                                    onTap: () => setState(
                                      () => _showReferralInput =
                                          !_showReferralInput,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            _showReferralInput
                                                ? Icons.remove_circle_outline
                                                : Icons.add_circle_outline,
                                            size: 14,
                                            color: AppColors.orangeDark,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Have a friend\'s referral code?',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.orangeDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_showReferralInput) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: 44,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLow,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppColors.borderCard,
                                              ),
                                            ),
                                            child: TextField(
                                              controller:
                                                  _referralCodeController,
                                              textCapitalization:
                                                  TextCapitalization.characters,
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Enter code (e.g. PRIYA100)',
                                                hintStyle: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                  color: AppColors.textTertiary,
                                                  letterSpacing: 0,
                                                ),
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          height: 44,
                                          child: ElevatedButton(
                                            onPressed: _validatingReferral
                                                ? null
                                                : _validateManualReferralCode,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF0F5132,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                  ),
                                            ),
                                            child: _validatingReferral
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Text(
                                                    'Apply',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                ],

                                // Shagun ₹50 voucher box
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.redeem,
                                        size: 18,
                                        color: AppColors.orangeDark,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Instant ₹50 shagun discount voucher auto-applies on your inaugural handcrafted jar!',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color:
                                                AppColors.onSecondaryContainer,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Get OTP Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: (isPhoneValid && !_isLoadingOtp)
                                        ? _sendOtp
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.pickleOrange,
                                      disabledBackgroundColor: AppColors
                                          .pickleOrange
                                          .withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isLoadingOtp
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Get OTP & Continue',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.arrow_forward,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ] else ...[
                                // OTP Step
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Enter 6-digit OTP',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        if (!_isLoadingOtp &&
                                            !_isVerifyingOtp) {
                                          _stopSmsListener();
                                          _timer?.cancel();
                                          _otpController.clear();
                                          setState(() => _isOtpStep = false);
                                        }
                                      },
                                      child: Text(
                                        'Sent to +91 $phoneText · Edit',
                                        style: GoogleFonts.poppins(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.orangeDark,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // OTP Expiry Countdown indicator based on expiresIn
                                Row(
                                  children: [
                                    Icon(
                                      _otpExpiresCountdown > 0
                                          ? Icons.access_time_rounded
                                          : Icons.error_outline_rounded,
                                      size: 13,
                                      color: _otpExpiresCountdown > 0
                                          ? AppColors.textSecondary
                                          : AppColors.chilliRed,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _otpExpiresCountdown > 0
                                          ? 'Code expires in ${_formatCountdown(_otpExpiresCountdown)}'
                                          : 'Code expired. Please request a new OTP.',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11.5,
                                        fontWeight: _otpExpiresCountdown > 0
                                            ? FontWeight.w400
                                            : FontWeight.w600,
                                        color: _otpExpiresCountdown > 0
                                            ? AppColors.textSecondary
                                            : AppColors.chilliRed,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // 6 Digit Visual Boxes stacked with invisible full-area input
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (!_isVerifyingOtp) {
                                      _otpFocusNode.requestFocus();
                                    }
                                  },
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: List.generate(6, (index) {
                                          final char = index < otpText.length
                                              ? otpText[index]
                                              : '';
                                          final isCurrent =
                                              index == otpText.length;
                                          final isFilled =
                                              index < otpText.length;

                                          return Container(
                                            width: 44,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceLow,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: isCurrent
                                                    ? AppColors.leafGreen
                                                    : (isFilled
                                                          ? AppColors
                                                                .onPrimaryContainer
                                                          : AppColors
                                                                .surfaceHighest),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                char,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),

                                      // Invisible Full-Sized Input overlay
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: 0.0,
                                          child: AutofillGroup(
                                            child: TextField(
                                              controller: _otpController,
                                              focusNode: _otpFocusNode,
                                              enabled: !_isVerifyingOtp,
                                              keyboardType:
                                                  TextInputType.number,
                                              autofillHints: const [
                                                AutofillHints.oneTimeCode,
                                              ],
                                              inputFormatters: [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                                LengthLimitingTextInputFormatter(
                                                  6,
                                                ),
                                              ],
                                              maxLength: 6,
                                              cursorColor: Colors.transparent,
                                              decoration: const InputDecoration(
                                                filled: false,
                                                fillColor: Colors.transparent,
                                                counterText: '',
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                disabledBorder:
                                                    InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true,
                                              ),
                                              onChanged: (val) {
                                                setState(() {});
                                                if (val.trim().length == 6 &&
                                                    !_isVerifyingOtp) {
                                                  _verifyOtp(appState);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Resend countdown
                                Center(
                                  child: _resendCountdown > 0
                                      ? Text(
                                          'Didn’t receive it? Resend in ${_formatCountdown(_resendCountdown)}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: _isLoadingOtp
                                              ? null
                                              : _resendOtp,
                                          child: _isLoadingOtp
                                              ? Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: AppColors
                                                                .orangeDark,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Resending code...',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: AppColors
                                                                .orangeDark,
                                                          ),
                                                    ),
                                                  ],
                                                )
                                              : Text(
                                                  'Didn’t receive it? Resend OTP',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.orangeDark,
                                                    decoration: TextDecoration
                                                        .underline,
                                                  ),
                                                ),
                                        ),
                                ),
                                const SizedBox(height: 16),

                                // Verify Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: (isOtpValid && !_isVerifyingOtp)
                                        ? () => _verifyOtp(appState)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.pickleOrange,
                                      disabledBackgroundColor: AppColors
                                          .pickleOrange
                                          .withValues(alpha: 0.5),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: _isVerifyingOtp
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'Verify & Continue',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.arrow_forward,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3 Trust Feature Badges
                        Row(
                          children: [
                            _buildTrustBadge(
                              Icons.soup_kitchen,
                              '100% Homemade',
                              'Zero preservatives',
                              AppColors.leafGreen,
                            ),
                            const SizedBox(width: 8),
                            _buildTrustBadge(
                              Icons.storefront,
                              'Heritage Kitchens',
                              'Grandma curated',
                              AppColors.orangeDark,
                            ),
                            const SizedBox(width: 8),
                            _buildTrustBadge(
                              Icons.verified,
                              'RBI Compliant',
                              'Secure 256-bit UPI',
                              AppColors.leafGreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Terms & Privacy
                        Column(
                          children: [
                            Text(
                              "By continuing, you agree to PickleO's Terms of Service &",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const PrivacyPolicyScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.leafGreen,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Privacy Policy',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // FSSAI Lic. Footer
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.leafGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'FSSAI Lic. No: 10020042000000 • Made with pure love in India',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadge(
    IconData icon,
    String title,
    String sub,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderCard),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 9.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

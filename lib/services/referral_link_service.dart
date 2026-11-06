import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:app_links/app_links.dart';
import '../models/referral.dart';
import '../theme/app_theme.dart';
import 'auth_service.dart';

/// Handles referral link resolution, deep links, App Links, and attribution persistence
class ReferralLinkService {
  static final ReferralLinkService instance = ReferralLinkService._();
  ReferralLinkService._();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  bool _initialized = false;

  /// Callback when a valid referral code is detected from a deep link
  void Function(PendingReferral referral, ReferralValidation? validation)?
      onReferralDetected;

  /// Initialize deep link listener for both cold start and warm start
  Future<void> initialize({
    void Function(PendingReferral referral, ReferralValidation? validation)?
        onReferral,
  }) async {
    if (_initialized) return;
    _initialized = true;

    _appLinks = AppLinks();
    if (onReferral != null) {
      onReferralDetected = onReferral;
    }

    // 1. Cold start: check if app was opened via a deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('Cold start deep link received: $initialUri');
        final result = await handleIncomingReferralUri(initialUri);
        if (result != null && onReferralDetected != null) {
          onReferralDetected!(result.referral, result.validation);
        }
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // 2. Warm start: listen to incoming links while app is in memory
    try {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) async {
          debugPrint('Warm start deep link stream received: $uri');
          final result = await handleIncomingReferralUri(uri);
          if (result != null && onReferralDetected != null) {
            onReferralDetected!(result.referral, result.validation);
          }
        },
        onError: (err) {
          debugPrint('Error in deep link stream: $err');
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to deep link stream: $e');
    }
  }

  /// Parse and validate an incoming referral URI
  ///
  /// Supported formats:
  /// - https://pickleo.in/r/<CODE>?m=wa
  /// - https://www.pickleo.in/r/<CODE>?m=wa
  /// - pickleo://refer?code=<CODE>&m=wa
  /// - pickleo://r/<CODE>?m=wa
  Future<ReferralLinkResult?> handleIncomingReferralUri(Uri uri) async {
    try {
      String? code;
      String? medium;

      // 1. Custom scheme: pickleo://
      if (uri.scheme == 'pickleo') {
        if (uri.host == 'refer' || uri.path == '/refer') {
          code = uri.queryParameters['code'];
          medium = uri.queryParameters['m'] ??
              uri.queryParameters['medium'] ??
              uri.queryParameters['utm_medium'];
        } else if (uri.host == 'r' || uri.path.startsWith('/r')) {
          code = uri.queryParameters['code'];
          if (code == null || code.isEmpty) {
            if (uri.pathSegments.isNotEmpty) {
              code = uri.pathSegments.last;
            }
          }
          medium = uri.queryParameters['m'] ??
              uri.queryParameters['medium'] ??
              uri.queryParameters['utm_medium'];
        }
      }
      // 2. HTTP/HTTPS App Links: pickleo.in or pickleo.co.in
      else if (uri.host.contains('pickleo.in') ||
          uri.host.contains('pickleo.co.in')) {
        if (uri.pathSegments.isNotEmpty && uri.pathSegments.first == 'r') {
          if (uri.pathSegments.length >= 2) {
            code = uri.pathSegments[1];
          }
        }
        code ??= uri.queryParameters['code'] ??
            uri.queryParameters['referralCode'];
        medium = uri.queryParameters['m'] ??
            uri.queryParameters['medium'] ??
            uri.queryParameters['utm_medium'];
      }

      if (code != null && code.trim().isNotEmpty) {
        final cleanCode = code.trim().toUpperCase();
        final cleanMedium = (medium != null && medium.trim().isNotEmpty)
            ? medium.trim().toLowerCase()
            : 'wa';

        debugPrint(
            'Referral deep link detected: code=$cleanCode, medium=$cleanMedium');

        // Check validity via public validation endpoint before saving
        final validationRes =
            await AuthService().validateReferralCode(cleanCode);
        if (validationRes.success && validationRes.data?.valid == true) {
          await AuthService().savePendingReferral(
            code: cleanCode,
            medium: cleanMedium,
          );
          final pending = PendingReferral(
            code: cleanCode,
            medium: cleanMedium,
            clickedAt: DateTime.now(),
          );
          return ReferralLinkResult(
            referral: pending,
            validation: validationRes.data,
          );
        } else {
          debugPrint(
              'Referral code $cleanCode is inactive, expired, or invalid.');
        }
      }
    } catch (e) {
      debugPrint('Error handling referral deep link: $e');
    }
    return null;
  }

  /// Show a user-friendly celebratory notification when a referral link is opened
  static void showReferralWelcomeDialog(
    BuildContext context, {
    required String code,
    ReferralValidation? validation,
  }) {
    final referrer = validation?.referrerFirstName ?? 'A friend';
    final discount = validation?.discountRs?.toInt() ?? 100;
    final minOrder = validation?.minOrder?.toInt() ?? 299;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFFFFF8F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF0F5132),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFF95D4AC),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '₹$discount Off Your First Jar!',
              style: GoogleFonts.lora(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2C160E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '$referrer invited you to try PickleO handcrafted pickles. Your ₹$discount discount has been automatically applied to your account!',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF95D4AC), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF0F5132), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Code $code Applied',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F5132),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (minOrder > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Valid on your first order of ₹$minOrder or more',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pickleOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Explore Pickles',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}

/// Helper container for parsed referral link result
class ReferralLinkResult {
  final PendingReferral referral;
  final ReferralValidation? validation;

  const ReferralLinkResult({
    required this.referral,
    this.validation,
  });
}

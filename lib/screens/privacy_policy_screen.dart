import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    _PrivacySectionData(
      icon: Icons.person_outline_rounded,
      title: 'Account information',
      description:
          'When you create or update an account, PickleO uses the details you provide to identify you and manage your account.',
      details: [
        'Phone number used for one-time-password sign-in',
        'Profile details and preferences you choose to provide',
        'Delivery addresses and any profile photo you upload',
      ],
    ),
    _PrivacySectionData(
      icon: Icons.shopping_bag_outlined,
      title: 'Orders and payments',
      description:
          'Your cart and order details help us confirm purchases, arrange delivery, and assist with order questions.',
      details: [
        'Payment processing is provided through Razorpay',
        'Payment providers handle payment information under their own privacy terms',
      ],
    ),
    _PrivacySectionData(
      icon: Icons.location_on_outlined,
      title: 'Location',
      description:
          'If you allow location access, PickleO uses your device location to help identify your delivery area. You can manage this permission in your device settings.',
    ),
    _PrivacySectionData(
      icon: Icons.notifications_none_rounded,
      title: 'App notifications',
      description:
          'PickleO uses a device notification token to send app notifications, including updates related to your orders. You can turn notifications off in your device settings.',
    ),
    _PrivacySectionData(
      icon: Icons.tune_rounded,
      title: 'Your choices',
      description:
          'You can review or update profile information and preferences in Account. To request account deletion, use Delete Account in Account settings. Device permissions and notifications can be changed in your device settings.',
    ),
  ];

  Future<void> _contactPrivacySupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@pickleo.co.in',
      queryParameters: {'subject': 'PickleO privacy enquiry'},
    );
    final opened = await launchUrl(uri);
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open your email app. Please email support@pickleo.co.in.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: const [UserAvatar(radius: 16), SizedBox(width: 16)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.leafGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: AppColors.onPrimaryContainer,
                        size: 28,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your privacy matters',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Here is a plain-language overview of information used to provide PickleO features.',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                height: 1.5,
                                color: AppColors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'PRIVACY AT A GLANCE',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                for (final section in _sections) ...[
                  _PrivacySection(data: section),
                  const SizedBox(height: 10),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderCard),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Questions about your privacy?',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Contact the PickleO support team.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _contactPrivacySupport(context),
                        icon: const Icon(Icons.email_outlined, size: 18),
                        label: const Text('support@pickleo.co.in'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.leafGreen,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacySectionData {
  final IconData icon;
  final String title;
  final String description;
  final List<String> details;

  const _PrivacySectionData({
    required this.icon,
    required this.title,
    required this.description,
    this.details = const [],
  });
}

class _PrivacySection extends StatelessWidget {
  final _PrivacySectionData data;

  const _PrivacySection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              Icon(data.icon, size: 21, color: AppColors.orangeDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  data.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            data.description,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (data.details.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final detail in data.details)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: AppColors.leafGreen,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        detail,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

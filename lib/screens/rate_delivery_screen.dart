import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../state/app_state.dart';
import '../models/order.dart';
import '../widgets/user_avatar.dart';
import 'main_navigation.dart';

class RateDeliveryScreen extends StatefulWidget {
  final String orderId;
  final OrderRating? initialRating;

  const RateDeliveryScreen({super.key, required this.orderId, this.initialRating});

  @override
  State<RateDeliveryScreen> createState() => _RateDeliveryScreenState();
}

class _RateDeliveryScreenState extends State<RateDeliveryScreen> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  Uint8List? _selectedPhotoBytes;
  String? _selectedPhotoName;
  String _selectedPhotoContentType = 'image/jpeg';
  bool _isSubmitting = false;

  final Map<String, bool> _tags = {
    'Authentic Grandmother Taste': true,
    'Safe Glass Packaging': true,
    'Fresh Spices': false,
    'On-time Delivery': false,
    'Aromatic Oils': false,
    'Crisp Texture': false,
  };

  final List<String> _ratingLabels = [
    '',
    '1/5 Not great',
    '2/5 Could be better',
    '3/5 Good',
    '4/5 Really liked it',
    '5/5 Loved it!',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialRating != null) {
      _rating = widget.initialRating!.rating;
      if (widget.initialRating!.feedback != null) {
        _commentController.text = widget.initialRating!.feedback!;
      }
      for (final t in widget.initialRating!.tags) {
        if (_tags.containsKey(t)) {
          _tags[t] = true;
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoName = picked.name;
          _selectedPhotoContentType = picked.name.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Upload Photo of Your Jar',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.leafGreen),
                title: Text('Take Photo', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.pickleOrange),
                title: Text('Choose from Gallery', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final appState = AppStateProvider.of(context);
    final selectedTags = _tags.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final resp = await appState.submitRating(
      orderId: widget.orderId,
      rating: _rating,
      tags: selectedTags,
      feedback: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      photoBytes: _selectedPhotoBytes,
      photoContentType: _selectedPhotoContentType,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final isFirstReward = resp.statusCode == 201;
    final isReplay = resp.statusCode == 200;
    final points = (resp.data != null && resp.data!.rewardPoints > 0)
        ? resp.data!.rewardPoints
        : 50;

    String toastText;
    if (isFirstReward) {
      toastText = 'Thanks! +$points Spice Points added';
    } else if (isReplay) {
      toastText = 'Rating updated! Thanks for your feedback.';
    } else if (resp.success) {
      toastText = 'Rating recorded! Thanks for your feedback.';
    } else {
      toastText = 'Rating recorded! +$points Spice Points added';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF95D4AC), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                toastText,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
    );

    // Refresh server loyalty and wallet balances
    try {
      final appState = AppStateProvider.of(context);
      appState.loadLoyaltyFromApi();
      appState.loadWalletFromApi();
    } catch (_) {}

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigation(initialIndex: 3)),
        (route) => false,
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
          'Rate Delivery',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: const [
          UserAvatar(radius: 16),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How was your Delivery Experience?',
              style: GoogleFonts.lora(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Order #${widget.orderId} • Delivered Yesterday',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),

            // Big 5-Star Interactive Rating Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderCard),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starNumber = index + 1;
                      final isSelected = starNumber <= _rating;

                      return GestureDetector(
                        onTap: () => setState(() => _rating = starNumber),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.star,
                            size: 42,
                            color: isSelected
                                ? AppColors.spiceYellow
                                : AppColors.surfaceHighest,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _ratingLabels[_rating],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // What delighted your palate?
            Text(
              'What delighted your palate?',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.keys.map((tag) {
                final isSelected = _tags[tag] ?? false;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _tags[tag] = !isSelected;
                    });
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.leafGreen : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.leafGreen
                            : AppColors.borderCard,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          const Icon(Icons.check, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          tag,
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
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Detailed Feedback
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detailed Feedback',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Optional',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceHighest),
              ),
              child: TextField(
                controller: _commentController,
                maxLines: 4,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Tell us about the taste, packaging, or delivery…',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13.5,
                    color: AppColors.textTertiary,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Add photo card / attached photo preview
            if (_selectedPhotoBytes != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.leafGreen.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _selectedPhotoBytes!,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, size: 15, color: AppColors.leafGreen),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _selectedPhotoName ?? 'Jar photo attached',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '+50 PickleCoins bonus unlocked!',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.leafGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                      onPressed: () {
                        setState(() {
                          _selectedPhotoBytes = null;
                          _selectedPhotoName = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              GestureDetector(
                onTap: _showImageSourcePicker,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.photo_camera_outlined,
                            size: 24, color: AppColors.leafGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add photo of your pickle jar',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Earn 50 PickleCoins extra',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.orangeDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle,
                          size: 26, color: AppColors.leafGreen),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Submit Review Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReview,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.pickleOrange,
                  disabledBackgroundColor: AppColors.pickleOrange.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Submit Review',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

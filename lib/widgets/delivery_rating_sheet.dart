import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/app_state.dart';

class DeliveryRatingSheet extends StatefulWidget {
  final String orderId;
  const DeliveryRatingSheet({
    super.key,
    this.orderId = 'PKL-87211',
  });

  static Future<void> show(BuildContext context, {String orderId = 'PKL-87211'}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DeliveryRatingSheet(orderId: orderId),
    );
  }

  @override
  State<DeliveryRatingSheet> createState() => _DeliveryRatingSheetState();
}

class _DeliveryRatingSheetState extends State<DeliveryRatingSheet> {
  int _rating = 5;
  final Set<String> _selectedTags = {
    'Authentic Grandmother Taste',
    'Safe Glass Packaging',
  };

  final List<String> _allTags = [
    'Authentic Grandmother Taste',
    'Safe Glass Packaging',
    'Fresh Spices',
    'On-time Delivery',
    'Aromatic Oils',
    'Crisp Texture',
  ];

  late final TextEditingController _feedbackController;
  bool _photoAdded = false;
  bool _submitted = false;
  bool _isSubmitting = false;
  bool _earnedBonus = false;

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController(
      text: 'The Avakaya brought back genuine childhood memories of Vijayawada! Superbly packed with zero leakage.',
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String get _ratingLabel {
    switch (_rating) {
      case 5:
        return '5/5 Loved it! 🔥';
      case 4:
        return '4/5 Very Delicious!';
      case 3:
        return '3/5 Good Flavor';
      case 2:
        return '2/5 Needs More Salt/Oil';
      case 1:
        return '1/5 Disappointing';
      default:
        return '5/5 Loved it!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x332C160E),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            bottomInset > 0 ? bottomInset + 16 : 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC0C9C0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header & Close
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TASTE EXPERIENCE',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: const Color(0xFFF57C00),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'How was your PickleO Experience?',
                          style: GoogleFonts.lora(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2C160E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Order #${widget.orderId} • Delivered Yesterday',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF404942),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE2DA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF2C160E)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (_submitted) ...[
                // Success feedback state
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF84C39B)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.stars, color: Color(0xFF0F5132), size: 48),
                      const SizedBox(height: 10),
                      Text(
                        'Review Submitted! 🎉',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F5132),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _earnedBonus
                            ? '+50 Spice Points added to your account for supporting grandma\'s kitchen recipes!'
                            : 'Thank you! Your feedback has been recorded successfully.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF404942),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F5132),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Back to App'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Star Rating Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A2C160E),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          final isFilled = star <= _rating;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _rating = star;
                              });
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                isFilled ? Icons.star : Icons.star_border,
                                size: 38,
                                color: const Color(0xFFD2A500),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE2DA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 15,
                              color: Color(0xFFD2A500),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _ratingLabel,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2C160E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Delight Tags
                Text(
                  'What delighted your palate?',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2C160E),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allTags.map((tag) {
                    final isSelected = _selectedTags.contains(tag);
                    return InkWell(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedTags.remove(tag);
                          } else {
                            _selectedTags.add(tag);
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF0F5132) : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x082C160E),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              tag,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF404942),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Detailed Feedback
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Detailed Feedback',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2C160E),
                      ),
                    ),
                    Text(
                      'Optional',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF707971),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x082C160E),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: const Color(0xFF2C160E),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write a few words about the aroma, crunch and taste...',
                      hintStyle: TextStyle(color: Color(0xFF707971), fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Photo Upload Box
                InkWell(
                  onTap: () {
                    setState(() {
                      _photoAdded = !_photoAdded;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _photoAdded ? const Color(0xFFE8F5E9) : const Color(0xFFFFF1ED),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _photoAdded ? const Color(0xFF84C39B) : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _photoAdded ? const Color(0xFF0F5132) : const Color(0xFFFFE2DA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _photoAdded ? Icons.check_circle : Icons.add_a_photo,
                            size: 20,
                            color: _photoAdded ? Colors.white : const Color(0xFF003820),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _photoAdded ? 'Jar photo attached ✓' : 'Add photo (optional)',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF2C160E),
                                ),
                              ),
                              Text(
                                '50 Spice Points awarded on review',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF964900),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _photoAdded ? Icons.check : Icons.add_circle,
                          color: const Color(0xFF003820),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            setState(() => _isSubmitting = true);
                            final appState = AppStateProvider.of(context);
                            final resp = await appState.rateOrder(
                              orderId: widget.orderId,
                              rating: _rating,
                              tags: _selectedTags.toList(),
                              feedback: _feedbackController.text.trim(),
                            );
                            if (!mounted) return;
                            setState(() {
                              _isSubmitting = false;
                              _submitted = true;
                              _earnedBonus = resp.statusCode == 201;
                            });
                          },
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.stars, size: 18, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Review (+50 Points)',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFC820C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

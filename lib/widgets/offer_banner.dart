import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/offer.dart';
import 'shimmer_loading.dart';

/// A dynamic Offers & Deals section for the home dashboard.
/// Displays active offers with image banners, discount badges, and a prominent
/// 'Copy Code' button overlay directly on the offer image.
class DynamicOffersSection extends StatefulWidget {
  final List<OfferItem> offers;
  final bool isLoading;
  final Function(String code) onApplyCode;

  const DynamicOffersSection({
    super.key,
    required this.offers,
    this.isLoading = false,
    required this.onApplyCode,
  });

  @override
  State<DynamicOffersSection> createState() => _DynamicOffersSectionState();
}

class _DynamicOffersSectionState extends State<DynamicOffersSection> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoPlayTimer;
  bool _isInteracting = false;
  final Set<String> _recentlyCopiedCodes = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant DynamicOffersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      if (_currentPage >= widget.offers.length) {
        _currentPage = 0;
      }
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.offers.length <= 1) return;

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 6), (timer) {
      if (!_isInteracting && _pageController.hasClients) {
        final nextPage = (_currentPage + 1) % widget.offers.length;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _copyCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    HapticFeedback.lightImpact();

    setState(() {
      _recentlyCopiedCodes.add(code);
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _recentlyCopiedCodes.remove(code);
        });
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: const Color(0xFF003820),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Color(0xFF95D4AC), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
                  children: [
                    const TextSpan(text: 'Offer code '),
                    TextSpan(
                      text: code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFDCC6),
                      ),
                    ),
                    const TextSpan(text: ' copied to clipboard!'),
                  ],
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'APPLY NOW',
          textColor: const Color(0xFFFFB74D),
          onPressed: () {
            widget.onApplyCode(code);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State Shimmer
    if (widget.isLoading && widget.offers.isEmpty) {
      return _buildLoadingPlaceholder();
    }

    // 2. Empty State: No active offers to display
    if (widget.offers.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeOffers = widget.offers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Offers Pill
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEDE8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      size: 18,
                      color: Color(0xFFF57C00),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EXCLUSIVE OFFERS',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: const Color(0xFF964900),
                        ),
                      ),
                      Text(
                        'Save on Traditional Flavors',
                        style: GoogleFonts.lora(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2C160E),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (activeOffers.length > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0EA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFBD1C4)),
                  ),
                  child: Text(
                    '${_currentPage + 1}/${activeOffers.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF964900),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Carousel or Single Card
        if (activeOffers.length == 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _buildOfferCard(context, activeOffers.first),
          )
        else
          Column(
            children: [
              SizedBox(
                height: 150,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _isInteracting = true;
                    } else if (notification is ScrollEndNotification) {
                      _isInteracting = false;
                      _startAutoPlay();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: activeOffers.length,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentPage = idx;
                      });
                    },
                    itemBuilder: (context, index) {
                      final offer = activeOffers[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildOfferCard(context, offer),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(activeOffers.length, (idx) {
                  final isCurrent = idx == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isCurrent ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFFF57C00)
                          : const Color(0xFFE0D5C9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ],
          ),
      ],
    );
  }

  /// Builds a unified offer card with background image, title, description, and copy code button.
  Widget _buildOfferCard(BuildContext context, OfferItem offer) {
    final hasCopied = _recentlyCopiedCodes.contains(offer.code);
    final descriptionText = offer.description.trim().isNotEmpty
        ? offer.description.trim()
        : (offer.discountBadgeText.isNotEmpty
            ? 'Get ${offer.discountBadgeText} on your order'
            : 'Exclusive deal on traditional flavors');

    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C160E).withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _copyCode(context, offer.code),
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image
              _buildCardBackgroundImage(offer),

              // 2. High-contrast Gradient Scrim
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF140A05).withValues(alpha: 0.88),
                      const Color(0xFF140A05).withValues(alpha: 0.55),
                      const Color(0xFF140A05).withValues(alpha: 0.78),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // 3. Card Content: Title, Description & Copy Code
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      descriptionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35,
                        shadows: const [
                          Shadow(
                            color: Colors.black45,
                            offset: Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // Copy Code Button on Bottom Right
                    Align(
                      alignment: Alignment.bottomRight,
                      child: _buildCopyButton(context, offer, hasCopied),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the background image for the offer card with resilient fallbacks
  Widget _buildCardBackgroundImage(OfferItem offer) {
    if (offer.imageUrl.trim().isNotEmpty) {
      return Image.network(
        offer.imageUrl.trim(),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildFallbackAssetImage(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const ShimmerLoading(
            child: ColoredBox(color: Color(0xFF2C160E)),
          );
        },
      );
    }
    return _buildFallbackAssetImage();
  }

  /// Fallback placeholder when offer image cannot be loaded
  Widget _buildFallbackAssetImage() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF421508), Color(0xFF8B2500), Color(0xFFC85A17)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  /// Prominent 'Copy Code' pill button
  Widget _buildCopyButton(
      BuildContext context, OfferItem offer, bool hasCopied) {
    return InkWell(
      onTap: () => _copyCode(context, offer.code),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasCopied
              ? const Color(0xFF003820)
              : const Color(0xFF1B1B1B).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasCopied
                ? const Color(0xFF95D4AC)
                : const Color(0xFFFFB74D),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCopied
                  ? Icons.check_circle_rounded
                  : Icons.copy_rounded,
              size: 14,
              color: hasCopied
                  ? const Color(0xFF95D4AC)
                  : const Color(0xFFFFB74D),
            ),
            const SizedBox(width: 5),
            Text(
              hasCopied ? 'COPIED!' : offer.code,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
            if (!hasCopied) ...[
              const SizedBox(width: 4),
              Text(
                'COPY',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFB74D),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shimmer loading skeleton matching the compact card height
  Widget _buildLoadingPlaceholder() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      height: 150,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: const ShimmerLoading(
          child: ColoredBox(color: Color(0xFFE6DED6)),
        ),
      ),
    );
  }
}



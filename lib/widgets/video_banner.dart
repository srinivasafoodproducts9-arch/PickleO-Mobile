import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../models/banner.dart';
import 'shimmer_loading.dart';

/// Full-featured dynamic banner component supporting both video and image banners
class DynamicHomeBanner extends StatefulWidget {
  final List<HomeBanner> banners;
  final bool isLoading;
  final VoidCallback onShopNow;

  const DynamicHomeBanner({
    super.key,
    required this.banners,
    this.isLoading = false,
    required this.onShopNow,
  });

  @override
  State<DynamicHomeBanner> createState() => _DynamicHomeBannerState();
}

class _DynamicHomeBannerState extends State<DynamicHomeBanner> {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoPlayTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _resetAutoPlayTimer();
  }

  @override
  void didUpdateWidget(covariant DynamicHomeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      if (_currentIndex >= widget.banners.length) {
        _currentIndex = 0;
      }
      _resetAutoPlayTimer();
    }
  }

  void _resetAutoPlayTimer() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length <= 1) return;

    // Check if the current banner is a video - if so, give it longer time or don't interrupt
    final isVideo = _currentIndex < widget.banners.length &&
        widget.banners[_currentIndex].isVideo;

    _autoPlayTimer = Timer.periodic(
      Duration(seconds: isVideo ? 12 : 5),
      (timer) {
        if (!_isInteracting && _pageController.hasClients) {
          final nextIndex = (_currentIndex + 1) % widget.banners.length;
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (widget.isLoading && widget.banners.isEmpty) {
      return _buildLoadingShimmer();
    }

    // 2. Empty State (No static banner when API returns empty)
    if (widget.banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bannerRatio =
        screenWidth >= 1000 ? 3.0 : (screenWidth >= 600 ? 2.5 : 2.0);

    // 3. Dynamic Banners Carousel (Image & Video)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AspectRatio(
        aspectRatio: bannerRatio,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5D4037).withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _isInteracting = true;
                } else if (notification is ScrollEndNotification) {
                  _isInteracting = false;
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.banners.length,
                onPageChanged: (idx) {
                  setState(() => _currentIndex = idx);
                  _resetAutoPlayTimer();
                },
                itemBuilder: (context, index) {
                  final banner = widget.banners[index];
                  final isCurrent = index == _currentIndex;

                  if (banner.isVideo) {
                    return _buildVideoBannerItem(banner, isCurrent);
                  } else {
                    return _buildImageBannerItem(banner);
                  }
                },
              ),
            ),

            // Top Status Badge (only for VIDEO)
            if (widget.banners.isNotEmpty &&
                _currentIndex < widget.banners.length &&
                widget.banners[_currentIndex].isVideo)
              Positioned(
                top: 12,
                right: 14,
                child: _buildMediaBadge(widget.banners[_currentIndex]),
              ),

            // Bottom Pagination Indicator Dots (if multiple banners)
            if (widget.banners.length > 1)
              Positioned(
                bottom: 12,
                right: 16,
                child: Row(
                  children: List.generate(
                    widget.banners.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(left: 4),
                      width: _currentIndex == index ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? const Color(0xFFF57C00)
                            : Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(3),
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
);
  }

  Widget _buildMediaBadge(HomeBanner banner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'VIDEO',
            style: GoogleFonts.poppins(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBannerItem(HomeBanner banner, bool isCurrent) {
    final validUrl = _isValidUrl(banner.mediaUrl);

    return GestureDetector(
      onTap: widget.onShopNow,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (validUrl)
            BannerVideoPlayer(
              videoUrl: banner.mediaUrl,
              isCurrent: isCurrent,
            )
          else
            const ShimmerLoading(
              child: ColoredBox(color: Color(0xFFE6DED6)),
            ),

          // Gradient overlay for text legibility at bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.45, 0.85],
              ),
            ),
          ),

          // Banner Title at bottom
          if (banner.title.isNotEmpty && banner.title != 'string')
            Positioned(
              left: 16,
              right: widget.banners.length > 1 ? 75 : 16,
              bottom: 14,
              child: Text(
                banner.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.25,
                  shadows: const [
                    Shadow(
                      color: Colors.black54,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageBannerItem(HomeBanner banner) {
    final validUrl = _isValidUrl(banner.mediaUrl);

    return GestureDetector(
      onTap: widget.onShopNow,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (validUrl)
            Image.network(
              banner.mediaUrl,
              fit: BoxFit.fill,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const ShimmerLoading(
                  child: ColoredBox(color: Color(0xFFF1EAE4)),
                );
              },
              errorBuilder: (_, __, ___) => _buildFallbackImagePlaceholder(),
            )
          else
            _buildFallbackImagePlaceholder(),

          // Subtle gradient at bottom for text and dots legibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.black.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                stops: const [0.0, 0.25, 0.55],
              ),
            ),
          ),

          // Title at bottom
          if (banner.title.isNotEmpty && banner.title != 'string')
            Positioned(
              left: 14,
              right: widget.banners.length > 1 ? 75 : 14,
              bottom: 10,
              child: Text(
                banner.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                  shadows: const [
                    Shadow(
                      color: Colors.black87,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFallbackImagePlaceholder() {
    return const ShimmerLoading(
      child: ColoredBox(color: Color(0xFFE6DED6)),
    );
  }

  Widget _buildLoadingShimmer() {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerRatio =
        screenWidth >= 1000 ? 3.0 : (screenWidth >= 600 ? 2.5 : 2.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: AspectRatio(
        aspectRatio: bannerRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: const ShimmerLoading(
            child: ColoredBox(color: Color(0xFFE6DED6)),
          ),
        ),
      ),
    );
  }

  bool _isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final clean = url.trim().toLowerCase();
    if (clean == 'string' || clean == 'null') return false;
    return clean.startsWith('http://') || clean.startsWith('https://');
  }
}

/// Robust inline video player for banner carousel
class BannerVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isCurrent;

  const BannerVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isCurrent,
  });

  @override
  State<BannerVideoPlayer> createState() => _BannerVideoPlayerState();
}

class _BannerVideoPlayerState extends State<BannerVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _userPaused = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      final controller = VideoPlayerController.networkUrl(uri);
      _controller = controller;

      await controller.initialize();
      if (!mounted) return;

      await controller.setLooping(true);
      await controller.setVolume(_isMuted ? 0.0 : 1.0);

      if (widget.isCurrent && !_userPaused) {
        await controller.play();
      }

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error loading banner video: $e');
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void didUpdateWidget(covariant BannerVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _isInitialized = false;
      _hasError = false;
      _initController();
    } else if (oldWidget.isCurrent != widget.isCurrent) {
      if (widget.isCurrent) {
        if (!_userPaused && _controller != null && _isInitialized) {
          _controller?.play();
        }
      } else {
        _controller?.pause();
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _userPaused = true;
      } else {
        _controller!.play();
        _userPaused = false;
      }
    });
  }

  void _toggleMute() {
    if (_controller == null || !_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF003820),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, color: Colors.white54, size: 40),
              SizedBox(height: 6),
              Text(
                'Unable to stream video',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Container(
        color: const Color(0xFF003820),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF57C00),
            strokeWidth: 2,
          ),
        ),
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      onTap: _togglePlayPause,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fitted Video
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),

          // Mute / Unmute Button (Top Left)
          Positioned(
            top: 12,
            left: 14,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isMuted ? 'Muted' : 'Sound On',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Play / Pause Overlay Icon when paused
          if (!isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

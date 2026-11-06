import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'onboarding_screen.dart';
import 'main_navigation.dart';
import '../services/notification_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  bool _hasNavigated = false;
  Timer? _safetyTimer;

  @override
  void initState() {
    super.initState();
    _initSplashVideo();
  }

  Future<void> _initSplashVideo() async {
    // Safety max timer (6.5s) to guarantee navigation even if playback stalls
    _safetyTimer = Timer(const Duration(milliseconds: 6500), () {
      _navigateToNext();
    });

    try {
      final controller =
          VideoPlayerController.asset('assets/videos/pickleo_splash.mp4');
      _videoController = controller;

      await controller.initialize();
      if (!mounted) {
        controller.dispose();
        return;
      }

      await controller.setLooping(false);
      // Mute to avoid interrupting any background audio (YouTube, Spotify, etc.)
      await controller.setVolume(0.0);

      controller.addListener(_videoListener);
      await controller.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _hasVideoError = false;
        });
      }
    } catch (e) {
      debugPrint('Splash video error (placeholder fallback used): $e');
      if (mounted) {
        setState(() {
          _hasVideoError = true;
        });
        // In headless/test environments where video player is not implemented,
        // navigate after 2.6s
        _safetyTimer?.cancel();
        _safetyTimer = Timer(const Duration(milliseconds: 2600), () {
          _navigateToNext();
        });
      }
    }
  }

  void _videoListener() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;

    final position = controller.value.position;
    final duration = controller.value.duration;

    // Navigate immediately when the video finishes
    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 150)) {
      _navigateToNext();
    }
  }

  Future<void> _navigateToNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    _safetyTimer?.cancel();
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      try {
        _videoController!.pause();
      } catch (_) {}
    }

    bool hasSeenOnboarding = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    } catch (_) {
      // Fallback for testing environments
    }

    if (!mounted) return;

    final Widget nextScreen =
        hasSeenOnboarding ? const MainNavigation() : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );

    NotificationService.instance.checkPendingNavigation();
  }

  @override
  void dispose() {
    _safetyTimer?.cancel();
    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      _videoController!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToNext,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5EE),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Instant first frame placeholder (eliminates any 1-second delay/flash before video starts)
            Image.asset(
              'assets/images/splash_placeholder.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),

            // Video player smoothly displays and takes over once initialized
            if (_isVideoInitialized &&
                !_hasVideoError &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              Center(
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController!.value.size.width > 0
                          ? _videoController!.value.size.width
                          : 1080,
                      height: _videoController!.value.size.height > 0
                          ? _videoController!.value.size.height
                          : 1920,
                      child: VideoPlayer(_videoController!),
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

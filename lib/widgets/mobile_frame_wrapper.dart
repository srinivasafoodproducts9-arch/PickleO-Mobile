import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MobileFrameWrapper extends StatefulWidget {
  final Widget child;

  const MobileFrameWrapper({super.key, required this.child});

  @override
  State<MobileFrameWrapper> createState() => _MobileFrameWrapperState();
}

class _MobileFrameWrapperState extends State<MobileFrameWrapper> {
  // On web, start with full responsive view; user can toggle mobile frame preview if desired
  bool _useFrameOnLargeScreen = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // On native mobile/tablet apps (Android, iOS) or small viewports (<600px),
        // always render directly in full native layout without any phone mockup frame.
        if (!kIsWeb || constraints.maxWidth < 600) {
          return widget.child;
        }

        // On desktop/tablet/web screen:
        if (!_useFrameOnLargeScreen) {
          return Stack(
            children: [
              widget.child,
              Positioned(
                bottom: 20,
                right: 20,
                child: _buildTogglePill(),
              ),
            ],
          );
        }

        // Showcase in sleek mobile device mockup
        return Scaffold(
          backgroundColor: const Color(0xFF181512),
          body: Stack(
            children: [
              // Subtle background pattern & branding
              Center(
                child: Opacity(
                  opacity: 0.08,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.eco, size: 140, color: Colors.white),
                      Text(
                        'PickleO Prototype',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Mobile Frame in Center
              Center(
                child: Container(
                  width: 410,
                  height: constraints.maxHeight * 0.94,
                  constraints: const BoxConstraints(
                    maxHeight: 880,
                    minHeight: 700,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warmCream,
                    borderRadius: BorderRadius.circular(44),
                    border: Border.all(
                      color: const Color(0xFF332D28),
                      width: 10,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 40,
                        spreadRadius: 4,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: Stack(
                      children: [
                        widget.child,

                        // Dynamic Island / Phone Speaker notch
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 110,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A1A1A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0F172A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Toggle Pill
              Positioned(
                bottom: 20,
                right: 20,
                child: _buildTogglePill(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTogglePill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _useFrameOnLargeScreen = !_useFrameOnLargeScreen;
          });
        },
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.leafGreen,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _useFrameOnLargeScreen
                    ? Icons.fullscreen_rounded
                    : Icons.phone_android_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _useFrameOnLargeScreen
                    ? 'Switch to Web View'
                    : 'Switch to Mobile Frame',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

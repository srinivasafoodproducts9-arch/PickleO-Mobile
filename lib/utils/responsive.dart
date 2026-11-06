import 'package:flutter/material.dart';

/// Responsive design utilities for PickleO tablet and phone layouts on Android, iOS and Web.
class Responsive {
  /// Breakpoint constants
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 800;
  static const double desktopBreakpoint = 1100;

  /// Whether current viewport width is tablet-sized or larger (>= 600px)
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  /// Whether current viewport is in landscape tablet or wide tablet mode (>= 800px)
  static bool isWideTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Whether current viewport is desktop / iPad Pro landscape sized (>= 1100px)
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Returns adaptive column count for grid layouts based on screen width
  static int gridColumns(
    BuildContext context, {
    int phone = 2,
    int tabletPortrait = 3,
    int tabletLandscape = 4,
    int largeScreen = 5,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return largeScreen;
    if (width >= tabletBreakpoint) return tabletLandscape;
    if (width >= mobileBreakpoint) return tabletPortrait;
    return phone;
  }

  /// Returns adaptive aspect ratio for product cards to keep them proportional
  static double cardAspectRatio(
    BuildContext context, {
    double phone = 0.52,
    double tabletPortrait = 0.64,
    double tabletLandscape = 0.68,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= tabletBreakpoint) return tabletLandscape;
    if (width >= mobileBreakpoint) return tabletPortrait;
    return phone;
  }

  /// Helper to center and constrain content width on wide screens
  static Widget constrained({
    required Widget child,
    double maxWidth = 850,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Reusable GPU-accelerated Shimmer Effect with vivid light sweeps
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration duration;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFFE6DED6),
    this.highlightColor = const Color(0xFFFFFFFF),
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TickerMode.of(context)) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.of(context)) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.0, -0.3),
              end: const Alignment(1.0, 0.3),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _controller.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      bounds.width * (slidePercent * 2 - 1),
      0.0,
      0.0,
    );
  }
}

/// A single skeleton placeholder box wrapped in shimmer
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final Color? color;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 6,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFFE6DED6),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Detailed Skeleton for a PickleO Product Card with visible internal structure
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E4D7), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D4037).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Image Area - Clean, light shimmer without static icons
          const AspectRatio(
            aspectRatio: 1.15,
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
              color: Color(0xFFEDE5DC),
            ),
          ),

          // Details Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kitchen / Origin subtitle
                  ShimmerBox(
                    width: 65,
                    height: 9,
                    borderRadius: 2,
                    color: const Color(0xFFEFE8E1),
                  ),
                  const SizedBox(height: 6),

                  // Title line 1
                  const ShimmerBox(
                    width: double.infinity,
                    height: 12,
                    borderRadius: 3,
                  ),
                  const SizedBox(height: 4),

                  // Title line 2
                  const ShimmerBox(
                    width: 85,
                    height: 12,
                    borderRadius: 3,
                  ),

                  const Spacer(),

                  // Price Row & ADD button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ShimmerBox(width: 44, height: 14, borderRadius: 3),
                          const SizedBox(height: 3),
                          ShimmerBox(
                            width: 28,
                            height: 9,
                            borderRadius: 2,
                            color: const Color(0xFFEFE8E1),
                          ),
                        ],
                      ),
                      // ADD Button placeholder
                      ShimmerBox(
                        width: 54,
                        height: 26,
                        borderRadius: 8,
                        color: const Color(0xFFFFF0E4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer Grid showing placeholder product cards with adaptive padding & aspect ratio
class ProductGridSkeleton extends StatelessWidget {
  final int itemCount;
  final SliverGridDelegate? gridDelegate;

  const ProductGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.gridDelegate,
  });

  /// Factory for a sliver version to use directly in CustomScrollView (e.g. HomeScreen)
  static Widget sliver({
    int itemCount = 4,
    required BuildContext context,
  }) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);
    final childAspectRatio = width > 600 ? 0.72 : 0.64;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ProductCardSkeleton(),
          childCount: itemCount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDelegate = gridDelegate ??
        SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: Responsive.gridColumns(
            context,
            phone: 2,
            tabletPortrait: 3,
            tabletLandscape: 4,
            largeScreen: 5,
          ),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: Responsive.cardAspectRatio(
            context,
            phone: 0.55,
            tabletPortrait: 0.62,
            tabletLandscape: 0.56,
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: effectiveDelegate,
        itemCount: itemCount,
        itemBuilder: (context, index) => const ProductCardSkeleton(),
      ),
    );
  }
}

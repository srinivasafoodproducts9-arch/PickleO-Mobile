import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import 'shimmer_loading.dart';

/// A reusable placeholder widget shown when a product has no image or fails to load.
class NoProductImagePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;
  final Color? textColor;

  const NoProductImagePlaceholder({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? const Color(0xFFFAF5EE);
    final icColor = iconColor ?? const Color(0xFFC07A50);
    final txtColor = textColor ?? const Color(0xFF8D6E63);

    Widget placeholder = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: const Color(0xFFEBE0D2),
          width: 0.8,
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : (height ?? 100.0);
          final w = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (width ?? 100.0);

          final isVerySmall = (h < 56) || (w < 56);
          final isSmall = (h < 110) || (w < 110);

          if (isVerySmall) {
            return Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: (h * 0.45).clamp(16.0, 22.0),
                color: icColor,
              ),
            );
          }

          final iconSize = isSmall ? 24.0 : 36.0;
          final fontSize = isSmall ? 10.0 : 12.0;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: iconSize,
                color: icColor,
              ),
              SizedBox(height: isSmall ? 3 : 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'No image available',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: txtColor,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (borderRadius != null) {
      placeholder = ClipRRect(
        borderRadius: borderRadius!,
        child: placeholder,
      );
    }

    return placeholder;
  }
}

/// A comprehensive product image widget that displays network image, asset fallback,
/// and "No image available" placeholder if the image is missing or cannot be loaded.
class ProductImage extends StatelessWidget {
  final Product product;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  const ProductImage({
    super.key,
    required this.product,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    final placeholder = NoProductImagePlaceholder(
      width: width,
      height: height,
      backgroundColor: backgroundColor,
    );

    if (product.hasValidNetworkImage) {
      content = Image.network(
        product.resolvedImageUrl!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) {
          if (product.hasValidAssetImage) {
            return Image.asset(
              product.imageAsset!,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: (_, __, ___) => placeholder,
            );
          }
          return placeholder;
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return ShimmerLoading(
            child: Container(
              width: width,
              height: height,
              color: backgroundColor ?? const Color(0xFFF1EAE4),
            ),
          );
        },
      );
    } else if (product.hasValidAssetImage) {
      content = Image.asset(
        product.imageAsset!,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => placeholder,
      );
    } else {
      content = placeholder;
    }

    if (borderRadius != null) {
      content = ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }
}

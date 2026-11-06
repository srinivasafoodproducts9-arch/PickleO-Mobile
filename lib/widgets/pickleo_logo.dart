import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PickleOLogo extends StatelessWidget {
  final double fontSize;
  final bool showTagline;
  final Color? textColor;
  final bool isDark;

  const PickleOLogo({
    super.key,
    this.fontSize = 22,
    this.showTagline = false,
    this.textColor,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = textColor ?? (isDark ? Colors.white : AppColors.leafGreen);
    final ringSize = fontSize * 0.78;
    final strokeWidth = (fontSize * 0.26).clamp(3.0, 7.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Pickle',
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: titleColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.pickleOrange,
                  width: strokeWidth,
                ),
              ),
            ),
          ],
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.eco, size: 16, color: AppColors.leafGreen),
                const SizedBox(width: 6),
                Text(
                  'Pickles • Foods • Goodness',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.leafGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class PickleOBrandBadge extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const PickleOBrandBadge({
    super.key,
    this.size = 112,
    this.showWordmark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: const [
              BoxShadow(
                color: Color(0x245D4037),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.asset(
              'assets/images/app-icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 8),
          Image.asset(
            'assets/images/wordmark.png',
            width: size * 1.96,
            fit: BoxFit.contain,
          ),
        ],
      ],
    );
  }
}

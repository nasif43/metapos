import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Renders the official MetaPOS Emerald SVG mark and optional title text.
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;

  const BrandLogo({
    super.key,
    this.size = 40.0,
    this.showText = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final logoWidget = SvgPicture.asset(
      'assets/images/metapos-mark-emerald.svg',
      width: size,
      height: size,
      placeholderBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.emerald,
            borderRadius: BorderRadius.circular(size * 0.21),
          ),
          child: Icon(
            Icons.point_of_sale_rounded,
            color: Colors.white,
            size: size * 0.6,
          ),
        ),
      ),
    );

    if (!showText) {
      return logoWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoWidget,
        const SizedBox(width: 12.0),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Meta',
                    style: AppTypography.heading2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: textColor ?? AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: 'POS',
                    style: AppTypography.heading2.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.emerald,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Smart Retail POS',
              style: AppTypography.caption.copyWith(
                color: textColor?.withValues(alpha: 0.7) ?? AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

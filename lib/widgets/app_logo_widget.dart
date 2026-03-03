import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'custom_loading_widget.dart';

/// App logo from URL (transparent PNG). Fallback to icon when URL is empty or fails.
class AppLogoWidget extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final Color? fallbackIconColor;
  final Color? backgroundColor;

  const AppLogoWidget({
    super.key,
    this.logoUrl,
    this.size = 60,
    this.fallbackIconColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) {
      return _buildFallback();
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _buildFallback(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: CustomLoadingWidget(
              size: size * 0.6,
              color: fallbackIconColor ?? AppColors.burntOrange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallback() {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: CustomLoadingWidget(
          size: size * 0.5,
          color: fallbackIconColor ?? AppColors.burntOrange,
        ),
      ),
    );
  }
}

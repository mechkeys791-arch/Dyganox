import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Simple spinner used when the app or an image is loading. No custom animation from admin.
/// Use [size] for inline (e.g. where an image is loading). Use [fullScreenOverlay] for whole-page loading.
class CustomLoadingWidget extends StatelessWidget {
  final double size;
  final bool fullScreen;
  final Color? color;

  const CustomLoadingWidget({
    super.key,
    this.size = 48,
    this.fullScreen = false,
    this.color,
  });

  /// Full-screen overlay for when the whole page is loading.
  static Widget fullScreenOverlay({Color? barrierColor}) {
    return Material(
      color: barrierColor ?? Colors.black26,
      child: Center(
        child: CustomLoadingWidget(size: 140, fullScreen: false, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.burntOrange;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SizedBox(
          width: size * 0.6,
          height: size * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    );
  }
}

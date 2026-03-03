import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Transparent Lottie or GIF overlay for the home red header. Red gradient shows through.
class HomeHeroOverlay extends StatelessWidget {
  final String mediaType;
  final String mediaUrl;
  final bool active;

  const HomeHeroOverlay({
    super.key,
    required this.mediaType,
    required this.mediaUrl,
    this.active = true,
  });

  bool get _hasMedia => active && mediaUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasMedia) return const SizedBox.shrink();

    if (mediaType.toLowerCase() == 'gif') {
      return Positioned.fill(
        child: IgnorePointer(
          child: Image.network(
            mediaUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    // Lottie (default)
    return Positioned.fill(
      child: IgnorePointer(
        child: Lottie.network(
          mediaUrl,
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/theme/app_colors.dart';
import '../services/app_remote_service.dart';

/// Customizable loading: shows Lottie or GIF from app branding (e.g. car going).
/// Use [size] for inline (e.g. where an image is loading). Use [fullScreen] for whole-page loading.
class CustomLoadingWidget extends StatefulWidget {
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
  State<CustomLoadingWidget> createState() => _CustomLoadingWidgetState();
}

class _CustomLoadingWidgetState extends State<CustomLoadingWidget> {
  String? _url;
  String? _type;
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    _url = AppRemoteService.cachedLoadingUrl;
    _type = AppRemoteService.cachedLoadingType;
    if (_url == null || _url!.isEmpty) {
      _fetchLoadingConfig();
    } else {
      _fetched = true;
    }
  }

  Future<void> _fetchLoadingConfig() async {
    final config = await AppRemoteService.getAppBrandingConfig();
    if (!mounted) return;
    final url = config?['loadingMediaUrl']?.toString()?.trim();
    final type = config?['loadingMediaType']?.toString()?.trim().toLowerCase();
    setState(() {
      _url = (url != null && url.isNotEmpty) ? url : null;
      _type = (type == 'gif' || type == 'lottie') ? type : null;
      _fetched = true;
    });
  }

  Widget _buildDefault() {
    final color = widget.color ?? AppColors.burntOrange;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: SizedBox(
          width: widget.size * 0.6,
          height: widget.size * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_fetched || _url == null || _url!.isEmpty) {
      return _buildDefault();
    }
    final type = _type ?? 'lottie';
    if (type == 'lottie') {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.network(
          _url!,
          fit: BoxFit.contain,
          width: widget.size,
          height: widget.size,
          errorBuilder: (_, __, ___) => _buildDefault(),
        ),
      );
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.network(
        _url!,
        fit: BoxFit.contain,
        width: widget.size,
        height: widget.size,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _buildDefault();
        },
        errorBuilder: (_, __, ___) => _buildDefault(),
      ),
    );
  }
}

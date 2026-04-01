import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_config.dart';

/// Image-only hero banner (Swiggy/Zepto style): fills the given box with [BoxFit.cover], rotates if multiple ads.
/// Auto-advance always moves **forward**; after the last slide it continues with a duplicate first slide then
/// jumps invisibly to page 0 (no scrolling back through all slides).
class ServiceAdStrip extends StatefulWidget {
  final List<Map<String, dynamic>> ads;
  final void Function(Map<String, dynamic> ad) onAdTap;
  /// Edge-to-edge in parent (no rounded corners, fills [expandedHeight] hero).
  final bool fullBleed;

  const ServiceAdStrip({
    super.key,
    required this.ads,
    required this.onAdTap,
    this.fullBleed = false,
  });

  @override
  State<ServiceAdStrip> createState() => _ServiceAdStripState();
}

class _ServiceAdStripState extends State<ServiceAdStrip> {
  PageController? _pageController;
  int _page = 0;
  Timer? _rotateTimer;

  static List<Map<String, dynamic>> _imageAdsOnly(List<Map<String, dynamic>> raw) {
    return raw.where((a) {
      final t = (a['mediaType'] ?? 'IMAGE').toString().toUpperCase();
      return t == 'IMAGE';
    }).toList();
  }

  int get _virtualCount {
    final ads = _imageAdsOnly(widget.ads);
    if (ads.isEmpty) return 0;
    if (ads.length <= 1) return ads.length;
    return ads.length + 1;
  }

  @override
  void initState() {
    super.initState();
    _initController();
    _startTimer();
  }

  void _initController() {
    _pageController?.dispose();
    _pageController = PageController();
    _page = 0;
  }

  @override
  void didUpdateWidget(ServiceAdStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldA = _imageAdsOnly(oldWidget.ads);
    final newA = _imageAdsOnly(widget.ads);
    if (oldA.length != newA.length ||
        oldA.map((e) => e['mediaUrl']).join() != newA.map((e) => e['mediaUrl']).join()) {
      _rotateTimer?.cancel();
      _initController();
      _startTimer();
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _rotateTimer?.cancel();
    final ads = _imageAdsOnly(widget.ads);
    if (ads.length <= 1) return;
    _rotateTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _pageController == null || !_pageController!.hasClients) return;
      final n = ads.length;
      if (n <= 1) return;
      final cur = _pageController!.page?.round() ?? _page;
      final next = cur + 1;
      if (next <= n) {
        _pageController!.animateToPage(
          next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  String _mediaUrl(Map<String, dynamic> ad) {
    final raw = ad['mediaUrl']?.toString() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${ApiConfig.baseUrl}$raw';
  }

  void _onPageChanged(int i, List<Map<String, dynamic>> ads) {
    final n = ads.length;
    if (n <= 1) {
      setState(() => _page = i);
      return;
    }
    if (i == n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pageController == null || !_pageController!.hasClients) return;
        _pageController!.jumpToPage(0);
        if (mounted) setState(() => _page = 0);
      });
    } else {
      setState(() => _page = i);
    }
  }

  int _adIndexForPage(int pageIndex, int n) {
    if (n <= 1) return pageIndex.clamp(0, n - 1);
    if (pageIndex >= n) return 0;
    return pageIndex;
  }

  @override
  Widget build(BuildContext context) {
    final ads = _imageAdsOnly(widget.ads);
    if (ads.isEmpty) return const SizedBox.shrink();
    final n = ads.length;
    final vCount = _virtualCount;
    final pc = _pageController;
    if (pc == null) return const SizedBox.shrink();

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onAdTap(ads[_adIndexForPage(_page, n)]),
        child: SizedBox.expand(
          child: PageView.builder(
            controller: pc,
            onPageChanged: (i) => _onPageChanged(i, ads),
            itemCount: vCount,
            itemBuilder: (context, i) {
              final adIdx = _adIndexForPage(i, n);
              final url = _mediaUrl(ads[adIdx]);
              if (url.isEmpty) return const SizedBox.shrink();
              return SizedBox.expand(
                child: ColoredBox(
                  color: widget.fullBleed ? Colors.black : const Color(0xFFF5F5F5),
                  child: Center(
                    child: Image.network(
                      url,
                      key: ValueKey<String>('$url-$i'),
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 40),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                      ),
                    );
                  },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    if (widget.fullBleed) {
      return ClipRect(child: content);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

/// Horizontal promo rail: one card at a time with peek of the next; auto-advances smoothly.
class ServiceAdHorizontalRail extends StatefulWidget {
  final List<Map<String, dynamic>> ads;
  final void Function(Map<String, dynamic> ad) onAdTap;
  /// Total row height; image fits inside with [BoxFit.contain].
  final double height;

  const ServiceAdHorizontalRail({
    super.key,
    required this.ads,
    required this.onAdTap,
    this.height = 96,
  });

  @override
  State<ServiceAdHorizontalRail> createState() => _ServiceAdHorizontalRailState();
}

class _ServiceAdHorizontalRailState extends State<ServiceAdHorizontalRail> {
  PageController? _pageController;
  Timer? _rotateTimer;
  int _page = 0;

  static List<Map<String, dynamic>> _imageOnly(List<Map<String, dynamic>> raw) {
    return raw.where((a) {
      final t = (a['mediaType'] ?? 'IMAGE').toString().toUpperCase();
      return t == 'IMAGE';
    }).toList();
  }

  String _mediaUrl(Map<String, dynamic> ad) {
    final raw = ad['mediaUrl']?.toString() ?? '';
    if (raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${ApiConfig.baseUrl}$raw';
  }

  int get _virtualCount {
    final list = _imageOnly(widget.ads);
    if (list.isEmpty) return 0;
    if (list.length <= 1) return list.length;
    return list.length + 1;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    _startTimer();
  }

  void _resetController() {
    _rotateTimer?.cancel();
    _pageController?.dispose();
    _pageController = PageController(viewportFraction: 0.88);
    _page = 0;
    _startTimer();
  }

  @override
  void didUpdateWidget(ServiceAdHorizontalRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldL = _imageOnly(oldWidget.ads);
    final newL = _imageOnly(widget.ads);
    if (oldL.length != newL.length ||
        oldL.map((e) => e['mediaUrl']).join('|') != newL.map((e) => e['mediaUrl']).join('|')) {
      _resetController();
      if (mounted) setState(() {});
    }
  }

  void _startTimer() {
    _rotateTimer?.cancel();
    final list = _imageOnly(widget.ads);
    if (list.length <= 1) return;
    _rotateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _pageController == null || !_pageController!.hasClients) return;
      final n = list.length;
      if (n <= 1) return;
      final cur = _pageController!.page?.round() ?? _page;
      final next = cur + 1;
      if (next <= n) {
        _pageController!.animateToPage(
          next,
          duration: const Duration(milliseconds: 720),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onPageChanged(int i, List<Map<String, dynamic>> list) {
    final n = list.length;
    if (n <= 1) {
      setState(() => _page = i);
      return;
    }
    if (i == n) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _pageController == null || !_pageController!.hasClients) return;
        _pageController!.jumpToPage(0);
        if (mounted) setState(() => _page = 0);
      });
    } else {
      setState(() => _page = i);
    }
  }

  int _adIndexForPage(int pageIndex, int n) {
    if (n <= 1) return pageIndex.clamp(0, n - 1);
    if (pageIndex >= n) return 0;
    return pageIndex;
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _imageOnly(widget.ads);
    if (list.isEmpty) return const SizedBox.shrink();
    final n = list.length;
    final vCount = _virtualCount;
    final pc = _pageController;
    if (pc == null) return const SizedBox.shrink();

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: PageView.builder(
          controller: pc,
          onPageChanged: (i) => _onPageChanged(i, list),
          itemCount: vCount,
          itemBuilder: (context, i) {
            final adIdx = _adIndexForPage(i, n);
            final ad = list[adIdx];
            final url = _mediaUrl(ad);
            if (url.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onAdTap(ad),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: const Color(0xFFE8E8E8),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Image.network(
                            url,
                            key: ValueKey<String>(url),
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            gaplessPlayback: true,
                            width: double.infinity,
                            height: widget.height - 8,
                            errorBuilder: (_, __, ___) => SizedBox(
                              height: widget.height - 16,
                              child: const Icon(Icons.broken_image_outlined, color: Colors.black38, size: 36),
                            ),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return SizedBox(
                                height: widget.height - 16,
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black26),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

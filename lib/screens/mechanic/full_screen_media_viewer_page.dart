import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen viewer for a single photo or video (damage or vehicle).
/// Tap outside or use back to close.
class FullScreenMediaViewerPage extends StatefulWidget {
  final String url;
  final String? title;

  const FullScreenMediaViewerPage({super.key, required this.url, this.title});

  /// True if URL looks like a video (e.g. .mp4, .mov, .webm).
  static bool isVideoUrl(String url) {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.mp4') || u.endsWith('.mov') || u.endsWith('.webm') || u.endsWith('.m4v');
  }

  bool get _isLocalFile => url.startsWith('/') || (!url.startsWith('http') && url.length < 500);

  @override
  State<FullScreenMediaViewerPage> createState() => _FullScreenMediaViewerPageState();
}

class _FullScreenMediaViewerPageState extends State<FullScreenMediaViewerPage> {
  VideoPlayerController? _controller;
  bool _isVideo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isVideo = FullScreenMediaViewerPage.isVideoUrl(widget.url);
    if (_isVideo && !widget._isLocalFile) {
      try {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..addListener(() { if (mounted) setState(() {}); })
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _controller!.play();
            }
          }).catchError((e) {
            if (mounted) setState(() => _error = e.toString());
          });
      } catch (e) {
        _error = e.toString();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Center(
              child: _isVideo
                  ? _buildVideo()
                  : _buildImage(),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
          if (widget.title != null && widget.title!.isNotEmpty)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    widget.title!,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final isFile = widget._isLocalFile && File(widget.url).existsSync();
    final child = isFile
        ? Image.file(File(widget.url), fit: BoxFit.contain)
        : Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
            ),
          );
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4,
      child: child,
    );
  }

  Widget _buildVideo() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: () {
        setState(() {
          _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          if (!_controller!.value.isPlaying)
            const Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
        ],
      ),
    );
  }
}


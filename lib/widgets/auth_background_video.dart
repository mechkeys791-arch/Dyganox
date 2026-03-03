import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen background video for login/signup. Loops muted with a dark overlay.
/// If [videoUrl] is null/empty or [active] is false, only [child] is shown.
class AuthBackgroundVideo extends StatefulWidget {
  final String? videoUrl;
  final bool active;
  final Widget child;

  const AuthBackgroundVideo({
    super.key,
    required this.child,
    this.videoUrl,
    this.active = true,
  });

  @override
  State<AuthBackgroundVideo> createState() => _AuthBackgroundVideoState();
}

class _AuthBackgroundVideoState extends State<AuthBackgroundVideo> {
  VideoPlayerController? _controller;
  bool _error = false;

  String? get _effectiveUrl {
    if (!widget.active) return null;
    final u = widget.videoUrl?.trim();
    return (u != null && u.isNotEmpty) ? u : null;
  }

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(covariant AuthBackgroundVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl || oldWidget.active != widget.active) {
      _disposeController();
      _setupController();
    }
  }

  Future<void> _setupController() async {
    final url = _effectiveUrl;
    if (url == null) {
      if (mounted) setState(() { _error = false; });
      return;
    }
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      _controller = c;
      setState(() { _error = false; });
    } catch (e) {
      if (mounted) setState(() { _error = true; });
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _error = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = _effectiveUrl;
    final showVideo = url != null && _controller != null && _controller!.value.isInitialized && !_error;

    if (!showVideo) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

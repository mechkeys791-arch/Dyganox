import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../../services/cognito_service.dart';
import '../../services/app_remote_service.dart';
import '../../homepage.dart';
import '../../widgets/app_logo_widget.dart';
import 'login_page.dart';
import '../mechanic/mechanic_login_request_page.dart';
import '../../core/theme/app_colors.dart';

class UserTypeSelectionPage extends StatefulWidget {
  const UserTypeSelectionPage({super.key});

  @override
  State<UserTypeSelectionPage> createState() => _UserTypeSelectionPageState();
}

class _UserTypeSelectionPageState extends State<UserTypeSelectionPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _welcomeTitle = 'Welcome to ProMech';
  String? _appLogoUrl;
  String? _welcomePageMediaUrl;
  String? _welcomePageMediaType;
  String? _welcomePageGifUrl;
  bool _showGifAfterVideo = false;
  VideoPlayerController? _welcomeVideoController;

  @override
  void initState() {
    super.initState();
    _loadBranding();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _welcomeVideoController?.dispose();
    super.dispose();
  }

  Future<void> _loadBranding() async {
    final config = await AppRemoteService.getAppBrandingConfig();
    if (!mounted) return;
    final welcomeUrl = config?['welcomePageMediaUrl']?.toString()?.trim();
    final welcomeType = config?['welcomePageMediaType']?.toString()?.trim().toLowerCase();
    final gifUrl = config?['welcomePageGifUrl']?.toString()?.trim();
    setState(() {
      _appLogoUrl = config?['appLogoUrl']?.toString();
      final t = config?['welcomeTitle']?.toString();
      if (t != null && t.isNotEmpty) _welcomeTitle = t;
      _welcomePageMediaUrl = welcomeUrl;
      _welcomePageMediaType = welcomeType;
      _welcomePageGifUrl = (gifUrl != null && gifUrl.isNotEmpty) ? gifUrl : null;
    });
    if (welcomeUrl != null && welcomeUrl.isNotEmpty && welcomeType == 'video') {
      _initWelcomeVideo(welcomeUrl, gifUrl != null && gifUrl.isNotEmpty);
    }
  }

  Future<void> _initWelcomeVideo(String url, bool hasGifAfter) async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(!hasGifAfter);
      await c.setVolume(0);
      await c.play();
      if (!mounted) return;
      setState(() => _welcomeVideoController = c);
      if (hasGifAfter) {
        c.addListener(_onVideoPositionChanged);
      }
    } catch (_) {
      if (mounted) setState(() => _welcomeVideoController = null);
    }
  }

  void _onVideoPositionChanged() {
    final c = _welcomeVideoController;
    if (c == null || !c.value.isInitialized || _welcomePageGifUrl == null) return;
    final duration = c.value.duration;
    final position = c.value.position;
    if (duration.inMilliseconds > 0 && position.inMilliseconds >= duration.inMilliseconds - 100) {
      c.removeListener(_onVideoPositionChanged);
      c.pause();
      if (mounted) {
        setState(() => _showGifAfterVideo = true);
      }
    }
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await CognitoService.isLoggedIn();
    if (isLoggedIn && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check login status on build
    _checkLoginStatus();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.burntOrange,
              AppColors.warmBrown,
              AppColors.warmAmber,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Welcome page GIF/video (from admin). GIF auto-plays after video ends if set.
                  if (_welcomePageMediaUrl != null && _welcomePageMediaUrl!.isNotEmpty ||
                      _showGifAfterVideo && _welcomePageGifUrl != null) ...[
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, _) {
                        final w = MediaQuery.of(context).size.width;
                        final mediaSize = (w * 0.6).clamp(160.0, 240.0);
                        final gifUrl = _showGifAfterVideo ? _welcomePageGifUrl : null;
                        if (gifUrl != null && gifUrl.isNotEmpty) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Image.network(
                              gifUrl,
                              width: mediaSize,
                              height: mediaSize,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          );
                        }
                        if (_welcomePageMediaType?.toLowerCase() == 'video' &&
                            _welcomeVideoController != null &&
                            _welcomeVideoController!.value.isInitialized) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: SizedBox(
                              width: mediaSize,
                              height: mediaSize,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _welcomeVideoController!.value.size.width,
                                  height: _welcomeVideoController!.value.size.height,
                                  child: VideoPlayer(_welcomeVideoController!),
                                ),
                              ),
                            ),
                          );
                        }
                        if (_welcomePageMediaType?.toLowerCase() == 'gif' &&
                            _welcomePageMediaUrl != null &&
                            _welcomePageMediaUrl!.isNotEmpty) {
                          return FadeTransition(
                            opacity: _fadeAnimation,
                            child: Image.network(
                              _welcomePageMediaUrl!,
                              width: mediaSize,
                              height: mediaSize,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Logo – large, transparent, no box
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final w = MediaQuery.of(context).size.width;
                      final logoSize = (w * 0.62).clamp(180.0, 280.0);
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: AppLogoWidget(
                            logoUrl: _appLogoUrl,
                            size: logoSize,
                            fallbackIconColor: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // Title
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          _welcomeTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Text(
                          'Choose your account type',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // User Type Cards
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            // User Card
                            _buildTypeCard(
                              icon: Icons.person_rounded,
                              title: 'I\'m a User',
                              subtitle: 'Find mechanics and get services',
                              color: Colors.white,
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const LoginPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Mechanic Card
                            _buildTypeCard(
                              icon: Icons.build_rounded,
                              title: 'I\'m a Mechanic',
                              subtitle: 'Register and offer services',
                              color: Colors.white.withOpacity(0.9),
                              onTap: () {
                                Navigator.of(context).pushReplacement(
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const MechanicLoginRequestPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.burntOrange,
                      AppColors.warmBrown,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  size: 35,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkChocolate,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

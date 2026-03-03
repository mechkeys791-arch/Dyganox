import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/fcm_notification_service.dart';
import '../../services/app_remote_service.dart';
import '../../homepage.dart';
import '../../widgets/app_logo_widget.dart';
import 'user_type_selection_page.dart';
import '../mechanic/mechanic_login_request_page.dart';
import '../mechanic/mechanic_service_dashboard.dart';

/// Splash video: try these in order. Place your MP4 in assets/videos/.
const List<String> _kSplashVideoAssets = [
  'assets/videos/splash.mp4',
  'assets/videos/Adobe Express - Copy of Prom ech (4).mp4',
  'assets/icons/Adobe Express - Copy of Prom ech (4).mp4',
];

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _launchRequestId;
  String? _appLogoUrl;
  String _welcomeTitle = 'Welcome to ProMech';
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoFailed = false;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadBranding();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _initVideo();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequestDetailIfLaunchedFromAccept());
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final id = await FcmNotificationService.getLaunchRequestId();
      if (mounted && id != null && id.isNotEmpty) {
        setState(() => _launchRequestId = id);
      }
    });
    // Do not navigate until the starting logo has appeared (see _scheduleNavigationAfterLogo).
    // Safety: if something fails, navigate after at most 8 seconds.
    Future.delayed(const Duration(seconds: 8), () {
      if (!mounted || _navigationScheduled) return;
      _navigationScheduled = true;
      _navigateAway();
    });
  }

  Future<void> _initVideo() async {
    for (final path in _kSplashVideoAssets) {
      try {
        final c = VideoPlayerController.asset(path);
        await c.initialize();
        if (!mounted) {
          c.dispose();
          return;
        }
        await c.setLooping(true);
        await c.setVolume(0);
        await c.play();
        if (mounted) {
          setState(() {
            _videoController = c;
            _videoReady = true;
          });
        }
        return;
      } catch (_) {
        continue;
      }
    }
    if (mounted) setState(() => _videoFailed = true);
  }

  Future<void> _navigateAway() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    try {
      if (FcmNotificationService.didOpenRequestDetailFromNotification) return;
      String? launchRequestId = _launchRequestId;
      if (launchRequestId == null || launchRequestId.isEmpty) {
        launchRequestId = await FcmNotificationService.getLaunchRequestId();
      }
      final isCustomer = await CognitoService.isLoggedIn();
      if (launchRequestId != null && launchRequestId.isNotEmpty) {
        await FcmNotificationService.clearLaunchRequestId();
        FcmNotificationService.didOpenRequestDetailFromNotification = true;
        int? mechanicId;
        try {
          final res = await http.get(
            Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$launchRequestId'),
            headers: {'Content-Type': 'application/json'},
          );
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>?;
            final m = data?['mechanicId'];
            mechanicId = m is int ? m : (m is num ? m.toInt() : int.tryParse(m?.toString() ?? ''));
          }
        } catch (_) {}
        if (!mounted) return;
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MechanicServiceDashboard(
              mechanicData: mechanicId != null ? {'id': mechanicId} : null,
              openRequestIdAfterMount: launchRequestId,
            ),
          ),
          (route) => false,
        );
        return;
      }
      if (isCustomer) {
        if (FcmNotificationService.didOpenRequestDetailFromNotification) return;
        navigator.pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final pendingEmail = prefs.getString('mechanic_pending_email');
      if (pendingEmail != null && pendingEmail.isNotEmpty && mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MechanicLoginRequestPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
        return;
      }
      _navigateToUserTypeSelection();
    } catch (e, st) {
      debugPrint('Splash navigation error: $e $st');
      if (mounted) _navigateToUserTypeSelection();
    }
  }

  Future<void> _openRequestDetailIfLaunchedFromAccept() async {
    if (!mounted) return;
    String? id = await FcmNotificationService.getLaunchRequestId();
    if ((id == null || id.isEmpty) && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      id = await FcmNotificationService.getLaunchRequestId();
    }
    if (!mounted || id == null || id.isEmpty) return;
    await FcmNotificationService.clearLaunchRequestId();
    FcmNotificationService.didOpenRequestDetailFromNotification = true;
    int? mechanicId;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        final m = data?['mechanicId'];
        mechanicId = m is int ? m : (m is num ? m.toInt() : int.tryParse(m?.toString() ?? ''));
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MechanicServiceDashboard(
          mechanicData: mechanicId != null ? {'id': mechanicId} : null,
          openRequestIdAfterMount: id,
        ),
      ),
      (route) => false,
    );
  }

  void _navigateToUserTypeSelection() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const UserTypeSelectionPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _loadBranding() async {
    final config = await AppRemoteService.getAppBrandingConfig();
    if (!mounted) return;
    setState(() {
      _appLogoUrl = config?['appLogoUrl']?.toString();
      final t = config?['welcomeTitle']?.toString();
      if (t != null && t.isNotEmpty) _welcomeTitle = t;
    });
    _scheduleNavigationAfterLogo();
  }

  /// Navigate to home/login only after the starting logo has appeared (branding loaded + minimum display time).
  void _scheduleNavigationAfterLogo() {
    if (!mounted || _navigationScheduled) return;
    _navigationScheduled = true;
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _navigateAway();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width * 0.65).clamp(200.0, 320.0);

    return Scaffold(
      backgroundColor: AppColors.burntOrange,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_videoReady && _videoController != null && _videoController!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.burntOrange,
                    AppColors.warmBrown,
                    AppColors.warmAmber,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          if (_videoReady) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLogoWidget(
                      logoUrl: _appLogoUrl,
                      size: logoSize,
                      fallbackIconColor: AppColors.cream,
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _welcomeTitle,
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cream.withOpacity(0.95),
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

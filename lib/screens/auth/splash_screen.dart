import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/fcm_notification_service.dart';
import '../../homepage.dart';
import 'user_type_selection_page.dart';
import '../mechanic/mechanic_login_request_page.dart';
import '../mechanic/mechanic_service_dashboard.dart';
import '../mechanic/mechanic_request_detail_page.dart';
import '../mechanic/mechanic_request_detail_book_flow_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  /// Read at 2s so we have it for 3s navigation (id is not consumed on read).
  String? _launchRequestId;

  @override
  void initState() {
    super.initState();
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

    // UBER/RAPIDO-STYLE: On first frame, if we were opened from "Accept" notification, go straight to request detail (no 3s wait).
    WidgetsBinding.instance.addPostFrameCallback((_) => _openRequestDetailIfLaunchedFromAccept());

    // Read launch request id at 2s for the 3s navigation fallback (id is not consumed on read)
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final id = await FcmNotificationService.getLaunchRequestId();
      if (mounted && id != null && id.isNotEmpty) {
        setState(() => _launchRequestId = id);
      }
    });

    // Check login status and navigate accordingly (normal flow after 3s)
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      try {
        // If we already navigated to Request Details (from notification Accept),
        // never override it with the normal splash flow.
        if (FcmNotificationService.didOpenRequestDetailFromNotification) return;

        // Use id we read at 2s, or read again now (in case 2s hadn't run yet)
        String? launchRequestId = _launchRequestId;
        if (launchRequestId == null || launchRequestId.isEmpty) {
          launchRequestId = await FcmNotificationService.getLaunchRequestId();
        }
        final isCustomer = await CognitoService.isLoggedIn();
        // When opened from Accept → go to mechanic dashboard with Bookings + Request Detail
        if (launchRequestId != null && launchRequestId.isNotEmpty) {
            await FcmNotificationService.clearLaunchRequestId();
            FcmNotificationService.didOpenRequestDetailFromNotification = true;
            int? mechanicId;
            try {
              final res = await http.get(Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$launchRequestId'), headers: {'Content-Type': 'application/json'});
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
          // Customer → HomePage (user). Mechanic only → mechanic dashboard (don’t send to user page).
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
        // If mechanic has pending application, go straight to mechanic flow (shows pending page)
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
    });
  }

  /// If app was opened from "Accept" notification, go to mechanic dashboard with Bookings + Request Detail.
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
      final res = await http.get(Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$id'), headers: {'Content-Type': 'application/json'});
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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/icons/dyganox_logo.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to custom logo if image fails to load
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.burntOrange, AppColors.warmBrown],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.car_repair,
                size: 60,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'DYGANOX',
              style: GoogleFonts.outfit(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.burntOrange,
                letterSpacing: 2,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.burntOrange,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.burntOrange, // Indigo-500
              AppColors.warmBrown, // Violet-500
              AppColors.warmAmber, // Cyan-500
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Animation
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 250,
                        height: 220,
                        decoration: BoxDecoration(
                          color: AppColors.cream,
                          borderRadius: BorderRadius.circular(205),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(25.0),
                          child: _buildLogo(),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 50),
              
              // Tagline
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Vehicle Service Provider',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.cream.withOpacity(0.95),
                        letterSpacing: 1.5,
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 50),
              
              // Loading Indicator
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.cream.withOpacity(0.8),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

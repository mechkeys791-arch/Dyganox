import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'screens/auth/splash_screen.dart';
import 'homepage.dart';
import 'screens/profile/profile_page.dart';
import 'emergency_assistance_page.dart';
import 'screens/test/backend_test_page.dart';
import 'screens/test/test_ev_api_page.dart';
import 'screens/auth/login_page.dart';
import 'screens/auth/signup_page.dart';
import 'screens/auth/user_type_selection_page.dart';
import 'screens/mechanic/mechanic_registration_page.dart';
import 'screens/mechanic/mechanic_dashboard_page.dart';
import 'screens/mechanic/mechanic_request_detail_page.dart';
import 'screens/mechanic/mechanic_service_dashboard.dart';
import 'services/api_config.dart';
import 'services/fcm_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'widgets/custom_loading_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FcmNotificationService.didOpenRequestDetailFromNotification = false;
  // Background handler must be registered before any other FCM usage (required for background messages).
  FcmNotificationService.registerBackgroundHandler();
  try {
    await FcmNotificationService.initialize();
    await FcmNotificationService.processLaunchNotificationResponse();
  } catch (e) {
    // On web or when Firebase/FCM is unavailable, still run the app
    debugPrint('FCM init skipped: $e');
    if (e.toString().contains('dart:io') || e.toString().contains('Platform')) {
      debugPrint('(Web or unsupported platform - notifications disabled)');
    }
  }
  runApp(const ServiceProviderApp());
}

class ServiceProviderApp extends StatefulWidget {
  const ServiceProviderApp({super.key});

  @override
  State<ServiceProviderApp> createState() => _ServiceProviderAppState();
}

class _ServiceProviderAppState extends State<ServiceProviderApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _pendingOpenRequestId;
  bool _openRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupOpenRequestDetailChannel();
    // If native already has a pending Accept id, open it once navigator is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _attemptOpenPendingRequestDetail());
  }

  /// When user taps Accept on notification, native calls this so we open request detail (and clear stack so dashboard is not shown).
  void _setupOpenRequestDetailChannel() {
    const MethodChannel('dyganox/mechanic_alarm').setMethodCallHandler((call) async {
      if (call.method != 'openRequestDetail' || call.arguments == null) return null;
      final id = call.arguments as String;
      if (id.isEmpty) return null;
      _enqueueOpenRequestDetail(id);
      return null;
    });
  }

  void _enqueueOpenRequestDetail(String requestId) {
    // Coalesce duplicates (native may retry / fire multiple times).
    if (_pendingOpenRequestId == requestId && _openRequestInProgress) return;
    _pendingOpenRequestId = requestId;
    _attemptOpenPendingRequestDetail();
  }

  void _attemptOpenPendingRequestDetail({int attempt = 0}) async {
    if (!mounted) return;
    final requestId = _pendingOpenRequestId;
    if (requestId == null || requestId.isEmpty) return;
    if (_openRequestInProgress) return;

    final nav = _navigatorKey.currentState;
    if (nav == null) {
      if (attempt < 30) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _attemptOpenPendingRequestDetail(attempt: attempt + 1);
        });
      }
      return;
    }

    _openRequestInProgress = true;
    FcmNotificationService.didOpenRequestDetailFromNotification = true;

    try {
      // Fetch request to get mechanicId for dashboard (broadcast requests have mechanicId=null)
      final url = '${ApiConfig.mechanicRequestsEndpoint}/$requestId';
      final res = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json'});
      int? mechanicId;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        final m = data?['mechanicId'];
        mechanicId = m is int ? m : (m is num ? m.toInt() : int.tryParse(m?.toString() ?? ''));
      }
      if (mechanicId == null) {
        mechanicId = await FcmNotificationService.getMechanicId();
      }
      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MechanicServiceDashboard(
            mechanicData: mechanicId != null ? {'id': mechanicId} : null,
            openRequestIdAfterMount: requestId,
          ),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => MechanicServiceDashboard(
            mechanicData: null,
            openRequestIdAfterMount: requestId,
          ),
        ),
        (route) => false,
      );
    }

    FcmNotificationService.clearLaunchRequestId();
    _pendingOpenRequestId = null;
    _openRequestInProgress = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // When app comes to foreground, open request detail if we were launched from Accept
    _pushLaunchRequestDetailIfAny();
  }

  Future<void> _pushLaunchRequestDetailIfAny() async {
    final id = await FcmNotificationService.getLaunchRequestId();
    if (id == null || id.isEmpty) return;
    _enqueueOpenRequestDetail(id);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ProMech - Vehicle Service Provider',
      debugShowCheckedModeBanner: false,
      theme: chocolateTruffleTheme,
      // Use initial route from native (Accept tap → /open-accept/123) - set by getInitialRoute()
      initialRoute: ui.PlatformDispatcher.instance.defaultRouteName,
      onGenerateRoute: (settings) {
        // Accept-from-notification: /open-accept/REQUEST_ID → Dashboard with Bookings + Request Detail
        final name = settings.name ?? '/';
        if (name.startsWith('/open-accept/')) {
          final requestId = name.substring('/open-accept/'.length).trim();
          if (requestId.isNotEmpty) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => _AcceptLaunchLoader(requestId: requestId),
            );
          }
        }
        return null; // fall through to routes
      },
      routes: {
        '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfilePage(),
        '/emergency': (context) => const EmergencyAssistancePage(),
        '/backend-test': (context) => const BackendTestPage(),
        '/test-ev-api': (context) => const TestEVAPIPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/user-type-selection': (context) => const UserTypeSelectionPage(),
        '/mechanic-registration': (context) => const MechanicRegistrationPage(),
        '/mechanic-dashboard': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          if (args is Map<String, dynamic>) {
            return MechanicDashboardPage(
              mechanicData: args['mechanicData'] as Map<String, dynamic>?,
              mechanicId: args['mechanicId'] as int?,
            );
          } else if (args is int) {
            return MechanicDashboardPage(mechanicId: args);
          }
          return const MechanicDashboardPage();
        },
        '/request-detail': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final requestId = args is String ? args : (args is Map ? args['requestId']?.toString() : null);
          if (requestId == null) return const SizedBox.shrink();
          return MechanicRequestDetailPage(requestId: requestId);
        },
        '/': (context) => const SplashScreen(),
      },
    );
  }
}

/// Shown when app launches from Accept notification (/open-accept/ID).
/// Fetches mechanicId then shows Dashboard with Bookings + Request Detail.
class _AcceptLaunchLoader extends StatefulWidget {
  final String requestId;

  const _AcceptLaunchLoader({required this.requestId});

  @override
  State<_AcceptLaunchLoader> createState() => _AcceptLaunchLoaderState();
}

class _AcceptLaunchLoaderState extends State<_AcceptLaunchLoader> {
  @override
  void initState() {
    super.initState();
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    int? mechanicId;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>?;
        final m = data?['mechanicId'];
        mechanicId = m is int ? m : (m is num ? m.toInt() : int.tryParse(m?.toString() ?? ''));
      }
    } catch (_) {}
    if (mechanicId == null) {
      mechanicId = await FcmNotificationService.getMechanicId();
    }
    if (!mounted) return;
    FcmNotificationService.didOpenRequestDetailFromNotification = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MechanicServiceDashboard(
          mechanicData: mechanicId != null ? {'id': mechanicId} : null,
          openRequestIdAfterMount: widget.requestId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomLoadingWidget.fullScreenOverlay(barrierColor: Theme.of(context).colorScheme.surface),
    );
  }
}

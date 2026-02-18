import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'services/fcm_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  final DateTime _appStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Only handle resume after splash has run (~4s) so cold start is handled by splash only
    if (DateTime.now().difference(_appStartTime).inSeconds < 4) return;
    _pushLaunchRequestDetailIfAny();
  }

  Future<void> _pushLaunchRequestDetailIfAny() async {
    final id = await FcmNotificationService.getLaunchRequestId();
    if (id == null || id.isEmpty) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MechanicRequestDetailPage(requestId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Dyganox - Vehicle Service Provider',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.inter().fontFamily,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: const Color(0xFF1E293B),
          displayColor: const Color(0xFF1E293B),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF706DC7), // Custom Purple
          secondary: Color(0xFF8B7ED8), // Light Purple
          tertiary: Color(0xFF5D4E99), // Dark Purple
          surface: Color(0xFFFFFFFF),
          error: Color(0xFFEF4444), // Red-500
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFF1E293B),
          onError: Color(0xFFFFFFFF),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF706DC7),
            foregroundColor: Colors.white,
            elevation: 8,
            shadowColor: const Color(0xFF706DC7).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF706DC7), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
      home: const SplashScreen(),
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
      },
    );
  }
}

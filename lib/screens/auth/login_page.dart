import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/user_profile_service.dart';
import 'signup_page.dart';
import 'otp_verification_page.dart';
import 'forgot_password_page.dart';
import '../../homepage.dart';
import '../../services/app_remote_service.dart';
import '../../widgets/auth_background_video.dart';
import '../../widgets/app_logo_widget.dart';
import 'complete_profile_page.dart';
import 'user_type_selection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _emailPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _authVideoUrl;
  bool _authVideoActive = false;
  String? _appLogoUrl;

  @override
  void initState() {
    super.initState();
    _loadAuthVideoConfig();
    _loadBranding();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  Future<void> _loadAuthVideoConfig() async {
    final config = await AppRemoteService.getAuthVideoConfig();
    if (!mounted) return;
    setState(() {
      _authVideoUrl = config?['videoUrl']?.toString();
      _authVideoActive = config?['active'] == true;
    });
  }

  Future<void> _loadBranding() async {
    final config = await AppRemoteService.getAppBrandingConfig();
    if (!mounted) return;
    setState(() => _appLogoUrl = config?['appLogoUrl']?.toString());
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    final email = _emailPhoneController.text.trim();
    final password = _passwordController.text;

    try {
      // Sign in directly with Cognito (no backend OTP required)
      final result = await CognitoService.signIn(
        username: email,
        password: password,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] as String? ?? 'Invalid email or password'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    HapticFeedback.lightImpact();
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: ApiConfig.googleWebClientId,
      );
      await googleSignIn.signOut();
      final account = await googleSignIn.signIn();
      if (account == null || !mounted) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          setState(() => _isGoogleLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get Google account info. Try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final r = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      final data = r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic>? : null;
      final success = data != null && (data['success'] == true);
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data?['message'] ?? 'Google sign-in failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final email = data!['email']?.toString() ?? account.email ?? '';
      final name = data['name']?.toString() ?? account.displayName ?? email;
      final photoUrl = data['profilePhotoUrl']?.toString() ?? account.photoUrl;
      await CognitoService.saveGoogleAuthData(email: email, name: name);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profilePhotoUrl', photoUrl);
      }
      final profileResult = await UserProfileService.getUserProfile(email);
      final profileData = profileResult['success'] == true ? profileResult['data'] as Map<String, dynamic>? : null;
      await _loadUserProfileFromDatabase(email);
      if (!mounted) return;
      final needsProfile = _isProfileIncomplete(profileData, email);
      if (needsProfile) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => CompleteProfilePage(email: email, name: name)),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildGoogleIcon() {
    return Image.asset(
      'assets/icons/google.png',
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.network(
        'https://www.google.com/favicon.ico',
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24, color: Colors.black87),
      ),
    );
  }

  bool _isProfileIncomplete(Map<String, dynamic>? profileData, String email) {
    if (profileData == null) return true;
    final phone = profileData['phone']?.toString().trim();
    if (phone == null || phone.isEmpty) return true;
    return false;
  }

  Future<void> _loadUserProfileFromDatabase(String email) async {
    try {
      final result = await UserProfileService.getUserProfile(email);
      if (result['success'] == true && result['data'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final profileData = result['data'] as Map<String, dynamic>;
        if (profileData['dateOfBirth'] != null) {
          await prefs.setString('user_date_of_birth', profileData['dateOfBirth'].toString());
        }
        if (profileData['gender'] != null) {
          await prefs.setString('user_gender', profileData['gender'].toString());
        }
        if (profileData['profilePhotoUrl'] != null && profileData['profilePhotoUrl'].toString().isNotEmpty) {
          await prefs.setString('profilePhotoUrl', profileData['profilePhotoUrl'].toString());
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final logoSize = (size.width * 0.56).clamp(160.0, 260.0);
    final showVideo = _authVideoUrl != null && _authVideoUrl!.isNotEmpty && _authVideoActive;
    return Scaffold(
      body: AuthBackgroundVideo(
        videoUrl: _authVideoUrl,
        active: _authVideoActive,
        child: Container(
          decoration: showVideo ? null : BoxDecoration(
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
          child: SingleChildScrollView(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Back to Welcome (ProMech) page
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.onBurntOrange),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const UserTypeSelectionPage(),
                                transitionsBuilder: (_, animation, __, child) =>
                                    SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(-1.0, 0.0),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Logo – large, transparent, no box
                      Center(
                        child: AppLogoWidget(
                          logoUrl: _appLogoUrl,
                          size: logoSize,
                          fallbackIconColor: AppColors.onBurntOrange,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Welcome Text
                      Text(
                        'Welcome Back!',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onBurntOrange,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to continue',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: AppColors.onBurntOrange.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 50),
                      // Login Form Card
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.onBurntOrange,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Email/Phone Field
                                TextFormField(
                                  controller: _emailPhoneController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email or Phone',
                                    prefixIcon: const Icon(Icons.person_outline_rounded),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.creamElevated,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email or phone';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                // Password Field
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.creamElevated,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                // Forgot Password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, animation, secondaryAnimation) =>
                                              const ForgotPasswordPage(),
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
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        color: AppColors.burntOrange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Login Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.burntOrange,
                                    foregroundColor: AppColors.onBurntOrange,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.onBurntOrange),
                                          ),
                                        )
                                      : Text(
                                          'Sign In',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 24),
                                // Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: AppColors.warmBrownMuted)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.inter(
                                          color: AppColors.warmBrownMuted,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: AppColors.warmBrownMuted)),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Google Sign In
                                OutlinedButton.icon(
                                  onPressed: _isGoogleLoading ? null : _handleGoogleSignIn,
                                  icon: _isGoogleLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : _buildGoogleIcon(),
                                  label: Text(
                                    _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: AppColors.warmBrownMuted!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New to app? ',
                            style: GoogleFonts.inter(
                              color: AppColors.onBurntOrange.withOpacity(0.9),
                              fontSize: 15,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) =>
                                      const SignupPage(),
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
                            child: Text(
                              'Sign Up',
                              style: GoogleFonts.outfit(
                                color: AppColors.onBurntOrange,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

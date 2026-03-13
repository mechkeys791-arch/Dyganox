import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../homepage.dart';
import '../mechanic/mechanic_registration_comprehensive_page.dart';
import '../vehicles/vehicle_onboarding_page.dart';

class OTPVerificationPage extends StatefulWidget {
  final String phoneNumber;
  final String email;
  final String name;
  final String password;
  final bool isSignIn; // Flag to indicate if this is sign-in OTP
  /// After verify, go to mechanic registration form instead of HomePage.
  final bool forMechanicSignUp;
  /// Login with OTP: backend sends OTP; after verify we call Cognito signIn and go to Home.
  final bool forLoginWithOtp;

  const OTPVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.email,
    required this.name,
    required this.password,
    this.isSignIn = false,
    this.forMechanicSignUp = false,
    this.forLoginWithOtp = false,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;

  @override
  void initState() {
    super.initState();
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
    _startResendCountdown();
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        return true;
      }
      return false;
    });
  }

  void _onOTPChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto-verify when all 6 digits are entered
    if (index == 5 && value.isNotEmpty) {
      String otp = _otpControllers.map((c) => c.text).join();
      if (otp.length == 6) {
        _verifyOTP(otp);
      }
    }
  }

  Future<void> _verifyOTP(String otp) async {
    setState(() {
      _isLoading = true;
    });

    HapticFeedback.lightImpact();

    final trimmedOtp = otp.trim();
    Map<String, dynamic> result;

    if (widget.forLoginWithOtp) {
      // Login OTP: verify via backend, then sign in with Cognito
      try {
        final r = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/login-verify-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': widget.email, 'otp': trimmedOtp}),
        );
        final data = r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic>? : null;
        result = data != null && (data['success'] == true)
            ? {'success': true}
            : {'success': false, 'message': data?['message'] ?? 'Invalid or expired OTP'};
      } catch (e) {
        result = {'success': false, 'message': 'Network error'};
      }
      if (result['success'] == true) {
        final signInResult = await CognitoService.signIn(
          username: widget.email,
          password: widget.password,
        );
        result = signInResult;
      }
    } else if (widget.forMechanicSignUp) {
      result = await CognitoService.verifyOTPForMechanic(
        email: widget.email,
        code: trimmedOtp,
        password: widget.password,
      );
    } else {
      result = await CognitoService.verifyOTP(
        email: widget.email,
        code: trimmedOtp,
        password: widget.password,
      );
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      if (widget.forMechanicSignUp) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MechanicRegistrationComprehensivePage(
              prefilledName: widget.name,
              prefilledEmail: widget.email,
              prefilledPhone: widget.phoneNumber,
            ),
          ),
          (route) => false,
        );
      } else {
        // After new account creation, show vehicle onboarding (add first vehicle or skip)
        if (!widget.isSignIn) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => VehicleOnboardingPage(userEmail: widget.email),
            ),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
            (route) => false,
          );
        }
      }
    } else {
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'OTP verification failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
    });

    Map<String, dynamic> result;
    if (widget.forLoginWithOtp) {
      try {
        final r = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/login-resend-otp'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': widget.email, 'password': widget.password}),
        );
        final data = r.statusCode == 200 ? jsonDecode(r.body) as Map<String, dynamic>? : null;
        result = data != null && (data['success'] == true)
            ? {'success': true, 'message': 'OTP resent to your email'}
            : {'success': false, 'message': data?['message'] ?? 'Failed to resend OTP'};
      } catch (e) {
        result = {'success': false, 'message': 'Network error'};
      }
    } else if (widget.forMechanicSignUp) {
      result = await CognitoService.resendOTPForMechanic(widget.email);
    } else {
      result = await CognitoService.resendOTP(widget.email);
    }

    if (!mounted) return;

    setState(() {
      _isResending = false;
      if (result['success'] == true) {
        _resendCountdown = 60;
        _startResendCountdown();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? (widget.forLoginWithOtp ? 'OTP resent to your email' : 'OTP resent successfully')
              : result['message'] ?? 'Failed to resend OTP',
        ),
        backgroundColor:
            result['success'] == true ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFF6B35),
              const Color(0xFFFF8C42),
              const Color(0xFFFFA500),
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
                      const SizedBox(height: 40),
                      // Back Button
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Icon
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            size: 50,
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Title
                      Text(
                        'Verify OTP',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter the 6-digit CONFIRMATION CODE sent to your email',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Enter the 6-digit code from your email. You will see each digit as you type.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // OTP Input Card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                          child: Column(
                            children: [
                              // OTP Input Fields - digits visible as you type (no dots/underscores)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: List.generate(6, (index) {
                                  return SizedBox(
                                    width: 48,
                                    height: 58,
                                    child: TextFormField(
                                      controller: _otpControllers[index],
                                      focusNode: _focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      maxLength: 1,
                                      obscureText: false,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      style: GoogleFonts.outfit(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF1a1a2e),
                                      ),
                                      decoration: InputDecoration(
                                        counterText: '',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide(
                                            color: Colors.grey[300]!,
                                            width: 2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFFF6B35),
                                            width: 2.5,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      onChanged: (value) => _onOTPChanged(index, value),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 32),
                              // Verify Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          String otp =
                                              _otpControllers.map((c) => c.text).join();
                                          if (otp.length == 6) {
                                            _verifyOTP(otp);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please enter all 6 digits'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B35),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : Text(
                                          'Verify',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Resend OTP
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Didn't receive code? ",
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed:
                                        _resendCountdown > 0 || _isResending
                                            ? null
                                            : _resendOTP,
                                    child: _isResending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _resendCountdown > 0
                                                ? 'Resend in ${_resendCountdown}s'
                                                : 'Resend OTP',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFFFF6B35),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
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

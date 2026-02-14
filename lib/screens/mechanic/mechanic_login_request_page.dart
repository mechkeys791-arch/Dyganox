import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../auth/otp_verification_page.dart';
import 'mechanic_registration_comprehensive_page.dart';
import 'mechanic_service_dashboard.dart';
import 'mechanic_approved_page.dart';
import 'mechanic_rejected_page.dart';
import 'mechanic_application_success_page.dart';

class MechanicLoginRequestPage extends StatefulWidget {
  const MechanicLoginRequestPage({super.key});

  @override
  State<MechanicLoginRequestPage> createState() => _MechanicLoginRequestPageState();
}

class _MechanicLoginRequestPageState extends State<MechanicLoginRequestPage> {
  bool _isLoginMode = true; // true = Login, false = Create Account
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _checkingPending = true; // Check pending registration on load

  @override
  void initState() {
    super.initState();
    _checkPendingAndRoute();
  }

  /// If mechanic has a pending application, stay in success state or route to approved/rejected.
  Future<void> _checkPendingAndRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingEmail = prefs.getString('mechanic_pending_email');
    if (pendingEmail == null || pendingEmail.isEmpty) {
      if (mounted) setState(() => _checkingPending = false);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/mechanic/registration-requests/email/${Uri.encodeComponent(pendingEmail)}'),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = data['approvalStatus'] ?? 'PENDING';
        if (status == 'PENDING') {
          setState(() => _checkingPending = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicApplicationSuccessPage(mechanicEmail: pendingEmail),
            ),
          );
          return;
        }
        await prefs.remove('mechanic_pending_email');
        if (status == 'APPROVED') {
          setState(() => _checkingPending = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicApprovedPage(email: data['email'] ?? pendingEmail),
            ),
          );
          return;
        }
        if (status == 'REJECTED') {
          setState(() => _checkingPending = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicRejectedPage(
                rejectionReason: data['rejectionReason'],
              ),
            ),
          );
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingPending = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// After Cognito login: route to form / success / approved / rejected based on registration request.
  Future<bool> _routeAfterLogin(String email) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/mechanic/registration-requests/email/${Uri.encodeComponent(email)}'),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final status = data['approvalStatus'] ?? 'PENDING';
        if (!mounted) return true;
        if (status == 'PENDING') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('mechanic_pending_email', email);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicApplicationSuccessPage(mechanicEmail: email),
            ),
          );
          return true;
        }
        if (status == 'APPROVED') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicApprovedPage(email: data['email'] ?? email),
            ),
          );
          return true;
        }
        if (status == 'REJECTED') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicRejectedPage(rejectionReason: data['rejectionReason']),
            ),
          );
          return true;
        }
      }
      // No registration request (404): maybe already approved mechanic — try mechanic by email
      if (res.statusCode == 404) {
        final mechanicRes = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/mechanic/email/${Uri.encodeComponent(email)}'),
        ).timeout(const Duration(seconds: 10));
        if (mechanicRes.statusCode == 200 && mounted) {
          final mechanicData = jsonDecode(mechanicRes.body);
          if (mechanicData['approvalStatus'] == 'APPROVED') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MechanicServiceDashboard(mechanicData: mechanicData),
              ),
            );
            return true;
          }
        }
        // No request and no approved mechanic: go to form with prefilled from mechanic Cognito
        final user = await CognitoService.getCurrentMechanicUser();
        if (!mounted) return true;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicRegistrationComprehensivePage(
              prefilledName: user['name'],
              prefilledEmail: user['email'],
              prefilledPhone: user['phone'],
            ),
          ),
        );
        return true;
      }
      return false;
    } catch (e) {
      print('Route after login error: $e');
      return false;
    }
  }

  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await CognitoService.signInForMechanic(
        username: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      if (result['success'] != true) {
        _showError(result['message'] ?? 'Login failed');
        return;
      }
      // Route by registration status: form / success / approved / rejected / dashboard
      await _routeAfterLogin(_emailController.text.trim());
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createAccount() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || email.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill name, email and phone'), backgroundColor: Colors.red),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();
    String phoneFormatted = phone;
    if (!phoneFormatted.startsWith('+')) phoneFormatted = '+91$phoneFormatted';

    try {
      final result = await CognitoService.signUpForMechanic(
        email: email,
        phone: phoneFormatted,
        password: password,
        name: name,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationPage(
              phoneNumber: phoneFormatted,
              email: email,
              name: name,
              password: password,
              forMechanicSignUp: true,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Sign up failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPending) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              
              // Logo/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1),
                      const Color(0xFF8B5CF6),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.build_circle,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                _isLoginMode ? 'Mechanic Login' : 'Join as Mechanic',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              Text(
                _isLoginMode 
                    ? 'Login to access your dashboard'
                    : 'Create account with email OTP, then fill the mechanic form',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
              // Toggle Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLoginMode = true;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isLoginMode ? const Color(0xFF6366F1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Login',
                            style: GoogleFonts.outfit(
                              color: _isLoginMode ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isLoginMode = false;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isLoginMode ? const Color(0xFF6366F1) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Create Account',
                            style: GoogleFonts.outfit(
                              color: !_isLoginMode ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              if (_isLoginMode) ...[
                // Login Form
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  hint: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  hint: 'Enter your password',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Login',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ] else ...[
                // Create Account: name, phone, email, password → OTP → form
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person,
                  hint: 'Enter your full name',
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone,
                  hint: 'e.g. 9876543210',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  hint: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock,
                  hint: 'Min 6 characters',
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Create Account',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import 'mechanic_login_request_page.dart';
import 'mechanic_service_dashboard.dart';

/// Shown when admin approves. Email is fetched from registration; password was sent to WhatsApp.
/// User logs in with that password.
class MechanicApprovedPage extends StatefulWidget {
  final String email;

  const MechanicApprovedPage({
    super.key,
    required this.email,
  });

  @override
  State<MechanicApprovedPage> createState() => _MechanicApprovedPageState();
}

class _MechanicApprovedPageState extends State<MechanicApprovedPage> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the password sent to your WhatsApp'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result = await CognitoService.signInForMechanic(
        username: widget.email,
        password: _passwordController.text,
      );
      if (result['success'] == true) {
        final res = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/mechanic/email/${Uri.encodeComponent(widget.email)}'),
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 && mounted) {
          final mechanicData = jsonDecode(res.body);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicServiceDashboard(mechanicData: mechanicData),
            ),
          );
        } else if (mounted) {
          _showError('Login successful but could not load profile.');
        }
      } else {
        _showError(result['message'] ?? 'Invalid password. Use the one sent to your WhatsApp.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.warmAmber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: AppColors.warmAmber,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'You\'re approved',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your email: ${widget.email}',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You will receive the password via WhatsApp. Enter it below to go to your dashboard.',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password (you will receive via WhatsApp)',
                  prefixIcon: const Icon(Icons.lock, color: AppColors.burntOrange),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burntOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Go to Dashboard',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

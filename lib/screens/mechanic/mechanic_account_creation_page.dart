import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import 'mechanic_service_dashboard.dart';

class MechanicAccountCreationPage extends StatefulWidget {
  final String mechanicEmail;
  final Map<String, dynamic>? mechanicData;

  const MechanicAccountCreationPage({
    super.key,
    required this.mechanicEmail,
    this.mechanicData,
  });

  @override
  State<MechanicAccountCreationPage> createState() => _MechanicAccountCreationPageState();
}

class _MechanicAccountCreationPageState extends State<MechanicAccountCreationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.mechanicEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Register in Cognito (separate pool for mechanics)
      final signUpResult = await CognitoService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: widget.mechanicData?['phone'] ?? '',
        name: widget.mechanicData?['name'] ?? '',
      );

      if (signUpResult['success'] == true) {
        // Update mechanic password in database
        final mechanicId = widget.mechanicData?['id'];
        if (mechanicId != null) {
          final response = await http.put(
            Uri.parse('${ApiConfig.baseUrl}/api/mechanic/$mechanicId/password'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'password': _passwordController.text, // Backend hashes this
              'passwordSet': true,
            }),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            // Sign in the mechanic
            final signInResult = await CognitoService.signIn(
              username: _emailController.text.trim(),
              password: _passwordController.text,
            );

            if (signInResult['success'] == true) {
              // Get updated mechanic data with all fields
              final mechanicResponse = await http.get(
                Uri.parse('${ApiConfig.baseUrl}/api/mechanic/email/${Uri.encodeComponent(_emailController.text.trim())}'),
              );

              if (mechanicResponse.statusCode == 200) {
                final updatedMechanicData = jsonDecode(mechanicResponse.body);
                
                // Navigate to dashboard with all data
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MechanicServiceDashboard(
                      mechanicData: updatedMechanicData,
                    ),
                  ),
                );
              } else {
                // Use existing data if fetch fails
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MechanicServiceDashboard(
                      mechanicData: widget.mechanicData,
                    ),
                  ),
                );
              }
            } else {
              _showError('Account created but sign in failed. Please try logging in.');
            }
          } else {
            _showError('Failed to update password in database');
          }
        } else {
          _showError('Mechanic ID not found');
        }
      } else {
        _showError(signUpResult['message'] ?? 'Failed to create account');
      }
    } catch (e) {
      _showError('Error creating account: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Create Account',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 40,
                    color: Colors.green,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  'Your Request is Approved!',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create your account to access the mechanic dashboard. Your registration data will be loaded automatically.',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),

                // Email (pre-filled, read-only)
                Text(
                  'Email',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
                const SizedBox(height: 24),

                // Password Field
                Text(
                  'Password',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    prefixIcon: const Icon(Icons.lock),
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Confirm Password Field
                Text(
                  'Confirm Password',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            'Your Registration Data',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.mechanicData != null) ...[
                        _buildInfoRow('Name', widget.mechanicData!['name'] ?? ''),
                        _buildInfoRow('Shop', widget.mechanicData!['shopName'] ?? ''),
                        _buildInfoRow('Services', '${(widget.mechanicData!['services'] ?? '').toString().split(',').length} services'),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'All your data will be loaded to your dashboard after account creation.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
                            'Create Account & Continue',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EVChargingProviderPage extends StatefulWidget {
  const EVChargingProviderPage({super.key});

  @override
  State<EVChargingProviderPage> createState() => _EVChargingProviderPageState();
}

class _EVChargingProviderPageState extends State<EVChargingProviderPage> {
  final _formKey = GlobalKey<FormState>();
  String? selectedChargerType;
  String? selectedAvailableHours;
  bool agreeToTerms = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final providerData = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'chargerType': selectedChargerType,
      'rate': _rateController.text,
      'availableHours': selectedAvailableHours,
    };

    try {
      print("🚀 Sending data to backend: $providerData");
      print("🌐 Target URL: http://localhost:8081/api/person");
      
      // First, let's test if the server is reachable
      try {
        final testResponse = await http.get(
          Uri.parse("http://localhost:8081/api/person"),
          headers: {"Content-Type": "application/json"},
        );
        print("🔍 Server connectivity test: ${testResponse.statusCode}");
      } catch (testError) {
        print("❌ Server connectivity test failed: $testError");
        throw Exception("Cannot connect to server: $testError");
      }
      
      final response = await http.post(
        Uri.parse("http://localhost:8081/api/person"), // Spring Boot backend
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(providerData),
      );

      print("📡 Response status: ${response.statusCode}");
      print("📡 Response body: ${response.body}");
      print("📡 Response headers: ${response.headers}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse response to get the created person data
        try {
          final responseData = jsonDecode(response.body);
          print("✅ Data successfully saved to database: $responseData");
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "✅ Application submitted successfully!\nID: ${responseData['id'] ?? 'N/A'}",
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: const Color(0xFF706DC7),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          _formKey.currentState?.reset();
          setState(() {
            selectedChargerType = null;
            selectedAvailableHours = null;
            agreeToTerms = false;
          });
        } catch (parseError) {
          print("❌ Error parsing response: $parseError");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "⚠️ Data sent but response format error",
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: const Color(0xFFF59E0B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else {
        print("❌ HTTP Error: ${response.statusCode} - ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "❌ Server Error (${response.statusCode})\n${response.body.length > 100 ? response.body.substring(0, 100) + '...' : response.body}",
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print("❌ Network/Connection Error: $e");
      String errorMessage = "Network Error";
      
      if (e.toString().contains('SocketException')) {
        errorMessage = "Cannot connect to server\nCheck if backend is running";
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = "Request timeout\nServer is taking too long to respond";
      } else if (e.toString().contains('FormatException')) {
        errorMessage = "Invalid response format from server";
      } else {
        errorMessage = "Error: ${e.toString()}";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    try {
      print("🔍 Testing connection to backend...");
      print("🌐 Target URL: http://localhost:8081/api/person");
      
      // Test GET request first
      final getResponse = await http.get(
        Uri.parse("http://localhost:8081/api/person"),
        headers: {"Content-Type": "application/json"},
      );
      
      print("✅ GET test successful: ${getResponse.statusCode}");
      print("📡 GET Response: ${getResponse.body}");
      
      // Test POST request
      final testData = {
        'name': 'Flutter Test User',
        'phone': '1234567890',
        'address': 'Test Address from Flutter',
        'chargerType': 'Type 2',
        'rate': 'Rs 15/kWh',
        'availableHours': '24/7'
      };
      
      print("🚀 Testing POST request with data: $testData");
      
      final postResponse = await http.post(
        Uri.parse("http://localhost:8081/api/person"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(testData),
      );
      
      print("✅ POST test successful: ${postResponse.statusCode}");
      print("📡 POST Response: ${postResponse.body}");
      
      final responseData = jsonDecode(getResponse.body);
      final postData = jsonDecode(postResponse.body);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "✅ Both tests successful!\nGET: ${getResponse.statusCode} (${responseData.length} records)\nPOST: ${postResponse.statusCode} (ID: ${postData['id']})",
            style: GoogleFonts.outfit(),
          ),
              backgroundColor: const Color(0xFF706DC7),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print("❌ Connection test failed: $e");
      print("❌ Error type: ${e.runtimeType}");
      print("❌ Error details: ${e.toString()}");
      
      String errorMessage = "Connection failed";
      if (e.toString().contains('SocketException')) {
        errorMessage = "Cannot connect to server\nCheck network connection";
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = "Request timeout\nServer not responding";
      } else {
        errorMessage = "Error: ${e.toString()}";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Become a Provider',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormHeader(),
              const SizedBox(height: 32),
              _buildFormField('Full Name', controller: _nameController),
              const SizedBox(height: 20),
              _buildFormField(
                'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length < 10) {
                    return 'Enter valid phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildFormField(
                'Complete Address',
                controller: _addressController,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                'Charger Type',
                ['Type 1', 'Type 2', 'CCS', 'CHAdeMO', 'Tesla'],
                validator: (value) =>
                    value == null ? 'Please select charger type' : null,
                onChanged: (value) {
                  setState(() {
                    selectedChargerType = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _buildFormField(
                'Charging Rate (₹/kWh)',
                controller: _rateController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter charging rate';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Enter valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _buildDropdownField(
                'Available Hours',
                ['9AM-10AM', '4PM-8PM', '6PM-10PM', '24/7'],
                validator: (value) =>
                    value == null ? 'Please select available hours' : null,
                onChanged: (value) {
                  setState(() {
                    selectedAvailableHours = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              _buildEarningInfo(),
              const SizedBox(height: 32),
              _buildAgreementCheckbox(),
              const SizedBox(height: 32),
              _buildTestButton(),
              const SizedBox(height: 16),
              _buildSubmitButton(),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Applications are reviewed within 24-48 hours of submission',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF06B6D4), Color(0xFF0891B2), Color(0xFF0E7490)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF45B7D1).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.electric_bolt,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start Earning with Your EV Charger',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Share your home charger and earn money while helping the EV community',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormField(
    String label, {
    TextEditingController? controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF1E293B),
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    List<String> options, {
    String? Function(String?)? validator,
    void Function(String?)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF06B6D4), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            fillColor: Colors.white,
            filled: true,
          ),
          items: options
              .map((value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ))
              .toList(),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildEarningInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF45B7D1).withOpacity(0.1),
            const Color(0xFF45B7D1).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF45B7D1).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF45B7D1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.attach_money,
              color: Color(0xFF06B6D4),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Earning Potential',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF45B7D1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Average providers earn ₹3,000 to ₹7,000 per month by sharing their chargers 4-6 hours daily',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: agreeToTerms,
          onChanged: (value) {
            setState(() {
              agreeToTerms = value ?? false;
            });
          },
          activeColor: const Color(0xFF45B7D1),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'I agree to the ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF45B7D1),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: ' and ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                  ),
                ),
                TextSpan(
                  text: 'Provider Guidelines',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF45B7D1),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _testConnection,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF706DC7),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          '🔍 Test Connection',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate() && agreeToTerms) {
            _submitForm();
          } else if (!agreeToTerms) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Please agree to terms and conditions',
                  style: GoogleFonts.outfit(),
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF706DC7),
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: const Color(0xFF706DC7).withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          'Submit Application',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

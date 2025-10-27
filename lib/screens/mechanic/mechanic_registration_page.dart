  import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mechanic_dashboard_page.dart';

class MechanicRegistrationPage extends StatefulWidget {
  const MechanicRegistrationPage({super.key});

  @override
  State<MechanicRegistrationPage> createState() => _MechanicRegistrationPageState();
}

class _MechanicRegistrationPageState extends State<MechanicRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  String? selectedSpecialty;
  String? selectedExperience;
  bool nightTimeAvailable = false;
  bool agreeToTerms = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location services are disabled.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location fetched successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    final mechanicData = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
      'specialty': selectedSpecialty,
      'experience': selectedExperience,
      'nightTimeAvailable': nightTimeAvailable,
      'latitude': _latitudeController.text,
      'longitude': _longitudeController.text,
    };

    print("Mechanic Registration: Submitting data...");

    try {
      final response = await http.post(
        Uri.parse("http://10.73.102.113:8081/api/mechanic"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(mechanicData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("Mechanic Registration: Success - Data stored in database");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration submitted successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        
        _formKey.currentState?.reset();
        setState(() {
          selectedSpecialty = null;
          selectedExperience = null;
          nightTimeAvailable = false;
          agreeToTerms = false;
        });
        _latitudeController.clear();
        _longitudeController.clear();
        
        // Navigate to mechanic dashboard after successful registration
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MechanicDashboardPage(),
          ),
        );
      } else {
        print("Mechanic Registration: Error - HTTP ${response.statusCode}: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to submit: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Mechanic Registration: Exception - $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        title: Text(
          'Register as Mechanic',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold, 
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormHeader(),
              const SizedBox(height: 24),
              _buildFormField('Full Name', controller: _nameController),
              const SizedBox(height: 16),
              _buildFormField(
                'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email address';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Enter valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              _buildDropdownField(
                'Specialty',
                ['General Repair', 'Engine Specialist', 'Electrical Works', 'Body Works', 'Brake Specialist', 'AC Repair'],
                validator: (value) =>
                    value == null ? 'Please select specialty' : null,
                onChanged: (value) {
                  setState(() {
                    selectedSpecialty = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Experience',
                ['0-2 years', '2-5 years', '5-10 years', '10+ years'],
                validator: (value) =>
                    value == null ? 'Please select experience level' : null,
                onChanged: (value) {
                  setState(() {
                    selectedExperience = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFormField(
                      'Latitude',
                      controller: _latitudeController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter latitude';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildFormField(
                      'Longitude',
                      controller: _longitudeController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter longitude';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Enter valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Get Current Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildNightAvailabilityCheckbox(),
              const SizedBox(height: 24),
              _buildEarningInfo(),
              const SizedBox(height: 24),
              _buildAgreementCheckbox(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Applications are reviewed within 24-48 hours of submission',
                  style: GoogleFonts.outfit(
                    color: Colors.grey, 
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
          const Icon(Icons.build_circle,
              size: 50, color: Color(0xFF6366F1)),
          const SizedBox(height: 16),
          Text(
            'Join as a Professional Mechanic',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with customers and grow your business',
            style: GoogleFonts.outfit(
              fontSize: 14, 
              color: Colors.grey[600],
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
        Text(label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        Text(label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold, 
              fontSize: 16,
            )),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: options
              .map((value) =>
                  DropdownMenuItem<String>(value: value, child: Text(value)))
              .toList(),
          validator: validator,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildNightAvailabilityCheckbox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Checkbox(
            value: nightTimeAvailable,
            onChanged: (value) {
              setState(() {
                nightTimeAvailable = value ?? false;
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available for Night Time Services',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check this if you can provide services during night hours (after 8 PM)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: Color(0xFF6366F1), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Earning Potential',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF6366F1))),
                const SizedBox(height: 4),
                Text(
                  'Professional mechanics earn ₹5000 to ₹15000 per month by providing quality services',
                  style: GoogleFonts.outfit(
                    fontSize: 14, 
                    color: Colors.grey[800],
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
      children: [
        Checkbox(
          value: agreeToTerms,
          onChanged: (value) {
            setState(() {
              agreeToTerms = value ?? false;
            });
          },
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' and '),
                TextSpan(
                  text: 'Mechanic Guidelines',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate() && agreeToTerms) {
            _submitForm();
          } else if (!agreeToTerms) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please agree to terms and conditions'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please fill all required fields'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6366F1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(
          'Submit Registration',
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

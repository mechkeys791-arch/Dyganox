import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EVProviderScreen extends StatefulWidget {
  const EVProviderScreen({super.key});

  @override
  State<EVProviderScreen> createState() => _EVProviderScreenState();
}

class _EVProviderScreenState extends State<EVProviderScreen> {
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
    // ALWAYS show this message to confirm method is called
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚀 _submitForm() CALLED!"),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
      ),
    );

    final providerData = {
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'chargerType': selectedChargerType,
      'rate': _rateController.text,
      'availableHours': selectedAvailableHours,
    };

    // Debug print to see the data being sent
    print("🚀 Submitting data: ${jsonEncode(providerData)}");
    print("🔍 Data validation:");
    print("  - Name: '${providerData['name']}' (empty: ${providerData['name']?.isEmpty})");
    print("  - Phone: '${providerData['phone']}' (empty: ${providerData['phone']?.isEmpty})");
    print("  - Address: '${providerData['address']}' (empty: ${providerData['address']?.isEmpty})");
    print("  - ChargerType: '${providerData['chargerType']}' (null: ${providerData['chargerType'] == null})");
    print("  - Rate: '${providerData['rate']}' (empty: ${providerData['rate']?.isEmpty})");
    print("  - AvailableHours: '${providerData['availableHours']}' (null: ${providerData['availableHours'] == null})");

    // Show data being sent
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("📤 Sending: ${providerData['name']} - ${providerData['phone']}"),
        backgroundColor: Colors.purple,
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      print("🌐 Making HTTP request to: http://localhost:8081/api/person");
      print("📦 Request headers: Content-Type: application/json");
      print("📦 Request body: ${jsonEncode(providerData)}");
      
      final response = await http.post(
        Uri.parse("http://localhost:8081/api/person"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(providerData),
      );

      print("📡 Response received:");
      print("  - Status Code: ${response.statusCode}");
      print("  - Headers: ${response.headers}");
      print("  - Body: ${response.body}");

      // Show response
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("📡 Response: ${response.statusCode} - ${response.body.length > 20 ? response.body.substring(0, 20) + '...' : response.body}"),
          backgroundColor: Colors.indigo,
          duration: const Duration(seconds: 3),
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ SUCCESS! Data stored in database!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ SUCCESS! Data stored in database!"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        _formKey.currentState?.reset();
        setState(() {
          selectedChargerType = null;
          selectedAvailableHours = null;
          agreeToTerms = false;
        });
      } else {
        print("❌ Request failed with status: ${response.statusCode}");
        print("❌ Error response: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Failed: ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("💥 Exception occurred: $e");
      print("💥 Exception type: ${e.runtimeType}");
      if (e.toString().contains('Connection refused')) {
        print("🔌 Connection refused - Backend might not be running on port 8081");
      } else if (e.toString().contains('SocketException')) {
        print("🌐 Network error - Check if backend is accessible");
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF706DC7),
        title: const Text(
          'Become a Provider',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
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
              _buildFormField('Full Name', controller: _nameController, fieldId: 'full_name'),
              const SizedBox(height: 16),
              _buildFormField(
                'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                fieldId: 'phone_number',
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
              _buildFormField(
                'Complete Address',
                controller: _addressController,
                maxLines: 3,
                fieldId: 'complete_address',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                'Charger Type',
                ['Type 1', 'Type 2', 'CCS', 'CHAdeMO', 'Tesla'],
                value: selectedChargerType,
                fieldId: 'charger_type',
                validator: (value) =>
                    value == null ? 'Please select charger type' : null,
                onChanged: (value) {
                  setState(() {
                    selectedChargerType = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildFormField(
                'Charging Rate (₹/kWh)',
                controller: _rateController,
                keyboardType: TextInputType.number,
                fieldId: 'charging_rate',
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
              const SizedBox(height: 16),
              _buildDropdownField(
                'Available Hours',
                ['9AM-10AM', '4PM-8PM', '6PM-10PM', '24/7'],
                value: selectedAvailableHours,
                fieldId: 'available_hours',
                validator: (value) =>
                    value == null ? 'Please select available hours' : null,
                onChanged: (value) {
                  setState(() {
                    selectedAvailableHours = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              _buildEarningInfo(),
              const SizedBox(height: 24),
              _buildAgreementCheckbox(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Applications are reviewed within 24-48 hours of submission',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
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
          const Icon(Icons.lightbulb_outline,
              size: 50, color: Color(0xFF706DC7)),
          const SizedBox(height: 16),
          const Text(
            'Start earning with your EV charger',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share your home charger and earn money while helping the EV community',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
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
    String? fieldId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        TextFormField(
          key: fieldId != null ? Key(fieldId) : null,
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
    String? value,
    String? fieldId,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: fieldId != null ? Key(fieldId) : null,
          value: value,
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

  Widget _buildEarningInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF706DC7).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF706DC7).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_money, color: Color(0xFF706DC7), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earning Potential',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF706DC7))),
                const SizedBox(height: 4),
                Text(
                  'Average providers earn ₹3000 to ₹7000 per month by sharing their chargers 4-6 hours daily',
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
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
          key: const Key('agree_to_terms'),
          value: agreeToTerms,
          onChanged: (value) {
            setState(() {
              agreeToTerms = value ?? false;
            });
          },
        ),
        const Expanded(
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
                  text: 'Provider Guidelines',
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
          // ALWAYS show this message to confirm button works
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🔍 SUBMIT BUTTON PRESSED!"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );

          bool formValid = _formKey.currentState!.validate();
          
          // Show validation status
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("🔍 Form valid: $formValid, Terms: $agreeToTerms"),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );

          if (formValid && agreeToTerms) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("✅ Validation passed - calling _submitForm()"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            _submitForm();
          } else if (!agreeToTerms) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Please agree to terms and conditions'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Please fill all required fields'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF706DC7),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'Submit Application',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}

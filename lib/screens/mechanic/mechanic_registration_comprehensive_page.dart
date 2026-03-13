import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_config.dart';
import '../profile/location_picker_map_page.dart';
import 'mechanic_application_success_page.dart';

class MechanicRegistrationComprehensivePage extends StatefulWidget {
  /// When set, name/email/phone are shown read-only (from Cognito account).
  final String? prefilledName;
  final String? prefilledEmail;
  final String? prefilledPhone;

  const MechanicRegistrationComprehensivePage({
    super.key,
    this.prefilledName,
    this.prefilledEmail,
    this.prefilledPhone,
  });

  @override
  State<MechanicRegistrationComprehensivePage> createState() => _MechanicRegistrationComprehensivePageState();
}

class _MechanicRegistrationComprehensivePageState extends State<MechanicRegistrationComprehensivePage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;
  /// True when name/email/phone come from account (read-only).
  bool _accountPrefilled = false;

  // Step 1: Personal Information
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  File? _profilePhoto;
  final ImagePicker _imagePicker = ImagePicker();

  // Step 2: Shop Location
  final TextEditingController _shopNameController = TextEditingController();
  String? _shopAddress;
  String? _shopCity;
  String? _shopState;
  String? _shopPincode;
  String? _shopCountry;
  double? _shopLatitude;
  double? _shopLongitude;

  // Step 3: Services & Vehicle types
  String _vehicleTypes = 'CAR,BIKE'; // CAR, BIKE, or CAR,BIKE
  File? _towingVehiclePhoto;
  String? _towingVehiclePhotoUrl; // Set after upload (when Towing is offered)
  final List<String> _availableServices = [
    'Car Service',
    'Bike Service',
    'Emergency',
    'Towing',
    'Fuel Refill',
    'EV Charging',
    'Tyre Care',
    'Minor Repair',
    'Battery Jump',
    'General Repair',
    'Engine Service',
    'Electrical Works',
    'Brake Service',
    'AC Repair',
    'Body Works',
    'Tire Service',
    'Battery Service',
    'Headlight Repair',
    'Oil Change',
    'Windshield',
    'Wheel Alignment',
    'Suspension',
  ];
  final List<String> _selectedServices = [];
  static const _carSubServices = [
    'Towing', 'Battery Jump', 'Headlight Repair', 'Tyre Care', 'Oil Change',
    'Brake Service', 'Windshield', 'Body Works', 'Wheel Alignment', 'Suspension',
  ];
  static const _bikeSubServices = [
    'Battery', 'Tyre Care', 'Body Works', 'Brake Service', 'Towing',
    'Windshield', 'Wheel Alignment', 'Suspension',
  ];
  final List<String> _selectedCarSubServices = [];
  final List<String> _selectedBikeSubServices = [];

  // Step 4: Additional Info & Timing
  bool _nightTimeAvailable = false;
  String? _specialty;
  String? _openingTime;
  String? _closingTime;
  List<String> _workingDays = []; // Monday, Tuesday, etc.
  final List<String> _daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.prefilledName != null || widget.prefilledEmail != null || widget.prefilledPhone != null) {
      _accountPrefilled = true;
      if (widget.prefilledName != null) _nameController.text = widget.prefilledName!;
      if (widget.prefilledEmail != null) _emailController.text = widget.prefilledEmail!;
      if (widget.prefilledPhone != null) _phoneController.text = widget.prefilledPhone!;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _aadharController.dispose();
    _experienceController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _profilePhoto = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickShopLocation() async {
    LatLng? initialPos;
    try {
      Position position = await Geolocator.getCurrentPosition();
      initialPos = LatLng(position.latitude, position.longitude);
    } catch (e) {
      // Use default location if current location fails
      initialPos = const LatLng(12.9716, 77.5946); // Bangalore
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: initialPos,
          forMechanicShop: true, // No label dialog, no user login — just return location data
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _shopAddress = result['fullAddress'];
        _shopCity = result['city'];
        _shopState = result['state'];
        _shopPincode = result['pincode'];
        _shopCountry = result['country'];
        _shopLatitude = result['latitude'];
        _shopLongitude = result['longitude'];
      });
    }
  }

  Future<String?> _uploadImageToServer(File imageFile) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/profile/mechanic');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final url = json['url'] as String?;
        if (url != null) {
          print('📸 Profile photo uploaded to S3: $url');
          return url;
        }
      }
      // Fallback: base64 (when S3 not configured on backend)
      final bytes = await imageFile.readAsBytes();
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (e) {
      print('Error uploading image (fallback to base64): $e');
      try {
        final bytes = await imageFile.readAsBytes();
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      } catch (_) {
        return null;
      }
    }
  }

  Future<String?> _uploadTowingVehiclePhoto(File imageFile) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/towing-vehicle-photo');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return json['url'] as String?;
      }
      return null;
    } catch (e) {
      print('Error uploading towing vehicle photo: $e');
      return null;
    }
  }

  Future<void> _submitRegistration() async {
    // Validate all steps
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _aadharController.text.isEmpty ||
        _experienceController.text.isEmpty) {
      _showError('Please fill all personal information fields');
      _goToStep(0);
      return;
    }

    if (_shopNameController.text.isEmpty ||
        _shopAddress == null ||
        _shopLatitude == null ||
        _shopLongitude == null) {
      _showError('Please select your shop location');
      _goToStep(1);
      return;
    }

    if (_selectedServices.isEmpty) {
      _showError('Please select at least one service');
      _goToStep(2);
      return;
    }

    if (_profilePhoto == null) {
      _showError('Passport size photo is required. Please add your photo.');
      _goToStep(0);
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Upload profile photo (required)
      final profilePhotoUrl = await _uploadImageToServer(_profilePhoto!);
      if (profilePhotoUrl == null || profilePhotoUrl.isEmpty) {
        Navigator.pop(context);
        _showError('Failed to upload photo. Please try again.');
        return;
      }

      // Upload towing vehicle photo if provided
      if (_towingVehiclePhoto != null) {
        final url = await _uploadTowingVehiclePhoto(_towingVehiclePhoto!);
        if (url != null && mounted) setState(() => _towingVehiclePhotoUrl = url);
      }

      // Prepare mechanic data - all fields saved in DB (aadhar, shop, lat/long, all services, specialty, 24hr, times, working days)
      final mechanicData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'aadharNumber': _aadharController.text.trim(),
        'experience': _experienceController.text.trim(),
        'profilePhotoUrl': profilePhotoUrl,
        'shopName': _shopNameController.text.trim(),
        'shopAddress': _shopAddress ?? '',
        'shopCity': _shopCity ?? '',
        'shopState': _shopState ?? '',
        'shopPincode': _shopPincode ?? '',
        'shopCountry': _shopCountry ?? '',
        'latitude': _shopLatitude?.toString() ?? '',
        'longitude': _shopLongitude?.toString() ?? '',
        'services': _buildServicesString(),
        'specialty': _specialty ?? 'General',
        'nightTimeAvailable': _nightTimeAvailable,
        'openingTime': _openingTime ?? '',
        'closingTime': _closingTime ?? '',
        'workingDays': _workingDays.join(','),
        'vehicleTypes': _vehicleTypes,
        if (_towingVehiclePhotoUrl != null && _towingVehiclePhotoUrl!.isNotEmpty) 'towingVehiclePhotoUrl': _towingVehiclePhotoUrl,
        'approvalStatus': 'PENDING',
      };

      // Submit to backend
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/mechanic'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mechanicData),
      ).timeout(const Duration(seconds: 30));

      Navigator.pop(context); // Close loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        final email = _emailController.text.trim();
        // Keep mechanic in "success/waiting" state until admin approves or rejects
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('mechanic_pending_email', email);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicApplicationSuccessPage(
              mechanicEmail: email,
            ),
          ),
        );
      } else {
        _showError('Registration failed: ${response.body}');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showError('Error submitting registration: $e');
    }
  }

  String _buildServicesString() {
    final parts = <String>{..._selectedServices};
    if (_selectedServices.contains('Car Service') && _selectedCarSubServices.isNotEmpty) {
      parts.addAll(_selectedCarSubServices);
    }
    if (_selectedServices.contains('Bike Service') && _selectedBikeSubServices.isNotEmpty) {
      parts.addAll(_selectedBikeSubServices);
    }
    return parts.join(',');
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

  void _goToStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitRegistration();
    }
  }

  Widget _vehicleTypeChip(String label, String value) {
    final isSelected = _vehicleTypes == value;
    return GestureDetector(
      onTap: () => setState(() => _vehicleTypes = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mechanic Registration',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Progress indicator
                Row(
                  children: List.generate(_totalSteps, (index) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(
                          right: index < _totalSteps - 1 ? 8 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: index <= _currentStep
                              ? const Color(0xFF6366F1)
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          _buildPersonalInfoStep(),
          _buildShopLocationStep(),
          _buildServicesStep(),
          _buildAdditionalInfoStep(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                  child: Text(
                    'Previous',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF6366F1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep == _totalSteps - 1 ? 'Submit' : 'Next',
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
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please provide your personal details for verification',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          
          // Profile Photo
          Center(
            child: GestureDetector(
              onTap: _pickProfilePhoto,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6366F1),
                    width: 3,
                  ),
                ),
                child: _profilePhoto != null
                    ? ClipOval(
                        child: Image.file(
                          _profilePhoto!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Passport size photo (required)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Name (read-only when from account)
          if (_accountPrefilled)
            _buildReadOnlyField(
              label: 'Full Name',
              value: _nameController.text,
              icon: Icons.person,
            )
          else
            _buildTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person,
              hint: 'Enter your full name',
            ),
          const SizedBox(height: 20),

          // Email (read-only when from account)
          if (_accountPrefilled)
            _buildReadOnlyField(
              label: 'Email Address',
              value: _emailController.text,
              icon: Icons.email,
            )
          else
            _buildTextField(
              controller: _emailController,
              label: 'Email Address',
              icon: Icons.email,
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
            ),
          const SizedBox(height: 20),

          // Phone (read-only when from account)
          if (_accountPrefilled)
            _buildReadOnlyField(
              label: 'Phone Number',
              value: _phoneController.text,
              icon: Icons.phone,
            )
          else
            _buildTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone,
              hint: 'Enter your phone number',
              keyboardType: TextInputType.phone,
            ),
          const SizedBox(height: 20),

          // Aadhar Number
          _buildTextField(
            controller: _aadharController,
            label: 'Aadhar Card Number',
            icon: Icons.badge,
            hint: 'Enter 12-digit Aadhar number',
            keyboardType: TextInputType.number,
            maxLength: 12,
          ),
          const SizedBox(height: 20),

          // Experience
          _buildTextField(
            controller: _experienceController,
            label: 'Years of Experience',
            icon: Icons.work_history,
            hint: 'e.g., 5',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildShopLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shop Location',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your mechanic shop location on the map',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Shop Name
          _buildTextField(
            controller: _shopNameController,
            label: 'Shop Name',
            icon: Icons.store,
            hint: 'Enter your shop name',
          ),
          const SizedBox(height: 24),

          // Location Picker Button
          ElevatedButton.icon(
            onPressed: _pickShopLocation,
            icon: const Icon(Icons.location_on),
            label: Text(
              _shopAddress != null ? 'Change Location' : 'Select Shop Location',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Selected Location Display
          if (_shopAddress != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Location Selected',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _shopAddress!,
                    style: GoogleFonts.inter(
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                  ),
                  if (_shopCity != null || _shopState != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_shopCity ?? ''}, ${_shopState ?? ''} ${_shopPincode ?? ''}',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildServicesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vehicle types you serve',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _vehicleTypeChip('Car only', 'CAR'),
              const SizedBox(width: 8),
              _vehicleTypeChip('Bike only', 'BIKE'),
              const SizedBox(width: 8),
              _vehicleTypeChip('Both', 'CAR,BIKE'),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Select Services',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the services you want to provide',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Services Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _availableServices.length,
            itemBuilder: (context, index) {
              final service = _availableServices[index];
              final isSelected = _selectedServices.contains(service);
              final isTowingOnly = _selectedServices.length == 1 && _selectedServices.contains('Towing');
              final isDisabled = isTowingOnly && service != 'Towing';
              return GestureDetector(
                onTap: isDisabled
                    ? null
                    : () {
                        setState(() {
                          if (isSelected) {
                            _selectedServices.remove(service);
                          } else {
                            _selectedServices.add(service);
                          }
                        });
                      },
                child: Opacity(
                  opacity: isDisabled ? 0.5 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        service,
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Car sub-services (when Car Service is selected)
          if (_selectedServices.contains('Car Service')) ...[
            Text(
              'Car sub-services – select which you provide',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _carSubServices.map((s) {
                final sel = _selectedCarSubServices.contains(s);
                return FilterChip(
                  selected: sel,
                  label: Text(s),
                  onSelected: (v) {
                    setState(() {
                      if (v) _selectedCarSubServices.add(s);
                      else _selectedCarSubServices.remove(s);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Bike sub-services (when Bike Service is selected)
          if (_selectedServices.contains('Bike Service')) ...[
            Text(
              'Bike sub-services – select which you provide',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _bikeSubServices.map((s) {
                final sel = _selectedBikeSubServices.contains(s);
                return FilterChip(
                  selected: sel,
                  label: Text(s),
                  onSelected: (v) {
                    setState(() {
                      if (v) _selectedBikeSubServices.add(s);
                      else _selectedBikeSubServices.remove(s);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          if (_selectedServices.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Services (${_buildServicesString().split(',').where((s) => s.isNotEmpty).length})',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildServicesString().split(',').where((s) => s.isNotEmpty).map((service) {
                      return Chip(
                        label: Text(service.trim()),
                        backgroundColor: Colors.blue[100],
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedServices.remove(service);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
          if (_selectedServices.contains('Towing')) ...[
            const SizedBox(height: 20),
            Text(
              'Towing vehicle photo (optional)',
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_towingVehiclePhoto != null || _towingVehiclePhotoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: _towingVehiclePhoto != null
                          ? Image.file(_towingVehiclePhoto!, fit: BoxFit.cover)
                          : _towingVehiclePhotoUrl != null
                              ? Image.network(_towingVehiclePhotoUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 40))
                              : const SizedBox(),
                    ),
                  ),
                if (_towingVehiclePhoto != null || _towingVehiclePhotoUrl != null) const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () async {
                    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 85);
                    if (image != null) setState(() { _towingVehiclePhoto = File(image.path); _towingVehiclePhotoUrl = null; });
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add photo'),
                ),
                if (_towingVehiclePhoto != null || _towingVehiclePhotoUrl != null)
                  TextButton.icon(
                    onPressed: () => setState(() { _towingVehiclePhoto = null; _towingVehiclePhotoUrl = null; }),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Remove'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Information',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide additional details about your services',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          // Specialty
          Text(
            'Specialty',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _specialty,
            decoration: InputDecoration(
              hintText: 'Select your specialty',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.star),
            ),
            items: ['General', 'Car Specialist', 'Bike Specialist', 'EV Specialist', 'Emergency']
                .map((specialty) => DropdownMenuItem(
                      value: specialty,
                      child: Text(specialty),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _specialty = value;
              });
            },
          ),
          const SizedBox(height: 32),

          // Night Time Available
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '24/7 Available',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Available for night time emergencies',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _nightTimeAvailable,
                  onChanged: (value) {
                    setState(() {
                      _nightTimeAvailable = value;
                    });
                  },
                  activeColor: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Shop Timing
          Text(
            'Shop Timing',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          
          // Opening & Closing Time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opening Time',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _openingTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Color(0xFF6366F1)),
                            const SizedBox(width: 12),
                            Text(
                              _openingTime ?? 'Select time',
                              style: GoogleFonts.inter(
                                color: _openingTime != null ? Colors.black : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Closing Time',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _closingTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: Color(0xFF6366F1)),
                            const SizedBox(width: 12),
                            Text(
                              _closingTime ?? 'Select time',
                              style: GoogleFonts.inter(
                                color: _closingTime != null ? Colors.black : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Working Days
          Text(
            'Working Days',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _daysOfWeek.map((day) {
              final isSelected = _workingDays.contains(day);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _workingDays.remove(day);
                    } else {
                      _workingDays.add(day);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF6366F1) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    day,
                    style: GoogleFonts.outfit(
                      color: isSelected ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6366F1).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Summary',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryRow('Name', _nameController.text),
                _buildSummaryRow('Email', _emailController.text),
                _buildSummaryRow('Phone', _phoneController.text),
                _buildSummaryRow('Shop', _shopNameController.text),
                _buildSummaryRow('Services', '${_selectedServices.length} selected'),
                _buildSummaryRow('24/7 Available', _nightTimeAvailable ? 'Yes' : 'No'),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6366F1), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value.isEmpty ? '—' : value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
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

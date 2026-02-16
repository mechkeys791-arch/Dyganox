import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../profile/location_picker_map_page.dart';

class MechanicProfileEditPage extends StatefulWidget {
  final Map<String, dynamic> mechanicProfile;
  final Function(Map<String, dynamic>) onSave;
  
  const MechanicProfileEditPage({
    super.key,
    required this.mechanicProfile,
    required this.onSave,
  });

  @override
  State<MechanicProfileEditPage> createState() => _MechanicProfileEditPageState();
}

class _MechanicProfileEditPageState extends State<MechanicProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _experienceController;
  late TextEditingController _specialtyController;
  late TextEditingController _rateController;
  
  Uint8List? _profileImageBytes;
  bool _isAvailableForNightService = false;
  bool _isCurrentlyAvailable = true;
  double? _savedLatitude;
  double? _savedLongitude;
  String? _savedShopAddress;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize controllers with existing data
    _nameController = TextEditingController(text: widget.mechanicProfile['name'] ?? '');
    _phoneController = TextEditingController(text: widget.mechanicProfile['phone'] ?? '');
    _emailController = TextEditingController(text: widget.mechanicProfile['email'] ?? '');
    _experienceController = TextEditingController(text: widget.mechanicProfile['experience'] ?? '');
    _specialtyController = TextEditingController(text: widget.mechanicProfile['specialty'] ?? '');
    _rateController = TextEditingController(text: widget.mechanicProfile['rate']?.toString() ?? '500');
    
    _isAvailableForNightService = widget.mechanicProfile['nightTimeAvailable'] ?? false;
    final lat = double.tryParse(widget.mechanicProfile['latitude']?.toString() ?? '');
    final lng = double.tryParse(widget.mechanicProfile['longitude']?.toString() ?? '');
    if (lat != null && lng != null) {
      _savedLatitude = lat;
      _savedLongitude = lng;
    }
    _savedShopAddress = widget.mechanicProfile['shopAddress'] ?? widget.mechanicProfile['shop_address'];
  }
  
  Future<void> _pickShopLocation() async {
    LatLng? initialPos;
    if (_savedLatitude != null && _savedLongitude != null) {
      initialPos = LatLng(_savedLatitude!, _savedLongitude!);
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: initialPos,
          forMechanicShop: true,
        ),
      ),
    );
    
    if (result != null && mounted) {
      final lat = result['latitude'] as num?;
      final lng = result['longitude'] as num?;
      if (lat != null && lng != null) {
        setState(() {
          _savedLatitude = lat.toDouble();
          _savedLongitude = lng.toDouble();
          _savedShopAddress = result['fullAddress']?.toString();
        });
        _showSnackBar('Location updated! Save to apply.', const Color(0xFF10B981));
      }
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _experienceController.dispose();
    _specialtyController.dispose();
    _rateController.dispose();
    super.dispose();
  }
  
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
      });
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      final updatedProfile = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'experience': _experienceController.text,
        'specialty': _specialtyController.text,
        'latitude': _savedLatitude?.toString() ?? widget.mechanicProfile['latitude']?.toString(),
        'longitude': _savedLongitude?.toString() ?? widget.mechanicProfile['longitude']?.toString(),
        'shopAddress': _savedShopAddress ?? widget.mechanicProfile['shopAddress'] ?? widget.mechanicProfile['shop_address'],
        'rate': _rateController.text,
        'nightTimeAvailable': _isAvailableForNightService,
        'rating': widget.mechanicProfile['rating'],
        'completedJobs': widget.mechanicProfile['completedJobs'],
      };
      
      widget.onSave(updatedProfile);
      Navigator.pop(context);
      _showSnackBar('Profile updated successfully!', const Color(0xFF10B981));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6366F1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.check, color: Colors.white),
            label: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.05),
              Colors.white.withOpacity(0.8),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section
                _buildProfilePictureSection(),
                const SizedBox(height: 24),
                
                // Basic Info Card
                _buildSectionCard(
                  title: 'Basic Information',
                  icon: Icons.person,
                  children: [
                    _buildTextField('Full Name', _nameController, Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildTextField('Phone', _phoneController, Icons.phone, keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Professional Info Card
                _buildSectionCard(
                  title: 'Professional Details',
                  icon: Icons.work,
                  children: [
                    _buildTextField('Specialty', _specialtyController, Icons.build_circle),
                    const SizedBox(height: 16),
                    _buildTextField('Experience', _experienceController, Icons.timeline),
                    const SizedBox(height: 16),
                    _buildTextField('Hourly Rate (₹)', _rateController, Icons.currency_rupee, keyboardType: TextInputType.number),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Location Card - Shop location from registration, change via map
                _buildSectionCard(
                  title: 'Shop Location',
                  icon: Icons.location_on,
                  children: [
                    if (_savedShopAddress != null || widget.mechanicProfile['shopAddress'] != null || widget.mechanicProfile['shop_address'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(Icons.place, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _savedShopAddress ?? widget.mechanicProfile['shopAddress'] ?? widget.mechanicProfile['shop_address'] ?? '',
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _pickShopLocation,
                        icon: const Icon(Icons.edit_location_alt),
                        label: const Text('Change Shop Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Availability Settings
                _buildSectionCard(
                  title: 'Availability Settings',
                  icon: Icons.access_time,
                  children: [
                    SwitchListTile(
                      value: _isCurrentlyAvailable,
                      onChanged: (value) {
                        setState(() => _isCurrentlyAvailable = value);
                      },
                      title: Text(
                        'Currently Available',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Toggle to accept new bookings',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                      activeColor: const Color(0xFF10B981),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: _isAvailableForNightService,
                      onChanged: (value) {
                        setState(() => _isAvailableForNightService = value);
                      },
                      title: Text(
                        'Night Service (8 PM - 6 AM)',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Earn extra with night surcharge',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                      activeColor: const Color(0xFF6366F1),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'Save Changes',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Stats Display (Read-only)
                _buildStatsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildProfilePictureSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _profileImageBytes != null
                      ? ClipOval(
                          child: Image.memory(_profileImageBytes!, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.account_circle, size: 60, color: Colors.white),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tap to change photo',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6366F1).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter $label';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Your Performance',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.star,
                '${widget.mechanicProfile['rating'] ?? 0.0}',
                'Rating',
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _buildStatItem(
                Icons.check_circle,
                '${widget.mechanicProfile['completedJobs'] ?? 0}',
                'Jobs Done',
              ),
              Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3)),
              _buildStatItem(
                Icons.currency_rupee,
                _rateController.text,
                'Per Hour',
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}


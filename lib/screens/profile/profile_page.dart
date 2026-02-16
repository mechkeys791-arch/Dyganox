import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../vehicles/vehicles_page.dart';
import 'addresses_page.dart';
import 'payment_methods_page.dart';
import 'service_history_page.dart';
import '../../widgets/custom_nav_bar.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/user_profile_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  DateTime? _dateOfBirth;
  String _gender = '';
  String _selectedLocation = '';
  String? _profileImagePath;
  Uint8List? _profileImageBytes;
  String? _profilePhotoUrl;
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load from Cognito service keys (matching what CognitoService saves)
    final userData = await CognitoService.getCurrentUser();
    
    final email = userData['email'] ?? prefs.getString('user_email') ?? '';
    
    setState(() {
      _userName = userData['name'] ?? prefs.getString('user_name') ?? '';
      _userEmail = email;
      _userPhone = userData['phone'] ?? prefs.getString('user_phone') ?? '';
    });
    
    // Load Date of Birth and Gender from database
    if (email.isNotEmpty) {
      try {
        final profileResult = await UserProfileService.getUserProfile(email);
        if (profileResult['success'] == true && profileResult['data'] != null) {
          final profileData = profileResult['data'];
          setState(() {
            // Update DOB from database
            if (profileData['dateOfBirth'] != null && profileData['dateOfBirth'].toString().isNotEmpty) {
              _dateOfBirth = DateTime.tryParse(profileData['dateOfBirth']);
              // Also save to local storage as backup
              if (_dateOfBirth != null) {
                prefs.setString('user_date_of_birth', _dateOfBirth!.toIso8601String());
              }
            } else {
              // Fallback to local storage if database doesn't have it
              final dobString = prefs.getString('user_date_of_birth');
              if (dobString != null) {
                _dateOfBirth = DateTime.tryParse(dobString);
              }
            }
            
            // Update Gender from database
            if (profileData['gender'] != null && profileData['gender'].toString().isNotEmpty) {
              _gender = profileData['gender'].toString();
              // Also save to local storage as backup
              prefs.setString('user_gender', _gender);
            } else {
              // Fallback to local storage if database doesn't have it
              _gender = prefs.getString('user_gender') ?? '';
            }
            // Profile photo URL from S3
            if (profileData['profilePhotoUrl'] != null && profileData['profilePhotoUrl'].toString().isNotEmpty) {
              _profilePhotoUrl = profileData['profilePhotoUrl'].toString();
              prefs.setString('profilePhotoUrl', _profilePhotoUrl!);
            } else {
              _profilePhotoUrl = prefs.getString('profilePhotoUrl');
            }
          });
        } else {
          // Database doesn't have profile, load from local storage
          _loadFromLocalStorage(prefs);
        }
        
        // Load selected address/location from user_addresses table
        try {
          final addressResult = await UserProfileService.getUserAddresses(email);
          if (addressResult['success'] == true && addressResult['data'] != null) {
            final rawList = addressResult['data'];
            final List<Map<String, dynamic>> addresses = rawList is List
                ? (rawList as List)
                    .where((e) => e is Map)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList()
                : [];
            if (addresses.isNotEmpty) {
              Map<String, dynamic> selected = addresses.firstWhere(
                (addr) => addr['isSelected'] == true,
                orElse: () => addresses.first,
              );
              final label = selected['label'] ?? '';
              final addressText = selected['fullAddress'] ??
                  selected['addressLine1'] ??
                  '${selected['city'] ?? ''}, ${selected['state'] ?? ''}'.trim();
              final displayText = label.isNotEmpty
                  ? '$label - $addressText'
                  : addressText.isNotEmpty
                      ? addressText
                      : 'Location set';
              if (!mounted) return;
              setState(() => _selectedLocation = displayText);
            } else {
              if (!mounted) return;
              setState(() => _selectedLocation = 'No address saved');
            }
          } else {
            if (!mounted) return;
            setState(() => _selectedLocation = 'No address saved');
          }
        } catch (e) {
          print('Warning: Could not load location from database: $e');
          if (!mounted) return;
          setState(() => _selectedLocation = 'No address saved');
        }
      } catch (e) {
        // If database fails, load from local storage
        print('Warning: Could not load profile from database: $e');
        _loadFromLocalStorage(prefs);
      }
    } else {
      // No email, load from local storage only
      _loadFromLocalStorage(prefs);
    }
    
    // Load profile image and settings from local storage
    setState(() {
      _profilePhotoUrl = prefs.getString('profilePhotoUrl');
      _profileImagePath = prefs.getString('profileImage');
      final imageBytesBase64 = prefs.getString('profileImageBytes');
      if (imageBytesBase64 != null) {
        try {
          _profileImageBytes = base64Decode(imageBytesBase64);
        } catch (e) {
          _profileImageBytes = null;
        }
      }
      
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _darkModeEnabled = prefs.getBool('darkMode') ?? false;
    });
  }
  
  void _loadFromLocalStorage(SharedPreferences prefs) {
    setState(() {
      // Load Date of Birth from local storage
      final dobString = prefs.getString('user_date_of_birth');
      if (dobString != null) {
        _dateOfBirth = DateTime.tryParse(dobString);
      }
      
      // Load Gender from local storage
      _gender = prefs.getString('user_gender') ?? '';
    });
  }

  Future<void> _saveUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save using Cognito service keys (matching what CognitoService uses)
    await prefs.setString('user_name', _userName);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_phone', _userPhone);
    
    // Save Date of Birth to local storage
    if (_dateOfBirth != null) {
      await prefs.setString('user_date_of_birth', _dateOfBirth!.toIso8601String());
    } else {
      await prefs.remove('user_date_of_birth');
    }
    
    // Save Gender to local storage
    if (_gender.isNotEmpty) {
      await prefs.setString('user_gender', _gender);
    } else {
      await prefs.remove('user_gender');
    }
    
    // Save Date of Birth and Gender to database
    if (_userEmail.isNotEmpty) {
      try {
        final dobString = _dateOfBirth != null ? _dateOfBirth!.toIso8601String().split('T')[0] : null;
        final result = await UserProfileService.saveUserProfile(
          email: _userEmail,
          name: _userName,
          phone: _userPhone,
          dateOfBirth: dobString,
          gender: _gender.isNotEmpty ? _gender : null,
          profilePhotoUrl: _profilePhotoUrl,
        );
        
        if (result['success'] == true) {
          print('✅ Profile saved to database successfully');
        } else {
          print('❌ Failed to save profile to database: ${result['error']}');
          // Show error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Warning: Could not save to database. Data saved locally only.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        // If database save fails, data is still saved locally
        print('❌ Exception saving profile to database: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: Could not save to database. Data saved locally only.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
    
    // Save profile image
    if (_profileImagePath != null) {
      await prefs.setString('profileImage', _profileImagePath!);
    }
    if (_profileImageBytes != null) {
      await prefs.setString('profileImageBytes', base64Encode(_profileImageBytes!));
    } else {
      await prefs.remove('profileImageBytes');
    }
    
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('darkMode', _darkModeEnabled);
  }

  ImageProvider? _getProfileImageProvider() {
    if (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty) {
      return NetworkImage(_profilePhotoUrl!);
    }
    if (_profileImageBytes != null) {
      return MemoryImage(_profileImageBytes!);
    }
    return null;
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Choose Profile Picture',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (!kIsWeb)
                    _buildImageSourceOption(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onTap: () async {
                        Navigator.pop(context);
                        final XFile? image = await picker.pickImage(
                          source: ImageSource.camera,
                          imageQuality: 80,
                        );
                        if (image != null) {
                          await _saveProfileImage(image);
                        }
                      },
                    ),
                  _buildImageSourceOption(
                    icon: Icons.photo_library,
                    label: kIsWeb ? 'Choose Image' : 'Gallery',
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await picker.pickImage(
                        source: kIsWeb ? ImageSource.gallery : ImageSource.gallery,
                        imageQuality: 80,
                      );
                        if (image != null) {
                          await _saveProfileImage(image);
                        }
                    },
                  ),
                  if (_profileImagePath != null)
                    _buildImageSourceOption(
                      icon: Icons.delete,
                      label: 'Remove',
                      color: Colors.red,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _profileImagePath = null;
                        });
                        _saveUserData();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  /// Save profile image - upload to S3, update backend, and save locally
  Future<void> _saveProfileImage(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final email = _userEmail;
      if (email.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please sign in to save profile photo'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      // Upload to S3 via backend (use fromBytes for web + mobile compatibility)
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/profile/user');
      final request = http.MultipartRequest('POST', uri);
      request.fields['email'] = email;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
          final url = decoded?['url'] as String?;
          if (url != null && url.isNotEmpty) {
            setState(() {
              _profilePhotoUrl = url;
              _profileImagePath = image.path;
              _profileImageBytes = bytes;
            });
            // Backend upload endpoint already updates Person.profilePhotoUrl
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('profilePhotoUrl', url);
            await prefs.setString('profileImage', image.path);
            await prefs.setString('profileImageBytes', base64Encode(bytes));

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Profile picture saved successfully!',
                    style: GoogleFonts.inter(color: Colors.white),
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
            return;
          }
        } catch (_) {}
      }

      // Fallback: save locally only
      setState(() {
        _profileImagePath = image.path;
        _profileImageBytes = bytes;
      });
      await _saveUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile picture saved locally (upload failed)',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Fallback: save locally
      try {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImagePath = image.path;
          _profileImageBytes = bytes;
        });
        await _saveUserData();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e. Saved locally only.',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFF6366F1)).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color ?? const Color(0xFF6366F1), size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color ?? const Color(0xFF6366F1),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final emailController = TextEditingController(text: _userEmail);
    final phoneController = TextEditingController(text: _userPhone);
    final genderController = TextEditingController(text: _gender);
    DateTime? selectedDate = _dateOfBirth;
    String selectedGender = _gender; // Local variable for gender in dialog

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Edit Personal Information',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        // Date of Birth
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setDialogState) {
                            return InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
                                  firstDate: DateTime(1950),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setDialogState(() {
                                    selectedDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Date of Birth',
                                  prefixIcon: const Icon(Icons.calendar_today),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                child: Text(
                                  selectedDate != null
                                      ? DateFormat('yyyy-MM-dd').format(selectedDate!)
                                      : 'Select Date of Birth',
                                  style: GoogleFonts.inter(
                                    color: selectedDate != null ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        // Gender
                        StatefulBuilder(
                          builder: (BuildContext context, StateSetter setDialogState) {
                            return DropdownButtonFormField<String>(
                              value: selectedGender.isNotEmpty ? selectedGender : null,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              items: ['Male', 'Female', 'Other'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setDialogState(() {
                                    selectedGender = newValue;
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _userName = nameController.text;
                            _userEmail = emailController.text;
                            _userPhone = phoneController.text;
                            _dateOfBirth = selectedDate;
                            _gender = selectedGender; // Update gender from dialog
                          });
                          _saveUserData();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Profile updated successfully!',
                                style: GoogleFonts.inter(color: Colors.white),
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
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
          onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          color: const Color(0xFF6366F1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.02,
            ),
          child: Column(
            children: [
              // Profile Header with Image
              Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: screenWidth * 0.15,
                        backgroundColor: const Color(0xFF706DC7),
                        backgroundImage: _getProfileImageProvider(),
                        child: _getProfileImageProvider() == null
                            ? Icon(
                                Icons.person,
                                size: screenWidth * 0.15,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    _userName,
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    _userEmail,
                    style: GoogleFonts.inter(
                      fontSize: screenWidth * 0.04,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userPhone,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Settings Section
              _buildSectionHeader('Settings'),
              const SizedBox(height: 12),
              
              _buildPersonalInfoCard(),
              
              _buildSwitchOption(
                icon: Icons.notifications_outlined,
                title: 'Push Notifications',
                subtitle: 'Receive service updates and alerts',
                value: _notificationsEnabled,
                onChanged: (value) async {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  await _saveUserData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Notifications ${value ? 'enabled' : 'disabled'}',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF6366F1),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // My Services Section
              _buildSectionHeader('My Services'),
              const SizedBox(height: 12),
              
              _buildProfileOption(
                icon: Icons.directions_car,
                title: 'My Vehicles',
                subtitle: 'Manage your registered vehicles',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const VehiclesPage()),
                  );
                },
              ),
              _buildProfileOption(
                icon: Icons.location_on_outlined,
                title: 'Saved Addresses',
                subtitle: 'Manage your saved addresses',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddressesPage()),
                  );
                  if (mounted) _loadUserData();
                },
              ),
              _buildProfileOption(
                icon: Icons.payment_outlined,
                title: 'Payment Methods',
                subtitle: 'Manage your payment options',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PaymentMethodsPage()),
                  );
                },
              ),
              _buildProfileOption(
                icon: Icons.history,
                title: 'Service History',
                subtitle: 'View your past service requests',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ServiceHistoryPage()),
                  );
                },
              ),
              _buildProfileOption(
                icon: Icons.favorite_outline,
                title: 'Favorite Services',
                subtitle: 'Your saved services and providers',
                onTap: () {
                  _showFavoritesDialog();
                },
              ),

              const SizedBox(height: 24),

              // Support Section
              _buildSectionHeader('Support & Info'),
              const SizedBox(height: 12),
              
              _buildProfileOption(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help and contact support',
                onTap: () {
                  _showHelpDialog();
                },
              ),
              _buildProfileOption(
                icon: Icons.policy_outlined,
                title: 'Privacy Policy',
                subtitle: 'Read our privacy policy',
                onTap: () {
                  _showPrivacyPolicyDialog();
                },
              ),
              _buildProfileOption(
                icon: Icons.description_outlined,
                title: 'Terms & Conditions',
                subtitle: 'Read our terms and conditions',
                onTap: () {
                  _showTermsDialog();
                },
              ),
              _buildProfileOption(
                icon: Icons.info_outline,
                title: 'About Dyganox',
                subtitle: 'App version 1.0.0',
                onTap: () {
                  _showAboutDialog();
                },
              ),

              const SizedBox(height: 24),

              // Logout Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.logout,
                                  color: Color(0xFFEF4444),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          content: Text(
                            'Are you sure you want to logout?',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                await CognitoService.signOut();
                                if (context.mounted) {
                                  Navigator.pop(context); // Close dialog
                                  // Navigate to user type selection and remove all previous routes
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/user-type-selection',
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Logout',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.logout,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Logout',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
        ),
      ),
      // Custom Floating Bottom Navigation Bar
      bottomNavigationBar: const CustomNavBar(currentIndex: 2),
    );
  }


  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF6366F1),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF94A3B8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF6366F1),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF6366F1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFavoritesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFFEF4444)),
            const SizedBox(width: 12),
            Text('Favorite Services', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildFavoriteItem('Car Full Service', 'Complete car maintenance'),
              _buildFavoriteItem('Battery Jump Start', 'Emergency battery service'),
              _buildFavoriteItem('Tyre Care', 'Tyre replacement & repair'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteItem(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.help, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Text('Help & Support', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Us:', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildContactItem(Icons.phone, '+91 1800 123 4567'),
            _buildContactItem(Icons.email, 'support@dyganox.com'),
            _buildContactItem(Icons.language, 'www.dyganox.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Text(text, style: GoogleFonts.inter(color: const Color(0xFF64748B))),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.policy, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Text('Privacy Policy', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This policy explains how we collect, use, and protect your personal information...\n\n'
            '1. Data Collection: We collect only necessary information.\n'
            '2. Data Usage: Your data is used to improve services.\n'
            '3. Data Protection: We use industry-standard security measures.\n'
            '4. Your Rights: You have control over your data.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.description, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Text('Terms & Conditions', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Welcome to Dyganox. By using our services, you agree to these terms:\n\n'
            '1. Service Usage: Use services responsibly and legally.\n'
            '2. Payment: All payments are processed securely.\n'
            '3. Cancellation: Check our cancellation policy.\n'
            '4. Liability: We strive for quality service delivery.',
            style: GoogleFonts.inter(color: const Color(0xFF64748B)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info, color: Color(0xFF6366F1)),
            const SizedBox(width: 12),
            Text('About Dyganox', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dyganox - Your On-Demand Vehicle Service App',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _buildAboutItem('Version', '1.0.0'),
            _buildAboutItem('Build', '100'),
            _buildAboutItem('Platform', 'Flutter'),
            const SizedBox(height: 16),
            Text(
              '© 2024 Dyganox. All rights reserved.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.outfit(color: const Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: _showEditProfileDialog,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF6366F1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to update your details',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF94A3B8),
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),
                // Name
                _buildInfoRow(Icons.person, 'Name', _userName.isNotEmpty ? _userName : 'Not set'),
                const SizedBox(height: 16),
                // Email
                _buildInfoRow(Icons.email, 'Email', _userEmail.isNotEmpty ? _userEmail : 'Not set'),
                const SizedBox(height: 16),
                // Phone
                _buildInfoRow(Icons.phone, 'Phone', _userPhone.isNotEmpty ? _userPhone : 'Not set'),
                const SizedBox(height: 16),
                // Date of Birth
                _buildInfoRow(
                  Icons.calendar_today,
                  'Date of Birth',
                  _dateOfBirth != null ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!) : 'Not set',
                ),
                const SizedBox(height: 16),
                // Gender
                _buildInfoRow(Icons.person_outline, 'Gender', _gender.isNotEmpty ? _gender : 'Not set'),
                const SizedBox(height: 16),
                // Location (from user_addresses table)
                _buildInfoRow(Icons.location_on, 'Location', _selectedLocation.isNotEmpty ? _selectedLocation : 'No address saved'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

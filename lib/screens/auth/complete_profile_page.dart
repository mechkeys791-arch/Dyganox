import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import '../../services/user_profile_service.dart';
import '../../homepage.dart';

class CompleteProfilePage extends StatefulWidget {
  final String email;
  final String name;

  const CompleteProfilePage({
    super.key,
    required this.email,
    required this.name,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  DateTime? _dateOfBirth;
  String _gender = '';
  String? _profilePhotoUrl;
  String? _profileImagePath;
  List<int>? _profileImageBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    setState(() {
      _profileImagePath = image.path;
      _profileImageBytes = bytes;
    });
  }

  Future<String?> _uploadProfilePhoto() async {
    if (_profileImageBytes == null) return null;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/profile/user');
      final request = http.MultipartRequest('POST', uri);
      request.fields['email'] = widget.email;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        _profileImageBytes!,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>?;
        return decoded?['url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      String? photoUrl = _profilePhotoUrl;
      if (_profileImageBytes != null) {
        photoUrl = await _uploadProfilePhoto();
      }
      String phone = _phoneController.text.trim();
      if (!phone.startsWith('+')) phone = '+91$phone';
      final dobString = _dateOfBirth != null
          ? _dateOfBirth!.toIso8601String().split('T')[0]
          : null;
      final result = await UserProfileService.saveUserProfile(
        email: widget.email,
        name: _nameController.text.trim(),
        phone: phone,
        dateOfBirth: dobString,
        gender: _gender.isEmpty ? null : _gender,
        profilePhotoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']?.toString() ?? 'Failed to save profile'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _nameController.text.trim());
      await prefs.setString('user_phone', phone);
      if (dobString != null) await prefs.setString('user_date_of_birth', _dateOfBirth!.toIso8601String());
      if (_gender.isNotEmpty) await prefs.setString('user_gender', _gender);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        await prefs.setString('profilePhotoUrl', photoUrl);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Complete your profile',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Center(
                            child: GestureDetector(
                              onTap: _pickProfileImage,
                              child: CircleAvatar(
                                radius: 56,
                                backgroundColor: Colors.grey[200],
                                backgroundImage: _profileImageBytes != null
                                    ? MemoryImage(Uint8List.fromList(_profileImageBytes!))
                                    : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                        ? NetworkImage(_profilePhotoUrl!)
                                        : null),
                                child: _profileImageBytes == null &&
                                        (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                                    ? Icon(Icons.add_a_photo, size: 48, color: Colors.grey[600])
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'Add profile photo',
                              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Name',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter name' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Phone number',
                              hintText: 'e.g. 9876543210 or +919876543210',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone number' : null,
                          ),
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
                                firstDate: DateTime(1900),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) setState(() => _dateOfBirth = date);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date of birth',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                _dateOfBirth != null
                                    ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                    : 'Select date',
                                style: GoogleFonts.inter(
                                  color: _dateOfBirth != null ? Colors.black87 : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _gender.isEmpty ? null : _gender,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.wc_outlined),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (v) => setState(() => _gender = v ?? ''),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveAndContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Text('Save & continue', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
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

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Service for managing user profile data (DOB, Gender) in database
class UserProfileService {
  /// Save or update user profile (DOB, Gender) to database
  static Future<Map<String, dynamic>> saveUserProfile({
    required String email,
    required String name,
    required String phone,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      final requestBody = {
        'email': email,
        'name': name,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
      };
      
      print('💾 Saving user profile to database:');
      print('   Email: $email');
      print('   Name: $name');
      print('   Phone: $phone');
      print('   DOB: $dateOfBirth');
      print('   Gender: $gender');
      print('   URL: ${ApiConfig.baseUrl}/api/person/profile');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/person/profile'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Profile saved successfully to database');
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ Failed to save profile: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Failed to save profile: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('❌ Exception saving profile: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user profile by email from database
  static Future<Map<String, dynamic>> getUserProfile(String email) async {
    try {
      final url = '${ApiConfig.baseUrl}/api/person/email/${Uri.encodeComponent(email)}';
      print('🔍 Loading user profile from database:');
      print('   Email: $email');
      print('   URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Profile loaded successfully from database');
        print('   DOB: ${data['dateOfBirth']}');
        print('   Gender: ${data['gender']}');
        return {
          'success': true,
          'data': data,
        };
      } else if (response.statusCode == 404 || response.statusCode == 500) {
        // User not found - return empty profile
        print('⚠️ User profile not found in database (status: ${response.statusCode})');
        return {
          'success': true,
          'data': null,
        };
      } else {
        print('❌ Failed to get profile: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Failed to get profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      // If backend is not available, return empty (fallback to local storage)
      print('❌ Exception loading profile: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Update user profile by email
  static Future<Map<String, dynamic>> updateUserProfile({
    required String email,
    String? name,
    String? phone,
    String? dateOfBirth,
    String? gender,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/person/profile/${Uri.encodeComponent(email)}'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (phone != null) 'phone': phone,
          if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
          if (gender != null) 'gender': gender,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to update profile: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

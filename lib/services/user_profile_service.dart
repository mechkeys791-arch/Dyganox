import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Service for managing user profile data (DOB, Gender) in database
class UserProfileService {
  /// Save or update user profile (DOB, Gender, profilePhotoUrl) to database
  static Future<Map<String, dynamic>> saveUserProfile({
    required String email,
    required String name,
    required String phone,
    String? dateOfBirth,
    String? gender,
    String? profilePhotoUrl,
  }) async {
    try {
      final requestBody = {
        'email': email,
        'name': name,
        'phone': phone,
        'dateOfBirth': dateOfBirth,
        'gender': gender,
        if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      };
      
      print('💾 Saving user profile to database:');
      print('   Email: $email');
      print('   Name: $name');
      print('   Phone: $phone');
      print('   DOB: $dateOfBirth');
      print('   Gender: $gender');
      
      final jsonBody = jsonEncode(requestBody);
      print('   Request JSON: $jsonBody');
      
      // Try the /profile endpoint first, fallback to base /api/person if it fails
      String endpoint = '${ApiConfig.baseUrl}/api/person/profile';
      print('   URL: $endpoint');
      
      var response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonBody,
      ).timeout(const Duration(seconds: 10));
      
      // If 405 Method Not Allowed, try the base POST endpoint as fallback
      if (response.statusCode == 405) {
        print('⚠️ /profile endpoint returned 405, trying base /api/person endpoint');
        endpoint = '${ApiConfig.baseUrl}/api/person';
        print('   Fallback URL: $endpoint');
        response = await http.post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonBody,
        ).timeout(const Duration(seconds: 10));
      }

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
    String? profilePhotoUrl,
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
          if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
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

  /// Save user address to database
  static Future<Map<String, dynamic>> saveUserAddress({
    required String email,
    required Map<String, dynamic> address,
  }) async {
    try {
      final requestBody = {
        'userEmail': email,
        'label': address['label'],
        'fullAddress': address['fullAddress'],
        'addressLine1': address['addressLine1'],
        'addressLine2': address['addressLine2'] ?? '',
        'city': address['city'] ?? '',
        'pincode': address['pincode'] ?? '',
        'state': address['state'] ?? '',
        'country': address['country'] ?? '',
        'latitude': address['latitude'],
        'longitude': address['longitude'],
        'type': address['type'] ?? 'other',
        'isSelected': address['isSelected'] ?? false,
        if (address.containsKey('id')) 'id': address['id'],
      };

      print('💾 Saving user address to database:');
      print('   Email: $email');
      print('   Label: ${address['label']}');
      print('   City: ${address['city']}');
      print('   State: ${address['state']}');
      print('   Country: ${address['country']}');
      print('   Pincode: ${address['pincode']}');

      // Try PersonController first; if 404/405 (EC2 without new endpoints), fallback to UserAddressController
      var response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/person/addresses'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404 || response.statusCode == 405) {
        print('📡 Fallback to /api/user-addresses');
        response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/user-addresses'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        ).timeout(const Duration(seconds: 10));
      }
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Address saved successfully to database');
        return {
          'success': true,
          'data': data,
        };
      } else {
        print('❌ Failed to save address to database: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Failed to save address: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('❌ Exception saving address to database: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get user addresses from database.
  /// Tries PersonController first; if 404/405, fallback to UserAddressController (for old EC2).
  static Future<Map<String, dynamic>> getUserAddresses(String email) async {
    try {
      print('📍 Loading user addresses from database: Email=$email');
      var response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/person/email/${Uri.encodeComponent(email)}/addresses'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404 || response.statusCode == 405) {
        print('📡 PersonController returned ${response.statusCode}, trying UserAddressController fallback');
        response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/user-addresses/user/${Uri.encodeComponent(email)}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
      }

      print('📡 getUserAddresses response: ${response.statusCode}, body length: ${response.body.length}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Handle both raw array [{}] and wrapped response {data:[], content:[]}
        final List<dynamic> addresses = data is List
            ? data
            : (data is Map && data['content'] != null)
                ? List<dynamic>.from(data['content'] as List)
                : (data is Map && data['data'] != null)
                    ? List<dynamic>.from(data['data'] as List)
                    : [];
        print('✅ Loaded ${addresses.length} addresses from database');
        return {
          'success': true,
          'data': addresses,
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get addresses: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Delete user address from database.
  /// Tries PersonController first; if 404/405, fallback to UserAddressController.
  static Future<Map<String, dynamic>> deleteUserAddress({
    required String email,
    required dynamic addressId, // Can be int or String
  }) async {
    try {
      final id = addressId.toString();
      print('🗑️ Deleting address from database: Email=$email, ID=$id');

      var response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/person/addresses/$id?userEmail=${Uri.encodeComponent(email)}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.delete(
          Uri.parse('${ApiConfig.baseUrl}/api/user-addresses/$id?userEmail=${Uri.encodeComponent(email)}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
      }
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Address deleted successfully from database');
        return {'success': true};
      } else {
        print('❌ Failed to delete address: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Failed to delete address: ${response.statusCode} - ${response.body}',
        };
      }
    } catch (e) {
      print('❌ Exception deleting address: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Set address as selected. Tries PersonController first; if 404/405, fallback to UserAddressController.
  static Future<bool> selectUserAddress({required String email, required String addressId}) async {
    try {
      var response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/person/addresses/$addressId/select?userEmail=${Uri.encodeComponent(email)}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/api/user-addresses/$addressId/select?userEmail=${Uri.encodeComponent(email)}'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Error selecting address: $e');
      return false;
    }
  }
}

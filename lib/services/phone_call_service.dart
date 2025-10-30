import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized Phone Call Service
/// Handles all phone call operations across the application
/// Ensures consistent behavior and error handling
class PhoneCallService {
  // Singleton pattern
  static final PhoneCallService _instance = PhoneCallService._internal();
  factory PhoneCallService() => _instance;
  PhoneCallService._internal();

  /// Emergency contact numbers
  static const Map<String, String> emergencyContacts = {
    'police': '100',
    'ambulance': '108',
    'fire': '101',
    'disaster': '1070',
    'women_helpline': '1091',
    'child_helpline': '1098',
    'roadside_assistance': '1800-123-4567',
  };

  /// Customer support numbers
  static const Map<String, String> supportContacts = {
    'customer_support': '+91 1800 123 4567',
    'emergency_roadside': '+91 9876543210',
    'technical_support': '+91 9876543211',
  };

  /// Format phone number to standard format
  /// Removes spaces, dashes, and parentheses
  /// Adds country code if missing
  String formatPhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters except +
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // If number starts with 0 and is 10 digits, replace with +91
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = '+91${cleaned.substring(1)}';
    }
    
    // If 10 digits without country code, add +91
    if (cleaned.length == 10 && !cleaned.startsWith('+')) {
      cleaned = '+91$cleaned';
    }
    
    return cleaned;
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    final cleaned = formatPhoneNumber(phoneNumber);
    
    // Check if it's an emergency number (3 digits)
    if (cleaned.length == 3 || cleaned.length == 4) {
      return RegExp(r'^\d{3,4}$').hasMatch(cleaned);
    }
    
    // Check if it's a valid international number
    if (cleaned.startsWith('+')) {
      return RegExp(r'^\+\d{10,15}$').hasMatch(cleaned);
    }
    
    // Check if it's a 10-digit number
    return RegExp(r'^\d{10}$').hasMatch(cleaned);
  }

  /// Extract phone numbers from text
  List<String> extractPhoneNumbers(String text) {
    final patterns = [
      // International format: +91 1234567890
      RegExp(r'\+\d{1,3}[\s-]?\d{10}'),
      // With country code: 91-1234567890
      RegExp(r'\d{1,3}[-\s]?\d{10}'),
      // Standard 10-digit: 1234567890
      RegExp(r'\b\d{10}\b'),
      // With dashes: 123-456-7890
      RegExp(r'\d{3}[-.\s]\d{3}[-.\s]\d{4}'),
      // Emergency numbers: 100, 108, etc.
      RegExp(r'\b\d{3,4}\b'),
    ];

    final Set<String> phoneNumbers = {};
    
    for (var pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        final number = match.group(0);
        if (number != null && isValidPhoneNumber(number)) {
          phoneNumbers.add(formatPhoneNumber(number));
        }
      }
    }
    
    return phoneNumbers.toList();
  }

  /// Make a phone call with proper error handling
  Future<bool> makePhoneCall(
    String phoneNumber, {
    BuildContext? context,
    bool showConfirmation = true,
  }) async {
    try {
      HapticFeedback.mediumImpact();
      
      // Format and validate the phone number
      final formattedNumber = formatPhoneNumber(phoneNumber);
      
      if (!isValidPhoneNumber(formattedNumber)) {
        if (context != null && context.mounted) {
          _showErrorSnackBar(
            context,
            'Invalid phone number format',
          );
        }
        return false;
      }

      // Show confirmation dialog if requested
      if (showConfirmation && context != null && context.mounted) {
        final confirmed = await _showCallConfirmation(context, formattedNumber);
        if (!confirmed) return false;
      }

      // Create tel URI
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: formattedNumber,
      );

      // Check if the device can make calls
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
        return true;
      } else {
        if (context != null && context.mounted) {
          _showErrorSnackBar(
            context,
            'Unable to make phone calls on this device',
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('Error making phone call: $e');
      if (context != null && context.mounted) {
        _showErrorSnackBar(
          context,
          'Failed to initiate call. Please try again.',
        );
      }
      return false;
    }
  }

  /// Make an emergency call (no confirmation dialog)
  Future<bool> makeEmergencyCall(
    String emergencyType,
    BuildContext? context,
  ) async {
    final phoneNumber = emergencyContacts[emergencyType];
    
    if (phoneNumber == null) {
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, 'Emergency contact not found');
      }
      return false;
    }

    return await makePhoneCall(
      phoneNumber,
      context: context,
      showConfirmation: false,
    );
  }

  /// Make a support call
  Future<bool> makeSupportCall(
    String supportType,
    BuildContext? context,
  ) async {
    final phoneNumber = supportContacts[supportType];
    
    if (phoneNumber == null) {
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, 'Support contact not found');
      }
      return false;
    }

    return await makePhoneCall(
      phoneNumber,
      context: context,
      showConfirmation: true,
    );
  }

  /// Show call confirmation dialog
  Future<bool> _showCallConfirmation(
    BuildContext context,
    String phoneNumber,
  ) async {
    return await showDialog<bool>(
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
                  color: const Color(0xFF706DC7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.phone,
                  color: Color(0xFF706DC7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Make Call?',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to call:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF706DC7).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      color: Color(0xFF706DC7),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        phoneNumber,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF706DC7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF706DC7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(
                'Call Now',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Show error snackbar
  void _showErrorSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Create a clickable phone number widget
  Widget buildPhoneButton({
    required String phoneNumber,
    required BuildContext context,
    IconData icon = Icons.phone_rounded,
    String? label,
    Color? color,
    bool isEmergency = false,
  }) {
    return ElevatedButton.icon(
      onPressed: () => makePhoneCall(
        phoneNumber,
        context: context,
        showConfirmation: !isEmergency,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFF706DC7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      icon: Icon(icon, color: Colors.white),
      label: Text(
        label ?? 'Call',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Create a text link for phone number
  Widget buildPhoneLink({
    required String phoneNumber,
    required BuildContext context,
    TextStyle? style,
  }) {
    return GestureDetector(
      onTap: () => makePhoneCall(phoneNumber, context: context),
      child: Text(
        phoneNumber,
        style: style ?? GoogleFonts.outfit(
          color: const Color(0xFF706DC7),
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}


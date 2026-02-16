import 'package:amazon_cognito_identity_dart_2/cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_profile_service.dart';

class CognitoService {
  // ---------- User pool (customers / app users) ----------
  static const String _userPoolId = 'us-east-1_vXPHD9qbi';
  static const String _clientId = '7o5vr364ksd1vbduhm05ea7odq';
  static const String _region = 'us-east-1';

  static final CognitoUserPool _userPool = CognitoUserPool(
    _userPoolId,
    _clientId,
  );

  // ---------- Mechanic pool (separate User Pool for mechanics) ----------
  static const String _mechanicUserPoolId = 'us-east-1_Jmv2RA63T';
  static const String _mechanicClientId = '3pc2dui9en0pvp3bageoklj32v';

  static late final CognitoUserPool _mechanicUserPool = CognitoUserPool(
    _mechanicUserPoolId,
    _mechanicClientId,
  );

  // SharedPreferences keys (user)
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyUserId = 'user_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserName = 'user_name';
  static const String _keyAccessToken = 'access_token';
  static const String _keyIdToken = 'id_token';
  static const String _keyRefreshToken = 'refresh_token';

  // SharedPreferences keys (mechanic - separate session)
  static const String _keyMechanicIsLoggedIn = 'mechanic_is_logged_in';
  static const String _keyMechanicUserEmail = 'mechanic_user_email';
  static const String _keyMechanicUserPhone = 'mechanic_user_phone';
  static const String _keyMechanicUserName = 'mechanic_user_name';
  static const String _keyMechanicAccessToken = 'mechanic_access_token';
  static const String _keyMechanicIdToken = 'mechanic_id_token';
  static const String _keyMechanicRefreshToken = 'mechanic_refresh_token';

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Sign up with email and phone - Requires OTP verification via EMAIL
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String phone,
    required String password,
    required String name,
  }) async {
    try {
      final userAttributes = [
        AttributeArg(name: 'email', value: email),
        AttributeArg(name: 'phone_number', value: phone),
        AttributeArg(name: 'name', value: name),
      ];

      final result = await _userPool.signUp(
        email,
        password,
        userAttributes: userAttributes,
      );

      // Save user data temporarily (before OTP verification)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserEmail, email);
      await prefs.setString(_keyUserPhone, phone);
      await prefs.setString(_keyUserName, name);

      // Check where the code was sent (Cognito might send to phone if configured that way)
      String deliveryMessage = 'Please verify OTP sent to your email.';
      
      // Note: Cognito sends verification codes based on User Pool configuration
      // If both email and phone are provided, it may send to phone (SMS) instead of email
      // To ensure email delivery, configure Cognito User Pool to verify email first
      
      return {
        'success': true,
        'message': 'Sign up successful. $deliveryMessage\n\nNote: If you don\'t receive the email, check:\n1. Spam/Junk folder\n2. AWS Cognito User Pool settings (may be sending to SMS)\n3. Verify email address is correct',
        'userSub': result.userSub ?? '',
      };
    } catch (e) {
      String errorMessage = e.toString();
      
      // Handle duplicate user errors
      if (errorMessage.contains('UsernameExistsException') ||
          errorMessage.contains('AliasExistsException') ||
          errorMessage.contains('An account with the given email already exists') ||
          errorMessage.contains('An account with the given phone_number already exists')) {
        return {
          'success': false,
          'message': 'User account already registered. This email or phone number is already in use.',
        };
      }
      
      return {
        'success': false,
        'message': errorMessage.replaceAll('Exception: ', '').replaceAll('CognitoClientException: ', ''),
      };
    }
  }

  // Verify OTP
  static Future<Map<String, dynamic>> verifyOTP({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      
      // Trim the code to ensure no whitespace
      final trimmedCode = code.trim();
      
      // Confirm registration with OTP code
      final confirmationResult = await cognitoUser.confirmRegistration(trimmedCode);

      if (confirmationResult == true) {
        // After OTP verification, sign in the user automatically
        final authResult = await cognitoUser.authenticateUser(
          AuthenticationDetails(
            username: email,
            password: password,
          ),
        );

        // Get user attributes
        final userAttributes = await cognitoUser.getUserAttributes();
        String phone = '';
        String name = '';

        if (userAttributes != null) {
          for (var attr in userAttributes) {
            if (attr.getName() == 'phone_number') phone = attr.getValue() ?? '';
            if (attr.getName() == 'name') name = attr.getValue() ?? '';
          }
        }

        await _saveAuthData(
          email: email,
          phone: phone,
          name: name,
          accessToken: authResult?.accessToken?.getJwtToken() ?? '',
          idToken: authResult?.idToken?.getJwtToken() ?? '',
          refreshToken: authResult?.refreshToken?.getToken() ?? '',
        );

        // Load user profile from database after signup (if exists)
        await _loadUserProfileFromDatabase(email);

        return {
          'success': true,
          'message': 'OTP verified successfully',
        };
      }

      return {
        'success': false,
        'message': 'OTP verification failed. Please check your code.',
      };
    } catch (e) {
      String errorMessage = e.toString();
      
      // Handle specific Cognito errors
      if (errorMessage.contains('CodeMismatchException') || 
          errorMessage.contains('code mismatch') ||
          errorMessage.contains('Invalid verification code')) {
        return {
          'success': false,
          'message': 'Invalid verification code. Please check and try again.',
        };
      } else if (errorMessage.contains('ExpiredCodeException') ||
                 errorMessage.contains('expired')) {
        return {
          'success': false,
          'message': 'Verification code has expired. Please request a new one.',
        };
      } else if (errorMessage.contains('NotAuthorizedException')) {
        return {
          'success': false,
          'message': 'User is already confirmed or code is invalid.',
        };
      }
      
      return {
        'success': false,
        'message': errorMessage.replaceAll('Exception: ', '').replaceAll('CognitoClientException: ', ''),
      };
    }
  }

  // Resend OTP
  static Future<Map<String, dynamic>> resendOTP(String email) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      await cognitoUser.resendConfirmationCode();

      return {
        'success': true,
        'message': 'OTP resent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Sign in with email/phone and password - NO OTP required (simple authentication)
  static Future<Map<String, dynamic>> signIn({
    required String username, // Can be email or phone
    required String password,
  }) async {
    try {
      final cognitoUser = CognitoUser(username, _userPool);
      
      // Authenticate user with password only (no OTP)
      final authResult = await cognitoUser.authenticateUser(
        AuthenticationDetails(
          username: username,
          password: password,
        ),
      );
      
      // If authentication succeeds, get user attributes and save session
      if (authResult != null) {
        // Get user attributes
        final userAttributes = await cognitoUser.getUserAttributes();
        
        String email = username;
        String phone = '';
        String name = '';

        if (userAttributes != null) {
          for (var attr in userAttributes) {
            if (attr.getName() == 'email') email = attr.getValue() ?? username;
            if (attr.getName() == 'phone_number') phone = attr.getValue() ?? '';
            if (attr.getName() == 'name') name = attr.getValue() ?? '';
          }
        }

        await _saveAuthData(
          email: email,
          phone: phone,
          name: name,
          accessToken: authResult?.accessToken?.getJwtToken() ?? '',
          idToken: authResult?.idToken?.getJwtToken() ?? '',
          refreshToken: authResult?.refreshToken?.getToken() ?? '',
        );

        // Load user profile from database (DOB, Gender) after login
        await _loadUserProfileFromDatabase(email);

        return {
          'success': true,
          'message': 'Sign in successful',
        };
      }
      
      return {
        'success': false,
        'message': 'Authentication failed. Please try again.',
      };
    } catch (e) {
      String errorMessage = e.toString();
      
      // Handle specific Cognito errors
      if (errorMessage.contains('NotAuthorizedException') || 
          errorMessage.contains('Incorrect username or password') ||
          errorMessage.contains('Invalid credentials')) {
        return {
          'success': false,
          'message': 'Incorrect email/phone or password. Please try again.',
        };
      } else if (errorMessage.contains('UserNotFoundException')) {
        return {
          'success': false,
          'message': 'User not found. Please sign up first.',
        };
      } else if (errorMessage.contains('UserNotConfirmedException')) {
        return {
          'success': false,
          'message': 'Please verify your account first. Check your email for verification code.',
        };
      } else if (errorMessage.contains('TooManyRequestsException')) {
        return {
          'success': false,
          'message': 'Too many login attempts. Please try again later.',
        };
      }
      
      return {
        'success': false,
        'message': errorMessage.replaceAll('Exception: ', '').replaceAll('CognitoClientException: ', ''),
      };
    }
  }

  // ==================== MECHANIC POOL (separate Cognito User Pool) ====================

  static Future<bool> isMechanicLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyMechanicIsLoggedIn) ?? false;
  }

  static Future<Map<String, String?>> getCurrentMechanicUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'email': prefs.getString(_keyMechanicUserEmail),
      'phone': prefs.getString(_keyMechanicUserPhone),
      'name': prefs.getString(_keyMechanicUserName),
    };
  }

  static Future<void> _saveMechanicAuthData({
    required String email,
    String? phone,
    String? name,
    required String accessToken,
    required String idToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMechanicIsLoggedIn, true);
    await prefs.setString(_keyMechanicUserEmail, email);
    if (phone != null) await prefs.setString(_keyMechanicUserPhone, phone);
    if (name != null) await prefs.setString(_keyMechanicUserName, name);
    await prefs.setString(_keyMechanicAccessToken, accessToken);
    await prefs.setString(_keyMechanicIdToken, idToken);
    await prefs.setString(_keyMechanicRefreshToken, refreshToken);
  }

  static Future<void> signOutMechanic() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyMechanicIsLoggedIn);
    await prefs.remove(_keyMechanicUserEmail);
    await prefs.remove(_keyMechanicUserPhone);
    await prefs.remove(_keyMechanicUserName);
    await prefs.remove(_keyMechanicAccessToken);
    await prefs.remove(_keyMechanicIdToken);
    await prefs.remove(_keyMechanicRefreshToken);
  }

  static Future<Map<String, dynamic>> signUpForMechanic({
    required String email,
    required String phone,
    required String password,
    required String name,
  }) async {
    try {
      final userAttributes = [
        AttributeArg(name: 'email', value: email),
        AttributeArg(name: 'phone_number', value: phone),
        AttributeArg(name: 'name', value: name),
      ];
      final result = await _mechanicUserPool.signUp(
        email,
        password,
        userAttributes: userAttributes,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMechanicUserEmail, email);
      await prefs.setString(_keyMechanicUserPhone, phone);
      await prefs.setString(_keyMechanicUserName, name);
      return {
        'success': true,
        'message': 'Sign up successful. Please verify OTP sent to your email.',
        'userSub': result.userSub ?? '',
      };
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('UsernameExistsException') || msg.contains('AliasExistsException') ||
          msg.contains('already exists')) {
        return {'success': false, 'message': 'This email or phone is already registered.'};
      }
      return {'success': false, 'message': msg.replaceAll('Exception: ', '').replaceAll('CognitoClientException: ', '')};
    }
  }

  static Future<Map<String, dynamic>> verifyOTPForMechanic({
    required String email,
    required String code,
    required String password,
  }) async {
    try {
      final cognitoUser = CognitoUser(email, _mechanicUserPool);
      final trimmedCode = code.trim();
      final confirmationResult = await cognitoUser.confirmRegistration(trimmedCode);
      if (confirmationResult == true) {
        final authResult = await cognitoUser.authenticateUser(
          AuthenticationDetails(username: email, password: password),
        );
        final userAttributes = await cognitoUser.getUserAttributes();
        String phone = '';
        String name = '';
        if (userAttributes != null) {
          for (var attr in userAttributes) {
            if (attr.getName() == 'phone_number') phone = attr.getValue() ?? '';
            if (attr.getName() == 'name') name = attr.getValue() ?? '';
          }
        }
        await _saveMechanicAuthData(
          email: email,
          phone: phone,
          name: name,
          accessToken: authResult?.accessToken?.getJwtToken() ?? '',
          idToken: authResult?.idToken?.getJwtToken() ?? '',
          refreshToken: authResult?.refreshToken?.getToken() ?? '',
        );
        return {'success': true, 'message': 'OTP verified successfully'};
      }
      return {'success': false, 'message': 'OTP verification failed.'};
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('CodeMismatchException') || msg.contains('Invalid verification code')) {
        return {'success': false, 'message': 'Invalid verification code. Please try again.'};
      }
      if (msg.contains('ExpiredCodeException')) {
        return {'success': false, 'message': 'Code expired. Please request a new one.'};
      }
      return {'success': false, 'message': msg.replaceAll('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> resendOTPForMechanic(String email) async {
    try {
      final cognitoUser = CognitoUser(email, _mechanicUserPool);
      await cognitoUser.resendConfirmationCode();
      return {'success': true, 'message': 'OTP resent successfully'};
    } catch (e) {
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  static Future<Map<String, dynamic>> signInForMechanic({
    required String username,
    required String password,
  }) async {
    try {
      final cognitoUser = CognitoUser(username, _mechanicUserPool);
      final authResult = await cognitoUser.authenticateUser(
        AuthenticationDetails(username: username, password: password),
      );
      if (authResult != null) {
        final userAttributes = await cognitoUser.getUserAttributes();
        String email = username;
        String phone = '';
        String name = '';
        if (userAttributes != null) {
          for (var attr in userAttributes) {
            if (attr.getName() == 'email') email = attr.getValue() ?? username;
            if (attr.getName() == 'phone_number') phone = attr.getValue() ?? '';
            if (attr.getName() == 'name') name = attr.getValue() ?? '';
          }
        }
        await _saveMechanicAuthData(
          email: email,
          phone: phone,
          name: name,
          accessToken: authResult.accessToken.getJwtToken() ?? '',
          idToken: authResult.idToken.getJwtToken() ?? '',
          refreshToken: authResult.refreshToken?.getToken() ?? '',
        );
        return {'success': true, 'message': 'Sign in successful'};
      }
      return {'success': false, 'message': 'Authentication failed.'};
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('NotAuthorizedException') || msg.contains('Incorrect username or password')) {
        return {'success': false, 'message': 'Incorrect email or password.'};
      }
      if (msg.contains('UserNotFoundException')) {
        return {'success': false, 'message': 'Account not found. Please create an account first.'};
      }
      if (msg.contains('UserNotConfirmedException')) {
        return {'success': false, 'message': 'Please verify your email first.'};
      }
      return {'success': false, 'message': msg.replaceAll('Exception: ', '')};
    }
  }

  // Save authentication data (user)
  static Future<void> _saveAuthData({
    required String email,
    String? phone,
    String? name,
    required String accessToken,
    required String idToken,
    required String refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyUserEmail, email);
    if (phone != null) await prefs.setString(_keyUserPhone, phone);
    if (name != null) await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyAccessToken, accessToken);
    await prefs.setString(_keyIdToken, idToken);
    await prefs.setString(_keyRefreshToken, refreshToken);
    await prefs.setString(_keyUserId, email); // Use email as user ID
  }

  // Load user profile (DOB, Gender) from database after login
  static Future<void> _loadUserProfileFromDatabase(String email) async {
    try {
      final result = await UserProfileService.getUserProfile(email);
      if (result['success'] == true && result['data'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final profileData = result['data'];
        
        // Save DOB, Gender, and profile photo URL to SharedPreferences for local access
        if (profileData['dateOfBirth'] != null) {
          await prefs.setString('user_date_of_birth', profileData['dateOfBirth']);
        }
        if (profileData['gender'] != null) {
          await prefs.setString('user_gender', profileData['gender']);
        }
        if (profileData['profilePhotoUrl'] != null && profileData['profilePhotoUrl'].toString().isNotEmpty) {
          await prefs.setString('profilePhotoUrl', profileData['profilePhotoUrl'].toString());
        }
      }
    } catch (e) {
      // Silently fail - user can still use the app without database connection
      print('Warning: Could not load user profile from database: $e');
    }
  }

  // Sign out (user only; mechanic session is separate)
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserPhone);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyIdToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove('user_date_of_birth');
    await prefs.remove('user_gender');
  }

  // Get current user data
  static Future<Map<String, String?>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getString(_keyUserId),
      'email': prefs.getString(_keyUserEmail),
      'phone': prefs.getString(_keyUserPhone),
      'name': prefs.getString(_keyUserName),
    };
  }

  // Get access token
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  // Forgot Password - Send reset code via EMAIL only
  // Note: AWS Cognito will send code to the user's email address
  static Future<Map<String, dynamic>> forgotPassword({
    required String email, // Use email instead of username/phone
  }) async {
    try {
      final cognitoUser = CognitoUser(email, _userPool);
      await cognitoUser.forgotPassword();

      // Success - code sent to email
      return {
        'success': true,
        'message': 'Reset code sent successfully. Please check your email.',
        'deliveryMedium': 'EMAIL',
        'email': email,
      };
    } catch (e) {
      String errorMessage = e.toString();
      
      if (errorMessage.contains('UserNotFoundException')) {
        return {
          'success': false,
          'message': 'User not found. Please check your email and try again.',
        };
      } else if (errorMessage.contains('LimitExceededException')) {
        return {
          'success': false,
          'message': 'Too many attempts. Please try again later.',
        };
      } else if (errorMessage.contains('InvalidParameterException')) {
        return {
          'success': false,
          'message': 'Invalid email format. Please check and try again.',
        };
      }
      
      return {
        'success': false,
        'message': errorMessage.replaceAll('Exception: ', '').replaceAll('CognitoClientException: ', ''),
      };
    }
  }

  // Confirm Password Reset
  static Future<Map<String, dynamic>> confirmPasswordReset({
    required String username,
    required String code,
    required String newPassword,
  }) async {
    try {
      final cognitoUser = CognitoUser(username, _userPool);
      await cognitoUser.confirmPassword(code, newPassword);

      return {
        'success': true,
        'message': 'Password reset successful',
      };
    } catch (e) {
      String errorMessage = e.toString();
      
      if (errorMessage.contains('CodeMismatchException') ||
          errorMessage.contains('Invalid verification code')) {
        return {
          'success': false,
          'message': 'Invalid verification code. Please check and try again.',
        };
      } else if (errorMessage.contains('ExpiredCodeException')) {
        return {
          'success': false,
          'message': 'Verification code has expired. Please request a new one.',
        };
      } else if (errorMessage.contains('InvalidPasswordException')) {
        return {
          'success': false,
          'message': 'Password does not meet requirements. Please use a stronger password.',
        };
      }
      
      return {
        'success': false,
        'message': errorMessage.replaceAll('Exception: ', '').replaceAll('CognitoClientException: ', ''),
      };
    }
  }

  // Check if new password matches old password
  static Future<Map<String, dynamic>> checkPasswordMatch({
    required String username,
    required String password,
  }) async {
    try {
      final cognitoUser = CognitoUser(username, _userPool);
      // Try to authenticate with the new password
      await cognitoUser.authenticateUser(
        AuthenticationDetails(
          username: username,
          password: password,
        ),
      );
      
      // If authentication succeeds, password is the same
      return {
        'isSame': true,
        'message': 'Password matches the previous one',
      };
    } catch (e) {
      String errorMessage = e.toString();
      
      // If authentication fails with NotAuthorizedException, password is different (good)
      if (errorMessage.contains('NotAuthorizedException') ||
          errorMessage.contains('Incorrect username or password')) {
        return {
          'isSame': false,
          'message': 'Password is different',
        };
      }
      
      // For other errors, assume password is different (allow reset)
      return {
        'isSame': false,
        'message': 'Password check completed',
      };
    }
  }
}

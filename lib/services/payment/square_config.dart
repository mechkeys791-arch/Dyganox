/// Square Payment Gateway Configuration
/// 
/// IMPORTANT: Replace these with your actual Square Sandbox credentials
/// Get them from: https://developer.squareup.com/apps
/// 
/// Steps to get credentials:
/// 1. Login to Square Developer Dashboard
/// 2. Select your app
/// 3. Go to "Credentials" section
/// 4. Copy "Sandbox Application ID" and "Sandbox Access Token"
/// 5. For Location ID, go to "Sandbox Test Accounts" → "Locations" → Copy Location ID

class SquareConfig {
  // 🔥 PUT YOUR SQUARE SANDBOX CREDENTIALS HERE 🔥
  
  // Your Sandbox Application ID (starts with "sandbox-sq0idb-")
  static const String applicationId = 'YOUR_SANDBOX_APPLICATION_ID_HERE';
  
  // Your Sandbox Access Token (starts with "EAAA" or "sandbox-")
  static const String accessToken = 'YOUR_SANDBOX_ACCESS_TOKEN_HERE';
  
  // Your Sandbox Location ID (starts with "L" or "location_")
  // Get this from: Sandbox Test Accounts → Locations
  static const String locationId = 'YOUR_SANDBOX_LOCATION_ID_HERE';
  
  // Payment environment
  static const bool isSandbox = true; // Set to false for production
  
  // Currency (USD for Square, can be changed)
  static const String currency = 'USD';
  
  // Helper to validate configuration
  static bool isValid() {
    return applicationId != 'YOUR_SANDBOX_APPLICATION_ID_HERE' &&
           accessToken != 'YOUR_SANDBOX_ACCESS_TOKEN_HERE' &&
           locationId != 'YOUR_SANDBOX_LOCATION_ID_HERE';
  }
}





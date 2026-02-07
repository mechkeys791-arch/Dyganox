/// API Configuration
/// 
/// This file manages the base URL for all API calls.
/// 
/// IMPORTANT: When running on physical device, replace the baseUrl with your computer's local IP address
/// 
/// To find your local IP address:
/// - Windows: Open Command Prompt and run: ipconfig
///   Look for "IPv4 Address" under your active network adapter (usually starts with 192.168.x.x or 10.0.x.x)
/// - Mac/Linux: Open Terminal and run: ifconfig or ip addr
///   Look for inet address under your active network interface
/// 
/// Examples:
/// - For Android Emulator: 'http://10.0.2.2:8081'
/// - For Physical Device: 'http://192.168.1.100:8081' (replace with your actual IP)
/// - For iOS Simulator: 'http://localhost:8081' or 'http://127.0.0.1:8081'

class ApiConfig {
  // CONFIGURATION - Change this based on your setup
  static const bool _useLocalServer = false; // Set to true for local server, false for EC2
  static const bool _useEmulator = false; // Set to true for Android emulator
  static const bool _forceHttps = false; // Set to true only when your remote server has HTTPS enabled
  
  // AWS EC2 Instance Public IP
  // TODO: Update this with your new EC2 instance IP after creating it
  static const String _ec2PublicIp = '54.175.33.37';
  
  // Your computer's local IP address (for local testing)
  static const String _localIpAddress = '192.168.11.73';
  
  // Backend port
  static const String _port = '8081';
  
  // Computed base URL
  static String get baseUrl {
    if (_useLocalServer) {
      // For local server (development)
      if (_useEmulator) {
        return 'http://10.0.2.2:$_port'; // Android Emulator
      } else {
        return 'http://$_localIpAddress:$_port'; // Physical device with local server
      }
    } else {
      // For AWS EC2 (production/remote)
      final scheme = _forceHttps ? 'https' : 'http';
      return '$scheme://$_ec2PublicIp:$_port';
    }
  }
  
  // API Endpoints
  static String get mechanicEndpoint => '$baseUrl/api/mechanic';
  static String get mechanicRequestsEndpoint => '$baseUrl/api/mechanic-requests';
  static String get evProviderEndpoint => '$baseUrl/api/evprovider';
  static String get personEndpoint => '$baseUrl/api/person';
  
  // Payment Endpoints
  static String get paymentEndpoint => '$baseUrl/api/payment';
  static String get squarePaymentEndpoint => '$baseUrl/api/payment/square';
  
  // Helper method to get full URL
  static String getUrl(String endpoint) => '$baseUrl$endpoint';
  
  // Print current configuration (useful for debugging)
  static void printConfig() {
    print('=== API Configuration ===');
    print('Using Local Server: $_useLocalServer');
    print('Using Emulator: $_useEmulator');
    print('Server Type: ${_useLocalServer ? "Local" : "AWS EC2"}');
    print('Base URL: $baseUrl');
    print('Mechanic API: $mechanicEndpoint');
    print('EV Provider API: $evProviderEndpoint');
    print('========================');
  }
}


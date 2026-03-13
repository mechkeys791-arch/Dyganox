
class ApiConfig {
  // CONFIGURATION - Change this based on your setup
  static const bool _useLocalServer = false; // Set to true for local server, false for EC2
  static const bool _useEmulator = false; // Set to true for Android emulator
  static const bool _forceHttps = false; // Set to true only when your remote server has HTTPS enabled
  
  // AWS EC2 Instance Public IP
  // TODO: Update this with your new EC2 instance IP after creating it
  static const String _ec2PublicIp = '34.228.113.212';
  
  // Your computer's local IP address (for local testing)
  static const String _localIpAddress = '192.168.11.73';
  
  // Backend port
  static const String _port = '8081';

  /// Optional: Web OAuth client ID from Google Cloud. Set this if you get
  /// "Could not get Google account info" on Android (needed to receive id_token).
  /// Create: APIs & Services → Credentials → Create OAuth client ID → Web application.
  static const String? googleWebClientId = '1027706392650-6f3kfkmchvlnejrg9dngo4gkhkc697g3.apps.googleusercontent.com';

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
  static String mechanicLocation(int mechanicId) => '$mechanicEndpoint/$mechanicId/location';
  static String get mechanicRequestsEndpoint => '$baseUrl/api/mechanic-requests';
  /// All bookings for a mechanic (pending, accepted, in-progress, completed, rejected). Backend may implement GET .../mechanic/{id}/bookings.
  static String mechanicBookingsForMechanic(int mechanicId) => '$mechanicRequestsEndpoint/mechanic/$mechanicId/bookings';
  /// Mechanic reports "I have reached" – POST with { latitude, longitude }. Backend should record event, notify customer for confirmation, and optionally check proximity.
  static String mechanicRequestReached(int requestId) => '$mechanicRequestsEndpoint/$requestId/reached';
  static String get mechanicWalletEndpoint => '$baseUrl/api/mechanic-wallet';
  static String get vehicleEndpoint => '$baseUrl/api/vehicle';
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


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/fcm_notification_service.dart';
import '../profile/location_picker_map_page.dart';
import 'mechanic_request_detail_page.dart';

class MechanicDashboardPage extends StatefulWidget {
  final Map<String, dynamic>? mechanicData;
  final int? mechanicId;
  
  const MechanicDashboardPage({
    super.key,
    this.mechanicData,
    this.mechanicId,
  });

  @override
  State<MechanicDashboardPage> createState() => _MechanicDashboardPageState();
}

class _MechanicDashboardPageState extends State<MechanicDashboardPage> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng? _mapPosition; // Shop location from registration, or current GPS as fallback
  String? _mapAddress;
  List<Map<String, dynamic>> _requests = [];
  String _status = 'Available'; // Available, Busy, Offline
  bool _isLoadingRequests = false;
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  int? _mechanicId;
  String _shopName = '';
  String? _profilePhotoUrl;
  
  // Earnings data
  double _monthlyEarnings = 2450.0;
  double _monthlyGoal = 5000.0;
  int _completedJobs = 8;
  List<Map<String, dynamic>> _transactions = [
    {
      'id': 'TXN001',
      'customerName': 'Rahul Sharma',
      'service': 'Battery Jump Start',
      'amount': 300.0,
      'date': '2024-11-05',
      'time': '10:30 AM',
      'status': 'Completed',
      'paymentMethod': 'Cash',
    },
    {
      'id': 'TXN002',
      'customerName': 'Priya Singh',
      'service': 'Flat Tyre Service',
      'amount': 450.0,
      'date': '2024-11-04',
      'time': '02:15 PM',
      'status': 'Completed',
      'paymentMethod': 'UPI',
    },
    {
      'id': 'TXN003',
      'customerName': 'Amit Kumar',
      'service': 'Car Full Service',
      'amount': 800.0,
      'date': '2024-11-03',
      'time': '09:00 AM',
      'status': 'Completed',
      'paymentMethod': 'Card',
    },
    {
      'id': 'TXN004',
      'customerName': 'Sneha Patel',
      'service': 'Brake Service',
      'amount': 350.0,
      'date': '2024-11-02',
      'time': '11:45 AM',
      'status': 'Pending',
      'paymentMethod': 'Cash',
    },
    {
      'id': 'TXN005',
      'customerName': 'Vikram Reddy',
      'service': 'Engine Check',
      'amount': 550.0,
      'date': '2024-11-01',
      'time': '03:30 PM',
      'status': 'Completed',
      'paymentMethod': 'UPI',
    },
  ];

  @override
  void initState() {
    super.initState();
    _mechanicId = widget.mechanicId ?? 
                  (widget.mechanicData?['id'] is int ? widget.mechanicData!['id'] : 
                   widget.mechanicData?['id'] is String ? int.tryParse(widget.mechanicData!['id'].toString()) : null);
    
    print("Mechanic Dashboard: Using mechanic ID: $_mechanicId");

    // Register FCM token so mechanic receives request notifications (Accept/Reject)
    if (_mechanicId != null) FcmNotificationService.registerMechanicToken(_mechanicId!);

    _loadMechanicProfile(); // Load profile (shop name, shop location, status)
    _fetchRequests();
    _checkLaunchRequestId();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }
  
  Future<void> _loadMechanicProfile() async {
    if (_mechanicId == null) {
      setState(() {
        _shopName = 'My Dashboard';
      });
      await _getCurrentLocationAsFallback();
      return;
    }
    
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.mechanicEndpoint}/${_mechanicId}"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (response.statusCode == 200) {
        final mechanic = jsonDecode(response.body);
        final profile = Map<String, dynamic>.from(mechanic);
        final shopLat = double.tryParse(profile['latitude']?.toString() ?? '');
        final shopLng = double.tryParse(profile['longitude']?.toString() ?? '');
        final shopAddr = profile['shopAddress'] ?? profile['shop_address'] ?? '';
        
        setState(() {
          _shopName = (profile['shopName'] ?? profile['shop_name'] ?? profile['name'] ?? 'My Shop').toString();
          _status = profile['status'] ?? 'Available';
          _profilePhotoUrl = profile['profilePhotoUrl']?.toString();
        });
        
        if (shopLat != null && shopLng != null && shopLat != 0 && shopLng != 0) {
          setState(() {
            _mapPosition = LatLng(shopLat, shopLng);
            _mapAddress = shopAddr.toString().isNotEmpty ? shopAddr : null;
          });
          if (_mapAddress == null || _mapAddress!.isEmpty) {
            await _getAddressFromCoordinates(shopLat, shopLng);
          }
        } else {
          await _getCurrentLocationAsFallback();
        }
        print("Mechanic Dashboard: Loaded profile - shop: $_shopName, status: $_status");
      } else {
        await _getCurrentLocationAsFallback();
      }
    } catch (e) {
      print("Mechanic Dashboard: Error loading profile: $e");
      setState(() {
        _shopName = 'My Dashboard';
      });
      await _getCurrentLocationAsFallback();
    }
  }
  
  Future<void> _updateMechanicStatus(String newStatus) async {
    if (_mechanicId == null) {
      _showSnackBar('Mechanic ID not found', Colors.red);
      return;
    }
    
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicEndpoint}/${_mechanicId}/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": newStatus}),
      );
      
      if (response.statusCode == 200) {
        _showSnackBar('Status updated to $newStatus', Colors.green);
        print("Mechanic Dashboard: Status updated successfully to: $newStatus");
      } else {
        _showSnackBar('Failed to update status', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error updating status: $e', Colors.red);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocationAsFallback() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _mapPosition = const LatLng(12.9716, 77.5946);
          _mapAddress = 'Bangalore (default)';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        setState(() {
          _mapPosition = const LatLng(12.9716, 77.5946);
          _mapAddress = 'Enable location for your shop';
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _mapPosition = LatLng(position.latitude, position.longitude);
      });
      await _getAddressFromCoordinates(position.latitude, position.longitude);

      if (_mapController != null && _mapPosition != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(_mapPosition!),
        );
      }
    } catch (e) {
      setState(() {
        _mapPosition = const LatLng(12.9716, 77.5946);
        _mapAddress = 'Location unavailable';
      });
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];
        if (place.name != null && place.name!.isNotEmpty) addressParts.add(place.name!);
        if (place.street != null && place.street!.isNotEmpty && place.street != place.name) addressParts.add(place.street!);
        if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
        if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
        if (place.postalCode != null && place.postalCode!.isNotEmpty) addressParts.add(place.postalCode!);
        
        setState(() {
          _mapAddress = addressParts.join(', ');
        });
      }
    } catch (e) {
      setState(() {
        _mapAddress = '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
      });
    }
  }

  Future<void> _editShopLocation() async {
    LatLng? initialPos = _mapPosition ?? const LatLng(12.9716, 77.5946);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: initialPos,
          forMechanicShop: true,
        ),
      ),
    );

    if (result != null && mounted && _mechanicId != null) {
      final lat = (result['latitude'] as num?)?.toDouble();
      final lng = (result['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() {
          _mapPosition = LatLng(lat, lng);
          _mapAddress = result['fullAddress']?.toString();
        });
        await _getAddressFromCoordinates(lat, lng);
        try {
          await http.put(
            Uri.parse("${ApiConfig.mechanicEndpoint}/$_mechanicId"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              'latitude': lat.toString(),
              'longitude': lng.toString(),
              'shopAddress': _mapAddress ?? result['fullAddress'],
              'shopCity': result['city'],
              'shopState': result['state'],
              'shopPincode': result['pincode'],
              'shopCountry': result['country'],
            }),
          );
          _showSnackBar('Shop location updated!', Colors.green);
        } catch (e) {
          _showSnackBar('Location saved locally. Sync when online.', Colors.orange);
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  /// When app was opened from "Accept" notification, show request details on top.
  Future<void> _checkLaunchRequestId() async {
    final id = await FcmNotificationService.getLaunchRequestId();
    if (!mounted || id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MechanicRequestDetailPage(requestId: id),
      ),
    );
  }

  Future<void> _fetchRequests() async {
    // If no mechanic ID is available, show error
    if (_mechanicId == null) {
      print("Error: Mechanic ID is not available. Cannot fetch requests.");
      _showSnackBar('Mechanic ID not found. Please login or register as a mechanic.', Colors.red);
      setState(() {
        _isLoadingRequests = false;
      });
      return;
    }

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      final mechanicId = _mechanicId!;
      final apiUrl = "${ApiConfig.mechanicRequestsEndpoint}/mechanic/$mechanicId/pending";
      print("Fetching requests for mechanic ID: $mechanicId");
      print("API URL: $apiUrl");
      
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _requests = data.map((request) => Map<String, dynamic>.from(request)).toList();
        });
        print("Fetched ${_requests.length} pending requests for mechanic ID: $mechanicId");
      } else {
        print("Failed to fetch requests: ${response.statusCode} - ${response.body}");
        _showSnackBar('Failed to fetch requests. Please try again.', Colors.orange);
      }
    } catch (e) {
      print("Error fetching requests: $e");
      _showSnackBar('Network error. Please check your connection.', Colors.red);
    } finally {
      setState(() {
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/${request['id']}/accept"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        _showSnackBar('Request accepted successfully!', Colors.green);
        _fetchRequests(); // Refresh requests
      } else {
        _showSnackBar('Failed to accept request', const Color.fromARGB(255, 221, 29, 15));
      }
    } catch (e) {
      _showSnackBar('Error accepting request: $e', const Color.fromARGB(255, 230, 27, 12));
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/${request['id']}/reject"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        _showSnackBar('Request rejected', Colors.orange);
        _fetchRequests(); // Refresh requests
      } else {
        _showSnackBar('Failed to reject request', Colors.red);
      }
    } catch (e) {
      _showSnackBar('Error rejecting request: $e', Colors.red);
    }
  }

  void _showRequestDetails(Map<String, dynamic> request) {
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
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.request_quote,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Service Request',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRequestDetailRow('Customer', request['customerName'] ?? 'Unknown'),
              _buildRequestDetailRow('Phone', request['customerPhone'] ?? 'Not provided'),
              _buildRequestDetailRow('Service', request['serviceType'] ?? 'General Service'),
              _buildRequestDetailRow('Amount', '₹${request['amount'] ?? '50'}'),
              _buildRequestDetailRow('Description', request['description'] ?? 'No description'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _rejectRequest(request);
              },
              child: Text(
                'Reject',
                style: GoogleFonts.outfit(
                  color: const Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _acceptRequest(request);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Accept',
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
  }

  Widget _buildRequestDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusDialog() {
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
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Update Status',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusOption('Available', '🟢', 'Ready to take requests'),
              _buildStatusOption('Busy', '🟡', 'Currently working on a job'),
              _buildStatusOption('Offline', '🔴', 'Not available for requests'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOption(String status, String emoji, String description) {
    final isSelected = _status == status;
    return GestureDetector(
      onTap: () async {
        // Update local state immediately for better UX
        setState(() {
          _status = status;
        });
        Navigator.pop(context);
        
        // Update status on backend
        await _updateMechanicStatus(status);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  void _showEarningsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final progress = _monthlyEarnings / _monthlyGoal;
        final avgPerJob = _completedJobs > 0 ? _monthlyEarnings / _completedJobs : 0.0;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monthly Earnings',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'November 2024',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${_monthlyEarnings.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'of ₹${_monthlyGoal.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% of monthly goal achieved',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildEarningStatCard(
                          'Completed Jobs',
                          _completedJobs.toString(),
                          Icons.check_circle,
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEarningStatCard(
                          'Avg per Job',
                          '₹${avgPerJob.toStringAsFixed(0)}',
                          Icons.trending_up,
                          const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Transaction History Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 20, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Text(
                        'Transaction History',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Transaction List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];
                      return _buildTransactionItem(transaction);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEarningStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCompleted = transaction['status'] == 'Completed';
    final statusColor = isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.pending,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['customerName'],
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction['service'],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${transaction['date']} • ${transaction['time']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${transaction['amount'].toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction['paymentMethod'],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _profilePhotoUrl!,
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Color(0xFF6366F1)),
                    ),
                  )
                : const Icon(Icons.person, color: Color(0xFF6366F1)),
          ),
        ),
        title: Text(
          _shopName.isNotEmpty ? _shopName : 'Mechanic Dashboard',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _showStatusDialog,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _getStatusColor()),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getStatusColor(),
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _status,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Notifications when app is closed (Android)
          if (Theme.of(context).platform == TargetPlatform.android)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Material(
                color: const Color(0xFF6366F1).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active_outlined, color: const Color(0xFF6366F1), size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Not getting requests when app is closed?',
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Enable notifications & allow background.',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => FcmNotificationService.openNotificationSettings(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text('Notifications', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                                  ),
                                  TextButton(
                                    onPressed: () => FcmNotificationService.openBatterySettings(),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text('Battery', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // Dynamic Earnings Card
          GestureDetector(
            onTap: _showEarningsDialog,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'This Month\'s Earnings',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.trending_up,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+25% from last month',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Main Earnings Amount Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${_monthlyEarnings.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$_completedJobs jobs completed',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Avg: ₹${(_completedJobs > 0 ? _monthlyEarnings / _completedJobs : 0).toStringAsFixed(0)}/job',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Goal: ₹${_monthlyGoal.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Progress Bar
                  Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: _monthlyEarnings / _monthlyGoal,
                          minHeight: 8,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${((_monthlyEarnings / _monthlyGoal) * 100).toStringAsFixed(0)}% achieved',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                'View Details',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 10,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Map Section
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    if (_mapPosition == null)
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                        ),
                      )
                    else
                      GoogleMap(
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target: _mapPosition!,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('shop_location'),
                            position: _mapPosition!,
                            infoWindow: InfoWindow(
                              title: _shopName.isNotEmpty ? _shopName : 'Shop Location',
                              snippet: _mapAddress ?? 'Loading address...',
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                          ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                      ),
                    if (_mapPosition != null && _mechanicId != null)
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: _editShopLocation,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_location_alt, size: 18, color: Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Text('Edit', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
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
          ),

          // Requests Section
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
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
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.request_quote,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Service Requests',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _isLoadingRequests
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          )
                        : _requests.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No pending requests',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'New requests will appear here',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: _fetchRequests,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Refresh'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF6366F1),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _requests.length,
                                itemBuilder: (context, index) {
                                  final request = _requests[index];
                                  return GestureDetector(
                                    onTap: () => _showRequestDetails(request),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey[200]!),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 5,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.request_quote,
                                              color: Color(0xFF10B981),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  request['customerName'] ?? 'Customer',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  request['serviceType'] ?? 'General Service',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '₹${request['amount'] ?? '50'}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF10B981),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'PENDING',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFFF59E0B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Color _getStatusColor() {
    switch (_status) {
      case 'Available':
        return const Color(0xFF10B981);
      case 'Busy':
        return const Color(0xFFF59E0B);
      case 'Offline':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF6366F1);
    }
  }
}

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/phone_call_service.dart';
import '../../services/payment/payment_config.dart';
import '../../services/payment/payment_gateway.dart';
import '../../services/vehicle_service.dart';
import '../../services/cognito_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../vehicles/add_edit_vehicle_page.dart';
import 'book_mechanic_flow_page.dart';

class MechanicFinderPage extends StatefulWidget {
  /// Optional: filter mechanics by vehicle type (BIKE, CAR). If null, show all.
  final String? vehicleType;

  const MechanicFinderPage({super.key, this.vehicleType});

  @override
  State<MechanicFinderPage> createState() => _MechanicFinderPageState();
}

/// Black/white attractive map style (grayscale with subtle contrast).
const String _mapStyleBlackWhite = '''
[
  {"featureType":"all","elementType":"geometry.fill","stylers":[{"color":"#f5f5f5"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#e0e0e0"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"lightness":100},{"visibility":"simplified"}]},
  {"featureType":"road.arterial","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"landscape","elementType":"geometry.fill","stylers":[{"color":"#ffffff"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"visibility":"off"}]}
]
''';

class _MechanicFinderPageState extends State<MechanicFinderPage> with TickerProviderStateMixin {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(12.9141, 74.8560);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _mechanics = [];
  String _locationMessage = '';
  PolylinePoints polylinePoints = PolylinePoints();
  late AnimationController _slideController;
  late AnimationController _fadeController;
  String _selectedFilter = 'All';
  int? _selectedMechanicIndex;
  bool _isLoading = false;

  List<Map<String, dynamic>> _allMechanics = [];
  late PaymentGateway _paymentGateway;

  @override
  void initState() {
    super.initState();
    _fetchMechanics();
    _getCurrentLocation();
    
    // Initialize payment gateway
    _paymentGateway = PaymentConfig.getPaymentGateway();
    _paymentGateway.initialize(context);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeController.forward();
  }

  Future<void> _fetchMechanics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("Mechanic Finder: Fetching approved mechanics from database...");
      // Only fetch approved mechanics for users
      final response = await http.get(
        Uri.parse("${ApiConfig.mechanicEndpoint}?approved=true"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Filter to only approved mechanics (double check on client side)
        final approvedMechanics = data.where((mechanic) {
          String approvalStatus = mechanic['approvalStatus']?.toString() ?? 'PENDING';
          return approvalStatus == 'APPROVED';
        }).toList();
        
        _allMechanics = approvedMechanics.map((mechanic) {
          double lat = double.tryParse(mechanic['latitude']?.toString() ?? '0') ?? 0.0;
          double lng = double.tryParse(mechanic['longitude']?.toString() ?? '0') ?? 0.0;
          
          double rating = (mechanic['rating'] is num) ? (mechanic['rating'] as num).toDouble() : (4.0 + ((mechanic['id'] as int) % 10) * 0.1);
          int reviewCount = (mechanic['ratingCount'] is int) ? mechanic['ratingCount'] as int : (50 + ((mechanic['id'] as int) % 200));
          String priceRange = ['₹₹', '₹₹₹'][(mechanic['id'] as int) % 2];
          
          List<String> services = _getServicesForSpecialty(mechanic['specialty'] ?? 'General Repair');
          
          return {
            "id": mechanic['id'],
            "name": mechanic['name'],
            "email": mechanic['email'],
            "phone": mechanic['phone'],
            "specialty": mechanic['specialty'] ?? 'General Repair',
            "serviceCategories": mechanic['serviceCategories'] ?? mechanic['service_categories'],
            "experience": mechanic['experience'] ?? 'Not specified',
            "nightTimeAvailable": mechanic['nightTimeAvailable'] ?? false,
            "rating": rating,
            "reviewCount": reviewCount,
            "priceRange": priceRange,
            "services": services,
            "lat": lat,
            "lng": lng,
            "distance": 0.0,
            "availability": _getAvailabilityStatus(mechanic),
          };
        }).toList();

        setState(() {
          _mechanics = _filterByVehicle(_allMechanics, widget.vehicleType);
        });

        print("Mechanic Finder: Successfully loaded ${_allMechanics.length} mechanics");
        _initializeMapMarkers();
      } else {
        print("Mechanic Finder: Error fetching mechanics - HTTP ${response.statusCode}");
        _showErrorSnackBar("Failed to load mechanics");
      }
    } catch (e) {
      print("Mechanic Finder: Exception fetching mechanics - $e");
      _showErrorSnackBar("Error loading mechanics: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Filter mechanics by vehicle type (BIKE / CAR). Shows all if type is null.
  List<Map<String, dynamic>> _filterByVehicle(List<Map<String, dynamic>> list, String? vehicleType) {
    if (vehicleType == null || vehicleType.isEmpty) return list;
    final type = vehicleType.toUpperCase();
    final filtered = list.where((m) {
      final specialty = (m['specialty'] ?? 'General Repair').toString().toLowerCase();
      final categories = (m['serviceCategories'] ?? m['service_categories'] ?? '').toString().toLowerCase();
      if (type == 'BIKE') {
        return specialty.contains('bike') || specialty.contains('two wheeler') || categories.contains('bike');
      }
      if (type == 'CAR') {
        return specialty.contains('car') || specialty.contains('general') || specialty.contains('engine') || specialty.contains('electrical') || specialty.contains('brake') || specialty.contains('ac') || categories.contains('car') || categories.isEmpty;
      }
      return true;
    }).toList();
    return filtered.isEmpty ? list : filtered;
  }

  String _getAvailabilityStatus(Map<String, dynamic> mechanic) {
    // Check status from database first
    final status = mechanic['status'] ?? '';
    
    if (status == 'Offline') {
      return 'Offline';
    } else if (status == 'Busy') {
      return 'Busy';
    } else if (status == 'Available') {
      // If available, check if 24/7 based on nightTimeAvailable
      if (mechanic['nightTimeAvailable'] == true) {
        return 'Available 24/7';
      } else {
        return 'Available Now';
      }
    } else {
      // Fallback for old data without status field
      if (mechanic['nightTimeAvailable'] == true) {
        return 'Available 24/7';
      } else {
        return 'Available Now';
      }
    }
  }

  List<String> _getServicesForSpecialty(String specialty) {
    switch (specialty) {
      case 'General Repair':
        return ['Oil Change', 'Brake Repair', 'Engine Diagnostics', 'General Maintenance'];
      case 'Engine Specialist':
        return ['Engine Repair', 'Turbo Services', 'Performance Tuning', 'Engine Rebuild'];
      case 'Electrical Works':
        return ['Electrical Repair', 'Battery Service', 'Wiring', 'ECU Diagnostics'];
      case 'Body Works':
        return ['Denting & Painting', 'Body Restoration', 'Detailing', 'Accident Repair'];
      case 'Brake Specialist':
        return ['Brake Repair', 'Brake Pad Replacement', 'Brake Fluid Service', 'ABS Repair'];
      case 'AC Repair':
        return ['AC Repair', 'AC Recharge', 'AC Compressor', 'Cooling System'];
      default:
        return ['General Services', 'Diagnostics', 'Maintenance'];
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _initializeMapMarkers() {
    setState(() {
      _markers.clear();
      
      // Add markers for all mechanics
      for (int i = 0; i < _allMechanics.length; i++) {
        final mechanic = _allMechanics[i];
        _markers.add(
          Marker(
            markerId: MarkerId('mechanic_$i'),
            position: LatLng(mechanic['lat'], mechanic['lng']),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: mechanic['name'],
              snippet: '${mechanic['distance'].toStringAsFixed(1)} km',
            ),
            onTap: () {
              _onMechanicMarkerTapped(i);
            },
          ),
        );
      }
      
      // Set initial camera position
      if (_allMechanics.isNotEmpty) {
        _center = LatLng(_allMechanics[0]['lat'], _allMechanics[0]['lng']);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _paymentGateway.dispose();
    super.dispose();
  }

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationMessage = 'Location services are disabled.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationMessage = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationMessage = 'Location permissions are permanently denied';
      });
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _locationMessage = 'Location fetched successfully!';
        _updateDistances(position.latitude, position.longitude);
      });
    } catch (e) {
      setState(() {
        _locationMessage = 'Error getting location: $e';
      });
    }
  }


  void _updateDistances(double userLat, double userLng) {
    setState(() {
      _mechanics = _allMechanics.map((mechanic) {
        double distance = Geolocator.distanceBetween(
          userLat, userLng, mechanic['lat'], mechanic['lng']
        ) / 1000;
        return {...mechanic, 'distance': double.parse(distance.toStringAsFixed(1))};
      }).toList();
      _mechanics.sort((a, b) => a['distance'].compareTo(b['distance']));
    });
  }

  void _onMechanicMarkerTapped(int index) {
    setState(() {
      _selectedMechanicIndex = index;
    });
    _showDirectionsOnMap(index);
  }

  void _showDirectionsOnMap(int mechanicIndex) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting your location...')));
      return;
    }

    final mechanic = _mechanics[mechanicIndex];
    final destination = LatLng(mechanic['lat'], mechanic['lng']);
    
    setState(() {
      _polylines.clear();
      _markers.clear();
      
      // Add current location marker
      _markers.add(Marker(
        markerId: const MarkerId('currentLocation'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
      
      // Add destination marker
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: InfoWindow(title: mechanic['name']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
    
    // Create polyline route
    await _createPolylineRoute(destination);
    
    // Animate camera to show both markers
    _animateToMarkers();
  }

  void _showDirections(LatLng destination, String mechanicName) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Maps: $e')),
      );
    }
  }

  void _showInAppMap(LatLng destination, String mechanicName) async {
    setState(() {
      _center = destination;
      _markers.clear();
      _polylines.clear();
      
      // Add current location marker
      _markers.add(Marker(
        markerId: const MarkerId('currentLocation'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        infoWindow: const InfoWindow(title: 'Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
      
      // Add destination marker
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: InfoWindow(title: mechanicName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
    
    // Create polyline route
    await _createPolylineRoute(destination);
  }

  Future<void> _createPolylineRoute(LatLng destination) async {
    // Google Maps API key from the EV charging page
    const String apiKey = 'AIzaSyCkWqRCPB-EovWgvPFuLirPBDKU30wYDzc';
    
    if (apiKey.isEmpty) {
      print('Using API key for route. Creating route...');
      _createFallbackRoute(destination);
      return;
    }

    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          mode: TravelMode.driving,
          origin: PointLatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        for (PointLatLng point in result.points) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        }

        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylineCoordinates,
              color: AppColors.burntOrange,
              width: 4,
              patterns: [],
            ),
          );
        });
      } else {
        _createFallbackRoute(destination);
      }
    } catch (e) {
      print('Error creating polyline route: $e');
      _createFallbackRoute(destination);
    }
  }

  void _createFallbackRoute(LatLng destination) {
    setState(() {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            destination,
          ],
          color: AppColors.burntOrange,
          width: 4,
          patterns: [],
        ),
      );
    });
  }

  void _animateToMarkers() {
    if (mapController == null || _markers.isEmpty) return;
    
    try {
      double minLat = double.infinity;
      double maxLat = -double.infinity;
      double minLng = double.infinity;
      double maxLng = -double.infinity;
      
      for (Marker marker in _markers) {
        minLat = minLat < marker.position.latitude ? minLat : marker.position.latitude;
        maxLat = maxLat > marker.position.latitude ? maxLat : marker.position.latitude;
        minLng = minLng < marker.position.longitude ? minLng : marker.position.longitude;
        maxLng = maxLng > marker.position.longitude ? maxLng : marker.position.longitude;
      }
      
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(minLat - 0.01, minLng - 0.01),
        northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
      );
      
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      print('Error animating to markers: $e');
      if (_markers.isNotEmpty) {
        mapController!.animateCamera(
          CameraUpdate.newLatLng(_markers.first.position),
        );
      }
    }
  }

  void _searchMechanics(String query) {
    setState(() {
      _mechanics = query.isEmpty 
          ? _allMechanics 
          : _allMechanics.where((mechanic) => 
              mechanic['name'].toLowerCase().contains(query.toLowerCase()) ||
              mechanic['specialty'].toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Mechanics',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('All'),
                _buildFilterChip('General Repair'),
                _buildFilterChip('Engine Specialist'),
                _buildFilterChip('Electrical Works'),
                _buildFilterChip('Body Works'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
          if (label == 'All') {
            _mechanics = _allMechanics;
          } else {
            _mechanics = _allMechanics.where((m) => m['specialty'] == label).toList();
          }
        });
        Navigator.pop(context);
      },
      selectedColor: AppColors.burntOrange.withOpacity(0.2),
      checkmarkColor: AppColors.burntOrange,
      labelStyle: GoogleFonts.outfit(
        color: isSelected ? AppColors.burntOrange : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  final PhoneCallService _phoneService = PhoneCallService();

  void _makePhoneCall(String phoneNumber) async {
    await _phoneService.makePhoneCall(
      phoneNumber,
      context: context,
      showConfirmation: true,
    );
  }

  void _showServicesDropdown(BuildContext context, List<String> services, String mechanicName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.burntOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.handyman,
                        color: AppColors.burntOrange,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Services Offered',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  mechanicName,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                ...services.map((service) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            service,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMechanicDetailPopup(Map<String, dynamic> mechanic, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.burntOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: AppColors.burntOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mechanic['name'] ?? 'Unknown',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            mechanic['specialty'] ?? 'General Mechanic',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Mechanic Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow(Icons.star, 'Rating', '${mechanic['rating']} ⭐ (${mechanic['reviewCount']} reviews)'),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.work, 'Experience', mechanic['experience'] ?? 'Not specified'),
                      const SizedBox(height: 12),
                      _buildDetailRow(Icons.access_time, 'Availability', mechanic['availability'] ?? 'Check availability'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedMechanicIndex = index;
                          });
                          _showDirectionsOnMap(index);
                        },
                        icon: const Icon(Icons.directions, size: 20),
                        label: const Text('Get direction'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.burntOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showRequestMechanicDialog(mechanic);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warmAmber,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Request mechanic'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.burntOrange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRequestMechanicDialog(Map<String, dynamic> mechanic) {
    // Navigate to Book Mechanic flow: vehicle (with Add new vehicle) → problem → details → location → send to this mechanic
    final mechanicId = mechanic['id'] as int?;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BookMechanicFlowPage(preselectedMechanicId: mechanicId),
      ),
    );
  }

  void _processMechanicRequest(
    Map<String, dynamic> mechanic,
    Map<String, dynamic>? selectedVehicle,
    String customerName,
    String customerEmail,
    String customerPhone,
  ) async {
    final orderId = 'order_${DateTime.now().millisecondsSinceEpoch}';
    final amount = 50.0;
    try {
      _paymentGateway.initialize(context);
      await _paymentGateway.makePayment(
        amount: amount,
        orderId: orderId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        onSuccess: () => _sendRequestToMechanic(
          mechanic,
          amount,
          orderId,
          customerName: customerName,
          customerEmail: customerEmail,
          customerPhone: customerPhone,
          selectedVehicle: selectedVehicle,
        ),
        onFailure: (error) {
          print('Request failed: $error');
          _showErrorDialog('Payment failed: $error');
        },
      );
    } catch (e) {
      print('Request error: $e');
      _showErrorDialog('Payment error: $e');
    }
  }

  Future<void> _sendRequestToMechanic(
    Map<String, dynamic> mechanic,
    double amount,
    String orderId, {
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    Map<String, dynamic>? selectedVehicle,
  }) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmAmber),
              ),
              const SizedBox(height: 16),
              Text(
                'Sending request to ${mechanic['name']}...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      // Distance in km (from map list) so backend can show it in the mechanic's notification
      final distanceKm = mechanic['distance'] is num ? (mechanic['distance'] as num).toDouble() : null;

      // Prepare request data
      final requestData = {
        'mechanicId': mechanic['id'],
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'serviceType': 'General Service',
        'description': 'Customer needs help with vehicle service',
        'latitude': _currentPosition?.latitude.toString() ?? '0',
        'longitude': _currentPosition?.longitude.toString() ?? '0',
        'amount': amount,
        'paymentOrderId': orderId,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (selectedVehicle != null && selectedVehicle['id'] != null) 'userVehicleId': selectedVehicle['id'],
      };

      final mechanicId = mechanic['id'];
      print('[Request] Sending to mechanicId=$mechanicId (${mechanic['name']}). Backend will send FCM if mechanic has opened app.');

      final response = await http.post(
        Uri.parse(ApiConfig.mechanicRequestsEndpoint),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestData),
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final body = jsonDecode(response.body);
          final requestId = body['id'];
          print('[Request] OK requestId=$requestId. Check backend EC2 logs for: FCM sent / no FCM token / FCM not initialized.');
        } catch (_) {
          print('[Request] OK. Check backend EC2 logs for FCM status.');
        }
        
        // Show success dialog
        _showSuccessDialog(mechanic);
      } else {
        print('[Request] FAIL ${response.statusCode}: ${response.body}');
        _showErrorDialog('Failed to send request. Please try again.');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      print('[Request] Error: $e');
      _showErrorDialog('Network error. Please check your connection and try again.');
    }
  }

  void _showSuccessDialog(Map<String, dynamic> mechanic) {
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
                  color: AppColors.warmAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.warmAmber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Request Sent!',
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
              Text(
                'Your request has been sent to ${mechanic['name']}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.creamElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warmAmber.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next:',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warmAmber,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Mechanic will respond within 15 minutes\n• Booking sent successfully',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.warmAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Got it!',
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

  void _showErrorDialog(String message) {
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
                  color: AppColors.errorRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error,
                  color: AppColors.errorRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Error',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorRed,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'OK',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Book Mechanic',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white, size: 24),
            onPressed: _getCurrentLocation,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
            onPressed: () {
              setState(() {
                _polylines.clear();
                _selectedMechanicIndex = null;
                _initializeMapMarkers();
              });
            },
          ),
        ],
      ),
      body: _buildSplitView(),
    );
  }

  Widget _buildSplitView() {
    return Column(
      children: [
        // Top 50% - Map
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: GoogleMap(
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
                if (_currentPosition != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    ),
                  );
                }
              },
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 13.0,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              zoomControlsEnabled: false,
              compassEnabled: true,
              style: _mapStyleBlackWhite,
            ),
          ),
        ),
        
        // Bottom 50% - List of Mechanics
        Expanded(
          flex: 1,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Small non-dismissible banner (content from admin dashboard when available)
                _buildFinderBanner(),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Mechanics nearby',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.burntOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_mechanics.length} found',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.burntOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Mechanic List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mechanics.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _buildCompactMechanicCard(_mechanics[index], index);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.burntOrange),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.darkChocolate,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Small non-dismissible banner; image/URL can be set from admin dashboard.
  Widget _buildFinderBanner() {
    // Optional: load banner URL from ApiConfig.baseUrl + /api/settings/finder-banner
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.burntOrange.withOpacity(0.15),
              AppColors.warmBrown.withOpacity(0.12),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.burntOrange.withOpacity(0.25)),
        ),
        child: Center(
          child: Text(
            'Find & request a mechanic below',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.darkChocolate),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedMechanicCard(Map<String, dynamic> mechanic, int index) {
    final availability = mechanic['availability'] ?? 'Available Now';
    final isAvailableNow = availability == 'Available Now' || availability == 'Available 24/7';
    
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.burntOrange.withOpacity(0.08),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showMechanicDetails(mechanic);
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Avatar (photo or icon)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.burntOrange.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: mechanic['profilePhotoUrl'] != null &&
                                  (mechanic['profilePhotoUrl'] as String).isNotEmpty
                              ? Image.network(
                                  mechanic['profilePhotoUrl'] as String,
                                  fit: BoxFit.cover,
                                  width: 44,
                                  height: 44,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.build_circle, color: AppColors.burntOrange, size: 22),
                                )
                              : const Icon(Icons.build_circle, color: AppColors.burntOrange, size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name and rating
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mechanic['name'],
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppColors.darkChocolate,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                ...List.generate(5, (i) {
                                  return Icon(
                                    i < mechanic['rating'].floor()
                                        ? Icons.star
                                        : (i < mechanic['rating'].ceil()
                                            ? Icons.star_half
                                            : Icons.star_border),
                                    color: Colors.amber[600],
                                    size: 11,
                                  );
                                }),
                                const SizedBox(width: 4),
                                Text(
                                  '${mechanic['rating']}',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  ' (${mechanic['reviewCount']})',
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
                      // Price indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          mechanic['priceRange'],
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.warmAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Info chips including services
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(
                        Icons.location_on,
                        '${mechanic['distance'].toStringAsFixed(1)} km',
                        AppColors.burntOrange,
                      ),
                      _buildInfoChip(
                        Icons.category,
                        mechanic['specialty'],
                        AppColors.warmBrown,
                      ),
                      _buildInfoChip(
                        Icons.work_history,
                        mechanic['experience'],
                        AppColors.warmAmber,
                      ),
                      // Services chip with dropdown
                      GestureDetector(
                        onTap: () {
                          _showServicesDropdown(context, mechanic['services'] as List<String>, mechanic['name']);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.burntOrange.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.handyman, size: 11, color: AppColors.burntOrange),
                              const SizedBox(width: 4),
                              Text(
                                'Services',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: AppColors.burntOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_drop_down,
                                size: 16,
                                color: AppColors.burntOrange,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Availability status
                  Builder(
                    builder: (context) {
                      final availability = mechanic['availability'] ?? 'Available Now';
                      final isAvailable = availability == 'Available Now' || availability == 'Available 24/7';
                      final isBusy = availability == 'Busy';
                      final isOffline = availability == 'Offline';
                      
                      Color statusColor;
                      Color statusBgColor;
                      List<Color> gradientColors;
                      
                      if (isAvailable) {
                        statusColor = AppColors.warmAmber;
                        statusBgColor = AppColors.warmAmber.withOpacity(0.15);
                        gradientColors = [
                          AppColors.warmAmber.withOpacity(0.15),
                          AppColors.warmAmber.withOpacity(0.15),
                        ];
                      } else if (isBusy) {
                        statusColor = Colors.orange[800]!;
                        statusBgColor = Colors.orange.withOpacity(0.15);
                        gradientColors = [
                          Colors.orange.withOpacity(0.15),
                          Colors.orange.withOpacity(0.1),
                        ];
                      } else { // Offline
                        statusColor = Colors.grey[700]!;
                        statusBgColor = Colors.grey.withOpacity(0.15);
                        gradientColors = [
                          Colors.grey.withOpacity(0.15),
                          Colors.grey.withOpacity(0.1),
                        ];
                      }
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              availability,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Action buttons: Request mechanic + Get direction only
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _showRequestMechanicDialog(mechanic);
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 14),
                          label: Text(
                            'Request mechanic',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _showDirections(
                              LatLng(mechanic['lat'], mechanic['lng']),
                              mechanic['name'],
                            );
                          },
                          icon: const Icon(Icons.directions, size: 14),
                          label: Text(
                            'Get direction',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMechanicCard(Map<String, dynamic> mechanic, int index) {
    final isSelected = _selectedMechanicIndex == index;
    final availability = mechanic['availability'] ?? 'Available Now';
    final isAvailableNow = availability == 'Available Now' || availability == 'Available 24/7';
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showMechanicDetailPopup(mechanic, index);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.burntOrange.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.burntOrange : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.burntOrange.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Photo or icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.burntOrange.withOpacity(0.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: mechanic['profilePhotoUrl'] != null &&
                        (mechanic['profilePhotoUrl'] as String).isNotEmpty
                    ? Image.network(
                        mechanic['profilePhotoUrl'] as String,
                        fit: BoxFit.cover,
                        width: 50,
                        height: 50,
                        errorBuilder: (_, __, ___) => const Icon(Icons.build_circle, color: AppColors.burntOrange, size: 26),
                      )
                    : const Icon(Icons.build_circle, color: AppColors.burntOrange, size: 26),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mechanic['name'],
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber[600], size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${mechanic['rating']}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: AppColors.burntOrange),
                      const SizedBox(width: 4),
                      Text(
                        '${mechanic['distance'].toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Builder(
                        builder: (context) {
                          final availStatus = mechanic['availability'] ?? 'Available Now';
                          final isAvail = availStatus == 'Available Now' || availStatus == 'Available 24/7';
                          final isBusy = availStatus == 'Busy';
                          final isOffline = availStatus == 'Offline';
                          
                          Color statusColor;
                          if (isAvail) {
                            statusColor = AppColors.warmAmber;
                          } else if (isBusy) {
                            statusColor = Colors.orange[800]!;
                          } else { // Offline
                            statusColor = Colors.grey[700]!;
                          }
                          
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                availStatus,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mechanic['specialty'],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isSelected ? AppColors.burntOrange : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showMechanicDetails(Map<String, dynamic> mechanic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mechanic['name'],
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < mechanic['rating'].floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 20,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${mechanic['rating']} (${mechanic['reviewCount']} reviews)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailRow(Icons.category, 'Specialty', mechanic['specialty']),
                    _buildDetailRow(Icons.work_history, 'Experience', mechanic['experience']),
                    _buildDetailRow(Icons.location_on, 'Distance', '${mechanic['distance'].toStringAsFixed(1)} km'),
                    _buildDetailRow(Icons.access_time, 'Availability', mechanic['availability']),
                    _buildDetailRow(Icons.attach_money, 'Price Range', mechanic['priceRange']),
                    const SizedBox(height: 24),
                    Text(
                      'Services Offered:',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (mechanic['services'] as List<String>).map((service) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            service,
                            style: GoogleFonts.outfit(
                              color: AppColors.burntOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showRequestMechanicDialog(mechanic);
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Request mechanic'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.burntOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showDirections(
                                LatLng(mechanic['lat'], mechanic['lng']),
                                mechanic['name'],
                              );
                            },
                            icon: const Icon(Icons.directions),
                            label: const Text('Get direction'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.burntOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}


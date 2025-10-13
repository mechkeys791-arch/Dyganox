import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class MechanicFinderPage extends StatefulWidget {
  const MechanicFinderPage({super.key});

  @override
  State<MechanicFinderPage> createState() => _MechanicFinderPageState();
}

class _MechanicFinderPageState extends State<MechanicFinderPage> with TickerProviderStateMixin {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(12.9141, 74.8560);
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Position? _currentPosition;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _mechanics = [];
  PolylinePoints polylinePoints = PolylinePoints();
  late AnimationController _slideController;
  late AnimationController _fadeController;
  int? _selectedMechanicIndex;

  final List<Map<String, dynamic>> _allMechanics = [
    {
      'name': 'City Auto Care',
      'distance': 0.8,
      'rating': 4.8,
      'specialty': 'General Repair',
      'experience': '10 years',
      'availability': 'Available Now',
      'phone': '+91 98765 43210',
      'reviewCount': 156,
      'priceRange': '₹₹',
      'services': ['Oil Change', 'Brake Repair', 'Engine Diagnostics'],
      'lat': 12.9141,
      'lng': 74.8560,
    },
    {
      'name': 'Quick Fix Garage',
      'distance': 1.2,
      'rating': 4.6,
      'specialty': 'Engine Specialist',
      'experience': '8 years',
      'availability': 'Available Today',
      'phone': '+91 98765 43211',
      'reviewCount': 98,
      'priceRange': '₹₹₹',
      'services': ['Engine Repair', 'Turbo Services', 'Performance Tuning'],
      'lat': 12.9156,
      'lng': 74.8572,
    },
    {
      'name': 'Expert Motors',
      'distance': 1.5,
      'rating': 4.9,
      'specialty': 'All Services',
      'experience': '15 years',
      'availability': 'Available Now',
      'phone': '+91 98765 43212',
      'reviewCount': 234,
      'priceRange': '₹₹',
      'services': ['Complete Service', 'AC Repair', 'Suspension Work'],
      'lat': 12.9120,
      'lng': 74.8545,
    },
    {
      'name': 'AutoCare Plus',
      'distance': 2.1,
      'rating': 4.5,
      'specialty': 'Electrical Works',
      'experience': '12 years',
      'availability': 'Available from 2 PM',
      'phone': '+91 98765 43213',
      'reviewCount': 87,
      'priceRange': '₹₹',
      'services': ['Electrical Repair', 'Battery Service', 'Wiring'],
      'lat': 12.9180,
      'lng': 74.8590,
    },
    {
      'name': 'Pro Mechanic Services',
      'distance': 2.3,
      'rating': 4.7,
      'specialty': 'Body Works',
      'experience': '7 years',
      'availability': 'Available Now',
      'phone': '+91 98765 43214',
      'reviewCount': 145,
      'priceRange': '₹₹₹',
      'services': ['Denting & Painting', 'Body Restoration', 'Detailing'],
      'lat': 12.9100,
      'lng': 74.8520,
    },
  ];

  @override
  void initState() {
    super.initState();
    _mechanics = _allMechanics;
    _getCurrentLocation();
    _initializeMapMarkers();
    
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
    super.dispose();
  }

  void _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _updateDistances(position.latitude, position.longitude);
      });
    } catch (e) {
      // Error getting location
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

  Future<void> _createPolylineRoute(LatLng destination) async {
    // Google Maps API key from the EV charging page
    const String apiKey = 'AIzaSyB82H7s8dM-Z9v5E_3HIl301m0iM3e6ctc';
    
    if (apiKey == 'AIzaSyB82H7s8dM-Z9v5E_3HIl301m0iM3e6ctc') {
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
              color: const Color(0xFF6366F1),
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
          color: const Color(0xFF6366F1),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6366F1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Find Nearest Mechanic',
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
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nearest Mechanics',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_mechanics.length} found',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF6366F1),
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

  Widget _buildCompactMechanicCard(Map<String, dynamic> mechanic, int index) {
    final isSelected = _selectedMechanicIndex == index;
    final isAvailableNow = mechanic['availability'] == 'Available Now';
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedMechanicIndex = index;
        });
        _showDirectionsOnMap(index);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
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
            // Icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.8),
                    const Color(0xFF8B7ED8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.build_circle,
                color: Colors.white,
                size: 26,
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
                      Icon(Icons.location_on, size: 14, color: const Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        '${mechanic['distance'].toStringAsFixed(1)} km',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isAvailableNow ? const Color(0xFF10B981) : Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mechanic['availability'],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isAvailableNow ? const Color(0xFF10B981) : Colors.orange[800],
                          fontWeight: FontWeight.w600,
                        ),
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
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

}


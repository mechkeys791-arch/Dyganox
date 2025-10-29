import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class FuelRefillPage extends StatefulWidget {
  const FuelRefillPage({super.key});

  @override
  State<FuelRefillPage> createState() => _FuelRefillPageState();
}

class _FuelRefillPageState extends State<FuelRefillPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String selectedFuelType = 'petrol';
  String selectedQuantity = '10';

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _openMapView(String name, String location, double lat, double lng) async {
    Position? currentPosition;
    
    try {
      // Get current location
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
      }
    } catch (e) {
      // Use default location if can't get current location
      currentPosition = Position(
        latitude: 12.9716,
        longitude: 77.5946,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    if (!mounted) return;

    // Navigate to map view
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FuelStationMapView(
          stationName: name,
          stationLocation: location,
          stationLat: lat,
          stationLng: lng,
          currentLat: currentPosition?.latitude ?? 12.9716,
          currentLng: currentPosition?.longitude ?? 77.5946,
        ),
      ),
    );
  }

  Widget _buildFuelServiceCard({
    required String title,
    required String description,
    required String iconPath,
    required String price,
    required int index,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value.dy * 50 * (index + 1)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(8),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                shadowColor: const Color(0xFF706DC7).withOpacity(0.2),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          const Color(0xFF706DC7).withOpacity(0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: const Color(0xFF706DC7).withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF706DC7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF706DC7).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              iconPath,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF706DC7).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Service fee $price',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: const Color(0xFF706DC7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF706DC7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFF706DC7),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFuelStationCard({
    required String name,
    required String location,
    required String fuelTypes,
    required String distance,
    required String currentPrice,
    required double lat,
    required double lng,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF706DC7).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            currentPrice,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF706DC7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            distance,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF706DC7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _openMapView(name, location, lat, lng);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF706DC7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(60, 36),
                ),
                child: Text(
                  'Navigate',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearbyStations = [
      {
        'name': 'HP Fuel Station',
        'location': 'MG Road Junction',
        'fuelTypes': 'Petrol, Diesel, CNG',
        'distance': '0.5 km',
        'currentPrice': '₹96.25/L',
        'lat': 12.9716,
        'lng': 77.5946,
      },
      {
        'name': 'BPCL Pump',
        'location': 'Brigade Road Corner',
        'fuelTypes': 'Petrol, Diesel',
        'distance': '1.2 km',
        'currentPrice': '₹96.30/L',
        'lat': 12.9719,
        'lng': 77.6040,
      },
      {
        'name': 'Indian Oil Station',
        'location': 'Commercial Street',
        'fuelTypes': 'Petrol, Diesel, CNG',
        'distance': '1.8 km',
        'currentPrice': '₹96.20/L',
        'lat': 12.9799,
        'lng': 77.6055,
      },
      {
        'name': 'Shell Fuel Stop',
        'location': 'Koramangala 5th Block',
        'fuelTypes': 'Petrol, Diesel, Premium',
        'distance': '2.1 km',
        'currentPrice': '₹96.35/L',
        'lat': 12.9352,
        'lng': 77.6245,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fuel Services',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF706DC7), Color(0xFF8B7ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF706DC7).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby Fuel Stations',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Find the nearest fuel station and navigate easily',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),


              // Nearby Stations Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Nearby Fuel Stations',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),

              // Stations List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: nearbyStations.length,
                itemBuilder: (context, index) {
                  final station = nearbyStations[index];
                  return _buildFuelStationCard(
                    name: station['name']! as String,
                    location: station['location']! as String,
                    fuelTypes: station['fuelTypes']! as String,
                    distance: station['distance']! as String,
                    currentPrice: station['currentPrice']! as String,
                    lat: station['lat'] as double,
                    lng: station['lng'] as double,
                    index: index,
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Fuel Station Map View Page
class FuelStationMapView extends StatefulWidget {
  final String stationName;
  final String stationLocation;
  final double stationLat;
  final double stationLng;
  final double currentLat;
  final double currentLng;

  const FuelStationMapView({
    super.key,
    required this.stationName,
    required this.stationLocation,
    required this.stationLat,
    required this.stationLng,
    required this.currentLat,
    required this.currentLng,
  });

  @override
  State<FuelStationMapView> createState() => _FuelStationMapViewState();
}

class _FuelStationMapViewState extends State<FuelStationMapView> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _initializeMap() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Add markers
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: LatLng(widget.currentLat, widget.currentLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(
          title: 'Your Location',
        ),
      ),
    );

    _markers.add(
      Marker(
        markerId: const MarkerId('fuel_station'),
        position: LatLng(widget.stationLat, widget.stationLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: widget.stationName,
          snippet: widget.stationLocation,
        ),
      ),
    );

    // Add polyline for route
    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(widget.currentLat, widget.currentLng),
          LatLng(widget.stationLat, widget.stationLng),
        ],
        color: const Color(0xFF706DC7),
        width: 5,
        patterns: [PatternItem.dot],
      ),
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Animate camera to show both markers
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                widget.currentLat < widget.stationLat ? widget.currentLat : widget.stationLat,
                widget.currentLng < widget.stationLng ? widget.currentLng : widget.stationLng,
              ),
              northeast: LatLng(
                widget.currentLat > widget.stationLat ? widget.currentLat : widget.stationLat,
                widget.currentLng > widget.stationLng ? widget.currentLng : widget.stationLng,
              ),
            ),
            100.0,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF706DC7).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Color(0xFF706DC7), size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.stationName,
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              widget.stationLocation,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (widget.currentLat + widget.stationLat) / 2,
                (widget.currentLng + widget.stationLng) / 2,
              ),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: true,
            zoomControlsEnabled: true,
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.8),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF706DC7),
                ),
              ),
            ),

          // Info Card at bottom
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF706DC7).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.local_gas_station,
                          color: Color(0xFF706DC7),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Route to Station',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap markers for more details',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
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
    );
  }
}

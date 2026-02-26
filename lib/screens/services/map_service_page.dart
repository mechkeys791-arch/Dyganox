import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';

class MapServicePage extends StatefulWidget {
  const MapServicePage({super.key});

  @override
  State<MapServicePage> createState() => _MapServicePageState();
}

class _MapServicePageState extends State<MapServicePage> with SingleTickerProviderStateMixin {
  GoogleMapController? mapController;
  LatLng _center = const LatLng(12.9141, 74.8560); // Mangalore coordinates
  Position? _currentPosition;
  String? _currentAddress;
  final TextEditingController _searchController = TextEditingController();
  final Set<Marker> _markers = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  String _selectedMapType = 'Normal';

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _searchController.dispose();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _isLoading = false;
      });
      _showLocationServicesDialog();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _isLoading = false;
        });
        _showPermissionDeniedDialog();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _isLoading = false;
      });
      _showPermissionDeniedForeverDialog();
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      setState(() {
        _currentPosition = position;
        _center = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      // Get actual address from coordinates
      await _getAddressFromCoordinates(position.latitude, position.longitude);

      // Add marker with actual address
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: _center,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: InfoWindow(
              title: 'Your Location',
              snippet: _currentAddress ?? 'Loading address...',
            ),
          ),
        );
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 15),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to get location: $e');
    }
  }

  Future<void> _getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Build a comprehensive address string
        List<String> addressParts = [];
        
        if (place.name != null && place.name!.isNotEmpty) {
          addressParts.add(place.name!);
        }
        if (place.street != null && place.street!.isNotEmpty && place.street != place.name) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        
        setState(() {
          _currentAddress = addressParts.join(', ');
        });
        
        print('Current Address: $_currentAddress');
        print('Coordinates: $latitude, $longitude');
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _currentAddress = 'Lat: ${latitude.toStringAsFixed(6)}, Lng: ${longitude.toStringAsFixed(6)}';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_currentPosition != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_center, 15),
      );
    }
  }

  void _changeMapType() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.creamElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Map Type',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkChocolate,
                ),
              ),
              const SizedBox(height: 20),
              _buildMapTypeOption('Normal', MapType.normal, Icons.map),
              _buildMapTypeOption('Satellite', MapType.satellite, Icons.satellite_alt),
              _buildMapTypeOption('Terrain', MapType.terrain, Icons.terrain),
              _buildMapTypeOption('Hybrid', MapType.hybrid, Icons.layers),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMapTypeOption(String title, MapType type, IconData icon) {
    bool isSelected = _selectedMapType == title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMapType = title;
          });
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.burntOrange.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.burntOrange : AppColors.warmBrownMuted,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.burntOrange : AppColors.warmBrownMuted,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppColors.burntOrange : AppColors.darkChocolate,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.burntOrange,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInGoogleMaps() async {
    if (_currentPosition != null) {
      final url = 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Location Services Disabled', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Please enable location services to use the map.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.outfit(color: AppColors.burntOrange)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Location Permission Denied', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Location permission is required to show your position on the map.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.outfit(color: AppColors.burntOrange)),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedForeverDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Location Permission Required', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Please enable location permission in your device settings.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.warmBrownMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Geolocator.openAppSettings();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burntOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Open Settings', style: GoogleFonts.outfit(color: AppColors.creamElevated)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Error', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.outfit(color: AppColors.burntOrange)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.creamElevated,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.burntOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back, color: AppColors.burntOrange, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Map Service',
          style: GoogleFonts.outfit(
            color: AppColors.darkChocolate,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.burntOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.layers, color: AppColors.burntOrange, size: 20),
            ),
            onPressed: _changeMapType,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          children: [
            // Map
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 13.0,
              ),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapType: _selectedMapType == 'Satellite' 
                  ? MapType.satellite 
                  : _selectedMapType == 'Terrain'
                      ? MapType.terrain
                      : _selectedMapType == 'Hybrid'
                          ? MapType.hybrid
                          : MapType.normal,
              compassEnabled: true,
              mapToolbarEnabled: false,
            ),

            // Loading Indicator
            if (_isLoading)
              Container(
                color: AppColors.darkChocolate.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.burntOrange),
                  ),
                ),
              ),

            // Control Buttons
            Positioned(
              right: 16,
              bottom: 100,
              child: Column(
                children: [
                  // My Location Button
                  FloatingActionButton(
                    heroTag: 'location',
                    onPressed: _getCurrentLocation,
                    backgroundColor: AppColors.creamElevated,
                    child: Icon(Icons.my_location, color: AppColors.burntOrange),
                  ),
                  const SizedBox(height: 12),
                  // Open in Google Maps Button
                  FloatingActionButton(
                    heroTag: 'google_maps',
                    onPressed: _openInGoogleMaps,
                    backgroundColor: AppColors.burntOrange,
                    child: Icon(Icons.map, color: AppColors.creamElevated),
                  ),
                ],
              ),
            ),

            // Info Card
            Positioned(
              bottom: 20,
              left: 16,
              right: 90,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.creamElevated,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.darkChocolate.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                            Icons.location_on,
                            color: AppColors.burntOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Location',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkChocolate,
                                ),
                              ),
                                Text(
                                  _currentPosition != null
                                    ? 'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}'
                                    : 'Getting location...',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.warmBrownMuted,
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
      ),
    );
  }
}


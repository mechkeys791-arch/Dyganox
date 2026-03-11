import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../../core/theme/app_colors.dart';
import '../../services/app_remote_service.dart';
import 'book_mechanic_flow_page.dart';

/// Custom mechanic marker size in pixels. Change this to make the icon bigger or smaller on the map.
const int _kMarkerSizePx = 48;

/// Only mechanics within this radius (km) are counted and shown in "X mechanics nearby".
const double _kCountRadiusKm = 15.0;

/// India approximate bounds (so map cannot be panned outside India).
final LatLng _kIndiaSw = const LatLng(8.0, 68.0);
final LatLng _kIndiaNe = const LatLng(37.0, 97.0);

/// See nearest mechanic: map pins only (no names). Locations added from admin "Nearest mechanic (map pins)".
/// Custom marker icon from admin. Book mechanic goes to full booking flow; location/contact disclosed only after booking.
class MechanicFinderPage extends StatefulWidget {
  final String? vehicleType;

  const MechanicFinderPage({super.key, this.vehicleType});

  @override
  State<MechanicFinderPage> createState() => _MechanicFinderPageState();
}

const double _kUserMarkerHue = BitmapDescriptor.hueAzure;
const double _kPinMarkerHue = BitmapDescriptor.hueOrange;

/// Map style: only city (locality) names visible; hide roads, POI, transit, other labels.
const String _kMapStyleCityNamesOnly = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "road", "stylers": [{"visibility": "off"}]},
  {"featureType": "road.local", "stylers": [{"visibility": "off"}]},
  {"featureType": "road.highway", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "landscape", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.province", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.country", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text", "stylers": [{"visibility": "on"}]},
  {"featureType": "administrative.locality", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';

class _MechanicFinderPageState extends State<MechanicFinderPage> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(12.9141, 74.8560);
  final Set<Marker> _markers = {};
  Position? _currentPosition;
  List<Map<String, dynamic>> _locations = [];
  /// Each map: location + distanceKm (distance from user in km).
  List<Map<String, dynamic>> _locationsWithDistance = [];
  String _markerIconUrl = '';
  String _userMarkerIconUrl = '';
  BitmapDescriptor? _customPinIcon;
  BitmapDescriptor? _customUserIcon;
  bool _isLoading = true;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (!mounted) return;
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _center = LatLng(position.latitude, position.longitude);
      });
      await _fetchPins();
    } catch (e) {
      setState(() {
        _message = 'Location: ${e.toString()}';
        _isLoading = false;
      });
      await _fetchPins();
    }
  }

  Future<void> _fetchPins() async {
    setState(() => _isLoading = true);
    try {
      final lat = _currentPosition?.latitude;
      final lng = _currentPosition?.longitude;
      final data = await AppRemoteService.getNearestMechanicLocations(lat: lat, lng: lng, radiusKm: 50);
      if (!mounted) return;
      final list = (data?['locations'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final iconUrl = data?['markerIconUrl']?.toString()?.trim() ?? '';
      final userIconUrl = data?['userLocationMarkerIconUrl']?.toString()?.trim() ?? '';
      setState(() {
        _locations = list;
        _markerIconUrl = iconUrl;
        _userMarkerIconUrl = userIconUrl;
        _isLoading = false;
        _message = '';
      });
      _computeDistances();
      await Future.wait([_loadCustomPinIcon(), _loadUserLocationIcon()]);
      if (mounted) {
        _buildMarkers();
        _moveCameraToUser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locations = [];
          _locationsWithDistance = [];
          _isLoading = false;
          _message = e.toString();
        });
      }
    }
  }

  void _computeDistances() {
    final userLat = _currentPosition?.latitude;
    final userLng = _currentPosition?.longitude;
    if (userLat == null || userLng == null) {
      _locationsWithDistance = _locations.map((loc) => {...loc, 'distanceKm': null}).toList();
      return;
    }
    final list = <Map<String, dynamic>>[];
    for (final loc in _locations) {
      final lat = double.tryParse(loc['latitude']?.toString() ?? '') ?? 0.0;
      final lng = double.tryParse(loc['longitude']?.toString() ?? '') ?? 0.0;
      double? distanceKm;
      if (lat != 0.0 || lng != 0.0) {
        final meters = Geolocator.distanceBetween(userLat, userLng, lat, lng);
        distanceKm = (meters / 1000.0);
      }
      list.add({...loc, 'distanceKm': distanceKm});
    }
    list.sort((a, b) {
      final aKm = a['distanceKm'] as double? ?? double.infinity;
      final bKm = b['distanceKm'] as double? ?? double.infinity;
      return aKm.compareTo(bKm);
    });
    _locationsWithDistance = list;
  }

  /// Locations within _kCountRadiusKm only (for display count).
  List<Map<String, dynamic>> get _nearbyOnly =>
      _locationsWithDistance.where((e) {
        final km = e['distanceKm'] as double?;
        return km != null && km <= _kCountRadiusKm;
      }).toList();

  Future<void> _loadCustomPinIcon() async {
    final url = _markerIconUrl.trim();
    if (url.isEmpty) {
      setState(() => _customPinIcon = null);
      return;
    }
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        setState(() => _customPinIcon = null);
        return;
      }
      final bytes = response.bodyBytes;
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (mounted) setState(() => _customPinIcon = null);
        return;
      }
      final resized = img.copyResize(decoded, width: _kMarkerSizePx, height: _kMarkerSizePx);
      final pngBytes = Uint8List.fromList(img.encodePng(resized));
      final descriptor = BitmapDescriptor.fromBytes(
        pngBytes,
        size: Size(_kMarkerSizePx.toDouble(), _kMarkerSizePx.toDouble()),
      );
      if (mounted) setState(() => _customPinIcon = descriptor);
    } catch (_) {
      if (mounted) setState(() => _customPinIcon = null);
    }
  }

  Future<void> _loadUserLocationIcon() async {
    final url = _userMarkerIconUrl.trim();
    if (url.isEmpty) {
      setState(() => _customUserIcon = null);
      return;
    }
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        setState(() => _customUserIcon = null);
        return;
      }
      final bytes = response.bodyBytes;
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        if (mounted) setState(() => _customUserIcon = null);
        return;
      }
      final resized = img.copyResize(decoded, width: _kMarkerSizePx, height: _kMarkerSizePx);
      final pngBytes = Uint8List.fromList(img.encodePng(resized));
      final descriptor = BitmapDescriptor.fromBytes(
        pngBytes,
        size: Size(_kMarkerSizePx.toDouble(), _kMarkerSizePx.toDouble()),
      );
      if (mounted) setState(() => _customUserIcon = descriptor);
    } catch (_) {
      if (mounted) setState(() => _customUserIcon = null);
    }
  }

  void _moveCameraToUser() {
    if (_mapController == null || _currentPosition == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_center, 14),
    );
  }

  void _buildMarkers() {
    final Set<Marker> markers = {};
    if (_currentPosition != null) {
      final userIcon = _customUserIcon ?? BitmapDescriptor.defaultMarkerWithHue(_kUserMarkerHue);
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: userIcon,
        infoWindow: const InfoWindow(title: 'Your location'),
      ));
    }
    final pinIcon = _customPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(_kPinMarkerHue);
    for (int i = 0; i < _locationsWithDistance.length; i++) {
      final loc = _locationsWithDistance[i];
      final lat = double.tryParse(loc['latitude']?.toString() ?? '') ?? 0.0;
      final lng = double.tryParse(loc['longitude']?.toString() ?? '') ?? 0.0;
      if (lat == 0.0 && lng == 0.0) continue;
      markers.add(Marker(
        markerId: MarkerId('pin_$i'),
        position: LatLng(lat, lng),
        icon: pinIcon,
        infoWindow: const InfoWindow(title: 'Mechanic nearby'),
      ));
    }
    setState(() {
      _markers.clear();
      _markers.addAll(markers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'See nearest mechanic',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Colors.white),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (GoogleMapController c) {
                    _mapController = c;
                    _moveCameraToUser();
                  },
                  initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  cameraTargetBounds: CameraTargetBounds(LatLngBounds(southwest: _kIndiaSw, northeast: _kIndiaNe)),
                ),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator(color: AppColors.burntOrange)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_nearbyOnly.length} mechanic${_nearbyOnly.length == 1 ? '' : 's'} nearby',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (_message.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_message, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BookMechanicFlowPage(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burntOrange,
                        foregroundColor: Colors.white,
                    
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Book mechanic', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
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
}

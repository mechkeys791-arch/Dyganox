import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

/// Must match API radius used in [AppRemoteService.getNearestMechanicLocations] (50km) for the count line.
const double _kCountRadiusKm = 50.0;

/// See nearest mechanic: pins are approved mechanics (live location if set, else shop lat/lng from mechanics table).
/// Custom marker icon from admin. Book mechanic goes to full booking flow; location/contact disclosed only after booking.
class MechanicFinderPage extends StatefulWidget {
  final String? vehicleType;

  const MechanicFinderPage({super.key, this.vehicleType});

  @override
  State<MechanicFinderPage> createState() => _MechanicFinderPageState();
}

const double _kUserMarkerHue = BitmapDescriptor.hueAzure;

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
  /// New Set instance each update so the map platform reliably picks up marker changes.
  Set<Marker> _markers = {};
  Position? _currentPosition;
  List<Map<String, dynamic>> _locations = [];
  /// Each map: location + distanceKm (distance from user in km).
  List<Map<String, dynamic>> _locationsWithDistance = [];
  String _userMarkerIconUrl = '';
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
      final list = _parseLocationsList(data?['locations']);
      final userIconUrl = data?['userLocationMarkerIconUrl']?.toString()?.trim() ?? '';
      if (kDebugMode) {
        debugPrint('MechanicFinder: ${list.length} location(s) from API (user lat=$lat lng=$lng)');
      }
      setState(() {
        _locations = list;
        _userMarkerIconUrl = userIconUrl;
        _isLoading = false;
        _message = '';
      });
      _computeDistances();
      // Show default markers immediately (do not wait for custom icon HTTP — avoids empty map).
      if (mounted) _buildMarkers();
      await _loadUserLocationIcon();
      if (mounted) {
        _buildMarkers();
        _fitMapToPins();
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

  List<Map<String, dynamic>> _parseLocationsList(dynamic raw) {
    if (raw is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(Map<String, dynamic>.from(e));
      } else if (e is Map) {
        out.add(Map<String, dynamic>.from(e));
      }
    }
    return out;
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
      final lat = _readLat(loc);
      final lng = _readLng(loc);
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

  /// Mechanics to include in "X nearby" (same list as pins after API filter). If GPS failed, distance is null — still count them.
  List<Map<String, dynamic>> get _nearbyOnly =>
      _locationsWithDistance.where((e) {
        final km = e['distanceKm'] as double?;
        if (km == null) return true;
        return km <= _kCountRadiusKm;
      }).toList();

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

  /// Fits camera so user + all mechanic pins are visible (with padding).
  void _fitMapToPins() {
    if (_mapController == null || _markers.isEmpty) return;
    if (_markers.length == 1) {
      final p = _markers.first.position;
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(p, 14));
      return;
    }
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final m in _markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLng = math.min(minLng, lng);
      maxLng = math.max(maxLng, lng);
    }
    if ((maxLat - minLat).abs() < 1e-4) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 1e-4) {
      minLng -= 0.002;
      maxLng += 0.002;
    }
    final sw = LatLng(minLat, minLng);
    final ne = LatLng(maxLat, maxLng);
    try {
      final bounds = LatLngBounds(southwest: sw, northeast: ne);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      _moveCameraToUser();
    }
  }

  double _parseCoord(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0.0;
  }

  double _readLat(Map<String, dynamic> loc) {
    return _parseCoord(loc['latitude'] ?? loc['lat'] ?? loc['Latitude']);
  }

  double _readLng(Map<String, dynamic> loc) {
    return _parseCoord(loc['longitude'] ?? loc['lng'] ?? loc['long'] ?? loc['Longitude']);
  }

  void _buildMarkers() {
    final markers = <Marker>{};
    if (_currentPosition != null) {
      final userIcon = _customUserIcon ?? BitmapDescriptor.defaultMarkerWithHue(_kUserMarkerHue);
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: userIcon,
        zIndexInt: 1,
        infoWindow: const InfoWindow(title: 'Your location'),
      ));
    }
    for (int i = 0; i < _locationsWithDistance.length; i++) {
      final loc = _locationsWithDistance[i];
      final lat = _readLat(loc);
      final lng = _readLng(loc);
      if (!lat.isFinite || !lng.isFinite) continue;
      if (lat == 0.0 && lng == 0.0) continue;
      final id = loc['id']?.toString() ?? 'idx_$i';
      // Always use default pins for mechanic locations. Custom BitmapDescriptor.fromBytes
      // (admin upload) often renders blank on device; default markers are reliable.
      final hue = (BitmapDescriptor.hueOrange + ((i * 35) % 330)).toDouble() % 360;
      markers.add(Marker(
        markerId: MarkerId('mechanic_$id'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        zIndexInt: 2,
        infoWindow: InfoWindow(title: 'Mechanic ${i + 1}', snippet: 'Nearby service point'),
      ));
    }
    if (kDebugMode) {
      debugPrint('MechanicFinder: built ${markers.length} marker(s) (${_locationsWithDistance.length} locations with distance)');
    }
    if (!mounted) return;
    setState(() {
      _markers = markers;
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
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (_markers.length > 1) {
                        _fitMapToPins();
                      } else {
                        _moveCameraToUser();
                      }
                    });
                  },
                  initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                  markers: Set<Marker>.from(_markers),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  mapType: MapType.normal,
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  // Unbounded so camera can always fit user + pins (India-only bound hid off-screen pins for some users).
                  cameraTargetBounds: CameraTargetBounds.unbounded,
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

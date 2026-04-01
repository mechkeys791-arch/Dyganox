import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/vehicle_service.dart';
import '../profile/location_picker_map_page.dart';
import '../../widgets/vehicle_selection_sheet.dart';

/// Flow: 1) Vehicle (from profile, bottom sheet) → 2) Location (pickup/drop) → 3) What happened → 4) Towing providers (map half + list)
class TowingServicePage extends StatefulWidget {
  const TowingServicePage({super.key});

  @override
  State<TowingServicePage> createState() => _TowingServicePageState();
}

class _TowingServicePageState extends State<TowingServicePage>
    with TickerProviderStateMixin {
  int _step = 0;

  // Step 1: What happened
  String? _incidentType;

  // Step 2: Location
  double? _pickupLat;
  double? _pickupLng;
  String _pickupAddress = 'Tap to set pickup location';
  double? _dropLat;
  double? _dropLng;
  String _dropAddress = 'Select destination';
  double _estimatedDistanceKm = 0;

  // Step 3: Vehicle (from profile)
  List<Map<String, dynamic>> _userVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  bool _loadingVehicles = false;

  // Step 4: Towing providers
  List<Map<String, dynamic>> _towingProviders = [];
  bool _loadingProviders = false;

  static const List<Map<String, String>> _incidentOptions = [
    {'id': 'breakdown', 'label': 'Breakdown', 'emoji': '🚗'},
    {'id': 'accident', 'label': 'Accident', 'emoji': '💥'},
    {'id': 'not_starting', 'label': 'Vehicle not starting', 'emoji': '🛻'},
    {'id': 'flat_tyre', 'label': 'Flat tyre (needs towing)', 'emoji': '🛞'},
    {'id': 'other', 'label': 'Other', 'emoji': '📍'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserVehicles();
    _getCurrentLocationForPickup();
  }

  Future<void> _getCurrentLocationForPickup() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) return;

      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return;
      setState(() {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
      });
      await _reverseGeocodePickup();
    } catch (_) {}
  }

  Future<void> _reverseGeocodePickup() async {
    if (_pickupLat == null || _pickupLng == null) return;
    try {
      List<Placemark> pm =
          await placemarkFromCoordinates(_pickupLat!, _pickupLng!);
      if (pm.isNotEmpty && mounted) {
        final p = pm.first;
        final addr = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((x) => x != null && x.toString().isNotEmpty).join(', ');
        setState(() {
          _pickupAddress = addr.isNotEmpty ? addr : 'Current Location';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _pickupAddress = 'Current Location');
    }
  }

  Future<void> _reverseGeocodeDrop() async {
    if (_dropLat == null || _dropLng == null) return;
    try {
      List<Placemark> pm =
          await placemarkFromCoordinates(_dropLat!, _dropLng!);
      if (pm.isNotEmpty && mounted) {
        final p = pm.first;
        final addr = [
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
        ].where((x) => x != null && x.toString().isNotEmpty).join(', ');
        setState(() {
          _dropAddress = addr.isNotEmpty ? addr : 'Selected destination';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _dropAddress = 'Selected destination');
    }
  }

  void _updateEstimatedDistance() {
    if (_pickupLat != null &&
        _pickupLng != null &&
        _dropLat != null &&
        _dropLng != null) {
      final d = Geolocator.distanceBetween(
            _pickupLat!,
            _pickupLng!,
            _dropLat!,
            _dropLng!,
          ) /
          1000;
      setState(() => _estimatedDistanceKm = d);
    } else {
      setState(() => _estimatedDistanceKm = 0);
    }
  }

  Future<void> _editPickupLocation() async {
    LatLng? init = _pickupLat != null && _pickupLng != null
        ? LatLng(_pickupLat!, _pickupLng!)
        : null;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: init,
          forMechanicShop: true,
        ),
      ),
    );
    if (result != null && mounted) {
      final lat = result['latitude'] as num?;
      final lng = result['longitude'] as num?;
      if (lat != null && lng != null) {
        setState(() {
          _pickupLat = lat.toDouble();
          _pickupLng = lng.toDouble();
          _pickupAddress = result['fullAddress']?.toString() ?? 'Selected';
        });
        _reverseGeocodePickup();
        _updateEstimatedDistance();
      }
    }
  }

  Future<void> _selectDropLocation() async {
    LatLng? init = _dropLat != null && _dropLng != null
        ? LatLng(_dropLat!, _dropLng!)
        : (_pickupLat != null && _pickupLng != null
            ? LatLng(_pickupLat!, _pickupLng!)
            : null);
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(
          initialPosition: init,
          forMechanicShop: true,
        ),
      ),
    );
    if (result != null && mounted) {
      final lat = result['latitude'] as num?;
      final lng = result['longitude'] as num?;
      if (lat != null && lng != null) {
        setState(() {
          _dropLat = lat.toDouble();
          _dropLng = lng.toDouble();
          _dropAddress = result['fullAddress']?.toString() ?? 'Selected';
        });
        _reverseGeocodeDrop();
        _updateEstimatedDistance();
      }
    }
  }

  String _userEmail = '';

  Future<void> _loadUserVehicles() async {
    setState(() => _loadingVehicles = true);
    try {
      final user = await CognitoService.getCurrentUser();
      final email = user['email']?.toString() ?? '';
      _userEmail = email;
      if (email.isEmpty) {
        if (mounted) setState(() { _userVehicles = []; _loadingVehicles = false; });
        return;
      }
      final list = await VehicleService.getMyVehicles(email);
      if (!mounted) return;
      setState(() {
        _userVehicles = list;
        _selectedVehicle = list.isEmpty ? null : (_selectedVehicle != null
            ? list.cast<Map<String, dynamic>>().firstWhere((v) => v['id'] == _selectedVehicle!['id'], orElse: () => list.first)
            : list.first);
        _loadingVehicles = false;
      });
    } catch (_) {
      if (mounted) setState(() { _userVehicles = []; _loadingVehicles = false; });
    }
  }

  Future<void> _fetchTowingProviders() async {
    setState(() => _loadingProviders = true);
    try {
      final lat = _pickupLat ?? 12.9716;
      final lng = _pickupLng ?? 77.5946;
      final uri = Uri.parse(
          '${ApiConfig.mechanicEndpoint}/by-category')
          .replace(queryParameters: {
        'problemCategory': 'towing_service',
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radiusKm': '20',
      });
      final r = await http.get(uri, headers: {'Content-Type': 'application/json'});
      if (r.statusCode == 200 && mounted) {
        final data = jsonDecode(r.body);
        final list = data is List ? data : (data is Map && data['content'] != null)
            ? data['content'] as List
            : [];
        setState(() {
          _towingProviders = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loadingProviders = false;
        });
      } else {
        if (mounted) setState(() {
          _towingProviders = [];
          _loadingProviders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() {
        _towingProviders = [];
        _loadingProviders = false;
      });
    }
  }

  void _goNext() {
    if (_step == 0) {
      if (_selectedVehicle != null || _userVehicles.isEmpty) {
        setState(() => _step = 1);
      } else {
        _showVehicleSheet();
      }
    } else if (_step == 1) {
      if (_pickupLat != null && _pickupLng != null) {
        setState(() => _step = 2);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please set pickup location', style: GoogleFonts.outfit()),
            backgroundColor: AppColors.burntOrange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (_step == 2 && _incidentType != null) {
      setState(() => _step = 3);
      _fetchTowingProviders();
    }
  }

  void _showVehicleSheet() {
    if (_userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in', style: GoogleFonts.outfit()), backgroundColor: Colors.orange),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (ctx) => VehicleSelectionSheet(
        title: 'Select vehicle',
        userEmail: _userEmail,
        parentContext: context,
        initialVehicles: _userVehicles.isEmpty ? null : _userVehicles,
        onSelectVehicle: (v) {
          Navigator.pop(ctx);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedVehicle = v);
          });
        },
        onAddVehicle: () {
          Navigator.pop(ctx);
          showAddVehicleInBottomSheet(context, userEmail: _userEmail).then((_) {
            if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserVehicles());
          });
        },
      ),
    );
  }

  void _goBack() {
    if (_step > 0) setState(() => _step--);
    else Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.creamElevated,
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
          onPressed: _goBack,
        ),
        title: Text(
          _step == 0 ? 'Vehicle' : _step == 1 ? 'Location' : _step == 2 ? 'What happened' : 'Towing Providers',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _step == 0 ? _buildVehicleStep() : _step == 1 ? _buildLocationStep() : _step == 2 ? _buildIncidentStep() : _buildProvidersStep(),
      ),
    );
  }

  Widget _buildIncidentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.burntOrange, AppColors.warmBrown],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.burntOrange.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.creamElevated.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/icons/tow-truck.png',
                    width: 32,
                    height: 32,
                    color: AppColors.creamElevated,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_shipping,
                      color: AppColors.creamElevated,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Professional Towing',
                        style: GoogleFonts.outfit(
                          color: AppColors.creamElevated,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '24/7 emergency response • Safe & reliable',
                        style: GoogleFonts.inter(
                          color: AppColors.creamElevated.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'What happened to your vehicle?',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(_incidentOptions.length, (i) {
            final opt = _incidentOptions[i];
            final selected = _incidentType == opt['id'];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                elevation: selected ? 6 : 2,
                borderRadius: BorderRadius.circular(16),
                color: selected
                    ? AppColors.burntOrange.withOpacity(0.15)
                    : AppColors.creamElevated,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _incidentType = opt['id']);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppColors.burntOrange
                            : AppColors.burntOrange.withOpacity(0.15),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          opt['emoji']!,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            opt['label']!,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (selected)
                          Icon(Icons.check_circle,
                              color: AppColors.burntOrange, size: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _incidentType != null ? _goNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    final showMap = _pickupLat != null && _pickupLng != null;
    final center = showMap
        ? LatLng(_pickupLat!, _pickupLng!)
        : const LatLng(12.9716, 77.5946);
    final markers = <Marker>{};
    if (_pickupLat != null && _pickupLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupLat!, _pickupLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    if (_dropLat != null && _dropLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('drop'),
          position: LatLng(_dropLat!, _dropLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMap) ...[
            Container(
              height: 180,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: markers.length == 2 ? 12 : 14,
                  ),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  liteModeEnabled: true,
                ),
              ),
            ),
          ],
          Text(
            'Pickup Location',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _editPickupLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.creamElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.burntOrange.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: AppColors.burntOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📍 Current Location',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppColors.burntOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _pickupAddress,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Edit Location',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.burntOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Drop Location (optional)',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: _selectDropLocation,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.creamElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.burntOrange.withOpacity(0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place, color: AppColors.burntOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dropAddress,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _dropLat != null
                              ? Colors.black87
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[600]),
                  ],
                ),
              ),
            ),
          ),
          if (_estimatedDistanceKm > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.burntOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.straighten, color: AppColors.burntOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated distance: ${_estimatedDistanceKm.toStringAsFixed(1)} km',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.burntOrange,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _pickupLat != null && _pickupLng != null
                  ? _goNext
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Continue →',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleImageUrl(Map<String, dynamic> v) {
    final url = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select your vehicle (from profile)',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          if (_loadingVehicles)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AppColors.burntOrange)))
          else if (_userVehicles.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.creamElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.burntOrange.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Icon(Icons.directions_car_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No vehicle in profile', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text('Add a vehicle to continue.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => showAddVehicleInBottomSheet(context, userEmail: _userEmail).then((_) {
                      if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserVehicles());
                    }),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add vehicle'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.burntOrange, foregroundColor: Colors.white),
                  ),
                ],
              ),
            )
          else
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _showVehicleSheet,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.burntOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _vehicleImageUrl(_selectedVehicle!).isNotEmpty
                            ? Image.network(_vehicleImageUrl(_selectedVehicle!), width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _vehicleIconWidget(_selectedVehicle!['type']))
                            : _vehicleIconWidget(_selectedVehicle!['type']),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_selectedVehicle!['makeName'] ?? ''} ${_selectedVehicle!['modelName'] ?? ''}'.trim(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('${_selectedVehicle!['plateNumber'] ?? ''} • ${_selectedVehicle!['type'] ?? 'Car'}', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),
            ),
          if (_userVehicles.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _showVehicleSheet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Change or add vehicle'),
              style: TextButton.styleFrom(foregroundColor: AppColors.burntOrange),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedVehicle != null ? _goNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                disabledBackgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Continue', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleIconWidget(dynamic type) {
    return Container(
      width: 72,
      height: 72,
      color: AppColors.creamElevated,
      child: Icon(_vehicleIcon(type), color: AppColors.burntOrange, size: 36),
    );
  }

  IconData _vehicleIcon(dynamic type) {
    final t = (type ?? 'car').toString().toLowerCase();
    if (t.contains('bike') || t.contains('motorcycle')) return Icons.two_wheeler;
    if (t.contains('van')) return Icons.local_shipping;
    if (t.contains('truck')) return Icons.local_shipping;
    if (t.contains('suv')) return Icons.directions_car;
    return Icons.directions_car;
  }

  Widget _buildProvidersStep() {
    final center = _pickupLat != null && _pickupLng != null
        ? LatLng(_pickupLat!, _pickupLng!)
        : const LatLng(12.9716, 77.5946);
    final markers = <Marker>{};
    if (_pickupLat != null && _pickupLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(_pickupLat!, _pickupLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: MediaQuery.of(context).size.height * 0.35,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 14),
              markers: markers,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Nearest towing providers',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingProviders
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.burntOrange))
              : _towingProviders.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No towing providers available at the moment',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Mechanics who offer towing service will appear here.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchTowingProviders,
                      color: AppColors.burntOrange,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _towingProviders.length,
                        itemBuilder: (context, i) {
                          final m = _towingProviders[i];
                          return _buildProviderCard(m, i);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.burntOrange.withOpacity(0.15),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'T',
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.burntOrange,
        ),
      ),
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> m, int index) {
    final name = m['name']?.toString() ?? 'Towing Provider';
    final specialty = m['specialty']?.toString() ?? 'Towing';
    final experience = m['experience']?.toString() ?? '—';
    final rating = 4.0 + (index % 5) * 0.2;
    final towingPhotoUrl = m['towingVehiclePhotoUrl']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: AppColors.creamElevated,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppColors.burntOrange.withOpacity(0.1), width: 1),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: towingPhotoUrl != null && towingPhotoUrl.isNotEmpty
                    ? Image.network(
                        towingPhotoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _avatarFallback(name),
                      )
                    : _avatarFallback(name),
              ),
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
                      '$specialty • $experience',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star,
                                  size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
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
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Request sent to $name',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: AppColors.burntOrange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burntOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(70, 38),
                ),
                child: Text(
                  'Request',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

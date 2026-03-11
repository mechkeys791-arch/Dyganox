import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../services/api_config.dart';

/// When mechanic has accepted: video placeholder, then when en route = map + ETA, then "Has mechanic reached?" confirm.
class MechanicAcceptedReadyPage extends StatefulWidget {
  final Map<String, dynamic> request;

  const MechanicAcceptedReadyPage({super.key, required this.request});

  @override
  State<MechanicAcceptedReadyPage> createState() => _MechanicAcceptedReadyPageState();
}

class _MechanicAcceptedReadyPageState extends State<MechanicAcceptedReadyPage> {
  String? _mechanicName;
  Map<String, dynamic> _request = {};
  Timer? _pollTimer;
  double? _mechanicLat;
  double? _mechanicLng;
  double? _customerLat;
  double? _customerLng;
  double? _distanceKm;
  int? _etaMinutes;
  bool _confirmingArrival = false;

  @override
  void initState() {
    super.initState();
    _request = Map.from(widget.request);
    _customerLat = double.tryParse(_request['latitude']?.toString() ?? '');
    _customerLng = double.tryParse(_request['longitude']?.toString() ?? '');
    _mechanicName = _request['acceptedMechanicName']?.toString();
    if (_mechanicName == null || _mechanicName!.isEmpty) _fetchMechanicName();
    _pollRequest();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _pollRequest() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      try {
        final id = _request['id'];
        if (id == null) return;
        final r = await http.get(
          Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$id'),
          headers: {'Content-Type': 'application/json'},
        );
        if (r.statusCode == 200 && mounted) {
          final req = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          setState(() => _request = req);
          final status = req['status']?.toString() ?? '';
          if (status == 'MECHANIC_EN_ROUTE' || status == 'ARRIVED') {
            _fetchMechanicLocation();
            if (status == 'MECHANIC_EN_ROUTE' && _mechanicLat != null && _customerLat != null) {
              _updateEta();
            }
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _fetchMechanicName() async {
    final id = _request['acceptedMechanicId'];
    if (id == null) return;
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() => _mechanicName = m['name']?.toString() ?? 'Mechanic');
      }
    } catch (_) {}
  }

  Future<void> _fetchMechanicLocation() async {
    final id = _request['acceptedMechanicId'];
    if (id == null) return;
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final lat = double.tryParse(m['currentLatitude']?.toString() ?? m['latitude']?.toString() ?? '');
        final lng = double.tryParse(m['currentLongitude']?.toString() ?? m['longitude']?.toString() ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _mechanicLat = lat;
            _mechanicLng = lng;
          });
          if (_customerLat != null && _customerLng != null) {
            final dist = Geolocator.distanceBetween(lat, lng, _customerLat!, _customerLng!) / 1000;
            setState(() => _distanceKm = dist);
          }
        }
      }
    } catch (_) {}
  }

  void _updateEta() {
    if (_distanceKm == null) return;
    // Rough: 30 km/h average in city -> 2 min per km
    final mins = (_distanceKm! * 2).round().clamp(1, 120);
    setState(() => _etaMinutes = mins);
  }

  Future<void> _confirmArrival() async {
    final id = _request['id'];
    if (id == null) return;
    setState(() => _confirmingArrival = true);
    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$id/confirm-arrival-user'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        setState(() => _confirmingArrival = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confirmed. Mechanic is at your location.'), backgroundColor: AppColors.warmAmber),
        );
        _pollRequest();
      }
    } catch (_) {
      if (mounted) setState(() => _confirmingArrival = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _mechanicName ?? 'Mechanic';
    final status = _request['status']?.toString() ?? 'PENDING_PAYMENT';
    final isEnRoute = status == 'MECHANIC_EN_ROUTE';
    final isArrived = status == 'ARRIVED';
    final showMap = isEnRoute && _mechanicLat != null && _customerLat != null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(
          isEnRoute ? 'Mechanic on the way' : isArrived ? 'Mechanic arrived' : 'Mechanic on the way',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.burntOrange, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$name has accepted', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
                        Text(
                          isEnRoute ? 'Mechanic is on the way to you.' : isArrived ? 'Mechanic has reached your location.' : 'Mechanic has joined. He will contact you.',
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showMap) ...[
              SizedBox(
                height: 220,
                width: double.infinity,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_customerLat!, _customerLng!),
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('you'),
                      position: LatLng(_customerLat!, _customerLng!),
                      infoWindow: const InfoWindow(title: 'You'),
                    ),
                    Marker(
                      markerId: const MarkerId('mechanic'),
                      position: LatLng(_mechanicLat!, _mechanicLng!),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                      infoWindow: const InfoWindow(title: 'Mechanic'),
                    ),
                  },
                  myLocationEnabled: true,
                ),
              ),
              if (_etaMinutes != null || _distanceKm != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.burntOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, color: AppColors.burntOrange, size: 24),
                      const SizedBox(width: 12),
                      if (_etaMinutes != null)
                        Text('ETA ~$_etaMinutes min', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.burntOrange)),
                      if (_etaMinutes != null && _distanceKm != null) Text('  •  ', style: GoogleFonts.outfit(color: AppColors.burntOrange)),
                      if (_distanceKm != null)
                        Text('${_distanceKm!.toStringAsFixed(1)} km away', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.darkChocolate)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ] else if (!isArrived)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.32),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.darkChocolate.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_rounded, size: 48, color: AppColors.burntOrange.withValues(alpha: 0.8)),
                      const SizedBox(height: 8),
                      Text('Mechanic getting ready', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkChocolate)),
                    ],
                  ),
                ),
              ),
            if (isArrived) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.creamElevated,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Has mechanic reached your location?', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.darkChocolate)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _confirmingArrival ? null : _confirmArrival,
                      icon: _confirmingArrival ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle, size: 22),
                      label: Text(_confirmingArrival ? 'Confirming...' : 'Yes, mechanic is here'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burntOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.creamElevated,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.burntOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.phone_in_talk_rounded, color: AppColors.burntOrange, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Mechanic will contact you',
                          style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.darkChocolate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Do not share your number outside the app. The mechanic will call you on the number linked to your account.',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700], height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

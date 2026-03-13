import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../../services/api_config.dart';
import '../../core/theme/app_colors.dart';

/// Shows mechanic location on an in-app map.
class MechanicLocationMapPage extends StatefulWidget {
  final int mechanicId;
  final String mechanicName;

  const MechanicLocationMapPage({
    super.key,
    required this.mechanicId,
    required this.mechanicName,
  });

  @override
  State<MechanicLocationMapPage> createState() => _MechanicLocationMapPageState();
}

class _MechanicLocationMapPageState extends State<MechanicLocationMapPage> {
  double? _mechanicLat;
  double? _mechanicLng;
  double? _userLat;
  double? _userLng;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      Position? userPos;
      try {
        userPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      } catch (_) {}

      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicEndpoint}/${widget.mechanicId}'),
        headers: {'Content-Type': 'application/json'},
      );

      if (r.statusCode == 200 && mounted) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final latStr = m['latitude']?.toString() ?? m['currentLatitude']?.toString();
        final lngStr = m['longitude']?.toString() ?? m['currentLongitude']?.toString();
        final lat = latStr != null ? double.tryParse(latStr) : null;
        final lng = lngStr != null ? double.tryParse(lngStr) : null;
        setState(() {
          _mechanicLat = lat;
          _mechanicLng = lng;
          _userLat = userPos?.latitude;
          _userLng = userPos?.longitude;
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Could not load mechanic location';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load location';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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
            widget.mechanicName,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.burntOrange)),
      );
    }

    if (_error != null || _mechanicLat == null || _mechanicLng == null) {
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
            widget.mechanicName,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error ?? 'Location not available',
              style: GoogleFonts.inter(fontSize: 16, color: AppColors.warmBrownMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final mechanicPos = LatLng(_mechanicLat!, _mechanicLng!);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('mechanic'),
        position: mechanicPos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: widget.mechanicName),
      ),
      if (_userLat != null && _userLng != null)
        Marker(
          markerId: const MarkerId('you'),
          position: LatLng(_userLat!, _userLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You'),
        ),
    };

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
          widget.mechanicName,
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: mechanicPos,
                zoom: 14,
              ),
              markers: markers,
              myLocationEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),
          if (_userLat != null && _userLng != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final url = 'https://www.google.com/maps/dir/?api=1&destination=$_mechanicLat,$_mechanicLng';
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.directions, size: 22),
                  label: const Text('Open in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

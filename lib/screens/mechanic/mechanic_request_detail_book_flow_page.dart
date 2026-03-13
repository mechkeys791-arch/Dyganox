import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_config.dart';

// Teal theme
import '../../core/theme/app_colors.dart';

/// Full request details for Book Mechanic: map (customer location + distance), all details, photos. Accept or Dismiss.
class MechanicRequestDetailBookFlowPage extends StatefulWidget {
  final int requestId;
  final int mechanicId;
  final double? mechanicLat;
  final double? mechanicLng;

  const MechanicRequestDetailBookFlowPage({
    super.key,
    required this.requestId,
    required this.mechanicId,
    this.mechanicLat,
    this.mechanicLng,
  });

  @override
  State<MechanicRequestDetailBookFlowPage> createState() => _MechanicRequestDetailBookFlowPageState();
}

class _MechanicRequestDetailBookFlowPageState extends State<MechanicRequestDetailBookFlowPage> {
  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _accepting = false;
  String? _error;
  double? _mechanicLat;
  double? _mechanicLng;
  double? _distanceKm;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _mechanicLat = widget.mechanicLat;
    _mechanicLng = widget.mechanicLng;
    _loadRequest();
    if (_mechanicLat == null || _mechanicLng == null) _getMechanicLocation();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdatesIfEnRoute() {
    if ((_request?['status']?.toString() ?? '') != 'MECHANIC_EN_ROUTE') return;
    _locationUpdateTimer?.cancel();
    _sendCurrentLocation();
    // Real-time: update every 2 seconds (Swiggy-style live tracking)
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) => _sendCurrentLocation());
  }

  Future<void> _sendCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await http.put(
        Uri.parse(ApiConfig.mechanicLocation(widget.mechanicId)),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'currentLatitude': pos.latitude.toString(),
          'currentLongitude': pos.longitude.toString(),
        }),
      );
    } catch (_) {}
  }

  Future<void> _getMechanicLocation() async {
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicEndpoint}/${widget.mechanicId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final m = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final lat = double.tryParse(m['latitude']?.toString() ?? '');
        final lng = double.tryParse(m['longitude']?.toString() ?? '');
        setState(() { _mechanicLat = lat; _mechanicLng = lng; });
        if (_request != null && lat != null && lng != null) _computeDistance(lat, lng);
      }
    } catch (_) {}
  }

  void _computeDistance(double mlat, double mlng) {
    final clat = double.tryParse(_request!['latitude']?.toString() ?? '');
    final clng = double.tryParse(_request!['longitude']?.toString() ?? '');
    if (clat != null && clng != null) {
      final dist = Geolocator.distanceBetween(mlat, mlng, clat, clng) / 1000;
      setState(() => _distanceKm = dist);
    }
  }

  Future<void> _loadRequest() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final req = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        setState(() {
          _request = req;
          _loading = false;
        });
        if (_mechanicLat != null && _mechanicLng != null) _computeDistance(_mechanicLat!, _mechanicLng!);
        if ((req['status']?.toString() ?? '') == 'MECHANIC_EN_ROUTE') _startLocationUpdatesIfEnRoute();
      } else {
        setState(() { _error = 'Failed to load request'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _accept() async {
    if (_request == null) return;
    if (_request!['acceptedMechanicId'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This request was already accepted by another mechanic.')));
      return;
    }
    setState(() => _accepting = true);
    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/accept-by/${widget.mechanicId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (mounted) {
        setState(() => _accepting = false);
        if (r.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have accepted. Wait for customer to complete payment.')));
          _loadRequest();
        } else {
          final body = jsonDecode(r.body) as Map?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body?['error']?.toString() ?? 'Could not accept')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _accepting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _startEnRoute() async {
    setState(() => _accepting = true);
    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/start-en-route'),
        headers: {'Content-Type': 'application/json'},
      );
      if (mounted) {
        setState(() => _accepting = false);
        if (r.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You\'re on the way. Customer can track you.')));
          _loadRequest().then((_) => _startLocationUpdatesIfEnRoute());
        } else {
          final body = jsonDecode(r.body) as Map?;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body?['error']?.toString() ?? 'Failed')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _accepting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markArrived() async {
    setState(() => _accepting = true);
    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/arrived'),
        headers: {'Content-Type': 'application/json'},
      );
      if (mounted) {
        setState(() => _accepting = false);
        if (r.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as arrived. Wait for customer to confirm.')));
          _loadRequest();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.burntOrange, title: Text('Request #${widget.requestId}', style: GoogleFonts.outfit(color: AppColors.onBurntOrange))),
        body: const Center(child: CircularProgressIndicator(color: AppColors.burntOrange)),
      );
    }
    if (_error != null || _request == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.burntOrange, title: Text('Request #${widget.requestId}', style: GoogleFonts.outfit(color: AppColors.onBurntOrange))),
        body: Center(child: Text(_error ?? 'Request not found', style: GoogleFonts.inter())),
      );
    }
    final r = _request!;
    final status = r['status']?.toString() ?? '';
    final accepted = r['acceptedMechanicId'] != null;
    final acceptedByMe = accepted && r['acceptedMechanicId'] == widget.mechanicId;
    final custLat = double.tryParse(r['latitude']?.toString() ?? '');
    final custLng = double.tryParse(r['longitude']?.toString() ?? '');
    List<String> photoUrls = [];
    try {
      final raw = r['photoUrls']?.toString();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) photoUrls = decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.onBurntOrange), onPressed: () => Navigator.pop(context)),
        title: Text('Request details', style: GoogleFonts.outfit(color: AppColors.onBurntOrange, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (custLat != null && custLng != null) ...[
              SizedBox(
                height: 200,
                width: double.infinity,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(custLat, custLng),
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('customer'),
                      position: LatLng(custLat, custLng),
                      infoWindow: const InfoWindow(title: 'Customer location'),
                    ),
                    if (_mechanicLat != null && _mechanicLng != null)
                      Marker(
                        markerId: const MarkerId('me'),
                        position: LatLng(_mechanicLat!, _mechanicLng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        infoWindow: const InfoWindow(title: 'You'),
                      ),
                  },
                ),
              ),
              if (_distanceKm != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: AppColors.burntOrange.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.straighten, color: AppColors.burntOrange, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '${_distanceKm!.toStringAsFixed(1)} km from you',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.burntOrange),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard('Problem', r['problemCategory'] ?? r['serviceType'] ?? '—', Icons.build_circle),
                  _sectionCard('Description', r['description'] ?? '—', Icons.description),
                  if (r['comment'] != null && r['comment'].toString().isNotEmpty)
                    _sectionCard('Customer note', r['comment'].toString(), Icons.note),
                  _sectionCard(
                    'Vehicle',
                    '${r['vehicleMakeName'] ?? ''} ${r['vehicleModelName'] ?? ''} (${r['vehiclePlateNumber'] ?? '—'})'.trim(),
                    Icons.directions_car,
                  ),
                  if (r['diagnosticAnswers'] != null && r['diagnosticAnswers'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionCard('Diagnostic answers', _formatDiagnosticAnswers(r['diagnosticAnswers']), Icons.quiz),
                  ],
                  if (photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Photos', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photoUrls.length,
                        itemBuilder: (context, i) {
                          final url = photoUrls[i];
                          final isFile = url.startsWith('/') || !url.startsWith('http');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: isFile && File(url).existsSync()
                                  ? Image.file(File(url), width: 100, height: 100, fit: BoxFit.cover)
                                  : Image.network(url, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderPhoto()),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accepted ? Colors.grey.shade100 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accepted ? Colors.grey.shade300 : Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(accepted ? Icons.info_outline : Icons.schedule, color: accepted ? Colors.grey : Colors.amber.shade800, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            accepted
                                ? (acceptedByMe ? 'You accepted. Waiting for customer payment.' : 'Another mechanic accepted.')
                                : 'Verify all details above. You have 5 minutes to accept.',
                            style: GoogleFonts.inter(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (!accepted) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.grey),
                              foregroundColor: Colors.grey[700],
                            ),
                            child: Text('Dismiss', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _accepting ? null : _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warmAmber,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _accepting
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onBurntOrange))
                                : Text('Accept request', style: GoogleFonts.outfit(color: AppColors.onBurntOrange, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ] else if (acceptedByMe) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.creamElevated,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer & vehicle', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                          const SizedBox(height: 10),
                          if (r['vehiclePhotoUrl'] != null && r['vehiclePhotoUrl'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  r['vehiclePhotoUrl'].toString().startsWith('http') ? r['vehiclePhotoUrl'].toString() : '${ApiConfig.baseUrl}${r['vehiclePhotoUrl']}',
                                  height: 80,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Icon(Icons.person, color: AppColors.burntOrange, size: 20),
                              const SizedBox(width: 8),
                              Text(r['customerName']?.toString() ?? '—', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.phone, color: AppColors.burntOrange, size: 20),
                              const SizedBox(width: 8),
                              SelectableText(r['customerPhone']?.toString() ?? '—', style: GoogleFonts.inter(fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (custLat != null && custLng != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final url = 'https://www.google.com/maps/dir/?api=1&destination=$custLat,$custLng';
                            try { launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); } catch (_) {}
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Get directions to customer'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: AppColors.burntOrange,
                            side: const BorderSide(color: AppColors.burntOrange),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (status == 'PENDING_PAYMENT') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _accepting ? null : _startEnRoute,
                          icon: const Icon(Icons.directions_car, size: 22),
                          label: const Text('Ready to drive'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else if (status == 'MECHANIC_EN_ROUTE') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _accepting ? null : _markArrived,
                          icon: const Icon(Icons.location_on, size: 22),
                          label: const Text('I\'ve reached destination'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warmAmber,
                            foregroundColor: AppColors.darkChocolate,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Convert raw diagnostic JSON to readable text (e.g. "Which tyre: Front left").
  String _formatDiagnosticAnswers(dynamic raw) {
    if (raw == null) return '—';
    Map<String, dynamic> map = {};
    if (raw is String) {
      if (raw.isEmpty) return '—';
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return raw;
      }
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }
    if (map.isEmpty) return '—';
    String humanize(String key) {
      return key.replaceAll('_', ' ').split(' ').map((s) {
        if (s.isEmpty) return '';
        if (s.length == 1) return s.toUpperCase();
        return s[0].toUpperCase() + s.substring(1).toLowerCase();
      }).join(' ');
    }
    return map.entries.map((e) => '${humanize(e.key)}: ${e.value ?? ''}').join('\n');
  }

  Widget _placeholderPhoto() {
    return Container(
      width: 100,
      height: 100,
      color: Colors.grey.shade200,
      child: Icon(Icons.image, size: 40, color: Colors.grey[500]),
    );
  }

  Widget _sectionCard(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.creamElevated,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.burntOrange.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppColors.burntOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.warmBrownMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(value.isEmpty ? '—' : value, style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

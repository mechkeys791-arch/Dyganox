import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_config.dart';
import 'full_screen_media_viewer_page.dart';

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

class _MechanicRequestDetailBookFlowPageState extends State<MechanicRequestDetailBookFlowPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _accepting = false;
  bool _dismissing = false;
  String? _error;
  double? _mechanicLat;
  double? _mechanicLng;
  double? _distanceKm;
  Timer? _locationUpdateTimer;

  final Set<Polyline> _polylines = {};
  bool _polylineFetched = false;
  double? _polylineAnchorLat;
  double? _polylineAnchorLng;
  DateTime? _lastRouteRefetchAt;

  double? _displayMechanicLat;
  double? _displayMechanicLng;
  double _animStartLat = 0, _animStartLng = 0, _animEndLat = 0, _animEndLng = 0;
  late AnimationController _markerAnimController;
  late Animation<double> _markerAnimCurve;
  static const double _minMoveMetersToAnimate = 8;

  @override
  void initState() {
    super.initState();
    _markerAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
    _markerAnimCurve = CurvedAnimation(parent: _markerAnimController, curve: Curves.easeOutCubic);
    _markerAnimController.addListener(_onMarkerAnimTick);
    _mechanicLat = widget.mechanicLat;
    _mechanicLng = widget.mechanicLng;
    if (_mechanicLat != null && _mechanicLng != null) {
      _displayMechanicLat = _mechanicLat;
      _displayMechanicLng = _mechanicLng;
    }
    _loadRequest();
    if (_mechanicLat == null || _mechanicLng == null) _getMechanicLocation();
  }

  void _onMarkerAnimTick() {
    if (!mounted) return;
    final t = _markerAnimCurve.value;
    setState(() {
      _displayMechanicLat = _animStartLat + (_animEndLat - _animStartLat) * t;
      _displayMechanicLng = _animStartLng + (_animEndLng - _animStartLng) * t;
    });
  }

  @override
  void dispose() {
    _markerAnimController.removeListener(_onMarkerAnimTick);
    _markerAnimController.dispose();
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
      if (!mounted) return;
      _applyMechanicGpsUpdate(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  void _applyMechanicGpsUpdate(double lat, double lng) {
    if (!mounted) return;
    if (_mechanicLat != null && _mechanicLng != null) {
      final startLat = _displayMechanicLat ?? _mechanicLat!;
      final startLng = _displayMechanicLng ?? _mechanicLng!;
      final distMeters = Geolocator.distanceBetween(startLat, startLng, lat, lng);
      if (distMeters >= _minMoveMetersToAnimate) {
        _animStartLat = startLat;
        _animStartLng = startLng;
        _animEndLat = lat;
        _animEndLng = lng;
        final t = (distMeters / 800).clamp(0.35, 1.0);
        _markerAnimController.duration = Duration(
          milliseconds: (2400 + 3800 * t).round().clamp(2000, 6800),
        );
        _markerAnimController.reset();
        _markerAnimController.forward();
      } else {
        setState(() {
          _displayMechanicLat = lat;
          _displayMechanicLng = lng;
        });
      }
    } else {
      setState(() {
        _displayMechanicLat = lat;
        _displayMechanicLng = lng;
      });
    }
    setState(() {
      _mechanicLat = lat;
      _mechanicLng = lng;
    });
    if (_request != null) {
      _computeDistance(lat, lng);
      _tryFetchRoutePolylineIfReady();
      if (_polylineFetched) _maybeRefetchRoutePolyline(lat, lng);
    }
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
        setState(() {
          _mechanicLat = lat;
          _mechanicLng = lng;
          _displayMechanicLat ??= lat;
          _displayMechanicLng ??= lng;
        });
        if (_request != null && lat != null && lng != null) {
          _computeDistance(lat, lng);
          _tryFetchRoutePolylineIfReady();
        }
      }
    } catch (_) {}
  }

  void _maybeRefetchRoutePolyline(double lat, double lng) {
    if (_polylineAnchorLat == null || _polylineAnchorLng == null) return;
    final moved = Geolocator.distanceBetween(_polylineAnchorLat!, _polylineAnchorLng!, lat, lng);
    final now = DateTime.now();
    if (moved < 85) return;
    if (_lastRouteRefetchAt != null && now.difference(_lastRouteRefetchAt!) < const Duration(seconds: 22)) return;
    _lastRouteRefetchAt = now;
    _polylineAnchorLat = lat;
    _polylineAnchorLng = lng;
    _polylineFetched = false;
    _fetchRoutePolyline();
  }

  void _tryFetchRoutePolylineIfReady() {
    final r = _request;
    if (r == null || _mechanicLat == null || _mechanicLng == null) return;
    final clat = double.tryParse(r['latitude']?.toString() ?? '');
    final clng = double.tryParse(r['longitude']?.toString() ?? '');
    if (clat == null || clng == null) return;
    if (!_polylineFetched) _fetchRoutePolyline();
  }

  Future<void> _fetchRoutePolyline() async {
    final r = _request;
    if (r == null || _mechanicLat == null || _mechanicLng == null) return;
    if (_polylineFetched) return;
    final clat = double.tryParse(r['latitude']?.toString() ?? '');
    final clng = double.tryParse(r['longitude']?.toString() ?? '');
    if (clat == null || clng == null) return;
    final key = ApiConfig.googleMapsApiKey;
    if (key.isEmpty) {
      _addFallbackPolyline(clat, clng, markFetched: true);
      return;
    }
    try {
      final polylinePoints = PolylinePoints();
      final result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          mode: TravelMode.driving,
          origin: PointLatLng(_mechanicLat!, _mechanicLng!),
          destination: PointLatLng(clat, clng),
        ),
        googleApiKey: key,
      );
      if (result.points.isNotEmpty && mounted) {
        final points = result.points.map((p) => LatLng(p.latitude, p.longitude)).toList();
        _polylineAnchorLat = _mechanicLat;
        _polylineAnchorLng = _mechanicLng;
        setState(() {
          _polylines
            ..clear()
            ..add(Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: AppColors.burntOrange,
              width: 6,
              geodesic: true,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              patterns: const [],
            ));
        });
        _polylineFetched = true;
      } else {
        _addFallbackPolyline(clat, clng, markFetched: true);
      }
    } catch (_) {
      _addFallbackPolyline(clat, clng, markFetched: true);
    }
  }

  void _addFallbackPolyline(double clat, double clng, {bool markFetched = false}) {
    if (_mechanicLat == null || _mechanicLng == null || !mounted) return;
    if (markFetched) _polylineFetched = true;
    setState(() {
      _polylines
        ..clear()
        ..add(Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(_mechanicLat!, _mechanicLng!),
            LatLng(clat, clng),
          ],
          color: AppColors.burntOrange,
          width: 5,
          geodesic: true,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          patterns: const [],
        ));
    });
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
        _tryFetchRoutePolylineIfReady();
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
    if (_request!['acceptedMechanicId'] != null && _request!['acceptedMechanicId'].toString().isNotEmpty) {
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

  Future<void> _dismissOffer() async {
    if (_request == null) return;
    final st = _request!['status']?.toString() ?? '';
    if (st == 'PENDING_BROADCAST') {
      setState(() => _dismissing = true);
      try {
        final r = await http.put(
          Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/broadcast-dismiss'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'mechanicId': widget.mechanicId}),
        );
        if (!mounted) return;
        setState(() => _dismissing = false);
        if (r.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You passed on this job. The customer still has other mechanics.')),
          );
          Navigator.pop(context, true);
        } else {
          final body = jsonDecode(r.body) as Map?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body?['error']?.toString() ?? 'Could not update. Try again.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _dismissing = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
      return;
    }
    if (st == 'PENDING') {
      setState(() => _dismissing = true);
      try {
        final r = await http.put(
          Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/reject'),
          headers: {'Content-Type': 'application/json'},
        );
        if (!mounted) return;
        setState(() => _dismissing = false);
        if (r.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined.')));
          Navigator.pop(context, true);
        } else {
          final body = jsonDecode(r.body) as Map?;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body?['error']?.toString() ?? 'Could not decline.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _dismissing = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _startEnRoute() async {
    setState(() => _accepting = true);
    try {
      await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/ready-to-drive'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mechanicId': widget.mechanicId}),
      );
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
    final accRaw = r['acceptedMechanicId'];
    final accId = accRaw == null
        ? null
        : (accRaw is num
            ? accRaw.toInt()
            : int.tryParse(accRaw.toString().contains('.') ? accRaw.toString().split('.').first : accRaw.toString()));
    final accepted = accId != null;
    final acceptedByMe = accId != null && accId == widget.mechanicId;
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
                  myLocationEnabled: false,
                  polylines: _polylines,
                  markers: {
                    Marker(
                      markerId: const MarkerId('customer'),
                      position: LatLng(custLat, custLng),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: 'Customer', snippet: 'User location'),
                    ),
                    if (_displayMechanicLat != null && _displayMechanicLng != null)
                      Marker(
                        markerId: const MarkerId('me'),
                        position: LatLng(_displayMechanicLat!, _displayMechanicLng!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        infoWindow: const InfoWindow(title: 'Mechanic', snippet: 'Your location'),
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
                    Text('Damage photos / videos', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: photoUrls.length,
                        itemBuilder: (context, i) {
                          final rawUrl = photoUrls[i];
                          final fullUrl = rawUrl.startsWith('http') ? rawUrl : '${ApiConfig.baseUrl}$rawUrl';
                          final isFile = rawUrl.startsWith('/') && !rawUrl.startsWith('http');
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                if (isFile && File(rawUrl).existsSync()) {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => FullScreenMediaViewerPage(url: rawUrl, title: 'Damage photo'),
                                  ));
                                } else {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => FullScreenMediaViewerPage(
                                      url: fullUrl,
                                      title: FullScreenMediaViewerPage.isVideoUrl(fullUrl) ? 'Damage video' : 'Damage photo',
                                    ),
                                  ));
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: isFile && File(rawUrl).existsSync()
                                    ? Image.file(File(rawUrl), width: 100, height: 100, fit: BoxFit.cover)
                                    : Image.network(fullUrl, width: 100, height: 100, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholderPhoto()),
                              ),
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
                                : 'Verify details, then accept or pass. The customer is waiting for a mechanic.',
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
                            onPressed: (_accepting || _dismissing) ? null : _dismissOffer,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Colors.grey),
                              foregroundColor: Colors.grey[700],
                            ),
                            child: _dismissing
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : Text('Pass on job', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (_accepting || _dismissing) ? null : _accept,
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
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  final vUrl = r['vehiclePhotoUrl'].toString().startsWith('http')
                                      ? r['vehiclePhotoUrl'].toString()
                                      : '${ApiConfig.baseUrl}${r['vehiclePhotoUrl']}';
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => FullScreenMediaViewerPage(url: vUrl, title: 'Vehicle photo'),
                                  ));
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    color: Colors.grey[100],
                                    constraints: const BoxConstraints(maxHeight: 220),
                                    child: Image.network(
                                      r['vehiclePhotoUrl'].toString().startsWith('http')
                                          ? r['vehiclePhotoUrl'].toString()
                                          : '${ApiConfig.baseUrl}${r['vehiclePhotoUrl']}',
                                      width: double.infinity,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const SizedBox(height: 120, child: Center(child: Icon(Icons.directions_car, size: 48))),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          Row(
                            children: [
                              Icon(Icons.person, color: AppColors.burntOrange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r['customerName']?.toString() ?? '—',
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone, color: AppColors.burntOrange, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  r['customerPhone']?.toString() ?? '—',
                                  style: GoogleFonts.inter(fontSize: 14),
                                ),
                              ),
                              if (r['customerPhone'] != null && r['customerPhone'].toString().trim().isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.call, color: AppColors.burntOrange),
                                  onPressed: () {
                                    final phone = r['customerPhone'].toString().trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
                                    try { launchUrl(Uri.parse('tel:$phone'), mode: LaunchMode.externalApplication); } catch (_) {}
                                  },
                                ),
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

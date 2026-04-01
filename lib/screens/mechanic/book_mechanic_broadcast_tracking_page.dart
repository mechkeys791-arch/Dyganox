import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../services/api_config.dart';
import '../../services/app_remote_service.dart';
import '../../services/service_ads_api.dart';
import '../../widgets/service_ad_strip.dart';
import 'mechanic_accepted_ready_page.dart';

/// Rapido-style: map with live mechanic pins while waiting; sheet shows counts, booking summary, promos (admin [BOOK_MECHANIC_WAITING]).
class BookMechanicBroadcastTrackingPage extends StatefulWidget {
  final int requestId;
  final Map<String, dynamic> initialRequest;
  final double userLat;
  final double userLng;
  final bool isNightService;
  final String problemLabel;
  final String vehicleLine;
  final String commentLine;
  /// Garage / model photo when tyre issue (optional).
  final String? vehiclePhotoUrl;
  /// Short line from diagnostic answers (optional).
  final String diagnosticLine;
  final String problemCategoryId;

  const BookMechanicBroadcastTrackingPage({
    super.key,
    required this.requestId,
    required this.initialRequest,
    required this.userLat,
    required this.userLng,
    required this.isNightService,
    required this.problemLabel,
    required this.vehicleLine,
    required this.commentLine,
    this.vehiclePhotoUrl,
    this.diagnosticLine = '',
    this.problemCategoryId = '',
  });

  @override
  State<BookMechanicBroadcastTrackingPage> createState() => _BookMechanicBroadcastTrackingPageState();
}

class _BookMechanicBroadcastTrackingPageState extends State<BookMechanicBroadcastTrackingPage> {
  Timer? _pollTimer;
  Timer? _smoothTimer;
  GoogleMapController? _mapController;
  Map<String, dynamic> _request = {};
  int _notified = 0;
  int _dismissed = 0;
  List<Map<String, dynamic>> _mechanicsRaw = [];
  final Map<int, LatLng> _smooth = {};
  final Map<int, LatLng> _targets = {};
  List<Map<String, dynamic>> _ads = [];
  DateTime? _expiresAt;
  bool _loading = true;
  BitmapDescriptor? _mechanicPinIcon;

  @override
  void initState() {
    super.initState();
    _request = Map<String, dynamic>.from(widget.initialRequest);
    _parseExpiry();
    _loadBrandingPin();
    _loadAds();
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
    _smoothTimer = Timer.periodic(const Duration(milliseconds: 50), (_) => _lerpMechanics());
  }

  void _parseExpiry() {
    final raw = _request['viewExpiryAt'] ?? _request['view_expiry_at'];
    if (raw == null) return;
    try {
      _expiresAt = DateTime.tryParse(raw.toString());
    } catch (_) {}
  }

  Future<void> _loadBrandingPin() async {
    try {
      final b = await AppRemoteService.getAppBrandingConfig();
      final url = b?['mechanicShopMarkerIconUrl']?.toString().trim() ?? '';
      if (url.isEmpty) return;
      final r = await http.get(Uri.parse(url));
      if (r.statusCode != 200 || !mounted) return;
      final codec = await ui.instantiateImageCodec(r.bodyBytes, targetWidth: 120);
      final frame = await codec.getNextFrame();
      final bd = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (bd != null && mounted) {
        setState(() => _mechanicPinIcon = BitmapDescriptor.fromBytes(bd.buffer.asUint8List()));
      }
    } catch (_) {}
  }

  Future<void> _loadAds() async {
    final list = await ServiceAdsApi.fetchMerged(
      ['BOOK_MECHANIC_WAITING', 'NIGHT_SERVICE'],
      lat: widget.userLat,
      lng: widget.userLng,
    );
    if (mounted) setState(() => _ads = list);
  }

  void _lerpMechanics() {
    if (!mounted || _targets.isEmpty) return;
    bool changed = false;
    for (final e in _targets.entries) {
      final t = e.value;
      final cur = _smooth[e.key] ?? t;
      final d = Geolocator.distanceBetween(cur.latitude, cur.longitude, t.latitude, t.longitude);
      if (d < 5) {
        if (_smooth[e.key] != t) {
          _smooth[e.key] = t;
          changed = true;
        }
      } else {
        final a = 0.14;
        _smooth[e.key] = LatLng(
          cur.latitude + (t.latitude - cur.latitude) * a,
          cur.longitude + (t.longitude - cur.longitude) * a,
        );
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _pollOnce() async {
    if (!mounted) return;
    try {
      final tr = await http.get(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}/customer-tracking'),
        headers: {'Content-Type': 'application/json'},
      );
      if (tr.statusCode == 200) {
        final data = jsonDecode(tr.body) as Map<String, dynamic>;
        final reqMap = data['request'];
        if (reqMap is Map) {
          _request = Map<String, dynamic>.from(reqMap);
        }
        _notified = (data['notifiedCount'] as num?)?.toInt() ?? 0;
        _dismissed = (data['dismissedCount'] as num?)?.toInt() ?? 0;
        final mechList = data['mechanics'];
        if (mechList is List) {
          _mechanicsRaw = mechList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          for (final m in _mechanicsRaw) {
            final id = (m['id'] as num?)?.toInt();
            if (id == null) continue;
            final lat = double.tryParse(m['latitude']?.toString() ?? '');
            final lng = double.tryParse(m['longitude']?.toString() ?? '');
            if (lat != null && lng != null) {
              _targets[id] = LatLng(lat, lng);
              _smooth.putIfAbsent(id, () => LatLng(lat, lng));
            }
          }
        }
        final st = _request['status']?.toString() ?? '';
        if (st == 'PENDING_PAYMENT') {
          _pollTimer?.cancel();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(builder: (_) => MechanicAcceptedReadyPage(request: _request)),
            );
          }
          return;
        }
        if (st == 'CANCELLED' || st == 'REJECTED') {
          _pollTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request $st')));
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
          return;
        }
        if (mounted) {
          setState(() => _loading = false);
          _fitCamera();
        }
        return;
      }
    } catch (_) {}

    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final req = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        _request = req;
        final st = req['status']?.toString() ?? '';
        if (st == 'PENDING_PAYMENT') {
          _pollTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute<void>(builder: (_) => MechanicAcceptedReadyPage(request: req)),
          );
          return;
        }
        setState(() => _loading = false);
      }
    } catch (_) {}
  }

  void _fitCamera() {
    if (_mapController == null) return;
    final pts = <LatLng>[LatLng(widget.userLat, widget.userLng)];
    for (final p in _smooth.values) {
      pts.add(p);
    }
    if (pts.length < 2) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(widget.userLat, widget.userLng), 14));
      return;
    }
    double minLat = pts.first.latitude, maxLat = minLat, minLng = pts.first.longitude, maxLng = minLng;
    for (final p in pts) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
        64,
      ),
    );
  }

  Set<Marker> get _markers {
    final s = <Marker>{
      Marker(
        markerId: const MarkerId('you'),
        position: LatLng(widget.userLat, widget.userLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Pickup', snippet: 'Your location'),
      ),
    };
    int i = 0;
    for (final e in _smooth.entries) {
      String name = 'Mechanic';
      for (final m in _mechanicsRaw) {
        if ((m['id'] as num?)?.toInt() == e.key) {
          name = m['name']?.toString() ?? 'Mechanic';
          break;
        }
      }
      s.add(
        Marker(
          markerId: MarkerId('m${e.key}'),
          position: e.value,
          icon: _mechanicPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange + (i++ % 3) * 10),
          infoWindow: InfoWindow(title: name, snippet: 'Shop location'),
        ),
      );
    }
    return s;
  }

  String? _timeLeftLabel() {
    if (_expiresAt == null) return null;
    final left = _expiresAt!.difference(DateTime.now());
    if (left.isNegative) return 'Expiring…';
    final m = left.inMinutes;
    final s = left.inSeconds % 60;
    return '${m}m ${s}s';
  }

  double? _nightEstimate() {
    if (!widget.isNightService) return null;
    final a = _request['amount'];
    if (a is num) return a.toDouble();
    return double.tryParse(a?.toString() ?? '');
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _smoothTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final nightAmt = _nightEstimate();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: h * 0.5,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(widget.userLat, widget.userLng), zoom: 13.5),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 48, bottom: h * 0.08),
              onMapCreated: (c) {
                _mapController = c;
                WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
              },
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _confirmLeave(context),
              ),
            ),
          ),
          if (_timeLeftLabel() != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              right: 12,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    _timeLeftLabel()!,
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.38,
            maxChildSize: 0.92,
            builder: (ctx, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    if (_ads.isNotEmpty) ...[
                      ServiceAdHorizontalRail(
                        ads: _ads,
                        height: 108,
                        onAdTap: (ad) {
                          final sub = ad['subtitle']?.toString() ?? '';
                          if (sub.isNotEmpty && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(sub)));
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Finding a mechanic',
                            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pins show each mechanic\'s shop until they head out.',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(child: _statTile('Notified', '$_notified', Icons.notifications_active_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: _statTile('Accepted', _request['acceptedMechanicId'] != null ? '1' : '0', Icons.check_circle_outline)),
                          const SizedBox(width: 8),
                          Expanded(child: _statTile('Declined', '$_dismissed', Icons.cancel_outlined)),
                        ],
                      ),
                    ),
                    if (nightAmt != null && nightAmt > 0) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.nightlight_round, color: AppColors.burntOrange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Night estimate (advance + fees): ₹${nightAmt.toStringAsFixed(0)}',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (_notified == 0 && !_loading) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton.icon(
                          onPressed: () => _pollOnce(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Check again'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.burntOrange),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your request', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          if (widget.problemCategoryId == 'tyre_puncture' &&
                              widget.vehiclePhotoUrl != null &&
                              widget.vehiclePhotoUrl!.trim().isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    widget.vehiclePhotoUrl!.trim().startsWith('http')
                                        ? widget.vehiclePhotoUrl!.trim()
                                        : '${ApiConfig.baseUrl}${widget.vehiclePhotoUrl!.trim()}',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 64,
                                      height: 64,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.directions_car),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.vehicleLine, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
                                      if (widget.diagnosticLine.isNotEmpty)
                                        Text(widget.diagnosticLine, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          _detailRow(Icons.build, widget.problemLabel),
                          if (widget.problemCategoryId != 'tyre_puncture' ||
                              widget.vehiclePhotoUrl == null ||
                              widget.vehiclePhotoUrl!.trim().isEmpty)
                            _detailRow(Icons.directions_car, widget.vehicleLine),
                          if (widget.diagnosticLine.isNotEmpty && widget.problemCategoryId != 'tyre_puncture') _detailRow(Icons.info_outline, widget.diagnosticLine),
                          if (widget.commentLine.isNotEmpty) _detailRow(Icons.notes, widget.commentLine),
                        ],
                      ),
                    ),
                    if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.burntOrange))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.creamElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: AppColors.burntOrange),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.burntOrange),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 14, height: 1.35))),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave tracking?'),
        content: const Text('Your request stays active. You can return from notifications or home.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok == true && context.mounted) Navigator.of(context).pop();
  }
}

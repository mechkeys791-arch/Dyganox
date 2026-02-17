import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_config.dart';

/// Full-screen request details shown after mechanic accepts from notification.
/// Map in a box on top, then service type, distance, customer, amount, description, Call, Navigate.
class MechanicRequestDetailPage extends StatefulWidget {
  final String requestId;

  const MechanicRequestDetailPage({super.key, required this.requestId});

  @override
  State<MechanicRequestDetailPage> createState() => _MechanicRequestDetailPageState();
}

class _MechanicRequestDetailPageState extends State<MechanicRequestDetailPage> {
  Map<String, dynamic>? _request;
  bool _loading = true;
  String? _error;
  double? _distanceKm;
  Position? _myPosition;
  GoogleMapController? _mapController;
  static const double _mapHeight = 240;

  @override
  void initState() {
    super.initState();
    _fetchRequest();
    _getMyLocation();
  }

  Future<void> _getMyLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() => _myPosition = pos);
    } catch (_) {}
  }

  Future<void> _fetchRequest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = '${ApiConfig.mechanicRequestsEndpoint}/${widget.requestId}';
      final res = await http.get(Uri.parse(url), headers: {'Content-Type': 'application/json'});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _request = data;
          _loading = false;
          _computeDistance(data);
        });
      } else {
        setState(() {
          _error = 'Request not found';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _computeDistance(Map<String, dynamic> data) {
    final lat = _parseDouble(data['latitude']);
    final lng = _parseDouble(data['longitude']);
    if (lat != null && lng != null && _myPosition != null) {
      final km = Geolocator.distanceBetween(
        _myPosition!.latitude,
        _myPosition!.longitude,
        lat,
        lng,
      ) / 1000;
      setState(() => _distanceKm = double.parse(km.toStringAsFixed(1)));
    } else if (data['distanceKm'] != null) {
      setState(() => _distanceKm = _parseDouble(data['distanceKm']));
    }
  }

  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  LatLng? get _customerPosition {
    if (_request == null) return null;
    final lat = _parseDouble(_request!['latitude']);
    final lng = _parseDouble(_request!['longitude']);
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          'Request Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : _error != null
              ? _buildError()
              : _request == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMapBox(),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildStatusChip(),
                                const SizedBox(height: 12),
                                _buildInfoCard(),
                                const SizedBox(height: 12),
                                _buildCustomerCard(),
                                const SizedBox(height: 12),
                                _buildAmountAndService(),
                                if (_request!['description'] != null &&
                                    (_request!['description'] as String).isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildDescriptionCard(),
                                ],
                                const SizedBox(height: 20),
                                _buildActionButtons(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Back', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBox() {
    final pos = _customerPosition;
    if (pos == null) {
      return Container(
        height: _mapHeight,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 40, color: Colors.grey[500]),
              const SizedBox(height: 8),
              Text(
                'Location not shared',
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final initialCamera = CameraPosition(target: pos, zoom: 14.5);
    final markers = {
      Marker(
        markerId: const MarkerId('customer'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: _request!['customerName']?.toString() ?? 'Customer',
          snippet: _request!['serviceType']?.toString() ?? 'Service',
        ),
      ),
    };
    if (_myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('me'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'You', snippet: 'Your location'),
      ));
    }

    return Container(
      height: _mapHeight,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: initialCamera,
        markers: markers,
        onMapCreated: (c) => _mapController = c,
        mapType: MapType.normal,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
    );
  }

  Widget _buildStatusChip() {
    final status = _request!['status']?.toString() ?? 'ACCEPTED';
    final isAccepted = status == 'ACCEPTED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isAccepted
            ? const Color(0xFF10B981).withOpacity(0.12)
            : Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAccepted ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 18,
            color: isAccepted ? const Color(0xFF059669) : Colors.orange[700],
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isAccepted ? const Color(0xFF059669) : Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service & distance',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _infoChip(
                Icons.build_circle_outlined,
                _request!['serviceType']?.toString() ?? 'General Service',
                const Color(0xFF6366F1),
              ),
              const SizedBox(width: 10),
              if (_distanceKm != null)
                _infoChip(
                  Icons.straighten_rounded,
                  '$_distanceKm km',
                  const Color(0xFF10B981),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
    final name = _request!['customerName']?.toString() ?? 'Customer';
    final phone = _request!['customerPhone']?.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (phone != null && phone.isNotEmpty)
                      Text(
                        phone,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountAndService() {
    final amount = _request!['amount'];
    final amountStr = amount != null ? '₹${(amount is num ? amount : double.tryParse(amount.toString()) ?? 0).toStringAsFixed(0)}' : '₹0';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amountStr,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _request!['serviceType']?.toString() ?? 'General',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6366F1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _request!['description']?.toString() ?? '—',
            style: GoogleFonts.inter(fontSize: 14, height: 1.4, color: const Color(0xFF334155)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final phone = _request!['customerPhone']?.toString();
    final pos = _customerPosition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (phone != null && phone.isNotEmpty)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _launchUrl('tel:${phone.replaceAll(RegExp(r'[\s\-\(\)]'), '')}'),
              icon: const Icon(Icons.phone_rounded, size: 22),
              label: Text('Call customer', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        if (phone != null && phone.isNotEmpty && pos != null) const SizedBox(height: 10),
        if (pos != null)
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _openInMaps(pos),
              icon: const Icon(Icons.directions_rounded, size: 22),
              label: Text('Navigate', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6366F1),
                side: const BorderSide(color: Color(0xFF6366F1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openInMaps(LatLng dest) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}';
    await _launchUrl(url);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

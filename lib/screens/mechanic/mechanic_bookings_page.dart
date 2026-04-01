import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'mechanic_request_detail_book_flow_page.dart';

class MechanicBookingsPage extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  final Function(Map<String, dynamic>) onAccept;
  final Function(Map<String, dynamic>) onReject;
  final Function(Map<String, dynamic>) onComplete;
  /// Called when mechanic taps "I have reached" with (booking, latitude, longitude). Optional; if null, button is hidden.
  final Future<void> Function(Map<String, dynamic> booking, double latitude, double longitude)? onReached;
  /// When set, the matching booking card gets a subtle border highlight
  final String? highlightRequestId;
  /// Initial filter: 'All', 'Pending', 'Accepted', 'Completed', 'Rejected', 'In progress'
  final String? initialFilter;
  /// Mechanic ID for opening request detail (required for View/accept broadcast flow)
  final int? mechanicId;
  
  const MechanicBookingsPage({
    super.key,
    required this.bookings,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    this.onReached,
    this.highlightRequestId,
    this.initialFilter,
    this.mechanicId,
  });

  @override
  State<MechanicBookingsPage> createState() => _MechanicBookingsPageState();
}

class _MechanicBookingsPageState extends State<MechanicBookingsPage> {
  late String _filterStatus; // All, Pending, Accepted, Completed, Rejected

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialFilter ?? 'All';
  }
  
  List<Map<String, dynamic>> get _filteredBookings {
    if (_filterStatus == 'All') {
      return widget.bookings;
    }
    // "In progress" and "Accepted" both match accepted-style bookings for display
    if (_filterStatus == 'In progress') {
      return widget.bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'in progress' || (b['status'] ?? '').toString().toLowerCase() == 'in-progress').toList();
    }
    return widget.bookings.where((b) => b['status'] == _filterStatus).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF111111), Color(0xFFFBBF24)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Bookings',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '${widget.bookings.length} Total',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', widget.bookings.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', widget.bookings.where((b) => b['status'] == 'Pending').length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Accepted', widget.bookings.where((b) => b['status'] == 'Accepted').length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', widget.bookings.where((b) => b['status'] == 'Rejected').length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Completed', widget.bookings.where((b) => b['status'] == 'Completed').length),
                ],
              ),
            ),
          ),
          
          // Bookings List
          Expanded(
            child: _filteredBookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No $_filterStatus bookings',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bookings will appear here',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(_filteredBookings[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, int count) {
    final isSelected = _filterStatus == label;
    Color chipColor;
    
    switch (label) {
      case 'Pending':
        chipColor = const Color(0xFFF59E0B);
        break;
      case 'Accepted':
        chipColor = const Color(0xFF10B981);
        break;
      case 'Completed':
        chipColor = const Color(0xFFFBBF24);
        break;
      case 'Rejected':
        chipColor = const Color(0xFFEF4444);
        break;
      default:
        chipColor = Colors.grey;
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.3) : chipColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : chipColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isPending = booking['status'] == 'Pending';
    final isAccepted = booking['status'] == 'Accepted';
    final inProgress = _isInProgress(booking);
    final location = (booking['location'] ?? 'Location').toString();
    
    Color statusColor;
    if (isPending) {
      statusColor = const Color(0xFFF59E0B);
    } else if (isAccepted) {
      statusColor = const Color(0xFF10B981);
    } else {
      statusColor = const Color(0xFFFBBF24);
    }
    
    final lat = _parseDouble(booking['latitude']);
    final lng = _parseDouble(booking['longitude']);
    final hasMap = lat != null && lng != null;
    
    final canOpenDetail = widget.mechanicId != null && (isPending || isAccepted || inProgress);
    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canOpenDetail
              ? () {
                  final reqId = booking['id'];
                  final mid = widget.mechanicId!;
                  if (reqId != null && mid > 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MechanicRequestDetailBookFlowPage(
                          requestId: reqId is int ? reqId : int.tryParse(reqId.toString()) ?? 0,
                          mechanicId: mid,
                        ),
                      ),
                    );
                  }
                }
              : null,
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Location as name + status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF111111), Color(0xFFFBBF24)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          location,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking['status'] ?? 'Pending',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Map box - 40-50% of card
          SizedBox(
            height: 180,
            child: hasMap
                ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(lat, lng),
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: MarkerId('booking_${booking['id']}'),
                        position: LatLng(lat, lng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    myLocationButtonEnabled: false,
                  )
                : Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off, size: 40, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text(
                            'Location not shared',
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Details in 2 columns
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildDetailCell('Customer', booking['customerName']?.toString() ?? '—')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDetailCellWithCall(
                        'Phone',
                        booking['customerPhone']?.toString() ?? '—',
                        booking['customerPhone'],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildDetailCell('Service', booking['service']?.toString() ?? '—')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDetailCell('Vehicle', booking['vehicle']?.toString() ?? '—')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildDetailCell('Date & Time', '${booking['date']} at ${booking['time']}')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDetailCell('Amount', booking['amount']?.toString() ?? '—')),
                  ],
                ),
                // Description (problem details from user)
                if ((booking['description'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailCell('Description', booking['description']?.toString() ?? '—'),
                ],
                // Customer note/comment
                if ((booking['comment'] ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailCell('Customer note', booking['comment']?.toString() ?? '—'),
                ],
                // Diagnostic answers (Q&A from problem flow)
                if (_parseDiagnosticAnswers(booking['diagnosticAnswers']).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildDetailCell('Diagnostic answers', _parseDiagnosticAnswers(booking['diagnosticAnswers'])),
                ],
                // Photos from user
                if (_parsePhotoUrls(booking['photoUrls']).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildPhotoRow(_parsePhotoUrls(booking['photoUrls'])),
                ],
                if (isPending) ...[
                  const SizedBox(height: 16),
                  _SwipeAcceptTrack(
                    onComplete: () async {
                      final dynamic r = widget.onAccept(booking);
                      if (r is Future) await r;
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.onReject(booking);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, size: 20),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ] else if (isAccepted || inProgress) ...[
                  if (widget.onReached != null && isAccepted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _onTapReached(booking),
                        icon: const Icon(Icons.location_on, size: 20),
                        label: const Text('I have reached'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF10B981),
                          side: const BorderSide(color: Color(0xFF10B981)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        widget.onComplete(booking);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: const Color(0xFF111111),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
    
    return card;
  }

  bool _isInProgress(Map<String, dynamic> booking) {
    final s = (booking['status'] ?? '').toString().toLowerCase().replaceAll('_', ' ');
    return s == 'in progress' || s == 'in-progress';
  }

  Future<void> _onTapReached(Map<String, dynamic> booking) async {
    if (widget.onReached == null) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      await widget.onReached!(booking, position.latitude, position.longitude);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not get location: $e'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  /// Parse diagnostic answers JSON to readable text (e.g. "Which tyre: Front left").
  String _parseDiagnosticAnswers(dynamic raw) {
    if (raw == null) return '';
    Map<String, dynamic> map = {};
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) map = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return raw;
      }
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }
    if (map.isEmpty) return '';
    String humanize(String key) {
      return key.replaceAll('_', ' ').split(' ').map((s) {
        if (s.isEmpty) return '';
        if (s.length == 1) return s.toUpperCase();
        return s[0].toUpperCase() + s.substring(1).toLowerCase();
      }).join(' ');
    }
    return map.entries.map((e) => '${humanize(e.key)}: ${e.value ?? ''}').join('\n');
  }

  List<String> _parsePhotoUrls(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
      } catch (_) {}
    }
    return [];
  }

  Widget _buildPhotoRow(List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photos', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            itemBuilder: (context, i) {
              final url = urls[i];
              final isFile = url.startsWith('/') || (!url.startsWith('http') && url.isNotEmpty);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isFile && url.isNotEmpty && File(url).existsSync()
                      ? Image.file(File(url), width: 80, height: 80, fit: BoxFit.cover)
                      : (url.startsWith('http')
                          ? Image.network(
                              url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _photoPlaceholder(),
                            )
                          : _photoPlaceholder()),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: Icon(Icons.image, size: 28, color: Colors.grey[500]),
    );
  }
  
  Widget _buildDetailCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
  
  Widget _buildDetailCellWithCall(String label, String value, dynamic phoneRaw) {
    final phone = phoneRaw?.toString() ?? '';
    final canCall = phone.isNotEmpty && phone != 'Not provided' && phone != '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (canCall)
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse('tel:${phone.replaceAll(RegExp(r'[\s\-\(\)]'), '')}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.call, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text('Call', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Slide thumb to the right to confirm accept (Rapido-style).
class _SwipeAcceptTrack extends StatefulWidget {
  final Future<void> Function() onComplete;

  const _SwipeAcceptTrack({required this.onComplete});

  @override
  State<_SwipeAcceptTrack> createState() => _SwipeAcceptTrackState();
}

class _SwipeAcceptTrackState extends State<_SwipeAcceptTrack> {
  double _dx = 0;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final trackW = c.maxWidth;
        const thumb = 48.0;
        const pad = 4.0;
        final maxDx = (trackW - thumb - pad * 2).clamp(0.0, double.infinity);
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF047857),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Slide to accept →',
                style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Positioned(
                left: pad + _dx.clamp(0, maxDx),
                top: pad,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    if (_busy) return;
                    setState(() => _dx = (_dx + d.delta.dx).clamp(0, maxDx));
                  },
                  onHorizontalDragEnd: (_) async {
                    if (_busy) return;
                    if (maxDx <= 0) return;
                    if (_dx >= maxDx * 0.82) {
                      setState(() {
                        _busy = true;
                        _dx = maxDx;
                      });
                      try {
                        await widget.onComplete();
                      } finally {
                        if (mounted) setState(() { _busy = false; _dx = 0; });
                      }
                    } else {
                      setState(() => _dx = 0);
                    }
                  },
                  child: Container(
                    width: thumb,
                    height: thumb,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: _busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF047857)),
                          )
                        : const Icon(Icons.arrow_forward_rounded, color: Color(0xFF047857), size: 26),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class MechanicBookingsPage extends StatefulWidget {
  final List<Map<String, dynamic>> bookings;
  final Function(Map<String, dynamic>) onAccept;
  final Function(Map<String, dynamic>) onReject;
  final Function(Map<String, dynamic>) onComplete;
  /// When set, the matching booking card gets a subtle border highlight
  final String? highlightRequestId;
  
  const MechanicBookingsPage({
    super.key,
    required this.bookings,
    required this.onAccept,
    required this.onReject,
    required this.onComplete,
    this.highlightRequestId,
  });

  @override
  State<MechanicBookingsPage> createState() => _MechanicBookingsPageState();
}

class _MechanicBookingsPageState extends State<MechanicBookingsPage> {
  String _filterStatus = 'All'; // All, Pending, Accepted, Completed
  
  List<Map<String, dynamic>> get _filteredBookings {
    if (_filterStatus == 'All') {
      return widget.bookings;
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
                if (isPending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            widget.onAccept(booking);
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.check_circle, size: 20),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
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
                    ],
                  ),
                ] else if (isAccepted) ...[
                  const SizedBox(height: 16),
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
    );
    
    return card;
  }
  
  double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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


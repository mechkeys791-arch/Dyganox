import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../core/theme/app_colors.dart';
import '../../services/api_config.dart';
import 'mechanic_bookings_page.dart';
import 'mechanic_profile_edit_page.dart';

/// Full mechanic profile: summary (earnings, jobs, rating, response rate),
/// tabs for Completed / Pending / Rejected records, and edit profile.
class MechanicProfilePage extends StatefulWidget {
  final Map<String, dynamic> mechanicData;
  final Map<String, dynamic> mechanicProfile;
  final List<Map<String, dynamic>> initialBookings;
  final VoidCallback? onProfileUpdated;

  const MechanicProfilePage({
    super.key,
    required this.mechanicData,
    required this.mechanicProfile,
    this.initialBookings = const [],
    this.onProfileUpdated,
  });

  @override
  State<MechanicProfilePage> createState() => _MechanicProfilePageState();
}

class _MechanicProfilePageState extends State<MechanicProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _bookings = [];
  bool _loadingBookings = true;
  late Map<String, dynamic> _profile;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _profile = Map<String, dynamic>.from(widget.mechanicProfile);
    _bookings = List<Map<String, dynamic>>.from(widget.initialBookings);
    _loadAllBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllBookings() async {
    setState(() => _loadingBookings = true);
    final mechanicId = widget.mechanicData['id'];
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId?.toString() ?? '');
    if (id != null) {
      try {
        final response = await http.get(
          Uri.parse(ApiConfig.mechanicBookingsForMechanic(id)),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && mounted) {
          final List<dynamic> data = jsonDecode(response.body);
          setState(() {
            _bookings = data.map((request) => _mapRequestToBooking(request)).toList();
          });
        }
      } catch (_) {
        // Use initialBookings (e.g. from dashboard pending fetch)
      }
    }
    if (mounted) setState(() => _loadingBookings = false);
  }

  Map<String, dynamic> _mapRequestToBooking(dynamic request) {
    String status = request['status'] ?? 'PENDING';
    status = status[0].toUpperCase() + status.substring(1).toLowerCase();
    final make = request['vehicleMakeName']?.toString() ?? '';
    final model = request['vehicleModelName']?.toString() ?? '';
    final plate = request['vehiclePlateNumber']?.toString() ?? '';
    final vehicleStr = '${make} ${model}'.trim();
    final vehicle = vehicleStr.isNotEmpty ? '$vehicleStr${plate.isNotEmpty ? ' ($plate)' : ''}' : (plate.isNotEmpty ? plate : 'Customer Vehicle');
    return {
      'id': request['id'],
      'customerName': request['customerName'] ?? 'Unknown',
      'customerPhone': request['customerPhone'] ?? 'Not provided',
      'customerEmail': request['customerEmail'] ?? '',
      'service': request['serviceType'] ?? request['problemCategory'] ?? 'General Service',
      'problemCategory': request['problemCategory'],
      'vehicle': vehicle,
      'vehicleMakeName': make,
      'vehicleModelName': model,
      'vehiclePlateNumber': plate,
      'latitude': request['latitude'],
      'longitude': request['longitude'],
      'location': '${request['latitude']}, ${request['longitude']}',
      'date': _safeSubstring(request['createdAt']?.toString(), 0, 10) ?? 'Today',
      'time': _safeSubstring(request['createdAt']?.toString(), 11, 16) ?? 'Now',
      'status': status,
      'amount': '₹${request['amount'] ?? 50}',
      'description': request['description'] ?? '',
      'comment': request['comment'] ?? '',
      'diagnosticAnswers': request['diagnosticAnswers'],
      'photoUrls': request['photoUrls'],
      'email': request['customerEmail'] ?? '',
    };
  }

  String? _safeSubstring(String? s, int start, int end) {
    if (s == null || s.isEmpty) return null;
    final len = s.length;
    if (start >= len) return null;
    final endClamped = end > len ? len : end;
    if (start >= endClamped) return null;
    return s.substring(start, endClamped);
  }

  int get _completedCount => _bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'completed').length;
  int get _pendingCount => _bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'pending').length;
  int get _rejectedCount => _bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'rejected').length;

  Future<void> _openEditProfile() async {
    final mid = widget.mechanicData['id'];
    final mechanicId = mid is int ? mid : (int.tryParse(mid?.toString() ?? '') ?? 0);
    if (mechanicId == 0) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MechanicProfileEditPage(
          mechanicProfile: _profile,
          mechanicId: mechanicId,
          onSave: (updated) {
            setState(() {
              _profile['name'] = updated['name'];
              _profile['phone'] = updated['phone'];
              _profile['email'] = updated['email'];
              _profile['specialty'] = updated['specialty'];
              _profile['experience'] = updated['experience'];
              _profile['shopAddress'] = updated['shopAddress'];
              _profile['latitude'] = updated['latitude'];
              _profile['longitude'] = updated['longitude'];
            });
            widget.onProfileUpdated?.call();
          },
        ),
      ),
    );
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
          'My Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _openEditProfile,
            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
            label: Text('Edit', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Completed ($_completedCount)'),
            Tab(text: 'Pending ($_pendingCount)'),
            Tab(text: 'Rejected ($_rejectedCount)'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllBookings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(),
              const SizedBox(height: 16),
              if (_loadingBookings)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.burntOrange)))
              else
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingList('Completed'),
                      _buildBookingList('Pending'),
                      _buildBookingList('Rejected'),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    final completedJobs = (_profile['completedJobs'] ?? 0) is int ? _profile['completedJobs'] as int : int.tryParse(_profile['completedJobs']?.toString() ?? '0') ?? 0;
    final rating = (_profile['rating'] ?? 0) is num ? (_profile['rating'] as num).toDouble() : double.tryParse(_profile['rating']?.toString() ?? '0') ?? 0.0;
    final totalRequests = _bookings.length;
    final responded = _bookings.where((b) {
      final s = (b['status'] ?? '').toString().toLowerCase();
      return s == 'accepted' || s == 'rejected' || s == 'completed';
    }).length;
    final responseRate = totalRequests > 0 ? (responded / totalRequests * 100).round() : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Summary', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Jobs completed',
                '${completedJobs}',
                Icons.check_circle_outline,
                AppColors.burntOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'Rating',
                rating > 0 ? rating.toStringAsFixed(1) : '–',
                Icons.star,
                Colors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Response rate',
                '$responseRate%',
                Icons.trending_up,
                const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                'Pending',
                '$_pendingCount',
                Icons.pending_actions,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildBookingList(String statusFilter) {
    final list = _bookings.where((b) => (b['status'] ?? '').toString() == statusFilter).toList();
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No $statusFilter bookings', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final b = list[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: AppColors.burntOrange.withOpacity(0.2),
              child: Icon(Icons.directions_car, color: AppColors.burntOrange),
            ),
            title: Text((b['customerName'] ?? 'Customer').toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${b['service'] ?? 'Service'} • ${b['vehicle'] ?? 'Vehicle'}',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: () => _openBookingsPageWithFilter(statusFilter),
          ),
        );
      },
    );
  }

  void _openBookingsPageWithFilter(String initialFilter) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MechanicBookingsPage(
          bookings: _bookings,
          onAccept: (_) {},
          onReject: (_) {},
          onComplete: (_) {},
          initialFilter: initialFilter,
        ),
      ),
    );
    _loadAllBookings();
  }
}

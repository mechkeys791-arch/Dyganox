import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../services/api_config.dart';
import '../../services/fcm_notification_service.dart';
import 'mechanic_bookings_page.dart';
import 'mechanic_services_page.dart';
import 'mechanic_profile_edit_page.dart';
import 'mechanic_help_chat_page.dart';
import 'mechanic_suspended_page.dart';
import 'mechanic_request_detail_page.dart';

class MechanicServiceDashboard extends StatefulWidget {
  final Map<String, dynamic>? mechanicData;
  /// When set, dashboard will auto-open Bookings section then Request Detail (for Accept-from-notification flow).
  final String? openRequestIdAfterMount;
  
  const MechanicServiceDashboard({super.key, this.mechanicData, this.openRequestIdAfterMount});

  @override
  State<MechanicServiceDashboard> createState() => _MechanicServiceDashboardState();
}

class _MechanicServiceDashboardState extends State<MechanicServiceDashboard> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  String _mechanicStatus = 'Available'; // Available, Busy, Offline
  List<Map<String, dynamic>> _bookings = [];
  List<String> _myServices = ['General Repair', 'Engine Service', 'Electrical Works'];
  // ignore: unused_field
  bool _isLoadingBookings = false;
  
  // Auto-refresh timer
  Timer? _refreshTimer;
  
  // Mock data for mechanic profile
  final Map<String, dynamic> _mechanicProfile = {
    'name': 'John Mechanic',
    'specialty': 'General Repair',
    'experience': '5-10 years',
    'rating': 4.8,
    'completedJobs': 127,
    'phone': '+91 98765 43210',
    'email': 'john.mechanic@example.com',
  };
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    if (widget.mechanicData != null) {
      _mechanicProfile['name'] = widget.mechanicData!['name'] ?? 'Mechanic';
      _mechanicProfile['specialty'] = widget.mechanicData!['specialty'] ?? 'General Repair';
      _mechanicProfile['experience'] = widget.mechanicData!['experience'] ?? '0-2 years';
      _mechanicProfile['phone'] = widget.mechanicData!['phone'] ?? '+91 98765 43210';
      _mechanicProfile['email'] = widget.mechanicData!['email'] ?? 'mechanic@example.com';
      _mechanicProfile['rating'] = widget.mechanicData!['rating'] ?? 4.5;
      _mechanicProfile['completedJobs'] = widget.mechanicData!['completedJobs'] ?? 0;
      _mechanicProfile['profilePhotoUrl'] = widget.mechanicData!['profilePhotoUrl'];
      _mechanicProfile['shopName'] = widget.mechanicData!['shopName'] ?? widget.mechanicData!['shop_name'];
      _mechanicProfile['shopAddress'] = widget.mechanicData!['shopAddress'] ?? widget.mechanicData!['shop_address'];
      _mechanicProfile['status'] = widget.mechanicData!['status'];
      _mechanicProfile['nightTimeAvailable'] = widget.mechanicData!['nightTimeAvailable'] ?? false;
      _mechanicProfile['openingTime'] = widget.mechanicData!['openingTime'];
      _mechanicProfile['closingTime'] = widget.mechanicData!['closingTime'];
      _mechanicProfile['workingDays'] = widget.mechanicData!['workingDays'];
      
      if (widget.mechanicData!['status'] != null) {
        _mechanicStatus = widget.mechanicData!['status'].toString();
      }
      if (widget.mechanicData!['services'] != null) {
        final servicesStr = widget.mechanicData!['services'].toString();
        if (servicesStr.isNotEmpty) {
          _myServices = servicesStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        }
      }
    }
    
    _loadMechanicProfileFromApi();
    _fetchBookings();

    // Register FCM token so mechanic receives request notifications (Accept/Reject)
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId != null) {
      final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
      if (id != null) FcmNotificationService.registerMechanicToken(id);
    }

    // Auto-refresh bookings every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchBookings();
      _loadMechanicProfileFromApi();
    });

    // Accept-from-notification: open Bookings section first, then Request Detail
    final requestId = widget.openRequestIdAfterMount;
    if (requestId != null && requestId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          _openBookingsThenRequestDetail(requestId);
        });
      });
    }
  }

  void _openBookingsThenRequestDetail(String requestId) {
    if (!mounted) return;
    // 1. Open Bookings section with highlighted/shaking card for this request
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MechanicBookingsPage(
          bookings: _bookings,
          onAccept: _acceptBooking,
          onReject: _rejectBooking,
          onComplete: _completeBooking,
          highlightRequestId: requestId,
        ),
      ),
    );
    // 2. Then open Request Detail on top (short delay so Bookings appears first)
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MechanicRequestDetailPage(requestId: requestId),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-register FCM token when app comes to foreground so notifications work after resume
    if (state == AppLifecycleState.resumed) {
      final mechanicId = widget.mechanicData?['id'];
      if (mechanicId != null) {
        final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
        if (id != null) FcmNotificationService.registerMechanicToken(id);
      }
    }
  }
  
  Future<void> _loadMechanicProfileFromApi() async {
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId == null) return;
    
    try {
      final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
      if (id == null) return;
      
      final response = await http.get(
        Uri.parse("${ApiConfig.mechanicEndpoint}/$id"),
        headers: {"Content-Type": "application/json"},
      );
      
      if (response.statusCode == 200 && mounted) {
        final m = jsonDecode(response.body);
        if (m['isSuspended'] == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicSuspendedPage(
                mechanicEmail: m['email']?.toString() ?? _mechanicProfile['email']?.toString(),
              ),
            ),
          );
          return;
        }
        setState(() {
          _mechanicStatus = m['status'] ?? 'Available';
          _mechanicProfile['name'] = m['name'] ?? _mechanicProfile['name'];
          _mechanicProfile['specialty'] = m['specialty'] ?? _mechanicProfile['specialty'];
          _mechanicProfile['experience'] = m['experience'] ?? _mechanicProfile['experience'];
          _mechanicProfile['phone'] = m['phone'] ?? _mechanicProfile['phone'];
          _mechanicProfile['email'] = m['email'] ?? _mechanicProfile['email'];
          _mechanicProfile['shopName'] = m['shopName'] ?? m['shop_name'] ?? _mechanicProfile['shopName'];
          _mechanicProfile['shopAddress'] = m['shopAddress'] ?? m['shop_address'] ?? _mechanicProfile['shopAddress'];
          _mechanicProfile['rating'] = m['rating'] ?? _mechanicProfile['rating'];
          _mechanicProfile['completedJobs'] = m['completedJobs'] ?? _mechanicProfile['completedJobs'];
          _mechanicProfile['nightTimeAvailable'] = m['nightTimeAvailable'] ?? false;
          _mechanicProfile['openingTime'] = m['openingTime'];
          _mechanicProfile['closingTime'] = m['closingTime'];
          _mechanicProfile['workingDays'] = m['workingDays'];
          if (m['services'] != null) {
            final s = m['services'].toString();
            if (s.isNotEmpty) {
              _myServices = s.split(',').map((e) => e.trim().toString()).where((e) => e.isNotEmpty).toList();
            }
          }
        });
      }
    } catch (e) {
      print("MechanicServiceDashboard: Error loading profile: $e");
    }
  }
  
  Future<void> _updateMechanicStatus(String newStatus) async {
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId == null) return;
    
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
    if (id == null) return;
    
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicEndpoint}/$id/status"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": newStatus}),
      );
      
      if (response.statusCode == 200) {
        setState(() => _mechanicStatus = newStatus);
        _showSnackBar('Status updated to $newStatus', const Color(0xFF10B981));
      } else {
        _showSnackBar('Failed to update status', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }
  
  Future<void> _fetchBookings() async {
    setState(() => _isLoadingBookings = true);
    
    try {
      // Get mechanic ID from profile data
      final mechanicId = widget.mechanicData?['id'] ?? 1;
      print("Mechanic Dashboard: Fetching requests for mechanic ID: $mechanicId");
      print("API URL: ${ApiConfig.mechanicRequestsEndpoint}/mechanic/$mechanicId/pending");
      
      final response = await http.get(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/mechanic/$mechanicId/pending"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print("Mechanic Dashboard: Received ${data.length} pending requests");
        
        setState(() {
          _bookings = data.map((request) {
            // Convert backend status (PENDING) to title case (Pending) for UI
            String status = request['status'] ?? 'PENDING';
            status = status[0].toUpperCase() + status.substring(1).toLowerCase();
            
            final lat = request['latitude'];
            final lng = request['longitude'];
            final locStr = request['address'] ?? request['location'] ?? 
                (lat != null && lng != null ? '${lat}, $lng' : 'Location not shared');
            return {
              'id': request['id'],
              'customerName': request['customerName'] ?? 'Unknown',
              'customerPhone': request['customerPhone'] ?? 'Not provided',
              'service': request['serviceType'] ?? 'General Service',
              'vehicle': request['vehicle'] ?? 'Customer Vehicle',
              'location': locStr.toString(),
              'latitude': lat,
              'longitude': lng,
              'date': request['createdAt']?.substring(0, 10) ?? 'Today',
              'time': request['createdAt']?.substring(11, 16) ?? 'Now',
              'status': status,
              'amount': '₹${request['amount'] ?? 50}',
              'description': request['description'] ?? 'Service request',
              'email': request['customerEmail'] ?? '',
              'distanceKm': request['distanceKm'],
            };
          }).toList();
        });
        
        print("Mechanic Dashboard: Loaded ${_bookings.length} bookings successfully");
      } else {
        print("Mechanic Dashboard: Failed to fetch requests - Status ${response.statusCode}");
        // Fallback to empty list if API fails
        setState(() {
          _bookings = [];
        });
      }
    } catch (e) {
      print("Mechanic Dashboard: Exception - $e");
      setState(() {
        _bookings = [];
      });
    } finally {
      setState(() => _isLoadingBookings = false);
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9E6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF111111),
        title: Text(
          (_mechanicProfile['shopName'] ?? _mechanicProfile['shop_name'] ?? 'Service Provider').toString(),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          // Status dropdown
          _buildStatusDropdown(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildOverviewTab(),
          _buildFloatingHelpBot(),
        ],
      ),
    );
  }

  Widget _buildFloatingHelpBot() {
    final email = (_mechanicProfile['email'] ?? widget.mechanicData?['email'] ?? '').toString();
    return Positioned(
      right: 16,
      bottom: 24,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: 0.95 + 0.15 * _pulseAnimation.value,
          child: child,
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MechanicHelpChatPage(mechanicEmail: email),
              ),
            );
          },
          child: _buildCuteRobotBot(),
        ),
      ),
    );
  }

  /// Cute robot appearance for the help bot
  Widget _buildCuteRobotBot() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFBBF24).withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Antenna
          Positioned(
            top: -6,
            child: Container(
              width: 3,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            top: -10,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Face
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Eyes
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _robotEye(),
                  const SizedBox(width: 10),
                  _robotEye(),
                ],
              ),
              const SizedBox(height: 2),
              // Smile - simple arc
              SizedBox(
                width: 18,
                height: 6,
                child: CustomPaint(
                  painter: _SmilePainter(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _robotEye() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2)],
      ),
      child: Center(
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
  
  Widget _buildStatusDropdown() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _mechanicStatus,
          dropdownColor: const Color(0xFF111111),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFFBBF24)),
          style: GoogleFonts.inter(
            color: const Color(0xFFFBBF24),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: ['Available', 'Busy', 'Offline'].map((status) {
            return DropdownMenuItem<String>(
              value: status,
              child: Text(status),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _mechanicStatus = value);
              _updateMechanicStatus(value);
            }
          },
        ),
      ),
    );
  }
  
  // OVERVIEW TAB
  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: () async {
        await _fetchBookings();
        _showSnackBar('Dashboard refreshed!', const Color(0xFF10B981));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => _buildProfileCard(),
            ),
            const SizedBox(height: 20),
            
            // Quick Actions Section
            _buildQuickActions(),
            const SizedBox(height: 20),
            
            // Stats Cards: Total Jobs, Pending, Today
            _buildStatsCards(),
            const SizedBox(height: 20),
            
            // Today's service & Today's earning - small boxes side by side
            _buildTodayServiceAndEarningBoxes(),
            const SizedBox(height: 20),
            
            // Earnings Overview + Service Summary (like image)
            _buildEarningsOverviewAndServiceSummary(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: () async {
        final mechanicId = widget.mechanicData?['id'];
        final id = mechanicId is int ? mechanicId : (mechanicId != null ? int.tryParse(mechanicId.toString()) : null);
        if (id == null) {
          _showSnackBar('Mechanic ID not found', Colors.orange);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicProfileEditPage(
              mechanicProfile: _mechanicProfile,
              mechanicId: id,
              onSave: (updatedProfile) {
                setState(() {
                  _mechanicProfile['name'] = updatedProfile['name'];
                  _mechanicProfile['phone'] = updatedProfile['phone'];
                  _mechanicProfile['email'] = updatedProfile['email'];
                  _mechanicProfile['specialty'] = updatedProfile['specialty'];
                  _mechanicProfile['experience'] = updatedProfile['experience'];
                  _mechanicProfile['shopAddress'] = updatedProfile['shopAddress'];
                  _mechanicProfile['latitude'] = updatedProfile['latitude'];
                  _mechanicProfile['longitude'] = updatedProfile['longitude'];
                  if (updatedProfile['profilePhotoUrl'] != null) _mechanicProfile['profilePhotoUrl'] = updatedProfile['profilePhotoUrl'];
                  if (updatedProfile['nightTimeAvailable'] != null) _mechanicProfile['nightTimeAvailable'] = updatedProfile['nightTimeAvailable'];
                });
              },
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF111111), Color(0xFFFBBF24)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withOpacity(0.35),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipOval(
              child: _mechanicProfile['profilePhotoUrl'] != null &&
                      (_mechanicProfile['profilePhotoUrl'] as String).isNotEmpty
                  ? Image.network(
                      _mechanicProfile['profilePhotoUrl'] as String,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, size: 40, color: Color(0xFF111111)),
                    )
                  : const Icon(Icons.account_circle, size: 40, color: Color(0xFF111111)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _mechanicProfile['name'],
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _mechanicProfile['specialty'],
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '${_mechanicProfile['rating']}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 16),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _mechanicStatus == 'Available' ? _pulseAnimation.value : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _mechanicStatus == 'Available'
                                  ? Colors.green
                                  : _mechanicStatus == 'Busy'
                                      ? Colors.orange
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _mechanicStatus,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  // QUICK ACTIONS
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildBookingsQuickAction(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionButton(
                'My Services',
                Icons.handyman,
                const Color(0xFFFBBF24),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MechanicServicesPage(
                        myServices: _myServices,
                        onAddService: _addService,
                        onRemoveService: _removeService,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                'Help Chat',
                Icons.chat_rounded,
                const Color(0xFF111111),
                () {
                  final email = (_mechanicProfile['email'] ?? widget.mechanicData?['email'] ?? '').toString();
                  if (email.isEmpty) {
                    _showSnackBar('Email not found', Colors.orange);
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MechanicHelpChatPage(mechanicEmail: email),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildStatsCards() {
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final todayCount = _bookings.where((b) {
      final d = (b['date'] ?? '').toString();
      return d.startsWith(todayStr) || d == todayStr;
    }).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 320 ? 6.0 : 12.0;
        return Row(
          children: [
            Expanded(child: _buildStatCard('Total Jobs', '${_mechanicProfile['completedJobs']}', Icons.check_circle_outline, const Color(0xFF10B981))),
            SizedBox(width: gap),
            Expanded(child: _buildStatCard('Pending', '${_bookings.where((b) => b['status'] == 'Pending').length}', Icons.pending_actions, const Color(0xFFF59E0B))),
            SizedBox(width: gap),
            Expanded(child: _buildStatCard('Today', '$todayCount', Icons.today, const Color(0xFFFBBF24))),
          ],
        );
      },
    );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTodayServiceAndEarningBoxes() {
    final todayStr = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
    final todayBookings = _bookings.where((b) => (b['date'] ?? '').toString().startsWith(todayStr) || (b['date'] ?? '') == todayStr).toList();
    final todayCount = todayBookings.length;
    double todayEarnings = 0;
    for (final b in todayBookings) {
      final amt = b['amount'];
      if (amt != null) {
        if (amt is num) {
          todayEarnings += amt.toDouble();
        } else {
          final parsed = double.tryParse(amt.toString().replaceAll(RegExp(r'[^0-9.]'), ''));
          if (parsed != null) todayEarnings += parsed;
        }
      }
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 320;
        final padding = isNarrow ? 10.0 : 14.0;
        final gap = isNarrow ? 8.0 : 12.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isNarrow ? 6 : 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.build_circle_outlined, color: const Color(0xFF111111), size: isNarrow ? 18 : 20),
                        ),
                        SizedBox(width: isNarrow ? 6 : 10),
                        Flexible(
                          child: Text(
                            'Today\'s service',
                            style: GoogleFonts.inter(
                              fontSize: isNarrow ? 11 : 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$todayCount',
                      style: GoogleFonts.outfit(
                        fontSize: isNarrow ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(padding),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isNarrow ? 6 : 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.currency_rupee, color: const Color(0xFF10B981), size: isNarrow ? 18 : 20),
                        ),
                        SizedBox(width: isNarrow ? 6 : 10),
                        Flexible(
                          child: Text(
                            'Today\'s earning',
                            style: GoogleFonts.inter(
                              fontSize: isNarrow ? 11 : 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '₹${todayEarnings.toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontSize: isNarrow ? 18 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEarningsOverviewAndServiceSummary() {
    // Mock weekly earnings (Sun-Sat) - in real app would come from API
    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final primaryEarnings = [1200.0, 950.0, 800.0, 1500.0, 2200.0, 1800.0, 1100.0];
    final secondaryEarnings = [300.0, 250.0, 200.0, 0.0, 400.0, 350.0, 280.0];
    final maxEarning = [...primaryEarnings, ...secondaryEarnings].fold<double>(0, (a, b) => a > b ? a : b);
    final completedJobs = _mechanicProfile['completedJobs'] is int
        ? _mechanicProfile['completedJobs'] as int
        : int.tryParse(_mechanicProfile['completedJobs']?.toString() ?? '0') ?? 0;
    final pendingCount = _bookings.where((b) => b['status'] == 'Pending').length;
    final totalJobs = completedJobs + pendingCount;
    const cancelledCount = 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 350;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: isNarrow ? 4 : 5,
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Earnings Overview',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, chartConstraints) {
                        final cellWidth = chartConstraints.maxWidth / 7;
                        final barW = (cellWidth * 0.35).clamp(3.0, 10.0);
                        const barHeight = 95.0;
                        return SizedBox(
                          height: 120,
                          child: Stack(
                            children: [
                              // 7 horizontal grid lines
                              Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: List.generate(7, (_) => Container(
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.15),
                                )),
                              ),
                              Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(7, (i) {
                              final primary = primaryEarnings[i];
                              final secondary = secondaryEarnings[i];
                              final ph = maxEarning > 0 ? (primary / maxEarning) * barHeight : 0.0;
                              final sh = maxEarning > 0 ? (secondary / maxEarning) * barHeight : 0.0;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (secondary > 0)
                                            Container(
                                              width: barW,
                                              height: sh,
                                              margin: const EdgeInsets.only(right: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withOpacity(0.6),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          Container(
                                            width: barW,
                                            height: ph,
                                            decoration: BoxDecoration(
                                              color: i == 5
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFFFBBF24),
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        weekDays[i],
                                        style: GoogleFonts.inter(
                                          fontSize: 7,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Service Summary',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildSummaryRow('Total Jobs:', '$totalJobs'),
                    _buildSummaryRow('Completed:', '$completedJobs'),
                    _buildSummaryRow('Cancelled:', '$cancelledCount'),
                    _buildSummaryRow('Pending:', '$pendingCount', highlight: true),
                  ],
                ),
              ),
            ],
          );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool highlight = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: highlight ? Colors.grey.withOpacity(0.08) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBookingsQuickAction() {
    final onTap = () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MechanicBookingsPage(
            bookings: _bookings,
            onAccept: _acceptBooking,
            onReject: _rejectBooking,
            onComplete: _completeBooking,
          ),
        ),
      );
    };
    final button = _buildQuickActionButton(
      'Bookings',
      Icons.calendar_month,
      const Color(0xFF111111),
      onTap,
    );
    if (_bookings.isEmpty) return button;
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) => Transform.scale(
        scale: 0.92 + 0.16 * _pulseAnimation.value,
        child: child,
      ),
      child: button,
    );
  }
  
  Widget _buildQuickActionButton(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // BOOKING ACTIONS
  Future<void> _acceptBooking(Map<String, dynamic> booking) async {
    try {
      print("Accepting booking ID: ${booking['id']}");
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/${booking['id']}/accept"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        setState(() {
          booking['status'] = 'Accepted';
        });
        _showSnackBar('Booking accepted! Customer has been notified.', const Color(0xFF10B981));
        print("✅ Booking ${booking['id']} accepted successfully");
      } else {
        print("❌ Failed to accept booking: ${response.statusCode}");
        _showSnackBar('Failed to accept booking. Please try again.', Colors.red);
      }
    } catch (e) {
      print("❌ Error accepting booking: $e");
      _showSnackBar('Network error. Please try again.', Colors.red);
    }
  }
  
  Future<void> _rejectBooking(Map<String, dynamic> booking) async {
    try {
      print("Rejecting booking ID: ${booking['id']}");
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/${booking['id']}/reject"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        setState(() {
          _bookings.remove(booking);
        });
        _showSnackBar('Booking declined.', Colors.orange);
        print("✅ Booking ${booking['id']} rejected successfully");
      } else {
        print("❌ Failed to reject booking: ${response.statusCode}");
        _showSnackBar('Failed to decline booking. Please try again.', Colors.red);
      }
    } catch (e) {
      print("❌ Error rejecting booking: $e");
      _showSnackBar('Network error. Please try again.', Colors.red);
    }
  }
  
  Future<void> _completeBooking(Map<String, dynamic> booking) async {
    try {
      print("Completing booking ID: ${booking['id']}");
      final response = await http.put(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/${booking['id']}/complete"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        setState(() {
          booking['status'] = 'Completed';
          _mechanicProfile['completedJobs']++;
        });
        _showSnackBar('Job marked as completed! Payment will be processed.', const Color(0xFF10B981));
        print("✅ Booking ${booking['id']} completed successfully");
      } else {
        print("❌ Failed to complete booking: ${response.statusCode}");
        _showSnackBar('Failed to complete booking. Please try again.', Colors.red);
      }
    } catch (e) {
      print("❌ Error completing booking: $e");
      _showSnackBar('Network error. Please try again.', Colors.red);
    }
  }
  
  // SERVICE MANAGEMENT - real-time DB update
  Future<void> _addService(String service) async {
    if (_myServices.contains(service)) return;
    setState(() => _myServices.add(service));
    await _updateServicesInDb();
  }
  
  Future<void> _removeService(String service) async {
    setState(() => _myServices.remove(service));
    await _updateServicesInDb();
  }
  
  Future<void> _updateServicesInDb() async {
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId == null) return;
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
    if (id == null) return;
    try {
      final servicesStr = _myServices.join(',');
      final res = await http.put(
        Uri.parse('${ApiConfig.mechanicEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'services': servicesStr}),
      );
      if (res.statusCode == 200) {
        if (mounted) _showSnackBar('Services saved', const Color(0xFF10B981));
      } else {
        _showSnackBar('Failed to update services', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    // Smile: corners up, center down (curve bulges downward)
    path.moveTo(0, 1);
    path.quadraticBezierTo(size.width / 2, size.height, size.width, 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

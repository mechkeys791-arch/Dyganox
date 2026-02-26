import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../services/api_config.dart';
import '../../services/fcm_notification_service.dart';
import 'package:geolocator/geolocator.dart';
import 'mechanic_bookings_page.dart';
import 'mechanic_services_page.dart';
import 'mechanic_profile_edit_page.dart';
import 'mechanic_help_chat_page.dart';
import 'mechanic_suspended_page.dart';
import 'mechanic_request_detail_book_flow_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MechanicServiceDashboard extends StatefulWidget {
  final Map<String, dynamic>? mechanicData;
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
  List<dynamic> _nearbyBroadcastRequests = [];
  bool _isLoadingNearby = false;
  List<String> _myServices = ['General Repair', 'Engine Service', 'Electrical Works'];
  // ignore: unused_field
  bool _isLoadingBookings = false;
  
  // Auto-refresh timer
  Timer? _refreshTimer;
  
  // Wallet (from API) - kept for potential future use
  // ignore: unused_field
  double _walletBalance = 0.0;
  // ignore: unused_field
  double _walletTotalEarned = 0.0;
  // ignore: unused_field
  static const int _minWithdraw = 100;
  // ignore: unused_field
  int _completedJobs = 0;
  // ignore: unused_field
  List<Map<String, dynamic>> _transactions = [];
  
  // Mechanic profile (from API / widget)
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
    _fetchWallet();
    _fetchNearbyBroadcastRequests();

    // Register FCM token and save mechanic ID for notification Accept/View (accept-by/mechanicId, open Book flow detail)
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId != null) {
      final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
      if (id != null) {
        FcmNotificationService.registerMechanicToken(id);
        FcmNotificationService.saveMechanicId(id);
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('mechanic_id', id);
        });
      }
    }

    // When request FCM arrives in foreground, show bottom sheet (pop up from bottom)
    FcmNotificationService.onMechanicRequestInForeground = _showRequestBottomSheet;

    // When launched from notification tap: show same popup as foreground FCM (then View opens detail)
    final openId = widget.openRequestIdAfterMount;
    if (openId != null && openId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final mid = widget.mechanicData?['id'];
        final id = mid is int ? mid : int.tryParse(mid?.toString() ?? '0');
        if (id != null && id > 0) {
          _showRequestBottomSheet(openId);
        }
      });
    }

    // Auto-refresh bookings every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchBookings();
      _loadMechanicProfileFromApi();
    });
  }

  @override
  void dispose() {
    FcmNotificationService.onMechanicRequestInForeground = null;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _showRequestBottomSheet(String requestId) {
    if (!mounted) return;
    final mechanicId = widget.mechanicData?['id'];
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId?.toString() ?? '');
    if (id == null || id == 0) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFFBBF24).withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text('New request', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24))),
              const SizedBox(height: 8),
              Text('A customer has requested your service.', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    final reqId = int.tryParse(requestId) ?? 0;
                    if (reqId > 0) {
                      Navigator.push(ctx, MaterialPageRoute(
                        builder: (_) => MechanicRequestDetailBookFlowPage(requestId: reqId, mechanicId: id),
                      ));
                    }
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('View problem'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFBBF24),
                    foregroundColor: const Color(0xFF111111),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        _showSnackBar('Status updated to $newStatus', const Color(0xFFFBBF24));
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
            // Build vehicle string from make, model, plate (same as user provided)
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
              'date': request['createdAt']?.substring(0, 10) ?? 'Today',
              'time': request['createdAt']?.substring(11, 16) ?? 'Now',
              'status': status,
              'amount': '₹${request['amount'] ?? 50}',
              'description': request['description'] ?? '',
              'comment': request['comment'] ?? '',
              'diagnosticAnswers': request['diagnosticAnswers'],
              'photoUrls': request['photoUrls'],
              'email': request['customerEmail'] ?? '',
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
  
  Future<void> _fetchNearbyBroadcastRequests() async {
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId == null) return;
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
    if (id == null) return;
    setState(() => _isLoadingNearby = true);
    try {
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {}
      final lat = pos?.latitude ?? 0.0;
      final lng = pos?.longitude ?? 0.0;
      final url = Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/nearby-for-mechanic').replace(
        queryParameters: {'mechanicId': id.toString(), 'lat': lat.toString(), 'lng': lng.toString()},
      );
      final r = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (r.statusCode == 200 && mounted) {
        final list = jsonDecode(r.body) as List;
        setState(() {
          _nearbyBroadcastRequests = list;
          _isLoadingNearby = false;
        });
      } else {
        setState(() { _nearbyBroadcastRequests = []; _isLoadingNearby = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _nearbyBroadcastRequests = []; _isLoadingNearby = false; });
    }
  }

  Future<void> _fetchWallet() async {
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId == null) return;
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
    if (id == null) return;
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicWalletEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final w = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() {
          _walletBalance = (w['balance'] as num?)?.toDouble() ?? 0.0;
          _walletTotalEarned = (w['totalEarned'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print('MechanicServiceDashboard: Wallet fetch error: $e');
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
  
  Widget _buildStatusDropdown() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _mechanicStatus,
          dropdownColor: const Color(0xFF111111),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: GoogleFonts.inter(
            color: Colors.white,
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
        await _fetchNearbyBroadcastRequests();
        await _fetchWallet();
        _showSnackBar('Dashboard refreshed!', const Color(0xFFFBBF24));
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
            
            // New requests near you (Book Mechanic flow - 5 min window)
            if (_nearbyBroadcastRequests.isNotEmpty) ...[
              _buildNearbyRequestsCard(),
              const SizedBox(height: 20),
            ],
            
            // Stats Cards
            _buildStatsCards(),
            const SizedBox(height: 20),
            
            // Today's Schedule
            _buildTodaySchedule(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: () async {
        final mid = widget.mechanicData?['id'];
        final mechanicId = mid is int ? mid : (int.tryParse(mid?.toString() ?? '') ?? 0);
        if (mechanicId == 0) {
          _showSnackBar('Unable to load mechanic profile', Colors.orange);
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicProfileEditPage(
              mechanicProfile: _mechanicProfile,
              mechanicId: mechanicId,
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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFBBF24).withOpacity(0.3),
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
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, size: 40, color: Color(0xFFFBBF24)),
                    )
                  : const Icon(Icons.account_circle, size: 40, color: Color(0xFFFBBF24)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_mechanicProfile['name'] ?? 'Mechanic').toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (_mechanicProfile['specialty'] ?? 'General Repair').toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.touch_app, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_mechanicProfile['rating'] ?? '0'}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _mechanicStatus == 'Available' ? _pulseAnimation.value : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _mechanicStatus == 'Available'
                                  ? const Color(0xFFFBBF24)
                                  : _mechanicStatus == 'Busy'
                                      ? Colors.orange
                                      : Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _mechanicStatus,
                              style: GoogleFonts.inter(
                                color: _mechanicStatus == 'Available' ? const Color(0xFF111111) : Colors.white,
                                fontSize: 11,
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
          // Edit indicator
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit, color: Colors.white, size: 20),
          ),
        ],
        ),
      ),
    );
  }
  
  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Jobs',
            '${_mechanicProfile['completedJobs']}',
            Icons.check_circle_outline,
            const Color(0xFFFBBF24),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            '${_bookings.where((b) => b['status'] == 'Pending').length}',
            Icons.pending_actions,
            const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Today',
            '${_bookings.where((b) => b['date'] == '2024-01-15').length}',
            Icons.today,
            const Color(0xFF111111),
          ),
        ),
      ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTodaySchedule() {
    final todayBookings = _bookings.where((b) => b['date'] == '2024-01-15').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Schedule',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (todayBookings.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'No bookings for today',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ...todayBookings.map((booking) => _buildMiniBookingCard(booking)),
      ],
    );
  }
  
  Widget _buildMiniBookingCard(Map<String, dynamic> booking) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: booking['status'] == 'Accepted' 
            ? const Color(0xFFFBBF24) 
            : const Color(0xFFF59E0B),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF111111).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.car_repair, color: Color(0xFFFBBF24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (booking['customerName'] ?? 'Customer').toString(),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${booking['service'] ?? '—'} • ${booking['time'] ?? '—'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: booking['status'] == 'Accepted'
                  ? const Color(0xFFFBBF24).withOpacity(0.1)
                  : const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              booking['status'],
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: booking['status'] == 'Accepted'
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
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
              child: _bookings.isNotEmpty
                  ? AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: _buildQuickActionButton(
                        'Bookings',
                        Icons.calendar_month,
                        const Color(0xFF111111),
                        () {
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
                        },
                      ),
                    )
                  : _buildQuickActionButton(
                      'Bookings',
                      Icons.calendar_month,
                      const Color(0xFF111111),
                      () {
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
                },
              ),
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
                const Color(0xFFFBBF24),
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

  Widget _buildFloatingHelpBot() {
    final email = (_mechanicProfile['email'] ?? widget.mechanicData?['email'] ?? '').toString();
    if (email.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: 16,
      bottom: 24,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MechanicHelpChatPage(mechanicEmail: email),
              ),
            );
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111111), Color(0xFFFBBF24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CustomPaint(
              painter: _CuteRobotBotPainter(),
              size: const Size(56, 56),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNearbyRequestsCard() {
    final mechanicId = widget.mechanicData?['id'];
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId?.toString() ?? '0');
    if (id == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'New requests near you',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_nearbyBroadcastRequests.length}',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFFFBBF24)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingNearby)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else
            ...(_nearbyBroadcastRequests.map((req) {
              final r = req as Map<String, dynamic>;
              final requestId = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '0') ?? 0;
              final problem = r['problemCategory'] ?? r['serviceType'] ?? 'Service';
              final desc = r['description'] ?? '';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MechanicRequestDetailBookFlowPage(
                            requestId: requestId,
                            mechanicId: id,
                            mechanicLat: null,
                            mechanicLng: null,
                          ),
                        ),
                      ).then((_) => _fetchNearbyBroadcastRequests());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.build_circle, color: Color(0xFFFBBF24), size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(problem.toString(), style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                                if (desc.isNotEmpty) Text(desc, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            })),
        ],
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
        _showSnackBar('Booking accepted! Customer has been notified.', const Color(0xFFFBBF24));
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
        _showSnackBar('Job marked as completed! Payment will be processed.', const Color(0xFFFBBF24));
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
  
  // SERVICE MANAGEMENT
  void _addService(String service) {
    setState(() {
      if (!_myServices.contains(service)) {
        _myServices.add(service);
      }
    });
  }
  
  void _removeService(String service) {
    setState(() {
      _myServices.remove(service);
    });
  }
}

/// Cute robot bot icon for floating help button (eyes, antenna, smile).
class _CuteRobotBotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Antenna
    final antennaPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx - 6, cy - 20), Offset(cx - 12, cy - 28), antennaPaint);
    canvas.drawLine(Offset(cx + 6, cy - 20), Offset(cx + 12, cy - 28), antennaPaint);
    canvas.drawCircle(Offset(cx - 12, cy - 28), 3, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + 12, cy - 28), 3, Paint()..color = Colors.white);

    // Eyes
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - 8, cy - 6), 5, eyePaint);
    canvas.drawCircle(Offset(cx + 8, cy - 6), 5, eyePaint);
    final pupilPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawCircle(Offset(cx - 8, cy - 6), 2, pupilPaint);
    canvas.drawCircle(Offset(cx + 8, cy - 6), 2, pupilPaint);

    // Smile (curved mouth)
    final mouthPath = Path();
    mouthPath.moveTo(cx - 10, cy + 8);
    mouthPath.quadraticBezierTo(cx, cy + 16, cx + 10, cy + 8);
    final mouthPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(mouthPath, mouthPaint);

    // Chat bubble hint
    canvas.drawCircle(Offset(cx + 18, cy - 18), 4, Paint()..color = Colors.white.withOpacity(0.9));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../services/api_config.dart';
import '../../services/app_remote_service.dart';
import '../../services/fcm_notification_service.dart';
import '../../widgets/app_logo_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'mechanic_bookings_page.dart';
import 'mechanic_services_page.dart';
import 'mechanic_profile_edit_page.dart';
import 'mechanic_profile_page.dart';
import 'mechanic_help_chat_page.dart';
import 'mechanic_suspended_page.dart';
import 'mechanic_request_detail_book_flow_page.dart';
import 'mechanic_login_request_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../services/cognito_service.dart';

class MechanicServiceDashboard extends StatefulWidget {
  final Map<String, dynamic>? mechanicData;
  /// If set, after mount the dashboard will open this request (e.g. from FCM Accept).
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
  
  Timer? _refreshTimer;
  Timer? _bookingsTimer;
  
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
  
  String? _appLogoUrl;

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
    _loadBranding();

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

    // When launched from notification tap (View or Accept): show "new booking" popup from bottom
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

    // Auto-refresh: nearby requests every 8 sec (for multi-device), bookings every 30 sec
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchNearbyBroadcastRequests());
    _bookingsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchBookings();
      _loadMechanicProfileFromApi();
    });
  } 

  @override
  void dispose() {
    FcmNotificationService.onMechanicRequestInForeground = null;
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _bookingsTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadBranding() async {
    final config = await AppRemoteService.getAppBrandingConfig();
    if (!mounted) return;
    setState(() => _appLogoUrl = config?['appLogoUrl']?.toString());
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
                    backgroundColor: AppColors.burntOrange,
                    foregroundColor: AppColors.cream,
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
          _mechanicProfile['serviceCategories'] = m['serviceCategories']?.toString();
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
        _showSnackBar('Status updated to $newStatus', AppColors.warmAmber);
      } else {
        _showSnackBar('Failed to update status', Colors.orange);
      }
    } catch (e) {
      _showSnackBar('Error: $e', Colors.red);
    }
  }
  
  Map<String, dynamic> _requestToBooking(dynamic request) {
    final rawStatus = (request['status'] ?? 'PENDING').toString().toUpperCase();
    String status;
    if (rawStatus == 'PENDING_BROADCAST') status = 'Pending';
    else if (rawStatus == 'IN_PROGRESS' || rawStatus == 'INPROGRESS') status = 'In progress';
    else status = rawStatus.isNotEmpty ? rawStatus[0] + rawStatus.substring(1).toLowerCase() : 'Pending';
    final make = request['vehicleMakeName']?.toString() ?? '';
    final model = request['vehicleModelName']?.toString() ?? '';
    final plate = request['vehiclePlateNumber']?.toString() ?? '';
    final vehicleStr = '${make} ${model}'.trim();
    final vehicle = vehicleStr.isNotEmpty ? '$vehicleStr${plate.isNotEmpty ? ' ($plate)' : ''}' : (plate.isNotEmpty ? plate : 'Customer Vehicle');
    final lat = request['latitude']?.toString() ?? '';
    final lng = request['longitude']?.toString() ?? '';
    final reqTime = (request['requestTime'] ?? request['createdAt'])?.toString() ?? '';
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
      'location': lat.isNotEmpty && lng.isNotEmpty ? '$lat, $lng' : 'Location',
      'date': reqTime.length >= 10 ? reqTime.substring(0, 10) : 'Today',
      'time': reqTime.length >= 16 ? reqTime.substring(11, 16) : 'Now',
      'status': status,
      'amount': '₹${request['amount'] ?? 50}',
      'description': request['description'] ?? '',
      'comment': request['comment'] ?? '',
      'diagnosticAnswers': request['diagnosticAnswers'],
      'photoUrls': request['photoUrls'],
      'email': request['customerEmail'] ?? '',
      'isBroadcast': rawStatus == 'PENDING_BROADCAST',
    };
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoadingBookings = true);
    final mechanicId = widget.mechanicData?['id'] ?? 1;
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
    if (id == null) {
      setState(() { _bookings = []; _isLoadingBookings = false; });
      return;
    }
    try {
      await _fetchNearbyBroadcastRequests();
      final response = await http.get(
        Uri.parse("${ApiConfig.mechanicRequestsEndpoint}/mechanic/$id"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        List<Map<String, dynamic>> apiBookings = List.from(data.map((r) => Map<String, dynamic>.from(_requestToBooking(r))));
        final apiIds = apiBookings.map((b) => b['id'].toString()).toSet();
        for (final req in _nearbyBroadcastRequests) {
          final r = req as Map<String, dynamic>;
          final rid = r['id']?.toString();
          if (rid != null && !apiIds.contains(rid)) {
            apiBookings.insert(0, Map<String, dynamic>.from(_requestToBooking(r)));
          }
        }
        setState(() {
          _bookings = apiBookings;
        });
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
      // Update mechanic's current location so broadcast can reach them (Ola-style)
      if (pos != null) {
        http.put(
          Uri.parse('${ApiConfig.mechanicEndpoint}/$id/location'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'currentLatitude': lat.toString(), 'currentLongitude': lng.toString()}),
        ).ignore();
      }
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

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirm != true) return;
    await CognitoService.signOutMechanic();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mechanic_id');
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const MechanicLoginRequestPage()),
      (route) => false,
    );
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
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.burntOrange,
        leading: Padding(
          padding: const EdgeInsets.all(6.0),
          child: AppLogoWidget(
            logoUrl: _appLogoUrl,
            size: 52,
            fallbackIconColor: Colors.white,
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
          _buildStatusDropdown(),
          _buildProfileMenu(),
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
          dropdownColor: AppColors.burntOrange,
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
        _showSnackBar('Dashboard refreshed!', AppColors.warmAmber);
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
            _buildEarningsSummary(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.burntOrange, AppColors.warmBrown],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.burntOrange.withOpacity(0.3),
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
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_circle, size: 40, color: AppColors.burntOrange),
                    )
                  : const Icon(Icons.account_circle, size: 40, color: AppColors.burntOrange),
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
                Text(
                  (_mechanicProfile['specialty'] ?? 'General Repair').toString(),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
        ],
      ),
    );
  }

  Future<void> _openProfileEdit() async {
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
  }

  Widget _buildProfileMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 26),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'notifications':
            // Toggle is handled in the menu item (state in prefs)
            setState(() {});
            break;
          case 'profile':
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MechanicProfilePage(
                  mechanicData: widget.mechanicData ?? {},
                  mechanicProfile: Map<String, dynamic>.from(_mechanicProfile),
                  initialBookings: _bookings,
                  onProfileUpdated: () {
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
            if (mounted) {
              _fetchBookings();
              setState(() {});
            }
            break;
          case 'approved':
            await Navigator.push(
              context,
                MaterialPageRoute(
                  builder: (context) => MechanicBookingsPage(
                    bookings: _bookings,
                    onAccept: _acceptBooking,
                    onReject: _rejectBooking,
                    onComplete: _completeBooking,
                    onReached: _reachedBooking,
                    highlightRequestId: null,
                    initialFilter: 'Accepted',
                    mechanicId: (widget.mechanicData?['id'] is int ? widget.mechanicData!['id'] : int.tryParse(widget.mechanicData?['id']?.toString() ?? '')),
                  ),
                ),
            );
            if (mounted) _fetchBookings();
            break;
          case 'rejected':
            await Navigator.push(
              context,
                MaterialPageRoute(
                  builder: (context) => MechanicBookingsPage(
                    bookings: _bookings,
                    onAccept: _acceptBooking,
                    onReject: _rejectBooking,
                    onComplete: _completeBooking,
                    onReached: _reachedBooking,
                    highlightRequestId: null,
                    initialFilter: 'Rejected',
                    mechanicId: (widget.mechanicData?['id'] is int ? widget.mechanicData!['id'] : int.tryParse(widget.mechanicData?['id']?.toString() ?? '')),
                  ),
                ),
            );
            if (mounted) _fetchBookings();
            break;
          case 'pending':
            await Navigator.push(
              context,
                MaterialPageRoute(
                  builder: (context) => MechanicBookingsPage(
                    bookings: _bookings,
                    onAccept: _acceptBooking,
                    onReject: _rejectBooking,
                    onComplete: _completeBooking,
                    onReached: _reachedBooking,
                    highlightRequestId: null,
                    initialFilter: 'Pending',
                    mechanicId: (widget.mechanicData?['id'] is int ? widget.mechanicData!['id'] : int.tryParse(widget.mechanicData?['id']?.toString() ?? '')),
                  ),
                ),
            );
            if (mounted) _fetchBookings();
            break;
          case 'profile_edit':
            await _openProfileEdit();
            break;
          case 'logout':
            _logout();
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person, color: AppColors.burntOrange, size: 22),
              const SizedBox(width: 12),
              Text('Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'notifications',
          enabled: false,
          child: StatefulBuilder(
            builder: (context, setMenuState) {
              return FutureBuilder<bool>(
                future: FcmNotificationService.areNotificationsEnabled(),
                builder: (context, snapshot) {
                  final enabled = snapshot.data ?? true;
                  return Row(
                    children: [
                      Icon(enabled ? Icons.notifications_active : Icons.notifications_off, color: AppColors.burntOrange, size: 22),
                      const SizedBox(width: 12),
                      Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                        value: enabled,
                        onChanged: (v) async {
                          await FcmNotificationService.setNotificationsEnabled(v);
                          setMenuState(() {});
                          setState(() {});
                          _showSnackBar(v ? 'Notifications on' : 'Notifications off', v ? Colors.green : Colors.grey);
                        },
                        activeColor: AppColors.burntOrange,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'pending',
          child: Row(
            children: [
              Icon(Icons.pending_actions, color: AppColors.burntOrange, size: 22),
              const SizedBox(width: 12),
              Text('Pending bookings', style: GoogleFonts.outfit()),
              const SizedBox(width: 8),
              Text('${_bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'pending').length}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'approved',
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.burntOrange, size: 22),
              const SizedBox(width: 12),
              Text('Approved bookings', style: GoogleFonts.outfit()),
              const SizedBox(width: 8),
              Text('${_bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'accepted').length}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'rejected',
          child: Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.burntOrange, size: 22),
              const SizedBox(width: 12),
              Text('Rejected bookings', style: GoogleFonts.outfit()),
              const SizedBox(width: 8),
              Text('${_bookings.where((b) => (b['status'] ?? '').toString().toLowerCase() == 'rejected').length}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'profile_edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: AppColors.burntOrange, size: 22),
              const SizedBox(width: 12),
              Text('Edit profile', style: GoogleFonts.outfit()),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: AppColors.burntOrange, size: 22),
              const SizedBox(width: 12),
              Text('Logout', style: GoogleFonts.outfit()),
            ],
          ),
        ),
      ],
    );
  }
  
  // ignore: unused_element
  Widget _buildShopAndServicesCard() {
    final shopName = (_mechanicProfile['shopName'] ?? _mechanicProfile['shop_name'] ?? '').toString();
    final shopAddr = (_mechanicProfile['shopAddress'] ?? _mechanicProfile['shop_address'] ?? '').toString();
    final specialty = (_mechanicProfile['specialty'] ?? '').toString();
    final experience = (_mechanicProfile['experience'] ?? '').toString();
    final opening = (_mechanicProfile['openingTime'] ?? '').toString();
    final closing = (_mechanicProfile['closingTime'] ?? '').toString();
    final workingDays = (_mechanicProfile['workingDays'] ?? '').toString();
    final nightAvailable = _mechanicProfile['nightTimeAvailable'] == true;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
        border: Border.all(color: AppColors.burntOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.burntOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.store, color: AppColors.burntOrange, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'My Shop & Info',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (shopName.isNotEmpty)
            _buildInfoRow(Icons.storefront, 'Shop', shopName),
          if (shopAddr.isNotEmpty)
            _buildInfoRow(Icons.location_on, 'Address', shopAddr),
          if (specialty.isNotEmpty)
            _buildInfoRow(Icons.build_circle, 'Specialty', specialty),
          if (experience.isNotEmpty)
            _buildInfoRow(Icons.timeline, 'Experience', experience),
          if (opening.isNotEmpty || closing.isNotEmpty)
            _buildInfoRow(Icons.access_time, 'Hours', 
              opening.isNotEmpty && closing.isNotEmpty 
                ? '$opening - $closing' 
                : (opening.isNotEmpty ? opening : closing)),
          if (workingDays.isNotEmpty)
            _buildInfoRow(Icons.calendar_today, 'Working Days', workingDays.replaceAll(',', ', ')),
          if (nightAvailable)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warmBrown.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.nightlight_round, color: AppColors.warmBrown, size: 18),
                  const SizedBox(width: 8),
                  Text('24/7 Night service available', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warmBrown,
                  )),
                ],
              ),
            ),
          if (_myServices.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Services Offered', style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700],
            )),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _myServices.map((s) => Chip(
                label: Text(s, style: GoogleFonts.inter(fontSize: 12)),
                backgroundColor: AppColors.warmAmber.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 14, color: Colors.black87)),
              ],
            ),
          ),
        ],
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
            AppColors.warmAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            '${_bookings.where((b) => b['status'] == 'Pending').length}',
            Icons.pending_actions,
            AppColors.warmAmber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Today',
            '${_bookings.where((b) => b['date'] == '2024-01-15').length}',
            Icons.today,
            AppColors.burntOrange,
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
  
  // ignore: unused_element
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
          color: AppColors.warmAmber,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.burntOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.car_repair, color: AppColors.burntOrange),
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
              color: AppColors.warmAmber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              booking['status'],
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warmAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEarningsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.warmAmber, AppColors.warmBrown],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.warmAmber.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Earnings',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_walletBalance.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _showEarningsDetailsDialog,
            icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
            label: Text('Details', style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _walletBalance >= _minWithdraw ? _showWithdrawDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.warmBrown,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Withdraw', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Withdraw', style: GoogleFonts.outfit()),
        content: Text(
          'Balance: ₹${_walletBalance.toStringAsFixed(0)}. Min ₹$_minWithdraw to withdraw. Withdraw feature will be available soon.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }
  
  void _showEarningsDetailsDialog() {
    final progress = _minWithdraw > 0 ? (_walletBalance / _minWithdraw).clamp(0.0, 1.0) : 0.0;
    final avgPerJob = _completedJobs > 0 ? _walletTotalEarned / _completedJobs : 0.0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.warmAmber, AppColors.warmBrown],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Wallet',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Balance • Min ₹$_minWithdraw to withdraw',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₹${_walletBalance.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'of ₹$_minWithdraw to withdraw',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.white.withOpacity(0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total earned: ₹${_walletTotalEarned.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildEarningStatCard(
                          'Completed Jobs',
                          _completedJobs.toString(),
                          Icons.check_circle,
                          AppColors.warmAmber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEarningStatCard(
                          'Avg per Job',
                          '₹${avgPerJob.toStringAsFixed(0)}',
                          Icons.trending_up,
                          AppColors.burntOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Transaction History Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Icon(Icons.history, size: 20, color: AppColors.warmBrownMuted),
                      const SizedBox(width: 8),
                      Text(
                        'Transaction History',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Transaction List (real data only)
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Text(
                            'No completed jobs yet',
                            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return _buildTransactionItem(transaction);
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEarningStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.warmBrownMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCompleted = transaction['status'] == 'Completed';
    final statusColor = isCompleted ? AppColors.warmAmber : AppColors.warmAmber;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.pending,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['customerName'],
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction['service'],
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 10, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${transaction['date']} • ${transaction['time']}',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${transaction['amount'].toStringAsFixed(0)}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  transaction['paymentMethod'],
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
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
              child: _buildQuickActionButton(
                'Bookings',
                Icons.calendar_month,
                AppColors.burntOrange,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>                   MechanicBookingsPage(
                        bookings: _bookings,
                        onAccept: _acceptBooking,
                        onReject: _rejectBooking,
                        onComplete: _completeBooking,
                        onReached: _reachedBooking,
                        highlightRequestId: null,
                        mechanicId: (widget.mechanicData?['id'] is int ? widget.mechanicData!['id'] : int.tryParse(widget.mechanicData?['id']?.toString() ?? '')),
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
                AppColors.warmBrown,
                () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MechanicServicesPage(
                        myServices: _myServices,
                        onAddService: _addService,
                        onRemoveService: _removeService,
                      ),
                    ),
                  );
                  _saveMechanicServices();
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
                AppColors.warmAmber,
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
                  color: AppColors.warmAmber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_nearbyBroadcastRequests.length}',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.warmAmber),
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
                  color: AppColors.creamElevated,
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
                          const Icon(Icons.build_circle, color: AppColors.warmAmber, size: 28),
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
  
  // ignore: unused_element
  Widget _buildPerformanceMetrics() {
    final completionRate = (_mechanicProfile['completedJobs'] / 150 * 100).clamp(0, 100);
    final responseRate = 95.0; // Mock data
    final customerSatisfaction = _mechanicProfile['rating'] / 5 * 100;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Performance',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warmAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppColors.warmAmber),
                    const SizedBox(width: 4),
                    Text(
                      '+12%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.warmAmber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetricBar('Completion Rate', completionRate, AppColors.burntOrange),
          const SizedBox(height: 16),
          _buildMetricBar('Response Rate', responseRate, AppColors.warmAmber),
          const SizedBox(height: 16),
          _buildMetricBar('Customer Satisfaction', customerSatisfaction, AppColors.warmAmber),
        ],
      ),
    );
  }
  
  Widget _buildMetricBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
  
  // ignore: unused_element
  Widget _buildRecentActivity() {
    final activities = [
      {'action': 'Completed job', 'detail': 'Engine Service for Rajesh Kumar', 'time': '2 hours ago', 'icon': Icons.check_circle, 'color': AppColors.warmAmber},
      {'action': 'New booking', 'detail': 'Brake Service requested', 'time': '4 hours ago', 'icon': Icons.event, 'color': AppColors.burntOrange},
      {'action': 'Payment received', 'detail': '₹1,500 from Priya Sharma', 'time': '5 hours ago', 'icon': Icons.currency_rupee, 'color': AppColors.warmAmber},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: activities.length,
            separatorBuilder: (context, index) => Divider(
              height: 20,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              final activity = activities[index];
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (activity['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      activity['icon'] as IconData,
                      color: activity['color'] as Color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity['action'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          activity['detail'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    activity['time'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
  
  // BOOKING ACTIONS
  Future<void> _acceptBooking(Map<String, dynamic> booking) async {
    final mechanicId = widget.mechanicData?['id'];
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId?.toString() ?? '');
    if (id == null) {
      _showSnackBar('Unable to accept: mechanic not loaded.', Colors.red);
      return;
    }
    final isBroadcast = booking['isBroadcast'] == true;
    final endpoint = isBroadcast
        ? "${ApiConfig.mechanicRequestsEndpoint}/${booking['id']}/accept-by/$id"
        : "${ApiConfig.mechanicRequestsEndpoint}/${booking['id']}/accept";
    try {
      print("Accepting booking ID: ${booking['id']} (broadcast=$isBroadcast)");
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        setState(() {
          booking['status'] = 'Accepted';
        });
        _showSnackBar('Booking accepted! Customer has been notified.', AppColors.warmAmber);
        _fetchBookings();
        _fetchNearbyBroadcastRequests();
        print("✅ Booking ${booking['id']} accepted successfully");
      } else {
        final body = jsonDecode(response.body) as Map?;
        _showSnackBar(body?['error']?.toString() ?? 'Failed to accept. Request may already be taken.', Colors.red);
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
        _showSnackBar('Job marked as completed! Payment will be processed.', AppColors.warmAmber);
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

  /// Mechanic taps "I have reached" – send coordinates to backend; backend should record event, notify customer for confirmation.
  Future<void> _reachedBooking(Map<String, dynamic> booking, double latitude, double longitude) async {
    try {
      final id = booking['id'];
      print("Reached booking ID: $id at $latitude, $longitude");
      final response = await http.post(
        Uri.parse(ApiConfig.mechanicRequestReached(id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0)),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"latitude": latitude, "longitude": longitude}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          booking['status'] = 'In progress';
        });
        _showSnackBar('Location sent. Waiting for customer to confirm.', AppColors.warmAmber);
        print("✅ Reached reported for booking $id");
      } else {
        _showSnackBar('Could not send location. Please try again.', Colors.orange);
      }
    } catch (e) {
      print("Error reporting reached: $e");
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

  Future<void> _saveMechanicServices() async {
    final mechanicId = widget.mechanicData?['id'];
    if (mechanicId == null) return;
    final id = mechanicId is int ? mechanicId : int.tryParse(mechanicId.toString());
    if (id == null) return;

    final servicesStr = _myServices.join(',');
    String? categories = _mechanicProfile['serviceCategories']?.toString();
    if (categories == null) categories = 'general_checkup';

    if (_myServices.any((s) => s.toLowerCase().contains('towing'))) {
      if (categories.isEmpty) {
        categories = 'towing_service';
      } else if (!categories.toLowerCase().contains('towing_service')) {
        categories = '$categories,towing_service';
      }
    } else {
      categories = categories.replaceAll(RegExp(r',?towing_service,?'), ',').replaceAll(RegExp(r'^,+|,+$'), '');
      if (categories.isEmpty) categories = 'general_checkup';
    }

    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicEndpoint}/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'services': servicesStr, 'serviceCategories': categories}),
      );
      if (r.statusCode == 200 && mounted) {
        _showSnackBar('Services updated', AppColors.warmBrown);
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to save services', Colors.red);
    }
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

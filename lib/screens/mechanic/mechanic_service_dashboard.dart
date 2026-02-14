import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../../services/api_config.dart';
import 'mechanic_bookings_page.dart';
import 'mechanic_services_page.dart';
import 'mechanic_profile_edit_page.dart';

class MechanicServiceDashboard extends StatefulWidget {
  final Map<String, dynamic>? mechanicData;
  
  const MechanicServiceDashboard({super.key, this.mechanicData});

  @override
  State<MechanicServiceDashboard> createState() => _MechanicServiceDashboardState();
}

class _MechanicServiceDashboardState extends State<MechanicServiceDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  String _mechanicStatus = 'Available'; // Available, Busy, Offline
  List<Map<String, dynamic>> _bookings = [];
  List<String> _myServices = ['General Repair', 'Engine Service', 'Electrical Works'];
  // ignore: unused_field
  bool _isLoadingBookings = false;
  
  // Auto-refresh timer
  Timer? _refreshTimer;
  
  // Earnings data
  double _monthlyEarnings = 12500.0;
  double _monthlyGoal = 15000.0;
  int _completedJobs = 15;
  List<Map<String, dynamic>> _transactions = [
    {
      'id': 'TXN001',
      'customerName': 'Rajesh Kumar',
      'service': 'Engine Service',
      'amount': 1200.0,
      'date': '2024-11-05',
      'time': '11:00 AM',
      'status': 'Completed',
      'paymentMethod': 'UPI',
    },
    {
      'id': 'TXN002',
      'customerName': 'Anita Desai',
      'service': 'Brake Service',
      'amount': 850.0,
      'date': '2024-11-04',
      'time': '03:30 PM',
      'status': 'Completed',
      'paymentMethod': 'Cash',
    },
    {
      'id': 'TXN003',
      'customerName': 'Suresh Patel',
      'service': 'Full Car Service',
      'amount': 1500.0,
      'date': '2024-11-03',
      'time': '10:15 AM',
      'status': 'Completed',
      'paymentMethod': 'Card',
    },
    {
      'id': 'TXN004',
      'customerName': 'Meena Shah',
      'service': 'Tyre Replacement',
      'amount': 950.0,
      'date': '2024-11-02',
      'time': '02:00 PM',
      'status': 'Completed',
      'paymentMethod': 'UPI',
    },
    {
      'id': 'TXN005',
      'customerName': 'Amit Verma',
      'service': 'Electrical Works',
      'amount': 600.0,
      'date': '2024-11-01',
      'time': '04:45 PM',
      'status': 'Pending',
      'paymentMethod': 'Cash',
    },
  ];
  
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
    
    // Pulse animation for status indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Load mechanic data if provided
    if (widget.mechanicData != null) {
      _mechanicProfile['name'] = widget.mechanicData!['name'] ?? 'Mechanic';
      _mechanicProfile['specialty'] = widget.mechanicData!['specialty'] ?? 'General Repair';
      _mechanicProfile['experience'] = widget.mechanicData!['experience'] ?? '0-2 years';
      _mechanicProfile['phone'] = widget.mechanicData!['phone'] ?? '+91 98765 43210';
      _mechanicProfile['email'] = widget.mechanicData!['email'] ?? 'mechanic@example.com';
      _mechanicProfile['rating'] = widget.mechanicData!['rating'] ?? 4.5;
      _mechanicProfile['completedJobs'] = widget.mechanicData!['completedJobs'] ?? 0;
      
      // Load services from mechanic data
      if (widget.mechanicData!['services'] != null) {
        final servicesStr = widget.mechanicData!['services'].toString();
        if (servicesStr.isNotEmpty) {
          _myServices = servicesStr.split(',').map((s) => s.trim()).toList();
        }
      }
    }
    
    _fetchBookings();
    
    // Auto-refresh bookings every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchBookings();
      print("🔄 Auto-refreshing mechanic dashboard...");
    });
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
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
            
            return {
              'id': request['id'],
              'customerName': request['customerName'] ?? 'Unknown',
              'customerPhone': request['customerPhone'] ?? 'Not provided',
              'service': request['serviceType'] ?? 'General Service',
              'vehicle': 'Customer Vehicle',  // Add vehicle field to backend if needed
              'location': '${request['latitude']}, ${request['longitude']}',
              'date': request['createdAt']?.substring(0, 10) ?? 'Today',
              'time': request['createdAt']?.substring(11, 16) ?? 'Now',
              'status': status,
              'amount': '₹${request['amount'] ?? 50}',
              'description': request['description'] ?? 'Service request',
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
        backgroundColor: const Color(0xFF6366F1),
        title: Text(
          'Service Provider Dashboard',
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
      body: _buildOverviewTab(),
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
          dropdownColor: const Color(0xFF6366F1),
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
              _showSnackBar('Status updated to $value', Colors.green);
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card with animation
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => _buildProfileCard(),
            ),
            const SizedBox(height: 20),
            
            // Quick Actions Section
            _buildQuickActions(),
            const SizedBox(height: 20),
            
            // Stats Cards with staggered animation
            _buildStatsCards(),
            const SizedBox(height: 20),
            
            // Performance Metrics
            _buildPerformanceMetrics(),
            const SizedBox(height: 20),
            
            // Today's Schedule
            _buildTodaySchedule(),
            const SizedBox(height: 20),
            
            // Recent Activity
            _buildRecentActivity(),
            const SizedBox(height: 20),
            
            // Earnings Summary with trend
            _buildEarningsSummary(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MechanicProfileEditPage(
              mechanicProfile: _mechanicProfile,
              onSave: (updatedProfile) {
                setState(() {
                  _mechanicProfile['name'] = updatedProfile['name'];
                  _mechanicProfile['phone'] = updatedProfile['phone'];
                  _mechanicProfile['email'] = updatedProfile['email'];
                  _mechanicProfile['specialty'] = updatedProfile['specialty'];
                  _mechanicProfile['experience'] = updatedProfile['experience'];
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
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.3),
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
            child: const Icon(Icons.account_circle, size: 40, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mechanicProfile['name'],
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _mechanicProfile['specialty'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            'Tap to edit',
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
            const Color(0xFF10B981),
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
            const Color(0xFF6366F1),
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
            ? const Color(0xFF10B981) 
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
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.car_repair, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['customerName'],
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${booking['service']} - ${booking['time']}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: booking['status'] == 'Accepted'
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              booking['status'],
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: booking['status'] == 'Accepted'
                    ? const Color(0xFF10B981)
                    : const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEarningsSummary() {
    final progress = _monthlyEarnings / _monthlyGoal;
    final avgPerJob = _completedJobs > 0 ? _monthlyEarnings / _completedJobs : 0.0;
    
    return GestureDetector(
      onTap: _showEarningsDetailsDialog,
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
          borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This Month\'s Earnings',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.trending_up, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '+25% from last month',
                        style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '₹${_monthlyEarnings.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                        fontSize: 42,
                      fontWeight: FontWeight.bold,
                        height: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '$_completedJobs jobs completed',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        'Avg: ₹${avgPerJob.toStringAsFixed(0)}/job',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Goal: ₹${_monthlyGoal.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
            Column(
              children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
                    value: progress,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}% achieved',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 11,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'View Details',
                          style: GoogleFonts.inter(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 10,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showEarningsDetailsDialog() {
    final progress = _monthlyEarnings / _monthlyGoal;
    final avgPerJob = _completedJobs > 0 ? _monthlyEarnings / _completedJobs : 0.0;
    
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
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
                                  'Monthly Earnings',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'November 2024',
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
                            '₹${_monthlyEarnings.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'of ₹${_monthlyGoal.toStringAsFixed(0)}',
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
                        '${(progress * 100).toStringAsFixed(0)}% of monthly goal achieved',
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
                          const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildEarningStatCard(
                          'Avg per Job',
                          '₹${avgPerJob.toStringAsFixed(0)}',
                          Icons.trending_up,
                          const Color(0xFF6366F1),
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
                      const Icon(Icons.history, size: 20, color: Color(0xFF64748B)),
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
                
                // Transaction List
                Expanded(
                  child: ListView.builder(
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
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isCompleted = transaction['status'] == 'Completed';
    final statusColor = isCompleted ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    
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
                const Color(0xFF6366F1),
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
                const Color(0xFF8B5CF6),
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
  
  // PERFORMANCE METRICS
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
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      '+12%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildMetricBar('Completion Rate', completionRate, const Color(0xFF6366F1)),
          const SizedBox(height: 16),
          _buildMetricBar('Response Rate', responseRate, const Color(0xFF10B981)),
          const SizedBox(height: 16),
          _buildMetricBar('Customer Satisfaction', customerSatisfaction, const Color(0xFFF59E0B)),
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
  
  // RECENT ACTIVITY
  Widget _buildRecentActivity() {
    final activities = [
      {'action': 'Completed job', 'detail': 'Engine Service for Rajesh Kumar', 'time': '2 hours ago', 'icon': Icons.check_circle, 'color': Color(0xFF10B981)},
      {'action': 'New booking', 'detail': 'Brake Service requested', 'time': '4 hours ago', 'icon': Icons.event, 'color': Color(0xFF6366F1)},
      {'action': 'Payment received', 'detail': '₹1,500 from Priya Sharma', 'time': '5 hours ago', 'icon': Icons.currency_rupee, 'color': Color(0xFFF59E0B)},
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

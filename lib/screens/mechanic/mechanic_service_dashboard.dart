import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicServiceDashboard extends StatefulWidget {
  final Map<String, dynamic>? mechanicData;
  
  const MechanicServiceDashboard({super.key, this.mechanicData});

  @override
  State<MechanicServiceDashboard> createState() => _MechanicServiceDashboardState();
}

class _MechanicServiceDashboardState extends State<MechanicServiceDashboard> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  String _mechanicStatus = 'Available'; // Available, Busy, Offline
  List<Map<String, dynamic>> _bookings = [];
  List<String> _myServices = [];
  bool _isLoadingBookings = false;
  
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
  
  // Available services list
  final List<Map<String, dynamic>> _availableServices = [
    {'name': 'General Repair', 'icon': Icons.build, 'color': Color(0xFF6366F1)},
    {'name': 'Engine Service', 'icon': Icons.settings, 'color': Color(0xFFEF4444)},
    {'name': 'Electrical Works', 'icon': Icons.electric_bolt, 'color': Color(0xFFF59E0B)},
    {'name': 'Brake Service', 'icon': Icons.disc_full, 'color': Color(0xFF10B981)},
    {'name': 'AC Repair', 'icon': Icons.ac_unit, 'color': Color(0xFF3B82F6)},
    {'name': 'Body Works', 'icon': Icons.car_repair, 'color': Color(0xFF8B5CF6)},
    {'name': 'Tire Service', 'icon': Icons.circle, 'color': Color(0xFFEC4899)},
    {'name': 'Battery Service', 'icon': Icons.battery_charging_full, 'color': Color(0xFF14B8A6)},
  ];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Pulse animation for status indicator
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Initialize with some services
    _myServices = ['General Repair', 'Engine Service'];
    
    // Load mechanic data if provided
    if (widget.mechanicData != null) {
      _mechanicProfile['name'] = widget.mechanicData!['name'] ?? 'Mechanic';
      _mechanicProfile['specialty'] = widget.mechanicData!['specialty'] ?? 'General Repair';
      _mechanicProfile['experience'] = widget.mechanicData!['experience'] ?? '0-2 years';
    }
    
    _fetchBookings();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchBookings() async {
    setState(() => _isLoadingBookings = true);
    
    try {
      // Mock bookings - replace with actual API call
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _bookings = [
          {
            'id': 1,
            'customerName': 'Rajesh Kumar',
            'customerPhone': '+91 98765 12345',
            'service': 'Engine Service',
            'vehicle': 'Honda City 2020',
            'location': 'Koramangala, Bangalore',
            'date': '2024-01-15',
            'time': '10:00 AM',
            'status': 'Pending',
            'amount': '₹1,500',
          },
          {
            'id': 2,
            'customerName': 'Priya Sharma',
            'customerPhone': '+91 98765 67890',
            'service': 'Brake Service',
            'vehicle': 'Maruti Swift 2019',
            'location': 'Indiranagar, Bangalore',
            'date': '2024-01-15',
            'time': '2:00 PM',
            'status': 'Accepted',
            'amount': '₹800',
          },
          {
            'id': 3,
            'customerName': 'Amit Patel',
            'customerPhone': '+91 98765 11111',
            'service': 'General Repair',
            'vehicle': 'Hyundai i20 2021',
            'location': 'Whitefield, Bangalore',
            'date': '2024-01-16',
            'time': '11:30 AM',
            'status': 'Pending',
            'amount': '₹2,000',
          },
        ];
      });
    } catch (e) {
      _showSnackBar('Error fetching bookings: $e', Colors.red);
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
        actions: [
          // Status dropdown
          _buildStatusDropdown(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Bookings'),
            Tab(text: 'Services'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildBookingsTab(),
          _buildServicesTab(),
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
          dropdownColor: const Color(0xFF6366F1),
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: ['Available', 'Busy', 'Offline'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value == 'Available' 
                        ? Colors.green 
                        : value == 'Busy' 
                          ? Colors.orange 
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(value),
                ],
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _mechanicStatus = newValue!;
            });
            _showSnackBar('Status changed to $_mechanicStatus', Colors.green);
          },
        ),
      ),
    );
  }
  
  // OVERVIEW TAB
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Card
          _buildProfileCard(),
          const SizedBox(height: 20),
          
          // Stats Cards
          _buildStatsCards(),
          const SizedBox(height: 20),
          
          // Today's Schedule
          _buildTodaySchedule(),
          const SizedBox(height: 20),
          
          // Earnings Summary
          _buildEarningsSummary(),
        ],
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return Container(
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
            child: const Icon(Icons.person, size: 40, color: Color(0xFF6366F1)),
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
    );
  }
  
  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Jobs',
            '${_mechanicProfile['completedJobs']}',
            Icons.check_circle,
            const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Pending',
            '${_bookings.where((b) => b['status'] == 'Pending').length}',
            Icons.pending,
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
            child: const Icon(Icons.directions_car, color: Color(0xFF6366F1)),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Month\'s Earnings',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.trending_up, color: Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '₹12,500',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '15 jobs completed this month',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  // BOOKINGS TAB
  Widget _buildBookingsTab() {
    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: _isLoadingBookings
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No bookings yet',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    return _buildBookingCard(_bookings[index]);
                  },
                ),
    );
  }
  
  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final isPending = booking['status'] == 'Pending';
    
    return Container(
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
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPending 
                ? const Color(0xFFF59E0B).withOpacity(0.1)
                : const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Booking #${booking['id']}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    booking['status'],
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildBookingInfoRow(Icons.person, 'Customer', booking['customerName']),
                const SizedBox(height: 12),
                _buildBookingInfoRow(Icons.phone, 'Phone', booking['customerPhone']),
                const SizedBox(height: 12),
                _buildBookingInfoRow(Icons.build, 'Service', booking['service']),
                const SizedBox(height: 12),
                _buildBookingInfoRow(Icons.directions_car, 'Vehicle', booking['vehicle']),
                const SizedBox(height: 12),
                _buildBookingInfoRow(Icons.location_on, 'Location', booking['location']),
                const SizedBox(height: 12),
                _buildBookingInfoRow(Icons.calendar_today, 'Date & Time', '${booking['date']} at ${booking['time']}'),
                const SizedBox(height: 12),
                _buildBookingInfoRow(Icons.attach_money, 'Amount', booking['amount']),
                
                if (isPending) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptBooking(booking),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectBooking(booking),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Decline'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _completeBooking(booking),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Mark as Completed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
  }
  
  Widget _buildBookingInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  void _acceptBooking(Map<String, dynamic> booking) {
    setState(() {
      booking['status'] = 'Accepted';
    });
    _showSnackBar('Booking accepted! Customer has been notified.', const Color(0xFF10B981));
  }
  
  void _rejectBooking(Map<String, dynamic> booking) {
    setState(() {
      _bookings.remove(booking);
    });
    _showSnackBar('Booking declined.', Colors.orange);
  }
  
  void _completeBooking(Map<String, dynamic> booking) {
    setState(() {
      booking['status'] = 'Completed';
      _mechanicProfile['completedJobs']++;
    });
    _showSnackBar('Job marked as completed! Payment will be processed.', const Color(0xFF10B981));
  }
  
  // SERVICES TAB
  Widget _buildServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Services',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage the services you provide to customers',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          
          // Active Services
          _buildActiveServices(),
          
          const SizedBox(height: 24),
          
          // Available Services to Add
          Text(
            'Add More Services',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildAvailableServices(),
        ],
      ),
    );
  }
  
  Widget _buildActiveServices() {
    if (_myServices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.build_circle_outlined, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No services added yet',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add services from the list below',
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _myServices.map((service) {
        final serviceData = _availableServices.firstWhere(
          (s) => s['name'] == service,
          orElse: () => {'name': service, 'icon': Icons.build, 'color': Color(0xFF6366F1)},
        );
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: serviceData['color'], width: 2),
            boxShadow: [
              BoxShadow(
                color: (serviceData['color'] as Color).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(serviceData['icon'], color: serviceData['color'], size: 20),
              const SizedBox(width: 8),
              Text(
                service,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _removeService(service),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.red),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildAvailableServices() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _availableServices.length,
      itemBuilder: (context, index) {
        final service = _availableServices[index];
        final isAdded = _myServices.contains(service['name']);
        
        return GestureDetector(
          onTap: isAdded ? null : () => _addService(service['name']),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAdded ? Colors.grey[100] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAdded ? Colors.grey[300]! : (service['color'] as Color).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                if (!isAdded)
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  service['icon'],
                  size: 36,
                  color: isAdded ? Colors.grey[400] : service['color'],
                ),
                const SizedBox(height: 12),
                Text(
                  service['name'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isAdded ? Colors.grey[500] : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (isAdded)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check, size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Added',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (service['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Add',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: service['color'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _addService(String service) {
    setState(() {
      _myServices.add(service);
    });
    _showSnackBar('$service added to your services!', const Color(0xFF10B981));
  }
  
  void _removeService(String service) {
    setState(() {
      _myServices.remove(service);
    });
    _showSnackBar('$service removed from your services.', Colors.orange);
  }
}


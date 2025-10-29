import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class NightServicePage extends StatefulWidget {
  const NightServicePage({super.key});

  @override
  State<NightServicePage> createState() => _NightServicePageState();
}

class _NightServicePageState extends State<NightServicePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  // Multiple animation controllers for various effects
  late AnimationController _moonController;
  late Animation<double> _moonRotation;
  
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  
  bool _isNightTime = false;
  String _currentTime = '';
  Timer? _timeTimer;
  // ignore: unused_field
  Position? _currentPosition;
  // ignore: unused_field
  bool _isLoadingLocation = false;
  String _selectedService = '';
  // ignore: unused_field
  bool _emergencyMode = false;
  
  // Night service providers (this can be fetched from backend)
  final List<Map<String, dynamic>> _nightProviders = [
    {
      'name': 'QuickFix Night Services',
      'rating': 4.8,
      'distance': '2.3 km',
      'available': true,
      'services': ['Towing', 'Puncture', 'Battery Jump', 'Minor Repair'],
      'contact': '+91 98765 43210',
      'surcharge': '30%',
    },
    {
      'name': '24/7 Emergency Assist',
      'rating': 4.9,
      'distance': '3.1 km',
      'available': true,
      'services': ['Emergency', 'Towing', 'Fuel Refill'],
      'contact': '+91 98765 43211',
      'surcharge': '25%',
    },
    {
      'name': 'Midnight Mechanics',
      'rating': 4.7,
      'distance': '4.5 km',
      'available': false,
      'services': ['All Services'],
      'contact': '+91 98765 43212',
      'surcharge': '35%',
    },
  ];

  final List<Map<String, dynamic>> _nightServices = [
    {
      'name': 'Emergency Towing',
      'icon': Icons.local_shipping,
      'color': Color(0xFFEF4444),
      'surcharge': 30,
      'available': true,
    },
    {
      'name': 'Battery Jump Start',
      'icon': Icons.battery_charging_full,
      'color': Color(0xFFF59E0B),
      'surcharge': 25,
      'available': true,
    },
    {
      'name': 'Puncture Repair',
      'icon': Icons.build_circle,
      'color': Color(0xFF3B82F6),
      'surcharge': 20,
      'available': true,
    },
    {
      'name': 'Fuel Refill',
      'icon': Icons.local_gas_station,
      'color': Color(0xFF10B981),
      'surcharge': 35,
      'available': true,
    },
    {
      'name': 'Minor Repairs',
      'icon': Icons.handyman,
      'color': Color(0xFF8B5CF6),
      'surcharge': 40,
      'available': true,
    },
    {
      'name': 'Lock Opening',
      'icon': Icons.lock_open,
      'color': Color(0xFFEC4899),
      'surcharge': 50,
      'available': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    
    // Fade animation for page entry
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    
    // Moon rotation animation (continuous)
    _moonController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _moonRotation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(_moonController);
    
    // Glow/pulse animation for night mode elements
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Slide animation for cards
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();
    
    // Bounce animation for badges
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
    
    // Shimmer animation for active providers
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    
    _checkNightTime();
    _startTimeUpdate();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    _moonController.dispose();
    _glowController.dispose();
    _slideController.dispose();
    _bounceController.dispose();
    _shimmerController.dispose();
    _timeTimer?.cancel();
    super.dispose();
  }

  void _checkNightTime() {
    final now = DateTime.now();
    final hour = now.hour;
    // Night time is between 8 PM (20:00) and 6 AM (06:00)
    setState(() {
      _isNightTime = hour >= 20 || hour < 6;
    });
  }

  void _startTimeUpdate() {
    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
      // Check night time every minute
      if (DateTime.now().second == 0) {
        _checkNightTime();
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isNightTime ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom App Bar
              SliverAppBar(
                expandedHeight: 200,
                floating: false,
                pinned: true,
                backgroundColor: _isNightTime ? const Color(0xFF1E293B) : const Color(0xFF6366F1),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Night Service',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              shadows: _isNightTime ? [
                                Shadow(
                                  color: const Color(0xFF6366F1).withOpacity(_glowAnimation.value),
                                  blurRadius: 10 * _glowAnimation.value,
                                ),
                                Shadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(_glowAnimation.value * 0.8),
                                  blurRadius: 20 * _glowAnimation.value,
                                ),
                              ] : [],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _moonRotation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _moonRotation.value,
                                child: Text(
                                  '🌙',
                                  style: TextStyle(
                                    fontSize: 20,
                                    shadows: _isNightTime ? [
                                      Shadow(
                                        color: Colors.white.withOpacity(_glowAnimation.value * 0.6),
                                        blurRadius: 15 * _glowAnimation.value,
                                      ),
                                    ] : [],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Gradient background
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isNightTime 
                              ? [Color(0xFF1E293B), Color(0xFF334155), Color(0xFF475569)]
                              : [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7)],
                          ),
                        ),
                      ),
                      // Animated stars (only at night)
                      if (_isNightTime) ..._buildStars(),
                      // Time and status overlay
                      Positioned(
                        bottom: 60,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentTime,
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                AnimatedBuilder(
                                  animation: _bounceAnimation,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: _isNightTime ? _bounceAnimation.value : 1.0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _isNightTime 
                                            ? Colors.green.withOpacity(0.2 * _glowAnimation.value)
                                            : Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isNightTime ? Colors.green : Colors.orange,
                                            width: _isNightTime ? 1 + (_glowAnimation.value * 0.5) : 1,
                                          ),
                                          boxShadow: _isNightTime ? [
                                            BoxShadow(
                                              color: Colors.green.withOpacity(_glowAnimation.value * 0.5),
                                              blurRadius: 10 * _glowAnimation.value,
                                              spreadRadius: 2 * _glowAnimation.value,
                                            ),
                                          ] : [],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _isNightTime ? Icons.nightlight : Icons.wb_sunny,
                                              color: _isNightTime ? Colors.green : Colors.orange,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _isNightTime ? 'Night Mode Active' : 'Day Time',
                                              style: GoogleFonts.inter(
                                                color: _isNightTime ? Colors.green : Colors.orange,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
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
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emergency Alert Banner with slide animation
                      if (_isNightTime) 
                        SlideTransition(
                          position: _slideAnimation,
                          child: _buildEmergencyBanner(),
                        ),
                      
                      const SizedBox(height: 20),

                      // Night Service Info Card with slide animation
                      SlideTransition(
                        position: _slideAnimation,
                        child: _buildInfoCard(),
                      ),
                      
                      const SizedBox(height: 20),

                      // Quick Service Selection
                      _buildSectionTitle('Available Night Services'),
                      const SizedBox(height: 12),
                      _buildServiceGrid(),
                      
                      const SizedBox(height: 24),

                      // Available Providers
                      _buildSectionTitle('Night Service Providers'),
                      const SizedBox(height: 12),
                      _buildProvidersList(),
                      
                      const SizedBox(height: 24),

                      // Safety Tips
                      _buildSectionTitle('Night Safety Tips'),
                      const SizedBox(height: 12),
                      _buildSafetyTips(),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Emergency FAB
      floatingActionButton: _buildEmergencyFAB(),
    );
  }

  List<Widget> _buildStars() {
    return List.generate(20, (index) {
      final random = (index * 123) % 100;
      final delay = (index * 0.1) % 1.0; // Stagger the twinkling
      
      return Positioned(
        left: (random * 3.0) % 100 + 10,
        top: (random * 2.0) % 150 + 20,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, child) {
            // Create phase-shifted twinkling effect for each star
            final twinkle = ((_glowController.value + delay) % 1.0);
            final opacity = 0.3 + (twinkle * 0.7);
            
            return Transform.scale(
              scale: 0.8 + (twinkle * 0.4),
              child: Icon(
                Icons.star,
                color: Colors.white.withOpacity(opacity),
                size: 4 + (random % 8).toDouble(),
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildEmergencyBanner() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 12 + (8 * _glowAnimation.value),
                offset: const Offset(0, 4),
                spreadRadius: 2 * _glowAnimation.value,
              ),
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.2 * _glowAnimation.value),
                blurRadius: 20 * _glowAnimation.value,
                offset: const Offset(0, 0),
                spreadRadius: 4 * _glowAnimation.value,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency 24/7 Available',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap here for immediate assistance',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _emergencyMode = true);
                  _showEmergencyDialog();
                },
                icon: const Icon(Icons.phone_in_talk, color: Colors.white),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isNightTime ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: _isNightTime ? Colors.blue[300] : const Color(0xFF6366F1),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Night Service Information',
                style: GoogleFonts.outfit(
                  color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.schedule, 'Operating Hours', '8:00 PM - 6:00 AM'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.attach_money, 'Night Surcharge', '20% - 50% extra'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.speed, 'Response Time', '15-30 minutes'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.verified_user, 'Safety Verified', 'All providers vetted'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(
          icon,
          color: _isNightTime ? Colors.grey[400] : Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: _isNightTime ? Colors.grey[400] : Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildServiceGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _nightServices.length,
      itemBuilder: (context, index) {
        final service = _nightServices[index];
        final isSelected = _selectedService == service['name'];
        
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedService = isSelected ? '' : service['name'];
            });
            _showServiceDetails(service);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isNightTime ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? service['color']
                  : (_isNightTime ? Colors.grey[800]! : Colors.grey[200]!),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                    ? (service['color'] as Color).withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  service['icon'],
                  color: service['color'],
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  service['name'],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${service['surcharge']}%',
                    style: GoogleFonts.inter(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProvidersList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _nightProviders.length,
      itemBuilder: (context, index) {
        final provider = _nightProviders[index];
        final isAvailable = provider['available'] as bool;
        
        return AnimatedBuilder(
          animation: _shimmerAnimation,
          builder: (context, child) {
            return Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isNightTime ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAvailable 
                        ? const Color(0xFF10B981) 
                        : (_isNightTime ? Colors.grey[800]! : Colors.grey[300]!),
                      width: isAvailable ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      if (isAvailable && _isNightTime)
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3 * _glowAnimation.value),
                          blurRadius: 15 * _glowAnimation.value,
                          spreadRadius: 2 * _glowAnimation.value,
                        ),
                    ],
                  ),
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isAvailable 
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
                      color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider['name'],
                          style: GoogleFonts.outfit(
                            color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${provider['rating']}',
                              style: GoogleFonts.inter(
                                color: _isNightTime ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on, color: const Color(0xFF6366F1), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              provider['distance'],
                              style: GoogleFonts.inter(
                                color: _isNightTime ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAvailable 
                        ? const Color(0xFF10B981).withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAvailable ? 'Available' : 'Busy',
                      style: GoogleFonts.inter(
                        color: isAvailable ? const Color(0xFF10B981) : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (provider['services'] as List).map((service) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isNightTime 
                        ? Colors.blue.withOpacity(0.1)
                        : const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      service,
                      style: GoogleFonts.inter(
                        color: _isNightTime ? Colors.blue[300] : const Color(0xFF6366F1),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isAvailable ? () => _requestService(provider) : null,
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text(
                        'Request Service',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '+${provider['surcharge']}',
                          style: GoogleFonts.inter(
                            color: Colors.orange,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'surcharge',
                          style: GoogleFonts.inter(
                            color: Colors.orange,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
                  ),
                ),
                // Shimmer overlay for available providers
                if (isAvailable && _isNightTime)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Transform.translate(
                        offset: Offset(_shimmerAnimation.value * 400, 0),
                        child: Container(
                          width: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFF10B981).withOpacity(0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSafetyTips() {
    final tips = [
      {'icon': Icons.location_on, 'title': 'Share Location', 'desc': 'Always share your location with someone'},
      {'icon': Icons.verified_user, 'title': 'Verify Provider', 'desc': 'Check provider ID before service'},
      {'icon': Icons.light_mode, 'title': 'Stay in Light', 'desc': 'Wait in well-lit area'},
      {'icon': Icons.groups, 'title': 'Stay Alert', 'desc': 'Keep someone informed about service'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isNightTime 
          ? const Color(0xFF1E293B)
          : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isNightTime ? Colors.orange.withOpacity(0.3) : Colors.orange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: tips.map((tip) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tip['icon'] as IconData,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip['title'] as String,
                        style: GoogleFonts.inter(
                          color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        tip['desc'] as String,
                        style: GoogleFonts.inter(
                          color: _isNightTime ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmergencyFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showEmergencyDialog(),
      backgroundColor: const Color(0xFFEF4444),
      icon: const Icon(Icons.emergency, color: Colors.white),
      label: Text(
        'SOS',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showServiceDetails(Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isNightTime ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  service['icon'],
                  color: service['color'],
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  service['name'],
                  style: GoogleFonts.outfit(
                    color: _isNightTime ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.attach_money, 'Night Surcharge', '+${service['surcharge']}%'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.schedule, 'Estimated Time', '15-30 min'),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.verified_user, 'Available Providers', '${_nightProviders.where((p) => p['available']).length}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Show provider selection
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: service['color'],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Find Providers',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emergency, color: Color(0xFFEF4444)),
            const SizedBox(width: 12),
            Text(
              'Emergency Service',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will immediately connect you with our 24/7 emergency team.',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Color(0xFFEF4444)),
                  const SizedBox(width: 12),
                  Text(
                    '+91 98765 43200',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement call functionality
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Emergency service activated! Help is on the way.',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: Text('Call Now', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _requestService(Map<String, dynamic> provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Request Night Service',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Provider: ${provider['name']}',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact: ${provider['contact']}',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Night surcharge: ${provider['surcharge']}',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Text(
              'Your location will be shared with the provider.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Service requested! Provider will contact you shortly.',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
            child: Text('Confirm', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


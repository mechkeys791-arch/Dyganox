import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../services/api_config.dart';

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
  bool _isLoadingProviders = false;
  
  // Night service providers (fetched from backend)
  List<Map<String, dynamic>> _nightProviders = [];

  final List<Map<String, dynamic>> _nightServices = [
    {
      'name': 'Emergency Towing',
      'icon': Icons.local_shipping,
      'color': AppColors.burntOrange,
      'surcharge': 30,
      'available': true,
    },
    {
      'name': 'Battery Jump Start',
      'icon': Icons.battery_charging_full,
      'color': AppColors.warmBrown,
      'surcharge': 25,
      'available': true,
    },
    {
      'name': 'Puncture Repair',
      'icon': Icons.build_circle,
      'color': AppColors.burntOrange,
      'surcharge': 20,
      'available': true,
    },
    {
      'name': 'Fuel Refill',
      'icon': Icons.local_gas_station,
      'color': AppColors.burntOrange,
      'surcharge': 35,
      'available': true,
    },
    {
      'name': 'Minor Repairs',
      'icon': Icons.handyman,
      'color': AppColors.warmBrown,
      'surcharge': 40,
      'available': true,
    },
    {
      'name': 'Lock Opening',
      'icon': Icons.lock_open,
      'color': AppColors.burntOrange,
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
    _fetchNightProviders();
  }
  
  Future<void> _fetchNightProviders() async {
    setState(() {
      _isLoadingProviders = true;
    });
    
    try {
      print("Night Service: Fetching night service providers...");
      final response = await http.get(
        Uri.parse(ApiConfig.mechanicEndpoint),
        headers: {"Content-Type": "application/json"},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Filter mechanics with nightTimeAvailable = true
        final nightMechanics = data.where((mechanic) {
          return mechanic['nightTimeAvailable'] == true;
        }).toList();
        
        // Transform to match the expected format
        _nightProviders = nightMechanics.map((mechanic) {
          // Calculate rating (you can replace with actual rating if available)
          double rating = 4.0 + ((mechanic['id'] as int) % 10) * 0.1;
          
          // Calculate distance (placeholder - you can implement actual distance calculation)
          double distance = 1.0 + ((mechanic['id'] as int) % 5) * 0.5;
          
          // Get status
          String status = mechanic['status']?.toString() ?? 'Available';
          bool isAvailable = status.toLowerCase() == 'available';
          
          // Get specialty/services
          String specialty = mechanic['specialty']?.toString() ?? 'General Service';
          List<String> services = specialty.split(',').map((s) => s.trim()).toList();
          if (services.isEmpty) services = ['All Services'];
          
          return {
            'name': mechanic['name']?.toString() ?? 'Unknown',
            'rating': rating,
            'distance': '${distance.toStringAsFixed(1)} km',
            'available': isAvailable,
            'services': services,
            'contact': mechanic['phone']?.toString() ?? 'N/A',
            'surcharge': '${20 + ((mechanic['id'] as int) % 20)}%',
            'id': mechanic['id'],
            'email': mechanic['email']?.toString(),
            'latitude': mechanic['latitude']?.toString(),
            'longitude': mechanic['longitude']?.toString(),
          };
        }).toList();
        
        print("Night Service: Found ${_nightProviders.length} night service providers");
      } else {
        print("Night Service: Failed to fetch providers. Status: ${response.statusCode}");
        // Keep empty list or show error
      }
    } catch (e) {
      print("Night Service: Error fetching providers: $e");
      // Keep empty list on error
    } finally {
      setState(() {
        _isLoadingProviders = false;
      });
    }
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
      backgroundColor: _isNightTime ? AppColors.darkChocolate : AppColors.cream,
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
                backgroundColor: _isNightTime ? AppColors.warmBrown : AppColors.burntOrange,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.creamElevated),
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
                              color: AppColors.creamElevated,
                              fontWeight: FontWeight.bold,
                              shadows: _isNightTime ? [
                                Shadow(
                                  color: AppColors.burntOrange.withOpacity(_glowAnimation.value),
                                  blurRadius: 10 * _glowAnimation.value,
                                ),
                                Shadow(
                                  color: AppColors.warmBrown.withOpacity(_glowAnimation.value * 0.8),
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
                                        color: AppColors.creamElevated.withOpacity(_glowAnimation.value * 0.6),
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
                              ? [AppColors.warmBrown, AppColors.darkChocolate, AppColors.warmBrownMuted]
                              : [AppColors.burntOrange, AppColors.warmBrown, AppColors.warmAmber],
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
                                  color: AppColors.creamElevated.withOpacity(0.9),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _currentTime,
                                  style: GoogleFonts.inter(
                                    color: AppColors.creamElevated.withOpacity(0.9),
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
                                            ? AppColors.burntOrange.withOpacity(0.2 * _glowAnimation.value)
                                            : AppColors.warmAmber.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isNightTime ? AppColors.burntOrange : AppColors.warmAmber,
                                            width: _isNightTime ? 1 + (_glowAnimation.value * 0.5) : 1,
                                          ),
                                          boxShadow: _isNightTime ? [
                                            BoxShadow(
                                              color: AppColors.burntOrange.withOpacity(_glowAnimation.value * 0.5),
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
                                              color: _isNightTime ? AppColors.burntOrange : AppColors.warmAmber,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              _isNightTime ? 'Night Mode Active' : 'Day Time',
                                              style: GoogleFonts.inter(
                                                color: _isNightTime ? AppColors.burntOrange : AppColors.warmAmber,
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
                      _isLoadingProviders 
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                color: AppColors.burntOrange,
                              ),
                            ),
                          )
                        : _nightProviders.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Text(
                                  'No night service providers available',
                                  style: GoogleFonts.inter(
                                    color: AppColors.warmBrownMuted,
                                  ),
                                ),
                              ),
                            )
                          : _buildProvidersList(),
                      
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
                color: AppColors.creamElevated.withOpacity(opacity),
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
              colors: [AppColors.burntOrange, AppColors.warmAmber],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.burntOrange.withOpacity(0.3 * _glowAnimation.value),
                blurRadius: 12 + (8 * _glowAnimation.value),
                offset: const Offset(0, 4),
                spreadRadius: 2 * _glowAnimation.value,
              ),
              BoxShadow(
                color: AppColors.warmAmber.withOpacity(0.2 * _glowAnimation.value),
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
                  color: AppColors.creamElevated.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emergency,
                  color: AppColors.creamElevated,
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
                        color: AppColors.creamElevated,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap here for immediate assistance',
                      style: GoogleFonts.inter(
                        color: AppColors.creamElevated.withOpacity(0.9),
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
                icon: Icon(Icons.phone_in_talk, color: AppColors.creamElevated),
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
        color: _isNightTime ? AppColors.warmBrown : AppColors.creamElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkChocolate.withOpacity(0.1),
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
                color: AppColors.burntOrange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Night Service Information',
                style: GoogleFonts.outfit(
                  color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
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
          color: AppColors.warmBrownMuted,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: AppColors.warmBrownMuted,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
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
        color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
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
              color: _isNightTime ? AppColors.warmBrown : AppColors.creamElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? service['color']
                  : (_isNightTime ? AppColors.darkChocolate : AppColors.cream),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                    ? (service['color'] as Color).withOpacity(0.3)
                    : AppColors.darkChocolate.withOpacity(0.05),
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
                    color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warmAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${service['surcharge']}%',
                    style: GoogleFonts.inter(
                      color: AppColors.warmAmber,
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
                    color: _isNightTime ? AppColors.warmBrown : AppColors.creamElevated,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAvailable 
                        ? AppColors.burntOrange 
                        : (_isNightTime ? AppColors.darkChocolate : AppColors.warmBrownMuted),
                      width: isAvailable ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkChocolate.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                      if (isAvailable && _isNightTime)
                        BoxShadow(
                          color: AppColors.burntOrange.withOpacity(0.3 * _glowAnimation.value),
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
                        ? AppColors.burntOrange.withOpacity(0.1)
                        : AppColors.warmBrownMuted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.store,
                      color: isAvailable ? AppColors.burntOrange : AppColors.warmBrownMuted,
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
                            color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: AppColors.warmAmber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${provider['rating']}',
                              style: GoogleFonts.inter(
                                color: AppColors.warmBrownMuted,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on, color: AppColors.burntOrange, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              provider['distance'],
                              style: GoogleFonts.inter(
                                color: AppColors.warmBrownMuted,
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
                        ? AppColors.burntOrange.withOpacity(0.1)
                        : AppColors.warmBrownMuted.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAvailable ? 'Available' : 'Busy',
                      style: GoogleFonts.inter(
                        color: isAvailable ? AppColors.burntOrange : AppColors.warmBrownMuted,
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
                        ? AppColors.burntOrange.withOpacity(0.1)
                        : AppColors.burntOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      service,
                      style: GoogleFonts.inter(
                        color: AppColors.burntOrange,
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
                        backgroundColor: AppColors.burntOrange,
                        foregroundColor: AppColors.creamElevated,
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
                      color: AppColors.warmAmber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '+${provider['surcharge']}',
                          style: GoogleFonts.inter(
                            color: AppColors.warmAmber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'surcharge',
                          style: GoogleFonts.inter(
                            color: AppColors.warmAmber,
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
                                AppColors.burntOrange.withOpacity(0.1),
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
          ? AppColors.warmBrown
          : AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isNightTime ? AppColors.warmAmber.withOpacity(0.3) : AppColors.warmAmber.withOpacity(0.2),
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
                    color: AppColors.warmAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tip['icon'] as IconData,
                    color: AppColors.warmAmber,
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
                          color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        tip['desc'] as String,
                        style: GoogleFonts.inter(
                          color: AppColors.warmBrownMuted,
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
    return FloatingActionButton(
      onPressed: () => _showEmergencyDialog(),
      backgroundColor: AppColors.burntOrange,
      child: Icon(Icons.report_problem_rounded, color: AppColors.creamElevated),
    );
  }

  void _showServiceDetails(Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isNightTime ? AppColors.warmBrown : AppColors.creamElevated,
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
                  color: AppColors.warmBrownMuted,
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
                    color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
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
                  foregroundColor: AppColors.creamElevated,
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
            Icon(Icons.emergency, color: AppColors.burntOrange),
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
                color: AppColors.burntOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone, color: AppColors.burntOrange),
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
                  backgroundColor: AppColors.burntOrange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burntOrange,
              foregroundColor: AppColors.creamElevated,
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
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.warmAmber),
            ),
            const SizedBox(height: 16),
            Text(
              'Your location will be shared with the provider.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.warmBrownMuted),
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
                  backgroundColor: AppColors.burntOrange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.burntOrange,
              foregroundColor: AppColors.creamElevated,
            ),
            child: Text('Confirm', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}


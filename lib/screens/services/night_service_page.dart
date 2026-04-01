import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/service_ads_api.dart';
import '../../widgets/service_ad_strip.dart';
import '../mechanic/book_mechanic_flow_page.dart';

class NightServicePage extends StatefulWidget {
  const NightServicePage({super.key});

  @override
  State<NightServicePage> createState() => _NightServicePageState();
}

class _NightServicePageState extends State<NightServicePage> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  // Multiple animation controllers for various effects
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  
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
  /// Promotional strip ads (platform + mechanic geo-targeted)
  List<Map<String, dynamic>> _serviceAds = [];
  /// Admin-configured tile icons: keys emergency_towing, ev_vehicle_charge, puncture_repair, general_service
  Map<String, String> _nightTileIconUrls = {};
  final ScrollController _scrollController = ScrollController();

  /// Stable keys must match admin JSON in App Branding → Night service icons.
  static const List<Map<String, dynamic>> _nightServiceDefs = [
    {'iconKey': 'emergency_towing', 'name': 'Emergency Towing', 'problemId': 'towing_service', 'color': AppColors.burntOrange, 'fallbackIcon': Icons.local_shipping},
    {'iconKey': 'ev_vehicle_charge', 'name': 'EV vehicle charge', 'problemId': 'ev_vehicle_charge', 'color': AppColors.warmAmber, 'fallbackIcon': Icons.ev_station},
    {'iconKey': 'puncture_repair', 'name': 'Puncture Repair', 'problemId': 'tyre_puncture', 'color': AppColors.burntOrange, 'fallbackIcon': Icons.build_circle},
    {'iconKey': 'general_service', 'name': 'General Service', 'problemId': 'general_checkup', 'color': AppColors.warmBrown, 'fallbackIcon': Icons.handyman},
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
    _fetchServiceAds();
    _fetchNightTileIcons();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollPeekFromEdge());
  }

  Future<void> _fetchNightTileIcons() async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/config/night-service-icons'));
      if (!mounted || r.statusCode != 200) return;
      final map = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
      setState(() {
        _nightTileIconUrls = map.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      });
    } catch (_) {}
  }

  void _scrollPeekFromEdge() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      64,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  void _openNightBookSheet({String? preselectedProblemId, int? preselectedMechanicId}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => BookMechanicFlowPage(
          preselectedProblemId: preselectedProblemId,
          preselectedMechanicId: preselectedMechanicId,
          nightServiceOnly: true,
        ),
      ),
    );
  }

  String _resolveNightIconUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http')) return raw;
    return '${ApiConfig.baseUrl}${raw.startsWith('/') ? '' : '/'}$raw';
  }

  List<Map<String, dynamic>> get _nightImageAds => _serviceAds.where((a) {
        final t = (a['mediaType'] ?? 'IMAGE').toString().toUpperCase();
        return t == 'IMAGE';
      }).toList();

  Future<void> _fetchServiceAds() async {
    final lat = _currentPosition?.latitude;
    final lng = _currentPosition?.longitude;
    final list = await ServiceAdsApi.fetch(placement: 'NIGHT_SERVICE', lat: lat, lng: lng);
    if (!mounted) return;
    setState(() => _serviceAds = list);
  }

  void _onServiceAdTap(Map<String, dynamic> ad) {
    final mid = ad['mechanicId'];
    int? mechanicId;
    if (mid is int) mechanicId = mid;
    else if (mid is num) mechanicId = mid.toInt();
    if (mechanicId != null) {
      _openNightBookSheet(preselectedMechanicId: mechanicId);
      return;
    }
    final sub = ad['subtitle']?.toString() ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sub.isNotEmpty ? sub : 'Explore night services below')),
    );
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
        
        // Filter: nightTimeAvailable AND status = Available (24/7 only if Available)
        final nightMechanics = data.where((mechanic) {
          if (mechanic['nightTimeAvailable'] != true) return false;
          final status = (mechanic['status'] ?? '').toString().toLowerCase();
          return status == 'available';
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
            'distance': distance,
            'distanceStr': '${distance.toStringAsFixed(1)} km',
            'available': isAvailable,
            'services': services,
            'contact': mechanic['phone']?.toString() ?? 'N/A',
            'id': mechanic['id'],
            'email': mechanic['email']?.toString(),
            'latitude': mechanic['latitude']?.toString(),
            'longitude': mechanic['longitude']?.toString(),
          };
        }).toList();
        // Sort by distance (nearest first)
        _nightProviders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        
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
    _glowController.dispose();
    _slideController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    _timeTimer?.cancel();
    super.dispose();
  }

  void _checkNightTime() {
    final now = DateTime.now();
    final hour = now.hour;
    // Night time: 7:00 PM to 7:00 AM (19:00 - 07:00)
    setState(() {
      _isNightTime = hour >= 19 || hour < 7;
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
      await _fetchServiceAds();
    } catch (e) {
      print('Error getting location: $e');
      await _fetchServiceAds();
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
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Custom App Bar
              SliverAppBar(
                expandedHeight: 248,
                floating: false,
                pinned: true,
                backgroundColor: _nightImageAds.isNotEmpty
                    ? Colors.black
                    : (_isNightTime ? AppColors.warmBrown : AppColors.burntOrange),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.45),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                title: null,
                flexibleSpace: FlexibleSpaceBar(
                  title: null,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_nightImageAds.isNotEmpty)
                        Positioned.fill(
                          child: ServiceAdStrip(
                            ads: _nightImageAds,
                            onAdTap: _onServiceAdTap,
                            fullBleed: true,
                          ),
                        )
                      else ...[
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
                        if (_isNightTime) ..._buildStars(),
                      ],
                      IgnorePointer(
                        child: _buildHeroTimeOverlay(),
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

  /// Clock + day/night chip over the hero (readable on ads and gradient).
  Widget _buildHeroTimeOverlay() {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 6, 10, 0),
          child: Material(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, color: Colors.white.withOpacity(0.95), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _currentTime,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 14, color: Colors.white24),
                  const SizedBox(width: 8),
                  Icon(
                    _isNightTime ? Icons.nightlight_round : Icons.wb_sunny_outlined,
                    color: Colors.white.withOpacity(0.9),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isNightTime ? 'Night' : 'Day',
                    style: GoogleFonts.inter(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
          _buildInfoRow(Icons.schedule, 'Operating Hours', '7:00 PM - 7:00 AM'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.info_outline, 'Pricing', 'Between you and mechanic. Transparent pricing.'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.speed, 'Response Time', 'More time given to mechanic (night hours)'),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.verified_user, 'Safety Verified', 'All providers vetted'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.warmBrownMuted,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: AppColors.warmBrownMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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

  Widget _buildNightServiceTileIcon(Map<String, dynamic> service) {
    final key = service['iconKey'] as String;
    final url = _resolveNightIconUrl(_nightTileIconUrls[key]);
    final fallback = service['fallbackIcon'] as IconData;
    final accent = service['color'] as Color;
    if (url.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withOpacity(0.2), accent.withOpacity(0.08)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(fallback, color: accent, size: 34),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 62,
        width: 62,
        color: (_isNightTime ? Colors.white : AppColors.darkChocolate).withOpacity(0.06),
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(fallback, color: accent, size: 34),
        ),
      ),
    );
  }

  Widget _buildServiceGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.05,
      ),
      itemCount: _nightServiceDefs.length,
      itemBuilder: (context, index) {
        final service = _nightServiceDefs[index];
        final isSelected = _selectedService == service['name'];
        final accent = service['color'] as Color;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() => _selectedService = isSelected ? '' : service['name'] as String);
              final problemId = service['problemId'] as String?;
              if (problemId != null) {
                _openNightBookSheet(preselectedProblemId: problemId);
              } else {
                _showServiceDetails(service);
              }
            },
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isNightTime
                      ? [AppColors.warmBrown.withOpacity(0.95), AppColors.darkChocolate.withOpacity(0.88)]
                      : [AppColors.creamElevated, Colors.white],
                ),
                border: Border.all(
                  color: isSelected ? accent : (_isNightTime ? accent.withOpacity(0.35) : AppColors.warmBrownMuted.withOpacity(0.35)),
                  width: isSelected ? 2.2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? accent.withOpacity(0.28) : Colors.black.withOpacity(_isNightTime ? 0.25 : 0.07),
                    blurRadius: isSelected ? 16 : 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildNightServiceTileIcon(service),
                    const SizedBox(height: 10),
                    Text(
                      service['name'] as String,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: _isNightTime ? AppColors.creamElevated : AppColors.warmBrown,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
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
                              provider['distanceStr'],
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
              const SizedBox(height: 8),
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

  /// Clear 24/7 label (avoids [Icons.emergency] which often draws as an empty box on some fonts).
  Widget _build247BadgeOutlined() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.burntOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.burntOrange, width: 1.5),
      ),
      child: Text(
        '24/7',
        style: GoogleFonts.outfit(
          color: AppColors.burntOrange,
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: -0.4,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildEmergencyFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showEmergencyDialog(),
      backgroundColor: AppColors.burntOrange,
      foregroundColor: AppColors.creamElevated,
      icon: Icon(Icons.phone_in_talk_rounded, color: AppColors.creamElevated, size: 22),
      label: Text(
        '24/7',
        style: GoogleFonts.outfit(
          color: AppColors.creamElevated,
          fontWeight: FontWeight.w900,
          fontSize: 15,
          letterSpacing: -0.5,
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
                  service['fallbackIcon'] as IconData,
                  color: service['color'] as Color,
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
            _build247BadgeOutlined(),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Emergency Service',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
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
                color: AppColors.burntOrange.withValues(alpha: 0.1),
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


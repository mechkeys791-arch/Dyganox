import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_colors.dart';
import '../../services/api_config.dart';
import 'package:google_fonts/google_fonts.dart';

class BatteryJumpPage extends StatefulWidget {
  const BatteryJumpPage({super.key});

  @override
  State<BatteryJumpPage> createState() => _BatteryJumpPageState();
}

class _BatteryJumpPageState extends State<BatteryJumpPage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String selectedVehicleType = 'car';
  String selectedBatteryType = '12v';

  List<Map<String, dynamic>> _batteryMechanics = [];
  bool _isLoadingMechanics = true;

  Future<void> _fetchBatteryMechanics() async {
    setState(() => _isLoadingMechanics = true);
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.mechanicEndpoint),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = jsonDecode(response.body);
        final battery = data.where((m) {
          final s = (m['specialty']?.toString() ?? '').toLowerCase();
          return s.contains('battery') || s.contains('jump') || s.contains('electrical');
        }).toList();
        setState(() {
          _batteryMechanics = battery.asMap().entries.map((e) {
            final m = e.value;
            final id = m['id'];
            return {
              'name': m['name']?.toString() ?? 'Mechanic',
              'experience': m['experience']?.toString() ?? 'Experience not specified',
              'rating': (4.0 + (id is int ? id % 10 : 0) * 0.1).toStringAsFixed(1),
              'distance': '${(1.0 + (id is int ? id % 5 : 0) * 0.5).toStringAsFixed(1)} km',
              'speciality': m['specialty']?.toString() ?? 'Battery',
            };
          }).toList();
          _isLoadingMechanics = false;
        });
      } else {
        if (mounted) setState(() { _batteryMechanics = []; _isLoadingMechanics = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _batteryMechanics = []; _isLoadingMechanics = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBatteryMechanics();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildBatteryServiceCard({
    required String title,
    required String description,
    required String iconPath,
    required String price,
    required int index,
    required VoidCallback onTap,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _slideAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value.dy * 50 * (index + 1)),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(8),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                color: AppColors.creamElevated,
                shadowColor: AppColors.burntOrange.withOpacity(0.2),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.creamElevated,
                          AppColors.burntOrange.withOpacity(0.02),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: AppColors.burntOrange.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.burntOrange.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Image.asset(
                              iconPath,
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkChocolate,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                description,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.warmBrownMuted,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.burntOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Starting at $price',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppColors.burntOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: AppColors.burntOrange,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMechanicCard({
    required String name,
    required String experience,
    required String rating,
    required String distance,
    required String speciality,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: AppColors.creamElevated,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.burntOrange.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.burntOrange.withOpacity(0.1),
                child: Text(
                  name[0],
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.burntOrange,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkChocolate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      speciality,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.warmBrownMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: AppColors.burntOrange),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.burntOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            distance,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.burntOrange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Calling $name...',
                        style: GoogleFonts.outfit(),
                      ),
                      backgroundColor: AppColors.burntOrange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.burntOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(60, 36),
                ),
                child: Text(
                  'Call',
                  style: GoogleFonts.outfit(
                    color: AppColors.creamElevated,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
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
  Widget build(BuildContext context) {
    final batteryServices = [
      {
        'title': 'Battery Jump Start',
        'description': 'Quick battery jump start service on-spot',
        'icon': 'assets/icons/jump-start.png',
        'price': '₹199',
      },
      {
        'title': 'Battery Replacement',
        'description': 'New battery installation with warranty',
        'icon': 'assets/icons/car-battery.png',
        'price': '₹2999',
      },
      {
        'title': 'Battery Testing',
        'description': 'Complete battery health check and diagnostics',
        'icon': 'assets/icons/car-battery.png',
        'price': '₹149',
      },
      {
        'title': 'Charging Service',
        'description': 'Battery charging service for deep discharge',
        'icon': 'assets/icons/charging-station.png',
        'price': '₹249',
      },
      {
        'title': 'Emergency Battery',
        'description': '24/7 emergency battery assistance',
        'icon': 'assets/icons/24-hour-service.png',
        'price': '₹299',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.creamElevated,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkChocolate.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: AppColors.darkChocolate, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Battery Services',
          style: GoogleFonts.outfit(
            color: AppColors.darkChocolate,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.burntOrange, AppColors.warmBrown],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.burntOrange.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
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
                      child: Image.asset(
                        'assets/icons/jump-start.png',
                        width: 30,
                        height: 30,
                        color: AppColors.creamElevated,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Battery Solutions',
                            style: GoogleFonts.outfit(
                              color: AppColors.creamElevated,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jump start • Replacement • Testing • 24/7 service',
                            style: GoogleFonts.inter(
                              color: AppColors.creamElevated.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Available Services Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Available Battery Services',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkChocolate,
                  ),
                ),
              ),

              // Services List
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: batteryServices.length,
                itemBuilder: (context, index) {
                  final service = batteryServices[index];
                  return _buildBatteryServiceCard(
                    title: service['title']!,
                    description: service['description']!,
                    iconPath: service['icon']!,
                    price: service['price']!,
                    index: index,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Row(
                              children: [
                                Image.asset(
                                  service['icon']!,
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    service['title']!,
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service['description']!,
                                  style: GoogleFonts.inter(),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.burntOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: AppColors.burntOrange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Available 24/7',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: AppColors.burntOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.battery_full,
                                            size: 16,
                                            color: AppColors.burntOrange,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Professional battery experts',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              color: AppColors.burntOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Close',
                                  style: GoogleFonts.outfit(),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Booking ${service['title']}...',
                                        style: GoogleFonts.outfit(),
                                      ),
                                      backgroundColor: AppColors.burntOrange,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.burntOrange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Book Now',
                                  style: GoogleFonts.outfit(
                                    color: AppColors.creamElevated,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              // Nearby Mechanics Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Text(
                  'Nearby Battery Experts',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkChocolate,
                  ),
                ),
              ),

              // Mechanics List (from mechanic registration)
              _isLoadingMechanics
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: AppColors.burntOrange)),
                    )
                  : _batteryMechanics.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No battery service mechanics available at the moment',
                              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _batteryMechanics.length,
                          itemBuilder: (context, index) {
                            final mechanic = _batteryMechanics[index];
                            return _buildMechanicCard(
                              name: mechanic['name'] as String,
                              experience: mechanic['experience'] as String,
                              rating: mechanic['rating'] as String,
                              distance: mechanic['distance'] as String,
                              speciality: mechanic['speciality'] as String,
                              index: index,
                            );
                          },
                        ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

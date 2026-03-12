import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../mechanic/book_mechanic_flow_page.dart';

class TyreCarePage extends StatefulWidget {
  const TyreCarePage({super.key});

  @override
  State<TyreCarePage> createState() => _TyreCarePageState();
}

class _TyreCarePageState extends State<TyreCarePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String selectedVehicleType = 'car';
  String selectedTyreSize = '155/65R14';
  bool _isLoadingMechanics = false;
  List<Map<String, dynamic>> _tyreMechanics = [];

  @override
  void initState() {
    super.initState();
    
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
    _fetchTyreMechanics();
  }
  
  Future<void> _fetchTyreMechanics() async {
    setState(() {
      _isLoadingMechanics = true;
    });
    
    try {
      print("Tyre Care: Fetching tyre mechanics...");
      final response = await http.get(
        Uri.parse(ApiConfig.mechanicEndpoint),
        headers: {"Content-Type": "application/json"},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Filter mechanics with specialty containing "tyre" (case-insensitive)
        final tyreMechanics = data.where((mechanic) {
          String specialty = (mechanic['specialty']?.toString() ?? '').toLowerCase();
          return specialty.contains('tyre') || specialty.contains('tire');
        }).toList();
        
        // Transform to match the expected format
        _tyreMechanics = tyreMechanics.map((mechanic) {
          // Calculate rating
          double rating = 4.0 + ((mechanic['id'] as int) % 10) * 0.1;
          
          // Calculate distance (placeholder)
          double distance = 1.0 + ((mechanic['id'] as int) % 5) * 0.5;
          
          return {
            'name': mechanic['name']?.toString() ?? 'Unknown',
            'experience': mechanic['experience']?.toString() ?? 'Not specified',
            'rating': rating.toStringAsFixed(1),
            'distance': '${distance.toStringAsFixed(1)} km',
            'speciality': mechanic['specialty']?.toString() ?? 'Tyre Expert',
            'id': mechanic['id'],
            'phone': mechanic['phone']?.toString(),
            'email': mechanic['email']?.toString(),
          };
        }).toList();
        
        print("Tyre Care: Found ${_tyreMechanics.length} tyre mechanics");
      } else {
        print("Tyre Care: Failed to fetch mechanics. Status: ${response.statusCode}");
      }
    } catch (e) {
      print("Tyre Care: Error fetching mechanics: $e");
    } finally {
      setState(() {
        _isLoadingMechanics = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Widget _buildTyreServiceCard({
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
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: Colors.green,
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
                  // Find the mechanic in the list to get phone number
                  final mechanic = _tyreMechanics.firstWhere(
                    (m) => m['name'] == name,
                    orElse: () => {'phone': 'N/A'},
                  );
                  final phone = mechanic['phone'] ?? 'N/A';
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        phone != 'N/A' ? 'Calling $name at $phone...' : 'Phone number not available',
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
    final tyreServices = [
      {
        'title': 'Puncture Repair',
        'description': 'Quick on-spot puncture repair and tube fixing',
        'icon': 'assets/icons/pun.png',
        'price': '₹149',
      },
      {
        'title': 'Tyre Replacement',
        'description': 'New tyre installation with balancing and alignment',
        'icon': 'assets/icons/tc.png',
        'price': '₹2999',
      },
      {
        'title': 'Wheel Balancing',
        'description': 'Professional wheel balancing for smooth ride',
        'icon': 'assets/icons/wa.png',
        'price': '₹299',
      },
      {
        'title': 'Pressure Check',
        'description': 'Free tyre pressure check and inflation service',
        'icon': 'assets/icons/tp.png',
        'price': 'Free',
      },
    ];

    // Use live data from API instead of dummy data
    final nearbyMechanics = _tyreMechanics.isEmpty ? [] : _tyreMechanics;

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
          'Tyre Care',
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
                        'assets/icons/punctured-tire.png',
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
                            'Complete Tyre Care',
                            style: GoogleFonts.outfit(
                              color: AppColors.creamElevated,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Puncture repair • Replacement • Balancing',
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
                  'Available Tyre Services',
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
                itemCount: tyreServices.length,
                itemBuilder: (context, index) {
                  final service = tyreServices[index];
                  return _buildTyreServiceCard(
                    title: service['title']!,
                    description: service['description']!,
                    iconPath: service['icon']!,
                    price: service['price']!,
                    index: index,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BookMechanicFlowPage(preselectedProblemId: 'tyre_puncture'),
                        ),
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
                  'Nearby Tyre Experts',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkChocolate,
                  ),
                ),
              ),

              // Mechanics List
              _isLoadingMechanics
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(
                        color: AppColors.burntOrange,
                      ),
                    ),
                  )
                : nearbyMechanics.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          'No tyre care mechanics available',
                          style: GoogleFonts.inter(
                            color: AppColors.warmBrownMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: nearbyMechanics.length,
                      itemBuilder: (context, index) {
                        final mechanic = nearbyMechanics[index];
                        return _buildMechanicCard(
                          name: mechanic['name'] ?? 'Unknown',
                          experience: mechanic['experience'] ?? 'Not specified',
                          rating: mechanic['rating'] ?? '4.0',
                          distance: mechanic['distance'] ?? 'N/A',
                          speciality: mechanic['speciality'] ?? 'Tyre Expert',
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

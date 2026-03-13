import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../mechanic/book_mechanic_flow_page.dart';
import 'mechanic_location_map_page.dart';

/// Same flow as TyreCarePage (home page) - fetches mechanics by tyre_puncture, shows list, tap opens problem sheet with Show location/Book mechanic.
class BikeTyreCarePage extends StatefulWidget {
  const BikeTyreCarePage({super.key});

  @override
  State<BikeTyreCarePage> createState() => _BikeTyreCarePageState();
}

class _BikeTyreCarePageState extends State<BikeTyreCarePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoadingMechanics = false;
  List<Map<String, dynamic>> _tyreMechanics = [];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();
    _fetchTyreMechanics();
  }

  Future<void> _fetchTyreMechanics() async {
    setState(() => _isLoadingMechanics = true);
    try {
      double lat = 12.9716;
      double lng = 77.5946;
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final uri = Uri.parse('${ApiConfig.mechanicEndpoint}/by-category').replace(
        queryParameters: {
          'problemCategory': 'tyre_puncture',
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radiusKm': '20',
        },
      );

      final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data is Map && data['content'] != null) ? data['content'] as List : [];
        _tyreMechanics = list.map<Map<String, dynamic>>((m) {
          final mechanic = Map<String, dynamic>.from(m as Map);
          final id = mechanic['id'];
          return {
            'name': mechanic['name']?.toString() ?? 'Unknown',
            'experience': mechanic['experience']?.toString() ?? 'Not specified',
            'rating': mechanic['rating']?.toString() ?? (4.0 + ((id is int ? id : 0) % 10) * 0.1).toStringAsFixed(1),
            'distance': 'Nearby',
            'speciality': mechanic['specialty']?.toString() ?? 'Bike Tyre Expert',
            'id': id,
            'phone': mechanic['phone']?.toString(),
            'email': mechanic['email']?.toString(),
          };
        }).toList();
      } else if (mounted) {
        _tyreMechanics = [];
      }
    } catch (e) {
      if (mounted) _tyreMechanics = [];
    } finally {
      if (mounted) setState(() => _isLoadingMechanics = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _openMechanicDirections(Map<String, dynamic> mechanic) {
    final id = mechanic['id'];
    final mechanicId = id is int ? id : int.tryParse(id?.toString() ?? '');
    final name = mechanic['name']?.toString() ?? 'Mechanic';
    if (mechanicId == null || mechanicId <= 0) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MechanicLocationMapPage(
          mechanicId: mechanicId,
          mechanicName: name,
        ),
      ),
    );
  }

  static const _tyreProblemTypes = [
    {'id': 'tyre_puncture', 'title': 'Puncture Repair', 'desc': 'Quick on-spot puncture repair'},
    {'id': 'tyre_puncture', 'title': 'Tyre Replacement', 'desc': 'New tyre installation'},
    {'id': 'tyre_puncture', 'title': 'Wheel Balancing', 'desc': 'Professional wheel balancing'},
    {'id': 'tyre_puncture', 'title': 'Pressure Check', 'desc': 'Tyre pressure check & inflation'},
  ];

  void _showTyreProblemSheet(Map<String, dynamic> mechanic) {
    String selectedTitle = _tyreProblemTypes.first['title']!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
          decoration: const BoxDecoration(
            color: AppColors.creamElevated,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    mechanic['name'] ?? 'Mechanic',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkChocolate,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mechanic['speciality'] ?? 'Bike Tyre Expert',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.warmBrownMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Select tyre problem',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkChocolate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._tyreProblemTypes.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: (selectedTitle == p['title'])
                          ? AppColors.burntOrange.withOpacity(0.15)
                          : AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => setModalState(() => selectedTitle = p['title']!),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.tire_repair,
                                color: AppColors.burntOrange,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['title']!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkChocolate,
                                      ),
                                    ),
                                    Text(
                                      p['desc']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.warmBrownMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedTitle == p['title'])
                                Icon(Icons.check_circle, color: AppColors.burntOrange, size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _openMechanicDirections(mechanic);
                          },
                          icon: const Icon(Icons.location_on, size: 20),
                          label: const Text('Show location'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.burntOrange,
                            side: const BorderSide(color: AppColors.burntOrange),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final mechanicId = mechanic['id'];
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BookMechanicFlowPage(
                                  preselectedProblemId: 'tyre_puncture',
                                  preselectedMechanicId: mechanicId is int ? mechanicId : null,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.book_online, size: 20),
                          label: const Text('Book mechanic'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.burntOrange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMechanicCard({
    required String name,
    required String experience,
    required String rating,
    required String distance,
    required String speciality,
    required Map<String, dynamic> mechanic,
    required int index,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: AppColors.creamElevated,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showTyreProblemSheet(mechanic);
          },
          borderRadius: BorderRadius.circular(16),
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
                    name.isNotEmpty ? name[0] : '?',
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
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.burntOrange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nearbyMechanics = _tyreMechanics;

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
          'Bike Tyre Care',
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
        child: RefreshIndicator(
          onRefresh: _fetchTyreMechanics,
          color: AppColors.burntOrange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
                          errorBuilder: (_, __, ___) => Icon(Icons.tire_repair, color: AppColors.creamElevated, size: 30),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Complete Bike Tyre Care',
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

                // Nearby Mechanics Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    'Nearby Bike Tyre Experts',
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
                            'No bike tyre care mechanics available',
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
                            speciality: mechanic['speciality'] ?? 'Bike Tyre Expert',
                            mechanic: mechanic,
                            index: index,
                          );
                        },
                      ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

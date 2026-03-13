import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../data/service_category_mapping.dart';
import '../../services/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../mechanic/book_mechanic_flow_page.dart';
import 'mechanic_location_map_page.dart';

/// Reusable page that shows mechanics who provide a specific service.
/// Used from Car/Bike service pages when user taps Oil Change, Windshield, Suspension, etc.
class MechanicsByServicePage extends StatefulWidget {
  final String serviceTitle;

  const MechanicsByServicePage({super.key, required this.serviceTitle});

  @override
  State<MechanicsByServicePage> createState() => _MechanicsByServicePageState();
}

class _MechanicsByServicePageState extends State<MechanicsByServicePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _mechanics = [];

  @override
  void initState() {
    super.initState();
    _fetchMechanics();
  }

  Future<void> _fetchMechanics() async {
    setState(() => _isLoading = true);
    try {
      final categoryId = ServiceCategoryMapping.getCategoryId(widget.serviceTitle);
      double lat = 12.9716;
      double lng = 77.5946;
      try {
        final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}

      final uri = Uri.parse('${ApiConfig.mechanicEndpoint}/by-category').replace(
        queryParameters: {
          'problemCategory': categoryId ?? 'general_checkup',
          'lat': lat.toString(),
          'lng': lng.toString(),
          'radiusKm': '20',
        },
      );

      final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final list = data is List ? data : (data is Map && data['content'] != null) ? data['content'] as List : [];
        _mechanics = list.map<Map<String, dynamic>>((m) {
          final mechanic = Map<String, dynamic>.from(m as Map);
          final id = mechanic['id'];
          return {
            'name': mechanic['name']?.toString() ?? 'Unknown',
            'experience': mechanic['experience']?.toString() ?? 'Not specified',
            'rating': (4.0 + ((id is int ? id : 0) % 10) * 0.1).toStringAsFixed(1),
            'distance': 'Nearby',
            'speciality': mechanic['specialty']?.toString() ?? widget.serviceTitle,
            'id': id,
            'phone': mechanic['phone']?.toString(),
            'email': mechanic['email']?.toString(),
          };
        }).toList();
      } else if (mounted) {
        _mechanics = [];
      }
    } catch (e) {
      if (mounted) _mechanics = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  void _openBookMechanic(Map<String, dynamic> mechanic) {
    final id = mechanic['id'];
    final mechanicId = id is int ? id : int.tryParse(id?.toString() ?? '');
    if (mechanicId == null || mechanicId <= 0) return;
    final problemId = ServiceCategoryMapping.getCategoryId(widget.serviceTitle) ?? 'general_checkup';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookMechanicFlowPage(
          preselectedMechanicId: mechanicId,
          preselectedProblemId: problemId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.serviceTitle,
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMechanics,
        color: AppColors.burntOrange,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.burntOrange))
            : _mechanics.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Icon(Icons.construction, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'No mechanic available',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No mechanics providing ${widget.serviceTitle} are available. Please try another service or check back later.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _mechanics.length,
                    itemBuilder: (context, index) {
                      final m = _mechanics[index];
                      return _buildMechanicCard(m);
                    },
                  ),
      ),
    );
  }

  Widget _buildMechanicCard(Map<String, dynamic> mechanic) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.creamElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.burntOrange.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.burntOrange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: AppColors.burntOrange, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mechanic['name'] ?? 'Mechanic',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
                      ),
                      Text(
                        mechanic['speciality'] ?? widget.serviceTitle,
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.warmBrownMuted),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(mechanic['rating'] ?? '4.5', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text(mechanic['distance'] ?? 'Nearby', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openMechanicDirections(mechanic),
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('Show location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.burntOrange,
                      side: const BorderSide(color: AppColors.burntOrange),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openBookMechanic(mechanic),
                    icon: const Icon(Icons.book_online, size: 18),
                    label: const Text('Book mechanic'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burntOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

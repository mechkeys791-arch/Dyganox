import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/vehicle_service.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../widgets/custom_nav_bar.dart';
import 'add_edit_vehicle_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  List<Map<String, dynamic>> _vehicles = [];
  String _userEmail = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndVehicles();
  }

  Future<void> _loadUserAndVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = await CognitoService.getCurrentUser();
    final email = userData['email']?.toString() ?? prefs.getString('user_email') ?? '';
    setState(() {
      _userEmail = email;
      _loading = true;
    });
    if (email.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final list = await VehicleService.getMyVehicles(email);
    if (mounted) setState(() {
      _vehicles = list;
      _loading = false;
    });
  }

  String _imageUrl(dynamic url) {
    if (url == null || url.toString().isEmpty) return '';
    final s = url.toString();
    if (s.startsWith('http')) return s;
    return '${ApiConfig.baseUrl}$s';
  }

  void _navigateToAdd() async {
    if (_userEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to add a vehicle'), backgroundColor: Colors.orange),
      );
      return;
    }
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditVehiclePage(userEmail: _userEmail),
      ),
    );
    if (refreshed == true) _loadUserAndVehicles();
  }

  void _navigateToEdit(Map<String, dynamic> vehicle) async {
    final refreshed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditVehiclePage(
          userEmail: _userEmail,
          existingVehicle: vehicle,
        ),
      ),
    );
    if (refreshed == true) _loadUserAndVehicles();
  }

  void _deleteVehicle(Map<String, dynamic> vehicle) {
    final id = vehicle['id'];
    if (id == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            Text('Delete Vehicle', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this vehicle?',
          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await VehicleService.deleteVehicle(id is int ? id : (id as num).toInt());
              if (mounted) {
                if (ok) {
                  _loadUserAndVehicles();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Vehicle deleted'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getVehicleIcon(String? type) {
    if (type?.toUpperCase() == 'BIKE') return Icons.two_wheeler;
    return Icons.directions_car;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Vehicles',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadUserAndVehicles,
              color: const Color(0xFF6366F1),
              child: _vehicles.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height - 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No Vehicles Added',
                                style: GoogleFonts.outfit(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add your first vehicle to get started',
                                style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      itemCount: _vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _vehicles[index];
                        final photoUrl = vehicle['photoUrl'] ?? vehicle['modelImageUrl'];
                        final imageUrl = _imageUrl(photoUrl);
                        final title = '${vehicle['makeName'] ?? ''} ${vehicle['modelName'] ?? ''}'.trim();
                        final subtitle = vehicle['plateNumber']?.toString() ?? 'No plate number';
                        final isDefault = vehicle['isDefault'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _navigateToEdit(vehicle),
                              borderRadius: BorderRadius.circular(18),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: imageUrl.isNotEmpty
                                            ? Image.network(
                                                imageUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => _leadingIcon(vehicle['type']),
                                              )
                                            : _leadingIcon(vehicle['type']),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  title.isNotEmpty ? title : 'Vehicle',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF1F2937)),
                                                ),
                                              ),
                                              if (isDefault)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    'Default',
                                                    style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6366F1), fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF6366F1)),
                                      onPressed: () => _navigateToEdit(vehicle),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                                      onPressed: () => _deleteVehicle(vehicle),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: const CustomNavBar(currentIndex: 1),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAdd,
        backgroundColor: const Color(0xFF6366F1),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Vehicle',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _leadingIcon(String? type) {
    return Center(
      child: Icon(_getVehicleIcon(type), color: const Color(0xFF6366F1), size: 36),
    );
  }
}

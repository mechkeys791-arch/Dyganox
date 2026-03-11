import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../services/api_config.dart';
import '../services/vehicle_service.dart';

/// Reusable bottom sheet to select a vehicle (same style as "Find mechanic for").
/// [onSelectVehicle] receives the full vehicle map so Book flow can set selected vehicle;
/// Find mechanic flow can use vehicle['type'] for MechanicFinderPage.
class VehicleSelectionSheet extends StatefulWidget {
  final String title;
  final String userEmail;
  final BuildContext parentContext;
  final void Function(Map<String, dynamic> vehicle) onSelectVehicle;
  final VoidCallback onAddVehicle;
  /// If provided, sheet uses this list instead of loading (e.g. Book flow already has vehicles).
  final List<Map<String, dynamic>>? initialVehicles;

  const VehicleSelectionSheet({
    super.key,
    this.title = 'Select vehicle',
    required this.userEmail,
    required this.parentContext,
    required this.onSelectVehicle,
    required this.onAddVehicle,
    this.initialVehicles,
  });

  @override
  State<VehicleSelectionSheet> createState() => _VehicleSelectionSheetState();
}

class _VehicleSelectionSheetState extends State<VehicleSelectionSheet> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialVehicles != null) {
      _vehicles = List.from(widget.initialVehicles!);
      _loading = false;
    } else {
      _loadVehicles();
    }
  }

  Future<void> _loadVehicles() async {
    if (widget.userEmail.isEmpty) {
      setState(() { _vehicles = []; _loading = false; });
      return;
    }
    final list = await VehicleService.getMyVehicles(widget.userEmail);
    if (mounted) setState(() { _vehicles = list; _loading = false; });
  }

  String _vehicleImageUrl(Map<String, dynamic> v) {
    final url = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  String _vehicleName(Map<String, dynamic> v) {
    final make = v['makeName'] ?? '';
    final model = v['modelName'] ?? '';
    final plate = v['plateNumber'] ?? '';
    final name = '$make $model'.trim();
    if (name.isEmpty) return plate.toString().isNotEmpty ? plate : 'Vehicle';
    return plate.toString().isNotEmpty ? '$name ($plate)' : name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                widget.title,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
              ),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: AppColors.burntOrange)))
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    ..._vehicles.map((v) {
                      final type = (v['type'] ?? 'CAR').toString().toUpperCase();
                      final imgUrl = _vehicleImageUrl(v);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onSelectVehicle(v),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: imgUrl.isNotEmpty
                                      ? Image.network(imgUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _vehiclePlaceholder(type))
                                      : _vehiclePlaceholder(type),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    _vehicleName(v),
                                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkChocolate),
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            const Divider(height: 1),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onAddVehicle,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.burntOrange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.add, color: AppColors.burntOrange, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'Add new vehicle',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.burntOrange),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehiclePlaceholder(String type) {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.creamElevated,
      child: Icon(
        type == 'BIKE' ? Icons.two_wheeler : Icons.directions_car,
        color: AppColors.burntOrange,
        size: 28,
      ),
    );
  }
}

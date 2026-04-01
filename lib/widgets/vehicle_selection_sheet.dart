import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../services/api_config.dart';
import '../services/vehicle_service.dart';
import '../screens/vehicles/add_edit_vehicle_page.dart';

/// Add / edit vehicle in a tall bottom sheet (not full-screen push).
Future<void> showAddVehicleInBottomSheet(
  BuildContext context, {
  required String userEmail,
  String? initialVehicleType,
}) {
  final h = MediaQuery.sizeOf(context).height;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(top: h * 0.05),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SizedBox(
          height: h * 0.95,
          child: Material(
            color: Colors.white,
            child: AddEditVehiclePage(
              userEmail: userEmail,
              initialVehicleType: initialVehicleType,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Reusable bottom sheet to select a vehicle (Rapido-style draggable sheet).
/// Use with [showModalBottomSheet](isScrollControlled: true, backgroundColor: transparent).
class VehicleSelectionSheet extends StatefulWidget {
  final String title;
  final String userEmail;
  final BuildContext parentContext;
  final void Function(Map<String, dynamic> vehicle) onSelectVehicle;
  final VoidCallback onAddVehicle;
  /// If provided, sheet uses this list instead of loading (e.g. Book flow already has vehicles).
  final List<Map<String, dynamic>>? initialVehicles;
  /// Initial height as fraction of screen (0.4–0.6 feels like ride-hailing apps).
  final double initialSize;
  final double minSize;
  final double maxSize;

  const VehicleSelectionSheet({
    super.key,
    this.title = 'Select vehicle',
    required this.userEmail,
    required this.parentContext,
    required this.onSelectVehicle,
    required this.onAddVehicle,
    this.initialVehicles,
    this.initialSize = 0.52,
    this.minSize = 0.36,
    this.maxSize = 0.92,
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
      setState(() {
        _vehicles = [];
        _loading = false;
      });
      return;
    }
    final list = await VehicleService.getMyVehicles(widget.userEmail);
    if (mounted) setState(() {
      _vehicles = list;
      _loading = false;
    });
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: widget.initialSize.clamp(0.28, 0.95),
      minChildSize: widget.minSize.clamp(0.25, 0.9),
      maxChildSize: widget.maxSize.clamp(0.5, 1.0),
      snap: true,
      snapSizes: [
        widget.minSize.clamp(0.25, 0.9),
        widget.initialSize.clamp(0.28, 0.95),
        widget.maxSize.clamp(0.5, 1.0),
      ],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: [
              BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, -4)),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  widget.title,
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.burntOrange))
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
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
                                            ? Image.network(
                                                imgUrl,
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _vehiclePlaceholder(type),
                                              )
                                            : _vehiclePlaceholder(type),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          _vehicleName(v),
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.darkChocolate,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
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
                                        color: AppColors.burntOrange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.add, color: AppColors.burntOrange, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      'Add new vehicle',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.burntOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
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

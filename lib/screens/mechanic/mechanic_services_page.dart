import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MechanicServicesPage extends StatefulWidget {
  final List<String> myServices;
  final Function(String) onAddService;
  final Function(String) onRemoveService;
  
  const MechanicServicesPage({
    super.key,
    required this.myServices,
    required this.onAddService,
    required this.onRemoveService,
  });

  @override
  State<MechanicServicesPage> createState() => _MechanicServicesPageState();
}

class _MechanicServicesPageState extends State<MechanicServicesPage> {
  // Available services list
  final List<Map<String, dynamic>> _availableServices = [
    {'name': 'General Repair', 'icon': Icons.handyman, 'color': Color(0xFF6366F1)},
    {'name': 'Engine Service', 'icon': Icons.settings_suggest, 'color': Color(0xFFEF4444)},
    {'name': 'Electrical Works', 'icon': Icons.electrical_services, 'color': Color(0xFFF59E0B)},
    {'name': 'Brake Service', 'icon': Icons.speed, 'color': Color(0xFF10B981)},
    {'name': 'AC Repair', 'icon': Icons.ac_unit, 'color': Color(0xFF3B82F6)},
    {'name': 'Body Works', 'icon': Icons.directions_car, 'color': Color(0xFF8B5CF6)},
    {'name': 'Tire Service', 'icon': Icons.album_outlined, 'color': Color(0xFFEC4899)},
    {'name': 'Battery Service', 'icon': Icons.battery_charging_full, 'color': Color(0xFF14B8A6)},
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF8B5CF6),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Services',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '${widget.myServices.length} Active',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Services Section
            _buildActiveServicesSection(),
            const SizedBox(height: 24),
            
            // Available Services to Add
            _buildAvailableServicesSection(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActiveServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Services',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.myServices.length} Services',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        if (widget.myServices.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.handyman_outlined, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No services added yet',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add services from below to get started',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: widget.myServices.map((service) {
              final serviceData = _availableServices.firstWhere(
                (s) => s['name'] == service,
                orElse: () => {'name': service, 'icon': Icons.handyman, 'color': Color(0xFF6366F1)},
              );
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: serviceData['color'], width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (serviceData['color'] as Color).withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(serviceData['icon'], color: serviceData['color'], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      service,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        widget.onRemoveService(service);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
  
  Widget _buildAvailableServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add More Services',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Expand your service offerings to reach more customers',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: _availableServices.length,
          itemBuilder: (context, index) {
            final service = _availableServices[index];
            final isAdded = widget.myServices.contains(service['name']);
            
            return GestureDetector(
              onTap: isAdded ? null : () {
                widget.onAddService(service['name']);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${service['name']} added to your services!',
                      style: GoogleFonts.inter(),
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isAdded ? Colors.grey[100] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isAdded ? Colors.grey[300]! : (service['color'] as Color).withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    if (!isAdded)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      service['icon'],
                      size: 36,
                      color: isAdded ? Colors.grey[400] : service['color'],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      service['name'],
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isAdded ? Colors.grey[500] : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isAdded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 12, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Active',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (service['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Add',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: service['color'],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}


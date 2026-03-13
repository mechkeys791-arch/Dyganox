import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'towing_service_page.dart';
import 'battery_jump_page.dart';
import 'tyre_care_page.dart';
import 'mechanics_by_service_page.dart';
import '../vehicles/add_edit_vehicle_page.dart';
import '../../core/theme/app_colors.dart';
import '../../services/app_remote_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/cognito_service.dart';
import '../../services/api_config.dart';

class CarServicePage extends StatefulWidget {
  const CarServicePage({super.key});

  @override
  State<CarServicePage> createState() => _CarServicePageState();
}

class _CarServicePageState extends State<CarServicePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String? _appLogoUrl;
  String? _carServiceImageUrl;
  List<Map<String, dynamic>> _userCars = [];
  bool _loadingCars = true;
  String _userEmail = '';

  static const _carServices = [
    {'title': 'Towing', 'icon': 'assets/icons/tow-truck.png'},
    {'title': 'EV Coming Soon', 'icon': 'assets/icons/charging-station.png'},
    {'title': 'Battery Jump', 'icon': 'assets/icons/jump-start.png'},
    {'title': 'Headlight Repair', 'icon': 'assets/icons/headlight.png'},
    {'title': 'Tyre Care', 'icon': 'assets/icons/punctured-tire.png'},
    {'title': 'Oil Change', 'icon': 'assets/icons/repair-tools.png'},
    {'title': 'Brake Service', 'icon': 'assets/icons/brake-service.png'},
    {'title': 'Windshield', 'icon': 'assets/icons/headlight.png'},
    {'title': 'Body Works', 'icon': 'assets/icons/smart-car.png'},
    {'title': 'Wheel Alignment', 'icon': 'assets/icons/wa.png'},
    {'title': 'Suspension', 'icon': 'assets/icons/new-bike-suspension.png'},
  ];

  @override
  void initState() {
    super.initState();
    AppRemoteService.getAppBrandingConfig().then((m) {
      if (mounted && m != null) {
        final logo = (m['appLogoUrl']?.toString() ?? '').trim();
        final carImg = (m['carServiceImageUrl']?.toString() ?? '').trim();
        setState(() {
          if (logo.isNotEmpty) _appLogoUrl = logo;
          if (carImg.isNotEmpty) _carServiceImageUrl = carImg;
        });
      }
    });
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _loadUserCars();
  }

  Future<void> _loadUserCars() async {
    setState(() => _loadingCars = true);
    try {
      final user = await CognitoService.getCurrentUser();
      final email = user['email']?.toString() ?? '';
      _userEmail = email;
      if (email.isEmpty) {
        if (mounted) setState(() { _userCars = []; _loadingCars = false; });
        return;
      }
      final list = await VehicleService.getMyVehicles(email);
      final cars = list.where((v) => (v['type'] ?? 'CAR').toString().toUpperCase() == 'CAR').toList();
      if (mounted) setState(() { _userCars = cars; _loadingCars = false; });
    } catch (_) {
      if (mounted) setState(() { _userCars = []; _loadingCars = false; });
    }
  }

  String _vehicleImageUrl(Map<String, dynamic> v) {
    final url = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  Widget _buildVehicleCard(Map<String, dynamic> v) {
    final make = v['makeName']?.toString() ?? '';
    final model = v['modelName']?.toString() ?? '';
    final plate = v['plateNumber']?.toString() ?? '';
    final name = '$make $model'.trim();
    final display = name.isEmpty ? (plate.isNotEmpty ? plate : 'Your car') : (plate.isNotEmpty ? '$name ($plate)' : name);
    final imgUrl = _vehicleImageUrl(v);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.creamElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.burntOrange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imgUrl.isNotEmpty
                ? Image.network(imgUrl, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _vehicleIconPlaceholder())
                : _vehicleIconPlaceholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your car', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.warmBrownMuted)),
                Text(display, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleIconPlaceholder() => Container(
    width: 64,
    height: 64,
    color: AppColors.burntOrange.withOpacity(0.1),
    child: Icon(Icons.directions_car, color: AppColors.burntOrange, size: 32),
  );

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Widget _buildServiceCard({
    required String title,
    required String iconPath,
    required int index,
    required VoidCallback onTap,
  }) {
    return Container(
              margin: const EdgeInsets.all(8),
              child: Material(
                color: AppColors.creamElevated,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 100,
                    height: 130,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.creamElevated,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Image.asset(
                              iconPath,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.build_circle_outlined,
                                size: 28,
                                color: AppColors.burntOrange,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
          'Car Services',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: () async { _loadUserCars(); },
          color: AppColors.burntOrange,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // User's Car at top
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _loadingCars
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.creamElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.burntOrange.withOpacity(0.2)),
                        ),
                        child: const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.burntOrange, strokeWidth: 2))),
                      )
                    : _userCars.isEmpty
                        ? Material(
                            color: AppColors.creamElevated,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () async {
                                if (_userEmail.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please sign in to add vehicle'), backgroundColor: AppColors.burntOrange),
                                  );
                                  return;
                                }
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEditVehiclePage(userEmail: _userEmail, initialVehicleType: 'CAR'),
                                  ),
                                );
                                _loadUserCars();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.burntOrange.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.burntOrange.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.directions_car, color: AppColors.burntOrange, size: 28),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Add car details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
                                          Text('Add your car to book services', style: GoogleFonts.inter(fontSize: 13, color: AppColors.warmBrownMuted)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.burntOrange),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : _buildVehicleCard(_userCars.first),
              ),
              const SizedBox(height: 16),
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
                child: _carServiceImageUrl != null && _carServiceImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          _carServiceImageUrl!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: _appLogoUrl != null && _appLogoUrl!.isNotEmpty
                                ? Image.network(_appLogoUrl!, height: 64, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.directions_car, size: 48, color: AppColors.creamElevated))
                                : Icon(Icons.directions_car, size: 48, color: AppColors.creamElevated),
                          ),
                        ),
                      )
                    : Center(
                        child: _appLogoUrl != null && _appLogoUrl!.isNotEmpty
                            ? Image.network(
                                _appLogoUrl!,
                                height: 64,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Icon(Icons.directions_car, size: 48, color: AppColors.creamElevated),
                              )
                            : Icon(Icons.directions_car, size: 48, color: AppColors.creamElevated),
                      ),
              ),

              // Services Grid
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available Services',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                        childAspectRatio: 0.77,
                      ),
                      itemCount: _carServices.length,
                      itemBuilder: (context, index) {
                        final service = _carServices[index];
                        final title = service['title']!;
                        return _buildServiceCard(
                          title: title,
                          iconPath: service['icon']!,
                          index: index,
                          onTap: () {
                            Widget? targetPage;
                            switch (title) {
                              case 'Towing': targetPage = const TowingServicePage(); break;
                              case 'Battery Jump': targetPage = const BatteryJumpPage(); break;
                              case 'Tyre Care': targetPage = const TyreCarePage(); break;
                              case 'Headlight Repair':
                              case 'Oil Change':
                              case 'Brake Service':
                              case 'Windshield':
                              case 'Body Works':
                              case 'Wheel Alignment':
                              case 'Suspension':
                                targetPage = MechanicsByServicePage(serviceTitle: title);
                                break;
                            }
                            if (title == 'EV Coming Soon') {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: const Text('Coming soon'),
                                  content: const Text('EV Charging will be available soon.'),
                                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                                ),
                              );
                              return;
                            }
                            if (targetPage != null) {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (context, animation, secondaryAnimation) => targetPage!,
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return SlideTransition(
                                      position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                      child: FadeTransition(opacity: animation, child: child),
                                    );
                                  },
                                  transitionDuration: const Duration(milliseconds: 400),
                                ),
                              );
                            } else {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                  content: Text('Professional ${title.toLowerCase()} service. Connect with mechanics from the Find Mechanic section.', style: GoogleFonts.inter()),
                                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
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
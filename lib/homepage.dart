import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'screens/mechanic/book_mechanic_flow_page.dart';
import 'screens/services/bike_battery_page.dart';
import 'screens/services/bike_tyre_care_page.dart';
import 'screens/services/mechanics_by_service_page.dart';
import 'screens/services/towing_service_page.dart';
import 'screens/services/battery_jump_page.dart';
import 'screens/ev_charging/ev_charging_page.dart';
import 'screens/services/fuel_refill_page.dart';
import 'screens/services/tyre_care_page.dart';
import 'screens/services/minor_repair_page.dart';
import 'screens/services/car_service_page.dart';
import 'screens/services/bike_service_page.dart';
import 'screens/mechanic/mechanic_finder_page.dart';
import 'widgets/vehicle_selection_sheet.dart';
import 'screens/services/map_service_page.dart';
import 'screens/services/night_service_page.dart';
import 'screens/profile/location_selection_page.dart';
import 'services/user_profile_service.dart';
import 'services/cognito_service.dart';
import 'emergency_assistance_page.dart';
import 'screens/vehicles/vehicles_page.dart';
import 'widgets/custom_nav_bar.dart';
import 'widgets/home_hero_overlay.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'services/api_config.dart';
import 'services/vehicle_service.dart';
import 'services/app_remote_service.dart';
import 'core/theme/app_colors.dart';

/// Material full-screen search (same pattern as Play Store / in-app search sheets).
class _HomeServiceSearchDelegate extends SearchDelegate<Object?> {
  final List<Map<String, dynamic>> services;

  _HomeServiceSearchDelegate(this.services);

  @override
  String get searchFieldLabel => 'Search services';

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;
    return [
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _list(context);

  @override
  Widget buildSuggestions(BuildContext context) => _list(context);

  Widget _list(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<Map<String, dynamic>>.from(services)
        : services
            .where((s) => s['name'].toString().toLowerCase().contains(q))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No services found',
                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Text(
                'Try another keyword',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final s = filtered[index];
        final icon = s['icon'] as IconData;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              close(context, null);
              Future.microtask(() => (s['route'] as void Function())());
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.creamElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.burntOrange.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.burntOrange.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.burntOrange, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s['name'].toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkChocolate,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.burntOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.22),
        hintStyle: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

// Global key to access HomePage state from other pages
final GlobalKey<_HomePageState> homePageKey = GlobalKey<_HomePageState>();

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late PageController _adPageController;
  /// Ad carousel page index — use [ValueNotifier] so auto-scroll does not rebuild the whole home screen.
  final ValueNotifier<int> _adPageIndex = ValueNotifier<int>(0);
  
  // Location variables
  String _currentLocation = 'Getting location...';
  // ignore: unused_field
  Position? _currentPosition;
  bool _isLoadingLocation = false;
  
  final List<Map<String, dynamic>> _allServices = [];

  // Carousel banners from API (null until loaded)
  List<Map<String, dynamic>>? _banners;

  // Show full-screen ad only on first app open (not when navigating back to homepage)
  static bool _openAdShownThisSession = false;
  bool _showOpenAd = false;

  // Default vehicle (e.g. for nearest mechanic vehicle filter)
  Map<String, dynamic>? _defaultVehicle;

  // Version check (show update dialog when updateAvailable)
  Map<String, dynamic>? _versionCheck;
  int _updateLaterCount = 0;
  String? _lastSeenAppVersion;

  // Home hero graphic (transparent Lottie/GIF on red header)
  String _homeHeroMediaType = '';
  String _homeHeroMediaUrl = '';
  bool _homeHeroActive = false;

  // App branding (quick service icon URLs from admin)
  Map<String, dynamic>? _branding;
  bool _brandingLoaded = false;

  /// After intro fade completes, drop [FadeTransition] so the scroll tree is not tied to an animation ticker.
  bool _homeIntroFadeDone = false;

  // Responsive design variables
  late double screenWidth;
  late double screenHeight;
  double _devicePixelRatio = 1.0;
  
  // Get profile image from SharedPreferences (S3 URL or local bytes). Used when profile icon is shown.
  // ignore: unused_element
  Future<({String? url, Uint8List? bytes})> _getProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('profilePhotoUrl');
      if (url != null && url.isNotEmpty) {
        return (url: url, bytes: null);
      }
      final imageBytesBase64 = prefs.getString('profileImageBytes');
      if (imageBytesBase64 != null) {
        return (url: null, bytes: base64Decode(imageBytesBase64));
      }
    } catch (e) {
      // If decoding fails, return null
    }
    return (url: null, bytes: null);
  }

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _adPageController = PageController(initialPage: 0);

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _homeIntroFadeDone = true);
      }
    });
    _fadeController.forward();
    
    // Auto-scroll ads
    _startAdAutoScroll();

    // Load branding first so quick service icons (S3) show without needing refresh
    _loadBranding();
    // Load default vehicle first, then banners (filtered by vehicle type)
    _loadDefaultVehicle();
    // Load home hero graphic config (transparent overlay on red header)
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHomeHeroConfig());
    // After first frame: check app version (show update dialog when needed)
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPosterAndVersion());

    // Load selected address from database first
    _loadSelectedAddress();
    // Ping activity for live users analytics
    _pingActivity();
    
    // Get current location (as fallback)
    _getCurrentLocation();
    
    // Initialize searchable services
    _initializeServices();
  }

  void _openServiceSearch() {
    showSearch<void>(
      context: context,
      delegate: _HomeServiceSearchDelegate(List<Map<String, dynamic>>.from(_allServices)),
    );
  }
  
  void _initializeServices() {
    _allServices.addAll([
      {'name': 'Emergency', 'icon': Icons.emergency, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyAssistancePage()))},
      {'name': 'Towing', 'icon': Icons.local_shipping, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TowingServicePage()))},
      {'name': 'Fuel Refill', 'icon': Icons.local_gas_station, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FuelRefillPage()))},
      {'name': 'EV Charging', 'icon': Icons.ev_station, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EVChargingPage()))},
      {'name': 'Tyre Care', 'icon': Icons.build, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TyreCarePage()))},
      {'name': 'General Repair', 'icon': Icons.handyman, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookMechanicFlowPage(preselectedProblemId: 'general_checkup')))},
      {'name': 'Battery Jump', 'icon': Icons.battery_charging_full, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BatteryJumpPage()))},
      {'name': 'Find Mechanic', 'icon': Icons.person_search, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MechanicFinderPage()))},
      {'name': 'Map Service', 'icon': Icons.map, 'route': () => _openMapService()},
      {'name': 'Night Service', 'icon': Icons.nightlight, 'route': () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NightServicePage()))},
    ]);
  }
  
  Future<void> _refreshHomePage() async {
    await _loadBranding();
    await _loadDefaultVehicle();
    await _loadBanners(_defaultVehicle?['type']?.toString());
    await _loadSelectedAddress();
    await _loadHomeHeroConfig();
    _pingActivity();
    if (mounted) setState(() {});
  }

  Future<void> _loadBranding() async {
    final m = await AppRemoteService.getAppBrandingConfig();
    if (mounted) setState(() {
      _branding = m;
      _brandingLoaded = true;
    });
  }

  /// Admin S3 URLs are usually absolute; allow relative paths from API.
  String? _resolveBrandingImageUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) return 'https:$s';
    final base = ApiConfig.baseUrl;
    if (s.startsWith('/')) return '$base$s';
    return '$base/$s';
  }

  Widget _nightServiceFallbackIcon(double size, bool isNightTime) {
    return Icon(
      Icons.nights_stay_rounded,
      size: size * 0.88,
      color: isNightTime ? AppColors.burntOrange : AppColors.darkChocolate.withOpacity(0.88),
    );
  }

  Future<void> _loadHomeHeroConfig() async {
    final config = await AppRemoteService.getHomeHeroMediaConfig();
    if (!mounted) return;
    setState(() {
      _homeHeroMediaType = config?['mediaType']?.toString() ?? '';
      _homeHeroMediaUrl = config?['mediaUrl']?.toString() ?? '';
      _homeHeroActive = config?['active'] == true;
    });
  }

  Future<void> _loadDefaultVehicle() async {
    final user = await CognitoService.getCurrentUser();
    final email = user['email']?.toString();
    if (email == null || email.isEmpty) {
      if (mounted) _loadBanners(null);
      return;
    }
    final list = await VehicleService.getMyVehicles(email);
    if (!mounted) return;
    Map<String, dynamic>? defaultOrFirst;
    if (list.isNotEmpty) {
      defaultOrFirst = list.firstWhere(
        (v) => v['isDefault'] == true,
        orElse: () => list.first,
      );
    }
    setState(() => _defaultVehicle = defaultOrFirst);
    _loadBanners(_defaultVehicle?['type']?.toString());
  }

  // ignore: unused_element
  Widget _vehiclePlaceholderIcon() {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.burntOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        (_defaultVehicle != null && (_defaultVehicle!['type'] ?? '').toString().toUpperCase() == 'BIKE')
            ? Icons.two_wheeler
            : Icons.directions_car,
        color: AppColors.burntOrange,
        size: 28,
      ),
    );
  }

  String _vehicleImageUrl(Map<String, dynamic> v) {
    final url = v['photoUrl'] ?? v['modelImageUrl'];
    if (url == null || url.toString().isEmpty) return '';
    final s = url.toString();
    if (s.startsWith('http')) return s;
    return '${ApiConfig.baseUrl}$s';
  }

  // ignore: unused_element
  Future<void> _showMyVehiclesSheet() async {
    final user = await CognitoService.getCurrentUser();
    final email = user['email']?.toString();
    if (email == null || email.isEmpty) {
      if (mounted) Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesPage()));
      return;
    }
    final list = await VehicleService.getMyVehicles(email);
    if (!mounted) return;
    if (list.isEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesPage()));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('My vehicles', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final v = list[i];
                  final imgUrl = _vehicleImageUrl(v);
                  final title = '${v['makeName'] ?? ''} ${v['modelName'] ?? ''}'.trim();
                  final plate = v['plateNumber']?.toString() ?? '';
                  final isBike = (v['type'] ?? '').toString().toUpperCase() == 'BIKE';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showVehicleDetailsSheet(v);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.warmBrownMuted),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.creamElevated,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.warmBrownMuted),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: imgUrl.isNotEmpty
                                    ? Image.network(imgUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(isBike ? Icons.two_wheeler : Icons.directions_car, color: AppColors.burntOrange, size: 32))
                                    : Icon(isBike ? Icons.two_wheeler : Icons.directions_car, color: AppColors.burntOrange, size: 32),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title.isNotEmpty ? title : 'Vehicle', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.darkChocolate)),
                                  if (plate.isNotEmpty) Text(plate, style: GoogleFonts.inter(fontSize: 13, color: AppColors.warmBrownMuted)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const VehiclesPage()));
                },
                icon: const Icon(Icons.settings, size: 20),
                label: Text('Manage vehicles', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleDetailsSheet(Map<String, dynamic> v) {
    final imgUrl = _vehicleImageUrl(v);
    final make = v['makeName']?.toString() ?? '';
    final model = v['modelName']?.toString() ?? '';
    final type = (v['type'] ?? '').toString().toUpperCase();
    final plate = v['plateNumber']?.toString() ?? '';
    final year = v['year']?.toString() ?? '';
    final isBike = type == 'BIKE';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.creamElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.warmBrownMuted),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imgUrl.isNotEmpty
                        ? Image.network(imgUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(isBike ? Icons.two_wheeler : Icons.directions_car, color: AppColors.burntOrange, size: 56))
                        : Icon(isBike ? Icons.two_wheeler : Icons.directions_car, color: AppColors.burntOrange, size: 56),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Vehicle details', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
              const SizedBox(height: 16),
              _detailRow('Type', type == 'CAR' ? 'Car' : 'Bike'),
              _detailRow('Make', make.isNotEmpty ? make : '—'),
              _detailRow('Model', model.isNotEmpty ? model : '—'),
              if (plate.isNotEmpty) _detailRow('Plate number', plate),
              if (year.isNotEmpty) _detailRow('Year', year),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _defaultVehicle = v);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text('Use this vehicle', style: GoogleFonts.outfit(color: AppColors.onBurntOrange, fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: GoogleFonts.outfit(fontSize: 14, color: AppColors.warmBrownMuted))),
          Expanded(child: Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.darkChocolate))),
        ],
      ),
    );
  }

  void _pingActivity() {
    CognitoService.getCurrentUser().then((user) {
      final email = user['email']?.toString().trim();
      if (email != null && email.isNotEmpty) {
        http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/person/activity'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email}),
        ).timeout(const Duration(seconds: 5)).ignore();
      }
    });
  }

  /// Load banners; [vehicleType] CAR or BIKE filters to car/bike + ALL, null = all only.
  Future<void> _loadBanners(String? vehicleType) async {
    try {
      final query = vehicleType != null && vehicleType.isNotEmpty
          ? '?targetType=${Uri.encodeComponent(vehicleType.toUpperCase())}'
          : '';
      final resp = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/banners$query')).timeout(const Duration(seconds: 5));
      if (mounted && resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List).cast<Map<String, dynamic>>();
        setState(() {
          _banners = list.isNotEmpty ? list : null;
          if (_banners != null && _adPageIndex.value >= _banners!.length) {
            _adPageIndex.value = 0;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (_adPageController.hasClients) _adPageController.jumpToPage(0);
            });
          }
          if (!_openAdShownThisSession) _showOpenAd = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _banners = null;
          if (!_openAdShownThisSession) _showOpenAd = true;
        });
      }
    }
  }

  int get _adCount => (_banners != null && _banners!.isNotEmpty) ? _banners!.length : 3;

  static const int _maxUpdateLaterCount = 10;

  Future<void> _checkPosterAndVersion() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    _updateLaterCount = prefs.getInt('update_later_count') ?? 0;
    _lastSeenAppVersion = prefs.getString('last_seen_app_version');

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    if (_lastSeenAppVersion != null && _lastSeenAppVersion != currentVersion) {
      _updateLaterCount = 0;
      await prefs.setInt('update_later_count', 0);
    }
    await prefs.setString('last_seen_app_version', currentVersion);

    final versionResp = await AppRemoteService.checkVersion(currentVersion);

    if (!mounted) return;
    setState(() {
      _versionCheck = versionResp;
    });

    if (_versionCheck != null && _versionCheck!['updateAvailable'] == true && mounted) {
      final mustUpdate = _updateLaterCount >= _maxUpdateLaterCount;
      _showUpdateDialog(mustUpdate, versionResp!, currentVersion, prefs);
    }
  }

  void _showUpdateDialog(bool mustUpdate, Map<String, dynamic> data, String currentVersion, SharedPreferences prefs) {
    final title = data['updateTitle']?.toString() ?? 'Update available';
    final message = data['updateMessage']?.toString() ?? 'A new version is available. Please update to continue.';
    showDialog(
      context: context,
      barrierDismissible: !mustUpdate,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          if (!mustUpdate)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                _updateLaterCount++;
                await prefs.setInt('update_later_count', _updateLaterCount);
              },
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Open store - you can add store URL from API later
              // url_launcher could open data['storeUrl']
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _startAdAutoScroll() {
    final count = _adCount;
    if (count == 0) return;
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      final next = (_adPageIndex.value + 1) % count;
      _adPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
      _startAdAutoScroll();
    });
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _adPageIndex.dispose();
    _adPageController.dispose();
    super.dispose();
  }

  void _showFindMechanicDialog() async {
    final userData = await CognitoService.getCurrentUser();
    final email = userData['email']?.toString() ?? '';
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => VehicleSelectionSheet(
        title: 'Book mechanic for',
        userEmail: email,
        parentContext: context,
        onSelectVehicle: (vehicle) {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookMechanicFlowPage(preselectedVehicle: vehicle),
            ),
          );
        },
        onAddVehicle: () {
          Navigator.pop(sheetContext);
          if (email.isNotEmpty) {
            showAddVehicleInBottomSheet(context, userEmail: email);
          }
        },
      ),
    );
  }

  void _showNearestMechanicVehicleChoice() async {
    final userData = await CognitoService.getCurrentUser();
    final email = userData['email']?.toString() ?? '';
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => VehicleSelectionSheet(
        title: 'Find mechanic for',
        userEmail: email,
        parentContext: context,
        onSelectVehicle: (vehicle) {
          Navigator.pop(sheetContext);
          final vehicleType = vehicle['type']?.toString();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MechanicFinderPage(vehicleType: vehicleType),
            ),
          );
        },
        onAddVehicle: () {
          Navigator.pop(sheetContext);
          if (email.isNotEmpty) {
            showAddVehicleInBottomSheet(context, userEmail: email);
          }
        },
      ),
    );
  }

  // Load selected address from database (user_addresses table) for top-left display
  Future<void> _loadSelectedAddress() async {
    try {
      final userData = await CognitoService.getCurrentUser();
      final email = userData['email'];

      if (email == null) {
        if (!mounted) return;
        setState(() => _currentLocation = 'Select your location');
        return;
      }

      // Get user's saved addresses (tries PersonController then UserAddressController)
      final result = await UserProfileService.getUserAddresses(email);

      if (!mounted) return;
      if (result['success'] == true && result['data'] != null) {
        final addresses = List<Map<String, dynamic>>.from(result['data']);
        if (addresses.isEmpty) {
          setState(() => _currentLocation = 'Tap to select location');
          return;
        }

        // Prefer address with isSelected == true; otherwise use first address
        Map<String, dynamic> selectedAddress = addresses.firstWhere(
          (addr) => addr['isSelected'] == true,
          orElse: () => addresses.first,
        );

        final label = selectedAddress['label'] ?? '';
        final addressText = selectedAddress['fullAddress'] ??
            selectedAddress['addressLine1'] ??
            '${selectedAddress['city'] ?? ''}, ${selectedAddress['state'] ?? ''}'.trim();
        final displayText = label.isNotEmpty
            ? '$label - $addressText'
            : addressText.isNotEmpty
                ? addressText
                : 'Location selected';

        setState(() => _currentLocation = displayText);
        return;
      }

      setState(() => _currentLocation = 'Tap to select location');
    } catch (e) {
      print('Error loading selected address: $e');
      if (!mounted) return;
      setState(() => _currentLocation = 'Tap to select location');
    }
  }

  Future<void> _getCurrentLocation() async {
    // Only use this as fallback if no address is selected
    // Don't override the selected address display
    
    // Check if we already have a selected address
    if (_currentLocation != 'Tap to select location' && 
        _currentLocation != 'Select your location' &&
        _currentLocation != 'Getting location...') {
      // Already have a selected address, don't override
      return;
    }

    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          if (_currentLocation == 'Tap to select location' || 
              _currentLocation == 'Select your location') {
            _currentLocation = 'Enable location services';
          }
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            if (_currentLocation == 'Tap to select location' || 
                _currentLocation == 'Select your location') {
              _currentLocation = 'Allow location access';
            }
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          if (_currentLocation == 'Tap to select location' || 
              _currentLocation == 'Select your location') {
            _currentLocation = 'Enable location in settings';
          }
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Convert coordinates to address text
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          List<String> addressParts = [];

          if (place.locality != null && place.locality!.isNotEmpty) {
            addressParts.add(place.locality!);
          }
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
            addressParts.add(place.administrativeArea!);
          }
          if (place.postalCode != null && place.postalCode!.isNotEmpty) {
            addressParts.add(place.postalCode!);
          }

          String addressText = addressParts.isNotEmpty 
              ? addressParts.join(', ')
              : 'Current location';

          setState(() {
            _currentPosition = position;
            // Only update if we don't have a selected address
            if (_currentLocation == 'Tap to select location' || 
                _currentLocation == 'Select your location' ||
                _currentLocation == 'Getting location...') {
              _currentLocation = addressText;
            }
            _isLoadingLocation = false;
          });
        } else {
          setState(() {
            _currentPosition = position;
            if (_currentLocation == 'Tap to select location' || 
                _currentLocation == 'Select your location') {
              _currentLocation = 'Current location';
            }
            _isLoadingLocation = false;
          });
        }
      } catch (e) {
        // If geocoding fails, show a default message
        setState(() {
          _currentPosition = position;
          if (_currentLocation == 'Tap to select location' || 
              _currentLocation == 'Select your location') {
            _currentLocation = 'Current location';
          }
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        if (_currentLocation == 'Tap to select location' || 
            _currentLocation == 'Select your location') {
          _currentLocation = 'Unable to get location';
        }
        _isLoadingLocation = false;
      });
    }
  }

  void _openMapService() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MapServicePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }


  static const List<Map<String, String>> _carServices = [
    {'title': 'Towing', 'icon': 'assets/icons/tow-truck.png'},
    {'title': 'EV Coming Soon', 'icon': 'assets/icons/charging-station.png'},
    {'title': 'Battery Jump', 'icon': 'assets/icons/jump-start.png'},
    {'title': 'Headlight Repair', 'icon': 'assets/icons/headlight.png'},
    {'title': 'Tyre Care', 'icon': 'assets/icons/punctured-tire.png'},
    {'title': 'Oil Change', 'icon': 'assets/icons/repair-tools.png'},
    {'title': 'Brake Service', 'icon': 'assets/icons/brake-service.png'},
    {'title': 'Windshield', 'icon': 'assets/icons/headlight.png'},
    {'title': 'Body Works', 'icon': 'assets/icons/smart-car.png'},
    {'title': 'Wheel Alignment', 'icon': 'assets/icons/wheel-alignment.png'},
    {'title': 'Suspension', 'icon': 'assets/icons/suspension.png'},
  ];

  static const List<Map<String, String>> _bikeServices = [
    {'title': 'Battery', 'icon': 'assets/icons/bike-battery.png'},
    {'title': 'Tyre Care', 'icon': 'assets/icons/bike-tyre.png'},
    {'title': 'Body Works', 'icon': 'assets/icons/bike-body-works.png'},
    {'title': 'Brake Service', 'icon': 'assets/icons/brake-service.png'},
    {'title': 'Towing', 'icon': 'assets/icons/tow-truck.png'},
    {'title': 'Windshield', 'icon': 'assets/icons/headlight.png'},
    {'title': 'EV Coming Soon', 'icon': 'assets/icons/charging-station.png'},
    {'title': 'Wheel Alignment', 'icon': 'assets/icons/bike-tyre.png'},
    {'title': 'Suspension', 'icon': 'assets/icons/new-bike-suspension.png'},
  ];

  void _pushPage(Widget page) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Widget _buildServiceGridTile({required String title, required String iconPath, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.burntOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Image.asset(
                    iconPath,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(Icons.build, size: 22, color: AppColors.burntOrange),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCategoryCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      shadowColor: AppColors.burntOrange.withOpacity(0.2),
      elevation: 4,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.burntOrange.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.burntOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.burntOrange),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildCarServicesGrid() {
    final crossAxisCount = screenWidth < 400 ? 3 : 4;
    final childAspectRatio = screenWidth < 400 ? 0.72 : 0.78;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: _carServices.length,
        itemBuilder: (context, index) {
          final s = _carServices[index];
          final title = s['title']!;
          final iconPath = s['icon']!;
          Widget? targetPage;
          switch (title) {
            case 'Minor Repair': targetPage = MinorRepairPage(); break;
            case 'Towing': targetPage = const TowingServicePage(); break;
            case 'Battery Jump': targetPage = const BatteryJumpPage(); break;
            case 'Tyre Care': targetPage = const TyreCarePage(); break;
          }
          return _buildServiceGridTile(
            title: title,
            iconPath: iconPath,
            onTap: () {
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
                _pushPage(targetPage);
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
    );
  }

  // ignore: unused_element
  Widget _buildBikeServicesGrid() {
    final crossAxisCount = screenWidth < 400 ? 3 : 4;
    final childAspectRatio = screenWidth < 400 ? 0.72 : 0.78;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: _bikeServices.length,
        itemBuilder: (context, index) {
          final s = _bikeServices[index];
          final title = s['title']!;
          final iconPath = s['icon']!;
          Widget? targetPage;
          switch (title) {
            case 'Battery': targetPage = const BikeBatteryPage(); break;
            case 'Tyre Care': targetPage = const BikeTyreCarePage(); break;
            case 'Brake Service': targetPage = MechanicsByServicePage(serviceTitle: title); break;
          }
          return _buildServiceGridTile(
            title: title,
            iconPath: iconPath,
            onTap: () {
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
                _pushPage(targetPage);
              } else {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                    content: Text('Professional ${title.toLowerCase()} for your bike. Connect with mechanics from the Find Mechanic section.', style: GoogleFonts.inter()),
                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }

  // ignore: unused_element
  Widget _buildServiceCard({
    required String title,
    required String subtitle,
    required String iconPath,
    required VoidCallback onTap,
    required int index,
  }) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _fadeAnimation.value) * 30),
          child: Opacity(
            opacity: _fadeAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Material(
                  color: Colors.white,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white,
                          Colors.grey.shade50,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.15),
                            shape: BoxShape.circle,
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
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
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

  // Dynamic Night Service Card - changes based on time
  Widget _buildDynamicNightServiceCard() {
    final now = DateTime.now();
    final hour = now.hour;
    final isNightTime = hour >= 20 || hour < 6; // 8 PM to 6 AM
    
    const double iconSize = 0.14; // same as other quick service icons
    final nightLogical = screenWidth * iconSize;
    final nightCachePx = (nightLogical * _devicePixelRatio).round().clamp(48, 256);
    final nightIconUrl = _resolveBrandingImageUrl(_branding?['quickServiceNightServiceIconUrl']?.toString());
    return Container(
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const NightServicePage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: nightIconUrl != null
                          ? Image.network(
                              nightIconUrl,
                              width: nightLogical,
                              height: nightLogical,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.low,
                              cacheWidth: nightCachePx,
                              cacheHeight: nightCachePx,
                              gaplessPlayback: true,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return SizedBox(
                                  width: nightLogical,
                                  height: nightLogical,
                                  child: Center(child: _nightServiceFallbackIcon(nightLogical, isNightTime)),
                                );
                              },
                              errorBuilder: (_, __, ___) => _nightServiceFallbackIcon(nightLogical, isNightTime),
                            )
                          : _nightServiceFallbackIcon(nightLogical, isNightTime),
                    ),
                    SizedBox(height: screenHeight * 0.008),
                    Flexible(
                      child: Text(
                        'Night Service',
                        style: GoogleFonts.outfit(
                          fontSize: screenWidth * 0.028,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkChocolate,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Night mode indicator badge
              if (isNightTime)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.burntOrange,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.burntOrange.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.nightlight,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'ACTIVE',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickServiceCard({
    required String title,
    required String iconPath,
    required Color color,
    required VoidCallback onTap,
    String? iconUrl,
  }) {
    final resolvedUrl = _resolveBrandingImageUrl(iconUrl);
    final useNetwork = resolvedUrl != null;
    const double iconSize = 0.14; // bigger icons (was 0.06 inside 0.12 circle)
    final iconLogicalPx = screenWidth * iconSize;
    final iconCachePx = (iconLogicalPx * _devicePixelRatio).round().clamp(48, 256);
    return Container(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.02),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: useNetwork
                      ? Image.network(
                          resolvedUrl,
                          width: iconLogicalPx,
                          height: iconLogicalPx,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.low,
                          cacheWidth: iconCachePx,
                          cacheHeight: iconCachePx,
                          gaplessPlayback: true,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Image.asset(iconPath, width: iconLogicalPx, height: iconLogicalPx, fit: BoxFit.contain);
                          },
                          errorBuilder: (_, __, ___) => Image.asset(iconPath, width: iconLogicalPx, height: iconLogicalPx, fit: BoxFit.contain),
                        )
                      : Image.asset(
                          iconPath,
                          width: iconLogicalPx,
                          height: iconLogicalPx,
                          fit: BoxFit.contain,
                        ),
                ),
                SizedBox(height: screenHeight * 0.008),
                Flexible(
                  child: Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth * 0.028,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkChocolate,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  /// Full-page smooth gradient: theme colors at top, soft transition to cream.
  /// Ensures aesthetic consistency and seamless integration with header and content.
  static BoxDecoration get _homePageBackgroundGradient => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.burntOrange,
            AppColors.burntOrange.withOpacity(0.95),
            AppColors.warmBrown.withOpacity(0.85),
            AppColors.cream.withOpacity(0.98),
            AppColors.cream,
          ],
          stops: const [0.0, 0.18, 0.45, 0.72, 1.0],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    screenWidth = mq.width;
    screenHeight = mq.height;
    _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          // Rounded, smooth full-page gradient (behind content)
          Positioned.fill(
            child: DecoratedBox(
              decoration: _homePageBackgroundGradient,
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refreshHomePage,
              color: AppColors.burntOrange,
              child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: AnimatedBuilder(
              animation: _fadeController,
              builder: (context, child) {
                if (_homeIntroFadeDone) return child!;
                return FadeTransition(opacity: _fadeAnimation, child: child!);
              },
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rounded, smooth header gradient — aligns with full-page gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.burntOrange,
                        AppColors.burntOrange.withOpacity(0.98),
                        AppColors.warmBrown.withOpacity(0.9),
                        AppColors.warmAmber.withOpacity(0.85),
                        AppColors.warmAmber.withOpacity(0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.burntOrange.withOpacity(0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      HomeHeroOverlay(
                        mediaType: _homeHeroMediaType,
                        mediaUrl: _homeHeroMediaUrl,
                        active: _homeHeroActive,
                      ),
                      Column(
                    children: [
                      // Top Bar with Location and Profile
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenHeight * 0.008,
                        ),
                        child: Row(
                          children: [
                            // Location Section
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LocationSelectionPage(),
                                      ),
                                    );
                                    _loadSelectedAddress();
                                  },
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _isLoadingLocation
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Icon(
                                                Icons.location_on_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _ScrollingLocationText(
                                            text: _currentLocation,
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.transparent,
                              child: Tooltip(
                                message: 'Search services',
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _openServiceSearch();
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(11),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.28),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.45),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.12),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.search_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Welcome Message
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          screenWidth * 0.04,
                          4,
                          screenWidth * 0.04,
                          6,
                        ),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hello! 👋',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'What service do you need today?',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withOpacity(0.95),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),


                // Sliding Advertisement Section - Colorful (RepaintBoundary: isolates layer work from rest of scroll view)
                RepaintBoundary(
                  child: Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: 8,
                    ),
                    height: 200,
                    child: PageView.builder(
                      controller: _adPageController,
                      onPageChanged: (index) {
                        _adPageIndex.value = index;
                      },
                      itemCount: _adCount,
                      itemBuilder: (context, index) {
                        return _buildAdCard(index);
                      },
                    ),
                  ),
                ),

                // Page Indicators — only this subtree rebuilds when the ad page changes
                ValueListenableBuilder<int>(
                  valueListenable: _adPageIndex,
                  builder: (context, current, _) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_adCount, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: current == index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: current == index ? AppColors.burntOrange : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: current == index
                                  ? [
                                      BoxShadow(
                                        color: AppColors.burntOrange.withOpacity(0.5),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),

                // Book Mechanic - same size as See nearest mechanic
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 6),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showFindMechanicDialog();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warmBrownMuted),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.burntOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.build_circle_rounded, color: AppColors.burntOrange, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Book Mechanic', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkChocolate)),
                                Text('At your location or get to place', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
                        ],
                      ),
                    ),
                  ),
                ),

                // See nearest mechanic - vehicle selection (same/different) then finder
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 6),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showNearestMechanicVehicleChoice();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.warmBrownMuted),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.burntOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: AppColors.burntOrange, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('See nearest mechanic', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkChocolate)),
                                Text('Find by vehicle • or request one', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[400], size: 22),
                        ],
                      ),
                    ),
                  ),
                ),

                // Quick Services
                Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.03, 
                    vertical: screenHeight * 0.01
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Services',
                        style: GoogleFonts.outfit(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkChocolate,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: _brandingLoaded
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  const crossAxisCount = 4;
                                  final spacingW = screenWidth * 0.015;
                                  final spacingH = screenHeight * 0.008;
                                  final maxW = constraints.maxWidth;
                                  final cellW = (maxW - spacingW * (crossAxisCount - 1)) / crossAxisCount;
                                  final cellH = cellW / 0.8;
                                  Widget cell(Widget w) => SizedBox(width: cellW, height: cellH, child: w);
                                  return Wrap(
                                    spacing: spacingW,
                                    runSpacing: spacingH,
                                    children: [
                                      cell(_buildDynamicNightServiceCard()),
                                      cell(_buildQuickServiceCard(
                              title: 'Towing',
                              iconPath: 'assets/icons/tow-truck.png',
                              color: AppColors.burntOrange,
                              iconUrl: _branding?['quickServiceTowingIconUrl']?.toString()?.trim(),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const TowingServicePage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        )),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    transitionDuration: const Duration(milliseconds: 400),
                                  ),
                                );
                              },
                            )),
                            cell(_buildQuickServiceCard(
                              title: 'Fuel Refill',
                              iconPath: 'assets/icons/fuel-station.png',
                              color: AppColors.burntOrange,
                              iconUrl: _branding?['quickServiceFuelRefillIconUrl']?.toString()?.trim(),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Coming soon'),
                                    content: const Text('Fuel Refill will be available soon.'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                                  ),
                                );
                              },
                            )),
                            cell(_buildQuickServiceCard(
                              title: 'EV Charging',
                              iconPath: 'assets/icons/charging-station.png',
                              color: AppColors.burntOrange,
                              iconUrl: _branding?['quickServiceEvChargingIconUrl']?.toString()?.trim(),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Coming soon'),
                                    content: const Text('EV Charging will be available soon.'),
                                    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
                                  ),
                                );
                              },
                            )),
                            cell(_buildQuickServiceCard(
                              title: 'Tyre Care',
                              iconPath: 'assets/icons/tyre.png',
                              color: AppColors.burntOrange,
                              iconUrl: _branding?['quickServiceTyreCareIconUrl']?.toString()?.trim(),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        const TyreCarePage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        )),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    transitionDuration: const Duration(milliseconds: 400),
                                  ),
                                );
                              },
                            )),
                            cell(_buildQuickServiceCard(
                              title: 'Minor Repair',
                              iconPath: 'assets/icons/repair-tools.png',
                              color: AppColors.burntOrange,
                              iconUrl: _branding?['quickServiceMinorRepairIconUrl']?.toString()?.trim(),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (context, animation, secondaryAnimation) =>
                                        MinorRepairPage(),
                                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                      return SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(1.0, 0.0),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        )),
                                        child: FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        ),
                                      );
                                    },
                                    transitionDuration: const Duration(milliseconds: 400),
                                  ),
                                );
                              },
                            )),
                            cell(_buildQuickServiceCard(
                             title: 'Battery Jump',
                             iconPath: 'assets/icons/jump-start.png',
                             color: AppColors.burntOrange,
                             iconUrl: _branding?['quickServiceBatteryJumpIconUrl']?.toString()?.trim(),
                             onTap: () {
                               Navigator.push(
                                 context,
                                 PageRouteBuilder(
                                   pageBuilder: (context, animation, secondaryAnimation) =>
                                       const BatteryJumpPage(),
                                   transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                     return SlideTransition(
                                       position: Tween<Offset>(
                                         begin: const Offset(1.0, 0.0),
                                         end: Offset.zero,
                                       ).animate(CurvedAnimation(
                                         parent: animation,
                                         curve: Curves.easeOutCubic,
                                       )),
                                       child: FadeTransition(
                                         opacity: animation,
                                         child: child,
                                       ),
                                     );
                                   },
                                   transitionDuration: const Duration(milliseconds: 400),
                                 ),
                               );
                             },
                            )),
                                    ],
                                  );
                                },
                              )
                            : SizedBox(
                                height: 200,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.burntOrange,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.015),
                                      Text(
                                        'Loading services...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
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
                // Main Services
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Our Services',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.burntOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Professional',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.burntOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Two icons: Car Services & Bike Services (tap to open full service page)
                      Row(
                        children: [
                          Expanded(
                            child: _buildServiceCategoryCard(
                              title: 'Car Services',
                              icon: Icons.directions_car_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CarServicePage()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildServiceCategoryCard(
                              title: 'Bike Services',
                              icon: Icons.two_wheeler_rounded,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const BikeServicePage()),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
          ),
        if (_showOpenAd) _buildOpenAdOverlay(),
        ],
      ),

      // Custom Floating Bottom Navigation Bar
      bottomNavigationBar: const CustomNavBar(currentIndex: 0),
    );
  }

  static final List<Map<String, dynamic>> _fallbackAds = [
    {
      'title': 'Emergency Roadside Assistance',
      'subtitle': '24/7 Support Available',
      'icon': Icons.emergency,
      'color': AppColors.burntOrange,
      'gradient': [AppColors.darkChocolate, AppColors.warmBrown, AppColors.burntOrange],
      'image': 'assets/icons/eva_on_road.png',
    },
    {
      'title': 'Premium Car Service',
      'subtitle': 'Expert Mechanics at Your Doorstep',
      'icon': Icons.build_circle,
      'color': AppColors.burntOrange,
      'gradient': [const Color(0xFF1A0F28), AppColors.warmBrown, AppColors.burntOrange],
      'image': 'assets/icons/luxcar.png',
    },
    {
      'title': 'EV Charging Network',
      'subtitle': 'Find Nearest Charging Stations',
      'icon': Icons.electric_car,
      'color': AppColors.burntOrange,
      'gradient': [AppColors.warmBrown, AppColors.darkChocolate, AppColors.burntOrange],
      'image': 'assets/icons/evnw.png',
    },
  ];

  String _resolveBannerImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}${url.startsWith('/') ? '' : '/'}$url';
  }

  /// Full-screen ad shown when user opens the app. Dismissible with Continue.
  Widget _buildOpenAdOverlay() {
    final List<Map<String, dynamic>> ads = (_banners != null && _banners!.isNotEmpty)
        ? _banners!
        : _fallbackAds;
    final ad = ads[0];
    final isFromApi = ad.containsKey('imageUrl');
    final String? rawImageUrl = ad['imageUrl'] as String?;
    final String bannerImageUrl = _resolveBannerImageUrl(rawImageUrl);
    final gradient = (ad['gradient'] as List<Color>?) ??
        [AppColors.darkChocolate, AppColors.warmBrown, AppColors.burntOrange];

    return Positioned.fill(
      child: Material(
        color: Colors.black87,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: isFromApi && bannerImageUrl.isNotEmpty
                      ? Image.network(
                          bannerImageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(child: Icon(Icons.campaign, size: 64, color: Colors.white70)),
                          ),
                        )
                      : Image.asset(
                          ad['image'] as String? ?? 'assets/icons/eva_on_road.png',
                          fit: BoxFit.contain,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Center(child: Icon(Icons.campaign, size: 64, color: Colors.white70)),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton.filled(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _HomePageState._openAdShownThisSession = true;
                  setState(() => _showOpenAd = false);
                },
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdCard(int index) {
    final List<Map<String, dynamic>> ads = (_banners != null && _banners!.isNotEmpty)
        ? _banners!
        : _fallbackAds;
    final ad = ads[index];
    final isFromApi = ad.containsKey('imageUrl');
    final String? rawImageUrl = ad['imageUrl'] as String?;
    final String bannerImageUrl = _resolveBannerImageUrl(rawImageUrl);
    final gradient = (ad['gradient'] as List<Color>?) ??
        [AppColors.darkChocolate, AppColors.warmBrown, AppColors.burntOrange];
    final color = ad['color'] as Color? ?? AppColors.burntOrange;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.35), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image (from API/local or asset)
            Positioned.fill(
              child: isFromApi && bannerImageUrl.isNotEmpty
                  ? Image.network(
                      bannerImageUrl,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.3),
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    )
                  : Image.asset(
                      ad['image'] as String? ?? 'assets/icons/eva_on_road.png',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.3),
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Strong dark scrim so carousel matches darker app chrome; text stays readable
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.52),
                      Colors.black.withOpacity(0.68),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // Content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Handle ad tap
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              (ad['title'] as String?) ?? 'Untitled',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.75),
                                    offset: const Offset(0, 2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (ad['subtitle'] as String?) ?? '',
                              style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.65),
                                    offset: const Offset(0, 1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }
}

// Scrolling Location Text Widget (Breaking News Style)
class _ScrollingLocationText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _ScrollingLocationText({
    required this.text,
    required this.style,
  });

  @override
  State<_ScrollingLocationText> createState() => _ScrollingLocationTextState();
}

class _ScrollingLocationTextState extends State<_ScrollingLocationText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _needsScrolling = false;
  double _textWidth = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20), // Smooth, slow scrolling
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.linear,
      ),
    );
  }

  void _checkIfScrollingNeeded(double containerWidth) {
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );
    textPainter.layout();
    _textWidth = textPainter.size.width;

    final needsScroll = _textWidth > containerWidth && containerWidth > 0;
    
    if (needsScroll != _needsScrolling) {
      setState(() {
        _needsScrolling = needsScroll;
      });
      
      if (_needsScrolling) {
        _controller.repeat(reverse: true); // Scroll left-right, then right-left
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void didUpdateWidget(_ScrollingLocationText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.reset();
      _needsScrolling = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerWidth = constraints.maxWidth;
        
        // Check if scrolling is needed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkIfScrollingNeeded(containerWidth);
        });

        if (!_needsScrolling || _textWidth <= containerWidth) {
          // Text fits, no scrolling needed
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }

        // Text overflows, show scrolling animation
        final scrollDistance = _textWidth - containerWidth + 30; // Add padding

        return ClipRect(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              // Calculate position: goes from 0 to scrollDistance and back
              double position;
              if (_animation.value < 0.5) {
                // First half: scroll left (text moves right, revealing end)
                position = _animation.value * 2 * scrollDistance;
              } else {
                // Second half: scroll right (text moves left, revealing start)
                position = (1 - (_animation.value - 0.5) * 2) * scrollDistance;
              }

              return Transform.translate(
                offset: Offset(-position, 0),
                child: Text(
                  widget.text,
                  style: widget.style,
                  maxLines: 1,
                  textAlign: TextAlign.left,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

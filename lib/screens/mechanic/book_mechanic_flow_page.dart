import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../data/book_mechanic_problems.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/payment/payment_config.dart';
import '../../services/payment/payment_gateway.dart';
import '../profile/location_picker_map_page.dart';
import '../../widgets/vehicle_selection_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../services/request_damage_upload_service.dart';
import 'book_mechanic_broadcast_tracking_page.dart';

/// Book Mechanic: vehicle → problem → details → photos → pickup + mechanics map → send → Rapido-style live map until accepted.
/// If [preselectedMechanicId] is set (from finder "Request mechanic"), flow sends after photos + pickup confirmation.
/// If [preselectedProblemId] is set (e.g. from Battery Jump or Tyre Care), problem is pre-selected and problem step is skipped.
/// If [preselectedVehicle] is set (e.g. from homepage Book mechanic / Find mechanic vehicle sheet), vehicle step is skipped.
class BookMechanicFlowPage extends StatefulWidget {
  final int? preselectedMechanicId;
  final String? preselectedProblemId;
  final Map<String, dynamic>? preselectedVehicle;
  /// When true (Night Service entry): mechanic list + broadcast only include mechanics with night time enabled.
  final bool nightServiceOnly;

  const BookMechanicFlowPage({
    super.key,
    this.preselectedMechanicId,
    this.preselectedProblemId,
    this.preselectedVehicle,
    this.nightServiceOnly = false,
  });

  @override
  State<BookMechanicFlowPage> createState() => _BookMechanicFlowPageState();
}

class _BookMechanicFlowPageState extends State<BookMechanicFlowPage> {
  int _step = 0;
  String? _userEmail;
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  String _vehicleType = 'CAR';
  ProblemItem? _selectedProblem;
  final TextEditingController _commentController = TextEditingController();
  final List<String> _photoUrls = [];
  Map<String, String> _diagnosticAnswers = {};
  List<Map<String, dynamic>> _mechanics = [];
  double? _userLat;
  double? _userLng;
  String _locationAddress = '';
  bool _loadingMechanics = false;
  bool _sendingRequest = false;
  Map<String, dynamic>? _createdRequest;
  late PaymentGateway _paymentGateway;
  Map<String, String> _problemIconUrlsCar = {};
  Map<String, String> _problemIconUrlsBike = {};

  static const double advanceAmount = 100.0;
  static const double platformFee = 9.0;
  static const double perKmCharge = 3.0;
  static const int freeKm = 5;

  @override
  void initState() {
    super.initState();
    _loadUserAndVehicles();
    _getCurrentLocation(showErrors: false);
    _loadProblemCategoryIcons();
    _paymentGateway = PaymentConfig.getPaymentGateway();
    _paymentGateway.initialize(context);
  }

  Future<void> _loadProblemCategoryIcons() async {
    try {
      final base = '${ApiConfig.baseUrl}/api/config/problem-category-icons';
      final carR = await http.get(Uri.parse('$base?vehicleType=CAR'), headers: {'Content-Type': 'application/json'});
      final bikeR = await http.get(Uri.parse('$base?vehicleType=BIKE'), headers: {'Content-Type': 'application/json'});
      if (!mounted) return;
      if (carR.statusCode == 200 && bikeR.statusCode == 200) {
        final carMap = Map<String, dynamic>.from(jsonDecode(carR.body) as Map);
        final bikeMap = Map<String, dynamic>.from(jsonDecode(bikeR.body) as Map);
        setState(() {
          _problemIconUrlsCar = carMap.map((k, v) => MapEntry(k, v?.toString() ?? ''));
          _problemIconUrlsBike = bikeMap.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        });
      }
    } catch (_) {}
  }

  String _normalizeProblemIconUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    if (s.startsWith('http')) return s;
    return '${ApiConfig.baseUrl}$s';
  }

  /// User vehicle photo or catalog model image; resolves relative API paths.
  String _vehiclePhotoUrl(Map<String, dynamic> v) {
    final url = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  String _problemIconUrlFor(ProblemItem p) {
    final map = _vehicleType.toUpperCase() == 'BIKE' ? _problemIconUrlsBike : _problemIconUrlsCar;
    final u = map[p.id];
    if (u == null || u.isEmpty) return '';
    return _normalizeProblemIconUrl(u);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _paymentGateway.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndVehicles() async {
    final user = await CognitoService.getCurrentUser();
    final email = user['email']?.toString();
    setState(() => _userEmail = email);
    if (email == null || email.isEmpty) return;
    final list = await VehicleService.getMyVehicles(email);
    if (!mounted) return;
    setState(() {
      _vehicles = list;
      if (widget.preselectedVehicle != null) {
        final id = widget.preselectedVehicle!['id'];
        _selectedVehicle = (id != null && list.any((v) => v['id'] == id))
            ? list.firstWhere((v) => v['id'] == id)
            : widget.preselectedVehicle;
        _step = widget.preselectedProblemId != null ? 2 : 1;
      } else {
        _selectedVehicle = list.isNotEmpty ? (list.firstWhere((v) => v['isDefault'] == true, orElse: () => list.first)) : null;
      }
      if (_selectedVehicle != null) _vehicleType = (_selectedVehicle!['type'] ?? 'CAR').toString().toUpperCase();
      if (widget.preselectedProblemId != null) {
        final problems = getProblemsForVehicle(_vehicleType);
        try {
          _selectedProblem = problems.firstWhere((p) => p.id == widget.preselectedProblemId);
        } catch (_) {
          _selectedProblem = null;
        }
      }
    });
  }

  Future<void> _getCurrentLocation({bool showErrors = true}) async {
    if (!mounted) return;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (showErrors && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location is disabled. Turn it on in your device settings, then try again.')),
          );
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (showErrors && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Allow location access to use your current position.')),
          );
        }
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showErrors && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turn on GPS/location services, then try again.')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      var address = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude)
            .timeout(const Duration(seconds: 12));
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
            if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
            if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
            if ((p.subAdministrativeArea ?? '').trim().isNotEmpty) p.subAdministrativeArea!.trim(),
            if ((p.administrativeArea ?? '').trim().isNotEmpty) p.administrativeArea!.trim(),
          ];
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _locationAddress = address;
      });
    } catch (e) {
      if (showErrors && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not get current location: $e')),
        );
      }
    }
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => _photoUrls.add(x.path));
  }

  List<ProblemItem> get _problems => getProblemsForVehicle(_vehicleType);

  bool get _isTyrePuncture => _selectedProblem?.id == 'tyre_puncture';
  bool get _photoRequired => false;

  /// Next: vehicle, details, photos only — pickup/mechanics step has its own CTA.
  bool _shouldShowBottomBar() {
    if (_step >= 4) return false;
    if (_step == 0) return _vehicles.isEmpty || _selectedVehicle != null || _vehicles.length >= 2;
    if (_step == 1) return false;
    return true;
  }

  Future<void> _nextStep() async {
    if (_step == 0 && _selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a vehicle or add one')));
      return;
    }
    if (_step == 1 && _selectedProblem == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a problem')));
      return;
    }
    if (_step == 2) {
      if (_photoRequired && _photoUrls.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a photo of the tyre/problem')));
        return;
      }
    }
    if (_step == 3) {
      await _getCurrentLocation();
      if (_userLat == null || _userLng == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turn on location or pick on map below')));
        }
        return;
      }
      if (widget.preselectedMechanicId == null) {
        _fetchMechanicsByCategory();
      }
      setState(() => _step = 4);
      return;
    }
    setState(() {
      if (_step == 0 && widget.preselectedProblemId != null) {
        _step = 2;
      } else {
        _step++;
      }
    });
  }

  Future<void> _sendRequestToPreselectedMechanic() async {
    if (_userEmail == null || _userLat == null || _userLng == null || _selectedProblem == null) return;
    final user = await CognitoService.getCurrentUser();
    final name = user['name']?.toString() ?? 'Customer';
    final phone = user['phone']?.toString() ?? '';
    setState(() => _sendingRequest = true);
    try {
      final uploadedUrls = _photoUrls.isNotEmpty
          ? await RequestDamageUploadService.uploadFiles(_photoUrls, _userEmail!)
          : <String>[];
      final body = {
        'mechanicId': widget.preselectedMechanicId,
        'customerName': name,
        'customerEmail': _userEmail,
        'customerPhone': phone,
        'userVehicleId': _selectedVehicle?['id'],
        'problemCategory': _selectedProblem?.id ?? 'general_checkup',
        'description': _selectedProblem?.label ?? 'General checkup',
        'diagnosticAnswers': jsonEncode(_diagnosticAnswers),
        'comment': _commentController.text.trim(),
        'photoUrls': uploadedUrls.isNotEmpty ? jsonEncode(uploadedUrls) : null,
        'latitude': _userLat.toString(),
        'longitude': _userLng.toString(),
        'amount': advanceAmount + platformFee,
        'advanceAmount': advanceAmount,
        'platformFee': platformFee,
        'requestRadiusKm': 5,
        if (widget.nightServiceOnly) 'nightServiceRequest': true,
      };
      final r = await http.post(
        Uri.parse(ApiConfig.mechanicRequestsEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (mounted) {
        setState(() => _sendingRequest = false);
        if (r.statusCode == 200 || r.statusCode == 201) {
          final created = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          setState(() => _createdRequest = created);
          _openLiveTracking(created);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send request')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _vehicleSummaryLine() {
    final v = _selectedVehicle;
    if (v == null) return '';
    return '${v['makeName'] ?? ''} ${v['modelName'] ?? ''} (${v['plateNumber'] ?? ''})'.trim();
  }

  String? _vehiclePhotoForTracking() {
    final v = _selectedVehicle;
    if (v == null) return null;
    final u = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
    if (u == null || u.trim().isEmpty) return null;
    return u.trim();
  }

  String _diagnosticSummaryLine() {
    if (_diagnosticAnswers.isEmpty) return '';
    String titleCase(String s) {
      if (s.isEmpty) return s;
      return s.split('_').map((w) {
        if (w.isEmpty) return w;
        return w[0].toUpperCase() + w.substring(1).toLowerCase();
      }).join(' ');
    }
    return _diagnosticAnswers.entries.map((e) => '${titleCase(e.key)}: ${e.value}').join(' · ');
  }

  void _openLiveTracking(Map<String, dynamic> created) {
    final id = created['id'];
    final rid = id is int ? id : int.tryParse(id?.toString() ?? '') ?? 0;
    if (!mounted || rid == 0 || _userLat == null || _userLng == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => BookMechanicBroadcastTrackingPage(
          requestId: rid,
          initialRequest: Map<String, dynamic>.from(created),
          userLat: _userLat!,
          userLng: _userLng!,
          isNightService: widget.nightServiceOnly,
          problemLabel: _selectedProblem?.label ?? 'Service',
          vehicleLine: _vehicleSummaryLine().isEmpty ? 'Your vehicle' : _vehicleSummaryLine(),
          commentLine: _commentController.text.trim(),
          vehiclePhotoUrl: _vehiclePhotoForTracking(),
          diagnosticLine: _diagnosticSummaryLine(),
          problemCategoryId: _selectedProblem?.id ?? '',
        ),
      ),
    );
  }

  Future<void> _pickLocationOnMap() async {
    final initial = _userLat != null && _userLng != null ? LatLng(_userLat!, _userLng!) : null;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerMapPage(initialPosition: initial, forMechanicShop: true),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _userLat = result['latitude'] as double?;
        _userLng = result['longitude'] as double?;
        _locationAddress = result['fullAddress']?.toString() ?? 'Selected location';
      });
    }
  }

  Future<void> _fetchMechanicsByCategory() async {
    if (_selectedProblem == null || _userLat == null || _userLng == null) return;
    setState(() => _loadingMechanics = true);
    try {
      final url = Uri.parse('${ApiConfig.mechanicEndpoint}/by-category').replace(
        queryParameters: {
          'problemCategory': _selectedProblem!.id,
          'lat': _userLat.toString(),
          'lng': _userLng.toString(),
          'radiusKm': '10',
          if (_vehicleType.isNotEmpty) 'vehicleType': _vehicleType,
          if (widget.nightServiceOnly) 'nightOnly': 'true',
        },
      );
      final r = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) setState(() { _mechanics = list; _loadingMechanics = false; });
      } else {
        if (mounted) setState(() { _mechanics = []; _loadingMechanics = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _mechanics = []; _loadingMechanics = false; });
    }
  }

  Future<void> _sendRequestToAll() async {
    if (_userEmail == null || _userLat == null || _userLng == null) return;
    final user = await CognitoService.getCurrentUser();
    final name = user['name']?.toString() ?? 'Customer';
    final phone = user['phone']?.toString() ?? '';
    setState(() => _sendingRequest = true);
    try {
      final uploadedUrls = _photoUrls.isNotEmpty
          ? await RequestDamageUploadService.uploadFiles(_photoUrls, _userEmail!)
          : <String>[];
      final body = {
        'customerName': name,
        'customerEmail': _userEmail,
        'customerPhone': phone,
        'userVehicleId': _selectedVehicle?['id'],
        'problemCategory': _selectedProblem?.id ?? 'general_checkup',
        'description': _selectedProblem?.label ?? 'General checkup',
        'diagnosticAnswers': jsonEncode(_diagnosticAnswers),
        'comment': _commentController.text.trim(),
        'photoUrls': uploadedUrls.isNotEmpty ? jsonEncode(uploadedUrls) : null,
        'latitude': _userLat,
        'longitude': _userLng,
        'advanceAmount': advanceAmount,
        'platformFee': platformFee,
        'comingChargePerKm': perKmCharge,
        'comingChargeTotal': 0.0,
        'requestRadiusKm': 5,
        if (widget.nightServiceOnly) 'nightServiceOnly': true,
      };
      final r = await http.post(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/broadcast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (mounted) {
        setState(() => _sendingRequest = false);
        if (r.statusCode == 200 || r.statusCode == 201) {
          final created = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          setState(() => _createdRequest = created);
          _openLiveTracking(created);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send request')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sendingRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showPaymentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RulesAndPaymentSheet(
        advanceAmount: advanceAmount,
        platformFee: platformFee,
        perKmCharge: perKmCharge,
        freeKm: freeKm,
        onAgreeAndPay: () {
          Navigator.pop(context);
          _doPayment();
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _doPayment() async {
    if (_createdRequest == null || _userEmail == null) return;
    final user = await CognitoService.getCurrentUser();
    final name = user['name']?.toString() ?? 'Customer';
    final phone = user['phone']?.toString() ?? '';
    final totalPay = advanceAmount + platformFee;
    await _paymentGateway.makePayment(
      amount: totalPay,
      orderId: 'book_${_createdRequest!['id']}_${DateTime.now().millisecondsSinceEpoch}',
      customerName: name,
      customerEmail: _userEmail!,
      customerPhone: phone,
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment done. Mechanic will reach you soon.')));
        Navigator.pop(context);
      },
      onFailure: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment failed: $e'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(
          _step == 0
              ? 'Select vehicle'
              : _step == 1
                  ? 'What\'s the problem?'
                  : _step == 2
                      ? 'Add details'
                      : _step == 3
                          ? 'Photos (optional)'
                          : 'Pickup & mechanics',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildStepContent(),
      bottomNavigationBar: _shouldShowBottomBar() ? _buildBottomBar() : null,
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            if (_step == 0 && _vehicles.isEmpty && _userEmail != null) {
              showAddVehicleInBottomSheet(context, userEmail: _userEmail!).then((_) {
                if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserAndVehicles());
              });
            } else {
              _nextStep();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.burntOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            _step == 0 && _vehicles.isEmpty ? 'Add vehicle' : 'Next',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildVehicleStep();
      case 1:
        return _buildProblemStep();
      case 2:
        return _buildDetailsStep();
      case 3:
        return _buildPhotoStep();
      case 4:
        return _buildMechanicsStep();
      default:
        return _buildMechanicsStep();
    }
  }

  void _showVehicleSelectionSheet() {
    if (_userEmail == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: false,
      builder: (sheetContext) => VehicleSelectionSheet(
        title: 'Select vehicle',
        userEmail: _userEmail!,
        parentContext: context,
        initialVehicles: _vehicles.isEmpty ? null : _vehicles,
        onSelectVehicle: (v) {
          Navigator.pop(sheetContext);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedVehicle = v;
              _vehicleType = (v['type'] ?? 'CAR').toString().toUpperCase();
            });
            if (_vehicles.length == 1) _advanceAfterVehicleSelection();
          });
        },
        onAddVehicle: () {
          Navigator.pop(sheetContext);
          showAddVehicleInBottomSheet(context, userEmail: _userEmail!).then((_) {
            if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserAndVehicles());
          });
        },
      ),
    );
  }

  Widget _buildVehicleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Which vehicle has broken down?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Choose the vehicle that needs service.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 20),
          if (_selectedVehicle != null) ...[
            Text('Selected vehicle', style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _buildSelectedVehicleCard(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: InkWell(
                onTap: _showVehicleSelectionSheet,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.burntOrange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 22, color: AppColors.burntOrange),
                      const SizedBox(width: 10),
                      Text(
                        'Change vehicle',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.burntOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else if (_vehicles.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('No vehicles added', style: GoogleFonts.inter(color: Colors.grey[700])),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_userEmail != null) {
                        showAddVehicleInBottomSheet(context, userEmail: _userEmail!).then((_) {
                          if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserAndVehicles());
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.burntOrange, foregroundColor: Colors.white),
                    icon: const Icon(Icons.add),
                    label: const Text('Add vehicle'),
                  ),
                ],
              ),
            )
          else
            Material(
              color: AppColors.creamElevated,
              borderRadius: BorderRadius.circular(16),
              elevation: 0,
              shadowColor: Colors.black.withValues(alpha: 0.06),
              child: InkWell(
                onTap: _showVehicleSelectionSheet,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.burntOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.directions_car, color: AppColors.burntOrange, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select vehicle', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600)),
                            Text('Tap to choose from your vehicles', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[500], size: 28),
                    ],
                  ),
                ),
              ),
            ),
          if (_vehicles.isNotEmpty && _selectedVehicle == null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                if (_userEmail != null) {
                  showAddVehicleInBottomSheet(context, userEmail: _userEmail!).then((_) {
                    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserAndVehicles());
                  });
                }
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add another vehicle'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedVehicleCard() {
    final v = _selectedVehicle!;
    final type = (v['type'] ?? 'CAR').toString().toUpperCase();
    final label = '${v['makeName'] ?? ''} ${v['modelName'] ?? ''} (${v['plateNumber'] ?? ''})'.trim();
    final imageUrl = _vehiclePhotoUrl(v);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.creamElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _vehicleIcon(type, 80))
                : _vehicleIcon(type, 80),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(type == 'BIKE' ? 'Bike' : 'Car', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: AppColors.burntOrange, size: 28),
        ],
      ),
    );
  }

  Widget _vehicleIcon(String type, double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.burntOrange.withValues(alpha: 0.15),
      child: Icon(type == 'BIKE' ? Icons.two_wheeler : Icons.directions_car, color: AppColors.burntOrange, size: size * 0.5),
    );
  }

  void _advanceAfterVehicleSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nextStep();
    });
  }

  void _advanceAfterProblemSelection() {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _nextStep();
    });
  }

  Widget _buildVehicleTile(Map<String, dynamic> v) {
    final isSelected = _selectedVehicle != null && v['id'] == _selectedVehicle!['id'];
    final type = (v['type'] ?? 'CAR').toString().toUpperCase();
    final label = '${v['makeName'] ?? ''} ${v['modelName'] ?? ''} (${v['plateNumber'] ?? ''})'.trim();
    final imageUrl = _vehiclePhotoUrl(v);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSelected ? AppColors.burntOrange.withValues(alpha: 0.08) : AppColors.creamElevated,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedVehicle = v;
              _vehicleType = type;
            });
            if (_vehicles.length == 1) _advanceAfterVehicleSelection();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _vehicleIcon(type, 56))
                      : _vehicleIcon(type, 56),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w600))),
                if (isSelected) Icon(Icons.check_circle, color: AppColors.burntOrange, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProblemStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What\'s the problem?', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
          const SizedBox(height: 6),
          Text('Select the issue that best describes your vehicle\'s condition.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 24),
          ...List.generate(_problems.length, (i) {
            final p = _problems[i];
            final isSelected = _selectedProblem?.id == p.id;
            final isGeneralCheckup = p.id == 'general_checkup';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isSelected ? AppColors.burntOrange.withValues(alpha: 0.1) : AppColors.creamElevated,
                borderRadius: BorderRadius.circular(16),
                elevation: isSelected ? 0 : 1,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedProblem = p);
                    _advanceAfterProblemSelection();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _problemIconUrlFor(p).isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _problemIconUrlFor(p),
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(p.icon, color: Colors.grey[500], size: 28),
                                  ),
                                )
                              : Icon(p.icon, color: Colors.grey[500], size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkChocolate)),
                              if (p.suggestion != null) ...[
                                const SizedBox(height: 6),
                                Text(p.suggestion!, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
                              ],
                              if (isGeneralCheckup) ...[
                                const SizedBox(height: 6),
                                Text('Mechanic will call you after you book the service.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.burntOrange, fontWeight: FontWeight.w500)),
                              ],
                            ],
                          ),
                        ),
                        if (isSelected) Icon(Icons.check_circle_rounded, color: AppColors.burntOrange, size: 28),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailsVehicleBanner() {
    final v = _selectedVehicle!;
    final type = (v['type'] ?? 'CAR').toString().toUpperCase();
    final imageUrl = _vehiclePhotoUrl(v);
    final title = '${v['makeName'] ?? ''} ${v['modelName'] ?? ''}'.trim();
    final plate = v['plateNumber']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.creamElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.22)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _vehicleIcon(type, 88),
                  )
                : _vehicleIcon(type, 88),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your vehicle', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  title.isEmpty ? (type == 'BIKE' ? 'Bike' : 'Car') : title,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
                ),
                if (plate.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(plate, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    final hasDiagnostic = _selectedProblem?.diagnosticQuestions != null && _selectedProblem!.diagnosticQuestions!.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add details', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
          const SizedBox(height: 6),
          Text('Answers help the mechanic prepare. You can add photos of damage in the next step.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          if (_selectedVehicle != null) ...[
            const SizedBox(height: 16),
            _buildDetailsVehicleBanner(),
          ],
          const SizedBox(height: 24),
          // Quick questions
          if (hasDiagnostic) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.creamElevated,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.help_outline_rounded, size: 22, color: AppColors.burntOrange),
                      const SizedBox(width: 10),
                      Text('Quick questions', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._selectedProblem!.diagnosticQuestions!.map((q) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.question, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: q.options.map((opt) {
                              final isSelected = _diagnosticAnswers[q.id] == opt;
                              return ChoiceChip(
                                label: Text(opt),
                                selected: isSelected,
                                onSelected: (sel) => setState(() => _diagnosticAnswers[q.id] = opt),
                                selectedColor: AppColors.burntOrange.withValues(alpha: 0.25),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          // 3. Description
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.creamElevated,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.notes_rounded, size: 22, color: AppColors.burntOrange),
                    const SizedBox(width: 10),
                    Text('More details (optional)', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'E.g. Front left tyre puncture, need repair',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add photo or video of vehicle damage', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
          const SizedBox(height: 8),
          Text('Optional. Helps the mechanic understand the issue before they arrive.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.creamElevated,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_photoUrls.isEmpty)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: AppColors.burntOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.35), width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: AppColors.burntOrange),
                          const SizedBox(height: 12),
                          Text('Add photo or video', style: GoogleFonts.outfit(fontSize: 16, color: AppColors.burntOrange, fontWeight: FontWeight.w600)),
                          Text('Tap to add (optional)', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photoUrls.length + 1,
                      itemBuilder: (context, i) {
                        if (i == _photoUrls.length) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 100,
                                decoration: BoxDecoration(
                                  color: AppColors.burntOrange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.add, size: 36, color: AppColors.burntOrange),
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.file(File(_photoUrls[i]), width: 100, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40)),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _photoUrls.removeAt(i)),
                                    child: const CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 18, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Next: confirm pickup on the map and request a mechanic.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMechanicsStep() {
    final preselected = widget.preselectedMechanicId != null;
    if (!preselected && _loadingMechanics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.burntOrange));
    }

    final markers = <Marker>{};
    if (_userLat != null && _userLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_userLat!, _userLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Pickup point'),
        ),
      );
    }
    var hueIdx = 0;
    for (final m in _mechanics) {
      final lat = double.tryParse(m['latitude']?.toString() ?? '');
      final lng = double.tryParse(m['longitude']?.toString() ?? '');
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('mc_${m['id']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange + (hueIdx++ % 6) * 6),
          infoWindow: InfoWindow(title: m['name']?.toString() ?? 'Mechanic'),
        ),
      );
    }

    Future<void> send() async {
      if (preselected) {
        await _sendRequestToPreselectedMechanic();
      } else {
        await _sendRequestToAll();
      }
    }

    return Stack(
      children: [
        if (_userLat != null && _userLng != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 240,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(_userLat!, _userLng!), zoom: 13),
              markers: markers,
              myLocationEnabled: true,
              padding: const EdgeInsets.only(bottom: 20),
            ),
          ),
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.38,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.creamElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
              ),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text('Double-check pickup', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _pickLocationOnMap,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.edit_location_alt, color: AppColors.burntOrange),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _locationAddress.isEmpty ? 'Tap to set on map' : _locationAddress,
                                style: GoogleFonts.inter(fontSize: 14),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.grey[600]),
                          ],
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.my_location, size: 20),
                    label: const Text('Use current location'),
                  ),
                  if (!preselected) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            _mechanics.isEmpty
                                ? 'No profiles in list — you can still broadcast nearby'
                                : 'Mechanics nearby (${_mechanics.length})',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_loadingMechanics || _sendingRequest)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.burntOrange),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_mechanics.isEmpty && !_loadingMechanics) ...[
                      OutlinedButton.icon(
                        onPressed: _fetchMechanicsByCategory,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text('Search nearby again'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.burntOrange),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ..._mechanics.map((m) {
                      final name = m['name'] ?? 'Mechanic';
                      final specialty = m['specialty'] ?? 'General';
                      final status = m['status']?.toString() ?? 'Available';
                      final isAvailable = status == 'Available';
                      return Opacity(
                        opacity: isAvailable ? 1.0 : 0.55,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isAvailable ? AppColors.burntOrange.withValues(alpha: 0.28) : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: AppColors.burntOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.engineering, color: AppColors.burntOrange, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15)),
                                      Text(specialty, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700])),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ] else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'We\'ll send this request to your selected mechanic.',
                        style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _sendingRequest ? null : () => send(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burntOrange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _sendingRequest
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(
                              preselected ? 'Send request to mechanic' : 'Request nearby mechanics',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _RulesAndPaymentSheet extends StatelessWidget {
  final double advanceAmount;
  final double platformFee;
  final double perKmCharge;
  final int freeKm;
  final VoidCallback onAgreeAndPay;
  final VoidCallback onCancel;

  const _RulesAndPaymentSheet({
    required this.advanceAmount,
    required this.platformFee,
    required this.perKmCharge,
    required this.freeKm,
    required this.onAgreeAndPay,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final total = advanceAmount + platformFee;
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).padding.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.creamElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rules & payment', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(
              '• ₹${advanceAmount.toStringAsFixed(0)} advance is mandatory (refunded after mechanic arrives and service is done or not done).\n'
              '• Platform fee ₹${platformFee.toStringAsFixed(0)} (HST included) is non-refundable.\n'
              '• Under $freeKm km: mechanic coming is free. Above $freeKm km: ₹${perKmCharge.toStringAsFixed(0)}/km will be charged.\n'
              '• Mechanic\'s service charges are paid on spot to the mechanic (not through app).',
              style: GoogleFonts.inter(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.burntOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Advance + Platform fee', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  Text('₹${total.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: AppColors.burntOrange),
                      foregroundColor: AppColors.burntOrange,
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAgreeAndPay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burntOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('I agree & pay', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
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

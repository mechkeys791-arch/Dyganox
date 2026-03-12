import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../../data/book_mechanic_problems.dart';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/payment/payment_config.dart';
import '../../services/payment/payment_gateway.dart';
import '../vehicles/add_edit_vehicle_page.dart';
import '../profile/location_picker_map_page.dart';
import '../../widgets/vehicle_selection_sheet.dart';
import '../../core/theme/app_colors.dart';
import 'mechanic_accepted_ready_page.dart';

/// Book Mechanic: vehicle → problem → details (photo compulsory for tyre) → location (map/current) → map + mechanics → send to all → wait → payment when accepted.
/// If [preselectedMechanicId] is set (from finder "Request mechanic"), flow sends to that mechanic only after location step.
/// If [preselectedProblemId] is set (e.g. from Battery Jump quick service), problem is pre-selected.
class BookMechanicFlowPage extends StatefulWidget {
  final int? preselectedMechanicId;
  final String? preselectedProblemId;

  const BookMechanicFlowPage({super.key, this.preselectedMechanicId, this.preselectedProblemId});

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
  bool _waitingForMechanic = false;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _waitingSecondsRemaining = 5 * 60; // 5 min
  late PaymentGateway _paymentGateway;
  Map<String, String> _problemIconUrls = {};

  static const double advanceAmount = 100.0;
  static const double platformFee = 9.0;
  static const double perKmCharge = 3.0;
  static const int freeKm = 5;

  @override
  void initState() {
    super.initState();
    _loadUserAndVehicles();
    _getCurrentLocation();
    _loadProblemCategoryIcons();
    _paymentGateway = PaymentConfig.getPaymentGateway();
    _paymentGateway.initialize(context);
  }

  Future<void> _loadProblemCategoryIcons() async {
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/config/problem-category-icons'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final map = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        setState(() {
          _problemIconUrls = map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
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
      _selectedVehicle = list.isNotEmpty ? (list.firstWhere((v) => v['isDefault'] == true, orElse: () => list.first)) : null;
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

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
        _locationAddress = 'Current location';
      });
    } catch (_) {}
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x != null && mounted) setState(() => _photoUrls.add(x.path));
  }

  List<ProblemItem> get _problems => getProblemsForVehicle(_vehicleType);

  bool get _isTyrePuncture => _selectedProblem?.id == 'tyre_puncture';
  bool get _photoRequired => _isTyrePuncture;

  /// Next button shown when user can proceed: step 0 (vehicle selected or add/select), steps 2–3.
  bool _shouldShowBottomBar() {
    if (_step >= 4) return false;
    if (_step == 0) return _vehicles.isEmpty || _selectedVehicle != null || _vehicles.length >= 2;
    if (_step == 1) return false;
    return true; // step 2 (details), step 3 (location)
  }

  void _nextStep() {
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
    if (_step == 3 && (_userLat == null || _userLng == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select your location or use current location')));
      return;
    }
    if (_step == 3) {
      if (widget.preselectedMechanicId != null) {
        _sendRequestToPreselectedMechanic();
        return;
      }
      _fetchMechanicsByCategory();
    }
    setState(() {
      _step++;
      if (_step == 1 && widget.preselectedProblemId != null && _selectedProblem != null) {
        _step = 2;
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
        'photoUrls': _photoUrls.isNotEmpty ? jsonEncode(_photoUrls) : null,
        'latitude': _userLat.toString(),
        'longitude': _userLng.toString(),
        'amount': advanceAmount + platformFee,
        'advanceAmount': advanceAmount,
        'platformFee': platformFee,
        'requestRadiusKm': 5,
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
          setState(() {
            _createdRequest = created;
            _waitingForMechanic = true;
            _waitingSecondsRemaining = 5 * 60;
            _startCountdownTimer();
          });
          _startPolling(created['id']);
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
          'radiusKm': '6',
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
      final body = {
        'customerName': name,
        'customerEmail': _userEmail,
        'customerPhone': phone,
        'userVehicleId': _selectedVehicle?['id'],
        'problemCategory': _selectedProblem?.id ?? 'general_checkup',
        'description': _selectedProblem?.label ?? 'General checkup',
        'diagnosticAnswers': jsonEncode(_diagnosticAnswers),
        'comment': _commentController.text.trim(),
        'photoUrls': _photoUrls.isNotEmpty ? jsonEncode(_photoUrls) : null,
        'latitude': _userLat,
        'longitude': _userLng,
        'advanceAmount': advanceAmount,
        'platformFee': platformFee,
        'comingChargePerKm': perKmCharge,
        'comingChargeTotal': 0.0,
        'requestRadiusKm': 5,
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
          setState(() {
            _createdRequest = created;
            _waitingForMechanic = true;
            _waitingSecondsRemaining = 5 * 60;
            _startCountdownTimer();
          });
          _startPolling(created['id']);
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

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_waitingSecondsRemaining <= 0) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        _cancelRequestAndGoHome();
        return;
      }
      setState(() => _waitingSecondsRemaining--);
    });
  }

  Future<void> _cancelRequestAndGoHome() async {
    if (_createdRequest == null) {
      if (mounted) _goHome('Request cancelled.');
      return;
    }
    try {
      await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/${_createdRequest!['id']}/cancel'),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (_) {}
    if (mounted) _goHome('No mechanic accepted in time. Request cancelled.');
  }

  void _goHome(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.orange));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _startPolling(dynamic requestId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final r = await http.get(
          Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$requestId'),
          headers: {'Content-Type': 'application/json'},
        );
        if (r.statusCode == 200) {
          final req = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
          final status = req['status']?.toString() ?? '';
          if (status == 'PENDING_PAYMENT') {
            _pollTimer?.cancel();
            _countdownTimer?.cancel();
            if (mounted) {
              setState(() => _waitingForMechanic = false);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MechanicAcceptedReadyPage(request: req)),
              );
            }
          }
          if (status == 'CANCELLED' || status == 'REJECTED') {
            _pollTimer?.cancel();
            _countdownTimer?.cancel();
          }
        }
      } catch (_) {}
    });
  }

  void _showPaymentSheet() {
    setState(() => _waitingForMechanic = false);
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
    if (_waitingForMechanic && _createdRequest != null) {
      return _buildWaitingScreen();
    }
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text(
          _step == 0 ? 'Select vehicle' : _step == 1 ? 'What\'s the problem?' : _step == 2 ? 'Add details' : _step == 3 ? 'Set location' : 'Mechanics nearby',
          style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildStepContent(),
      bottomNavigationBar: _shouldShowBottomBar() ? _buildBottomBar() : null,
    );
  }

  Widget _buildWaitingScreen() {
    final mins = _waitingSecondsRemaining ~/ 60;
    final secs = _waitingSecondsRemaining % 60;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(backgroundColor: AppColors.burntOrange, elevation: 0, title: Text('Request sent', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.1),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) => Transform.scale(scale: value, child: child),
                child: Icon(Icons.check_circle, size: 80, color: AppColors.burntOrange),
              ),
              const SizedBox(height: 24),
              Text(
                'Your request has been sent',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Waiting for a mechanic to accept...',
                style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.burntOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')} left',
                  style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.burntOrange),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'If no mechanic accepts in 5 min, request will be cancelled.',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.burntOrange)),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Back to home', style: GoogleFonts.outfit(color: AppColors.burntOrange, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            if (_step == 0 && _vehicles.isEmpty && _userEmail != null) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => AddEditVehiclePage(userEmail: _userEmail!),
              )).then((_) => _loadUserAndVehicles());
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
        return _buildLocationStep();
      case 4:
        return _buildMechanicsStep();
      default:
        return _buildMechanicsStep();
    }
  }

  void _showVehicleSelectionSheet() {
    if (_userEmail == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => VehicleSelectionSheet(
        title: 'Select vehicle',
        userEmail: _userEmail!,
        parentContext: context,
        initialVehicles: _vehicles.isEmpty ? null : _vehicles,
        onSelectVehicle: (v) {
          Navigator.pop(sheetContext);
          setState(() {
            _selectedVehicle = v;
            _vehicleType = (v['type'] ?? 'CAR').toString().toUpperCase();
          });
          if (_vehicles.length == 1) _advanceAfterVehicleSelection();
        },
        onAddVehicle: () {
          Navigator.pop(sheetContext);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddEditVehiclePage(userEmail: _userEmail!)),
          ).then((_) => _loadUserAndVehicles());
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
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => AddEditVehiclePage(userEmail: _userEmail!),
                        )).then((_) => _loadUserAndVehicles());
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
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) => AddEditVehiclePage(userEmail: _userEmail!),
                  )).then((_) => _loadUserAndVehicles());
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
    final imageUrl = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
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
            child: imageUrl != null && imageUrl.isNotEmpty
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
    final imageUrl = v['photoUrl']?.toString() ?? v['modelImageUrl']?.toString();
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
                  child: imageUrl != null && imageUrl.isNotEmpty
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.burntOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: _problemIconUrls[p.id] != null && _problemIconUrls[p.id]!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _problemIconUrls[p.id]!,
                                    width: 26,
                                    height: 26,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Icon(p.icon, color: AppColors.burntOrange, size: 26),
                                  ),
                                )
                              : Icon(p.icon, color: AppColors.burntOrange, size: 26),
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

  Widget _buildDetailsStep() {
    final hasDiagnostic = _selectedProblem?.diagnosticQuestions != null && _selectedProblem!.diagnosticQuestions!.isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add details', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate)),
          const SizedBox(height: 6),
          Text('Photos and answers help the mechanic prepare.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 24),
          // 1. Add photo — in a card
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
                    Icon(Icons.add_photo_alternate, size: 22, color: AppColors.burntOrange),
                    const SizedBox(width: 10),
                    Text(
                      _photoRequired ? 'Add photo (required)' : 'Add photo (optional)',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (_photoRequired) Text(' *', style: GoogleFonts.outfit(fontSize: 16, color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                if (_photoUrls.isEmpty)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 160,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.burntOrange.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.35), width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 48, color: AppColors.burntOrange),
                          const SizedBox(height: 10),
                          Text('Tap to add photo', style: GoogleFonts.outfit(fontSize: 14, color: AppColors.burntOrange, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 110,
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
                          padding: EdgeInsets.only(right: 10, left: i == 0 ? 0 : 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.file(File(_photoUrls[i]), width: 100, height: 110, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40)),
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
          // 2. Quick questions
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

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Where is the vehicle?', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Select on map or use current location so we can show nearby mechanics.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700])),
          if (_locationAddress.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.burntOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.burntOrange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.burntOrange, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_locationAddress, style: GoogleFonts.inter(fontSize: 14))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 20),
                  label: const Text('Use current location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickLocationOnMap,
                  icon: const Icon(Icons.map, size: 20),
                  label: const Text('Pick on map'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.burntOrange),
                    foregroundColor: AppColors.burntOrange,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicsStep() {
    if (_loadingMechanics) {
      return const Center(child: CircularProgressIndicator(color: AppColors.burntOrange));
    }
    if (_mechanics.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.engineering, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('No mechanics within 6 km for this problem.', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[700]), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('You can still send a request – we\'ll notify mechanics within 5 km.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _sendingRequest ? null : _sendRequestToAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.burntOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _sendingRequest
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Send request to nearby mechanics', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        if (_userLat != null && _userLng != null)
          SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: LatLng(_userLat!, _userLng!), zoom: 14),
              markers: {Marker(markerId: const MarkerId('me'), position: LatLng(_userLat!, _userLng!), icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure))},
              myLocationEnabled: true,
            ),
          ),
        DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.creamElevated,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4))],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Mechanics available (${_mechanics.length})', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _mechanics.length + 1,
                      itemBuilder: (context, i) {
                        if (i == _mechanics.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 24),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _sendingRequest ? null : _sendRequestToAll,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.burntOrange,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _sendingRequest
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text('Send request to nearby mechanics', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                              ),
                            ),
                          );
                        }
                        final m = _mechanics[i];
                        final name = m['name'] ?? 'Mechanic';
                        final specialty = m['specialty'] ?? 'General';
                        final status = m['status']?.toString() ?? 'Available';
                        final isAvailable = status == 'Available';
                        final availability = isAvailable ? 'Available' : (status == 'Offline' ? 'Offline' : 'Busy');
                        return Opacity(
                          opacity: isAvailable ? 1.0 : 0.5,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cream,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isAvailable ? AppColors.burntOrange.withValues(alpha: 0.3) : Colors.grey.shade200),
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
                                        Text(availability, style: GoogleFonts.inter(fontSize: 12, color: isAvailable ? AppColors.burntOrange : Colors.grey)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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

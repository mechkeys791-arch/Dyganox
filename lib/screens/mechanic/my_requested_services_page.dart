import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';
import '../../services/payment/payment_config.dart';
import '../../services/payment/payment_gateway.dart';
import 'book_mechanic_flow_page.dart';

// Teal theme - no purple
import '../../core/theme/app_colors.dart';

/// Lists user's mechanic requests: Pending, Accepted, Rejected, Cancelled. Cancel for pending; Pay when accepted.
class MyRequestedServicesPage extends StatefulWidget {
  const MyRequestedServicesPage({super.key});

  @override
  State<MyRequestedServicesPage> createState() => _MyRequestedServicesPageState();
}

class _MyRequestedServicesPageState extends State<MyRequestedServicesPage> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _userEmail;
  late PaymentGateway _paymentGateway;

  @override
  void initState() {
    super.initState();
    _paymentGateway = PaymentConfig.getPaymentGateway();
    _paymentGateway.initialize(context);
    _loadUserAndRequests();
  }

  @override
  void dispose() {
    _paymentGateway.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndRequests() async {
    final user = await CognitoService.getCurrentUser();
    final email = user['email']?.toString();
    setState(() { _userEmail = email; _loading = true; });
    if (email == null || email.isEmpty) {
      setState(() { _requests = []; _loading = false; });
      return;
    }
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/customer/${Uri.encodeComponent(email)}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final list = (jsonDecode(r.body) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        setState(() { _requests = list; _loading = false; });
      } else {
        setState(() { _requests = []; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _requests = []; _loading = false; });
    }
  }

  Future<void> _cancelRequest(int requestId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text('This request will be cancelled. Nearby mechanics will no longer see it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$requestId/cancel'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled')));
        _loadUserAndRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${r.body}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _payNow(Map<String, dynamic> req) async {
    final user = await CognitoService.getCurrentUser();
    final name = user['name']?.toString() ?? 'Customer';
    final phone = user['phone']?.toString() ?? '';
    const advance = 100.0;
    const platformFee = 9.0;
    await _paymentGateway.makePayment(
      amount: advance + platformFee,
      orderId: 'book_${req['id']}_${DateTime.now().millisecondsSinceEpoch}',
      customerName: name,
      customerEmail: _userEmail ?? '',
      customerPhone: phone,
      onSuccess: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment done. Mechanic will reach you soon.')));
        _loadUserAndRequests();
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
        title: Text('My requested services', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burntOrange))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No mechanic requests yet', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey[700])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadUserAndRequests,
                  color: AppColors.burntOrange,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, i) {
                      final r = _requests[i];
                      return _RequestCard(
                        request: r,
                        onCancel: () => _cancelRequest(r['id'] as int),
                        onPay: () => _payNow(r),
                        onTapAccepted: () async {
                          final status = r['status']?.toString() ?? '';
                          if (status == 'PENDING_PAYMENT' || status == 'COMPLETED') {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => _MechanicAcceptedDetailPage(request: r, onRated: _loadUserAndRequests),
                            ));
                            _loadUserAndRequests();
                          }
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onCancel;
  final VoidCallback onPay;
  final VoidCallback? onTapAccepted;

  const _RequestCard({required this.request, required this.onCancel, required this.onPay, this.onTapAccepted});

  @override
  Widget build(BuildContext context) {
    final status = request['status']?.toString() ?? 'PENDING_BROADCAST';
    final problem = request['problemCategory'] ?? request['serviceType'] ?? 'Service';
    final vehicle = '${request['vehicleMakeName'] ?? ''} ${request['vehicleModelName'] ?? ''}'.trim();
    final createdAt = request['createdAt'] ?? request['requestTime']?.toString() ?? '';
    final isPending = status == 'PENDING_BROADCAST';
    final isAccepted = status == 'PENDING_PAYMENT';
    final isCancelled = status == 'CANCELLED';
    final isRejected = status == 'REJECTED';
    final isCompleted = status == 'COMPLETED';

    Color statusColor = Colors.orange;
    String statusText = 'Pending';
    if (isAccepted) {
      statusColor = AppColors.burntOrange;
      statusText = 'Mechanic accepted – Pay now';
    } else if (isPending) {
      statusColor = Colors.orange;
      statusText = 'Waiting for mechanic';
    } else if (isCancelled) {
      statusColor = Colors.grey;
      statusText = 'Cancelled';
    } else if (isRejected) {
      statusColor = Colors.red;
      statusText = 'Rejected';
    } else if (isCompleted) {
      statusColor = AppColors.warmAmber;
      statusText = 'Completed';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.creamElevated,
      child: InkWell(
        onTap: (isAccepted || isCompleted) ? onTapAccepted : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.burntOrange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.build_circle, color: AppColors.burntOrange, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(problem, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 16)),
                      if (vehicle.isNotEmpty) Text(vehicle, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text(statusText, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            if (createdAt.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(createdAt.length > 19 ? createdAt.substring(0, 19) : createdAt, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
            ],
            if (isPending || isAccepted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isPending)
                    TextButton(
                      onPressed: onCancel,
                      child: Text('Cancel request', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.w600)),
                    ),
                  if (isAccepted) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onPay,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.burntOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text('Pay now', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

/// Shows "Mechanic will contact you shortly", problem description, and static map with mechanic location (Zomato/Swiggy style).
class _MechanicAcceptedDetailPage extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback? onRated;

  const _MechanicAcceptedDetailPage({required this.request, this.onRated});

  @override
  State<_MechanicAcceptedDetailPage> createState() => _MechanicAcceptedDetailPageState();
}

class _MechanicAcceptedDetailPageState extends State<_MechanicAcceptedDetailPage> {
  double? _mechanicLat;
  double? _mechanicLng;
  bool _loading = true;
  bool _ratingSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadMechanicLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.request['status']?.toString() == 'COMPLETED' &&
          widget.request['customerRating'] == null &&
          !_ratingSubmitted) {
        _showRatingDialog();
      }
    });
  }

  Future<void> _showRatingDialog() async {
    final selectedStars = [5];
    final commentController = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Rate your mechanic',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final star = i + 1;
                      return IconButton(
                        icon: Icon(
                          star <= selectedStars[0] ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 40,
                        ),
                        onPressed: () => setSheetState(() => selectedStars[0] = star),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Optional feedback',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _submitRating(selectedStars[0].toDouble(), commentController.text);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.burntOrange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Submit rating', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitRating(double rating, String comment) async {
    final id = widget.request['id'];
    if (id == null) return;
    try {
      final r = await http.put(
        Uri.parse('${ApiConfig.mechanicRequestsEndpoint}/$id/rate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rating': rating, 'comment': comment.trim().isEmpty ? null : comment}),
      );
      if (mounted) {
        setState(() => _ratingSubmitted = true);
        if (r.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thank you for your rating!'), backgroundColor: AppColors.warmAmber, behavior: SnackBarBehavior.floating),
          );
          widget.onRated?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not submit rating'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _loadMechanicLocation() async {
    final mechanicId = widget.request['acceptedMechanicId'];
    if (mechanicId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final r = await http.get(
        Uri.parse('${ApiConfig.mechanicEndpoint}/$mechanicId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (r.statusCode == 200 && mounted) {
        final m = jsonDecode(r.body) as Map<String, dynamic>;
        final lat = double.tryParse(m['latitude']?.toString() ?? '');
        final lng = double.tryParse(m['longitude']?.toString() ?? '');
        setState(() { _mechanicLat = lat; _mechanicLng = lng; _loading = false; });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final custLat = double.tryParse(r['latitude']?.toString() ?? '');
    final custLng = double.tryParse(r['longitude']?.toString() ?? '');
    final problem = r['problemCategory'] ?? r['serviceType'] ?? 'Service';
    final description = r['description'] ?? r['comment'] ?? '';

    final hasMap = (custLat != null && custLng != null) || (_mechanicLat != null && _mechanicLng != null);
    final centerLat = _mechanicLat ?? custLat ?? 12.97;
    final centerLng = _mechanicLng ?? custLng ?? 77.59;

    Set<Marker> markers = {};
    if (custLat != null && custLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('you'),
        position: LatLng(custLat, custLng),
        infoWindow: const InfoWindow(title: 'Your location'),
      ));
    }
    if (_mechanicLat != null && _mechanicLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('mechanic'),
        position: LatLng(_mechanicLat!, _mechanicLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Mechanic'),
      ));
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Text('Request details', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: AppColors.burntOrange, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Mechanic will contact you shortly',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.darkChocolate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Describe the problem so the mechanic can prepare:',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.creamElevated,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Text(description.isNotEmpty ? description : problem, style: GoogleFonts.inter(fontSize: 14)),
                  ),
                ],
              ),
            ),
            if (hasMap) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Mechanic location', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: AppColors.burntOrange))
                    : GoogleMap(
                        initialCameraPosition: CameraPosition(target: LatLng(centerLat, centerLng), zoom: 14),
                        markers: markers,
                        myLocationEnabled: true,
                        zoomControlsEnabled: false,
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

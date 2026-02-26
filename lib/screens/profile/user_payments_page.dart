import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';

import '../../core/theme/app_colors.dart';

/// User Payment Section: lists successful and other payments for the logged-in user.
class UserPaymentsPage extends StatefulWidget {
  const UserPaymentsPage({super.key});

  @override
  State<UserPaymentsPage> createState() => _UserPaymentsPageState();
}

class _UserPaymentsPageState extends State<UserPaymentsPage> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final user = await CognitoService.getCurrentUser();
    final email = user['email']?.toString();
    if (email == null || email.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please log in to see your payments.';
      });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final url = Uri.parse('${ApiConfig.squarePaymentEndpoint}/user').replace(
        queryParameters: {'email': email},
      );
      final r = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (r.statusCode == 200) {
        final list = (jsonDecode(r.body) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        if (mounted) setState(() { _payments = list; _loading = false; });
      } else {
        if (mounted) setState(() { _payments = []; _loading = false; _error = 'Could not load payments.'; });
      }
    } catch (e) {
      if (mounted) setState(() { _payments = []; _loading = false; _error = 'Network error.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.burntOrange,
        elevation: 0,
        title: Text('Payment history', style: GoogleFonts.outfit(color: AppColors.onBurntOrange, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onBurntOrange),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.burntOrange))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 56, color: AppColors.warmBrownMuted),
                        const SizedBox(height: 16),
                        Text(_error!, style: GoogleFonts.inter(color: AppColors.warmBrownMuted), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _loadPayments,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long, size: 64, color: AppColors.warmBrownMuted),
                          const SizedBox(height: 16),
                          Text('No payments yet', style: GoogleFonts.outfit(fontSize: 18, color: AppColors.warmBrownMuted)),
                          const SizedBox(height: 8),
                          Text('Your successful and other payments will appear here.', style: GoogleFonts.inter(fontSize: 14, color: AppColors.warmBrownMuted), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPayments,
                      color: AppColors.burntOrange,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _payments.length,
                        itemBuilder: (context, i) {
                          final p = _payments[i];
                          final status = p['status']?.toString() ?? '—';
                          final amount = (p['amount'] is num) ? (p['amount'] as num).toDouble() : 0.0;
                          final currency = p['currency']?.toString() ?? 'INR';
                          final orderId = p['orderId']?.toString() ?? '—';
                          final createdAt = p['createdAt']?.toString();
                          final completedAt = p['completedAt']?.toString();
                          final isSuccess = status.toUpperCase() == 'SUCCESS';
                          final isFailed = status.toUpperCase() == 'FAILED';
                          final isCancelled = status.toUpperCase() == 'CANCELLED';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              leading: CircleAvatar(
                                backgroundColor: isSuccess ? AppColors.burntOrange.withValues(alpha: 0.2) : (isFailed || isCancelled) ? AppColors.errorRed.withValues(alpha: 0.2) : AppColors.warmBrownMuted.withValues(alpha: 0.2),
                                child: Icon(
                                  isSuccess ? Icons.check_circle : (isFailed || isCancelled) ? Icons.cancel : Icons.schedule,
                                  color: isSuccess ? AppColors.burntOrange : (isFailed || isCancelled) ? AppColors.errorRed : AppColors.warmBrownMuted,
                                ),
                              ),
                              title: Text(
                                '₹${amount.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Text(
                                '${orderId.isNotEmpty ? orderId : "Payment"} • ${status}',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.warmBrownMuted),
                              ),
                              trailing: Text(
                                completedAt != null && completedAt.isNotEmpty ? _formatDate(completedAt) : (createdAt != null ? _formatDate(createdAt) : ''),
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.warmBrownMuted),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.tryParse(iso);
      if (dt != null) return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {}
    return iso;
  }
}

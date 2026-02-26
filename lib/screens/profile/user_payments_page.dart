import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/cognito_service.dart';

const _primary = Color(0xFF0D9488);
const _cardBg = Color(0xFFFFFFFF);
const _surface = Color(0xFFF0FDFA);

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
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        title: Text('Payment history', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 56, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(_error!, style: GoogleFonts.inter(color: Colors.grey[700]), textAlign: TextAlign.center),
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
                          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No payments yet', style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[700])),
                          const SizedBox(height: 8),
                          Text('Your successful and other payments will appear here.', style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPayments,
                      color: _primary,
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
                                backgroundColor: isSuccess ? _primary.withValues(alpha: 0.2) : (isFailed || isCancelled) ? Colors.red.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                                child: Icon(
                                  isSuccess ? Icons.check_circle : (isFailed || isCancelled) ? Icons.cancel : Icons.schedule,
                                  color: isSuccess ? _primary : (isFailed || isCancelled) ? Colors.red : Colors.grey,
                                ),
                              ),
                              title: Text(
                                '₹${amount.toStringAsFixed(0)}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                              subtitle: Text(
                                '${orderId.isNotEmpty ? orderId : "Payment"} • ${status}',
                                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                              ),
                              trailing: Text(
                                completedAt != null && completedAt.isNotEmpty ? _formatDate(completedAt) : (createdAt != null ? _formatDate(createdAt) : ''),
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
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

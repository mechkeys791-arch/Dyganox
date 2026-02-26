import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  List<Map<String, dynamic>> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final String? paymentMethodsJson = prefs.getString('payment_methods');
    if (paymentMethodsJson != null) {
      setState(() {
        _paymentMethods = List<Map<String, dynamic>>.from(json.decode(paymentMethodsJson));
      });
    }
  }

  Future<void> _savePaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_methods', json.encode(_paymentMethods));
  }

  void _showAddEditPaymentDialog({Map<String, dynamic>? payment, int? index}) {
    final labelController = TextEditingController(text: payment?['label'] ?? '');
    final detailsController = TextEditingController(text: payment?['details'] ?? '');
    String selectedType = payment?['type'] ?? 'card';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.burntOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  payment == null ? Icons.add : Icons.edit,
                  color: AppColors.burntOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                payment == null ? 'Add Payment Method' : 'Edit Payment Method',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Payment Type',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'card', child: Text('Credit/Debit Card')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'netbanking', child: Text('Net Banking')),
                    DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  ],
                  onChanged: (value) {
                    setDialogState(() {
                      selectedType = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: labelController,
                  decoration: InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g., My HDFC Card',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  decoration: InputDecoration(
                    labelText: _getDetailsLabel(selectedType),
                    hintText: _getDetailsHint(selectedType),
                    prefixIcon: const Icon(Icons.payment),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: AppColors.warmBrownMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (labelController.text.isNotEmpty && detailsController.text.isNotEmpty) {
                  setState(() {
                    if (index != null) {
                      _paymentMethods[index] = {
                        'label': labelController.text,
                        'details': detailsController.text,
                        'type': selectedType,
                      };
                    } else {
                      _paymentMethods.add({
                        'label': labelController.text,
                        'details': detailsController.text,
                        'type': selectedType,
                      });
                    }
                  });
                  _savePaymentMethods();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        payment == null
                            ? 'Payment method added successfully!'
                            : 'Payment method updated successfully!',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please fill all fields',
                        style: GoogleFonts.inter(color: Colors.white),
                      ),
                      backgroundColor: AppColors.errorRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.burntOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                payment == null ? 'Add' : 'Update',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDetailsLabel(String type) {
    switch (type) {
      case 'card':
        return 'Card Number';
      case 'upi':
        return 'UPI ID';
      case 'netbanking':
        return 'Account Number';
      case 'wallet':
        return 'Wallet ID';
      default:
        return 'Details';
    }
  }

  String _getDetailsHint(String type) {
    switch (type) {
      case 'card':
        return 'Last 4 digits (e.g., 1234)';
      case 'upi':
        return 'e.g., name@bank';
      case 'netbanking':
        return 'Last 4 digits';
      case 'wallet':
        return 'e.g., 9876543210';
      default:
        return '';
    }
  }

  void _deletePaymentMethod(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete, color: AppColors.errorRed, size: 20),
            ),
            const SizedBox(width: 12),
            Text('Delete Payment Method', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this payment method?',
          style: GoogleFonts.inter(color: AppColors.warmBrownMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.warmBrownMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _paymentMethods.removeAt(index);
              });
              _savePaymentMethods();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Payment method deleted successfully!',
                      style: GoogleFonts.inter(color: Colors.white)),
                  backgroundColor: AppColors.errorRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getPaymentIcon(String type) {
    switch (type) {
      case 'card':
        return Icons.credit_card;
      case 'upi':
        return Icons.account_balance_wallet;
      case 'netbanking':
        return Icons.account_balance;
      case 'wallet':
        return Icons.wallet;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentTypeName(String type) {
    switch (type) {
      case 'card':
        return 'Card';
      case 'upi':
        return 'UPI';
      case 'netbanking':
        return 'Net Banking';
      case 'wallet':
        return 'Wallet';
      default:
        return type;
    }
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
              color: Colors.white,
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
          'Payment Methods',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.creamElevated.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.payment_outlined,
                size: 80,
                color: Colors.orange[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payments Disabled',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.warmBrownMuted,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Payment functionality is currently disabled in the system. Bookings can be made without payment.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.warmBrownMuted,
                ),
              ),
            ),
          ],
        ),
      ),
      // FloatingActionButton removed - payments are disabled
    );
  }
}


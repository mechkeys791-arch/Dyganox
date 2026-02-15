import 'package:flutter/material.dart';
import 'payment_gateway.dart';

/// No Payment Gateway Implementation
/// 
/// This implementation bypasses all payment processing.
/// It always succeeds immediately, allowing bookings to proceed without payment.
/// 
/// This is used when payment functionality is disabled in the system.
class NoPayment implements PaymentGateway {
  @override
  void initialize(BuildContext context) {}

  @override
  Future<void> makePayment({
    required double amount,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required VoidCallback onSuccess,
    required Function(String) onFailure,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    onSuccess();
  }
  
  @override
  void dispose() {
    // No cleanup needed
  }
}

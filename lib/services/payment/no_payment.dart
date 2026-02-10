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
  void initialize(BuildContext context) {
    print('✅ NoPayment gateway initialized (payments disabled)');
  }
  
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
    print('💳 Payment bypassed (payments disabled)');
    print('   Order ID: $orderId');
    print('   Amount: ₹$amount (not charged)');
    print('   Customer: $customerName');
    
    // Immediately call success callback to proceed with booking
    // No actual payment processing occurs
    await Future.delayed(const Duration(milliseconds: 300)); // Small delay for UX
    onSuccess();
  }
  
  @override
  void dispose() {
    // No cleanup needed
  }
}

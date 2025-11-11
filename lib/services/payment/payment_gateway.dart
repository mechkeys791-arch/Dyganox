import 'package:flutter/material.dart';

/// Abstract payment gateway interface
/// This allows easy switching between payment providers (Square, Razorpay, etc.)
abstract class PaymentGateway {
  /// Initialize the payment gateway
  void initialize(BuildContext context);
  
  /// Make a payment
  /// 
  /// [amount] - Payment amount in the base currency (e.g., 50.0 for ₹50 or $50)
  /// [orderId] - Unique order identifier
  /// [customerName] - Customer's full name
  /// [customerEmail] - Customer's email address
  /// [customerPhone] - Customer's phone number
  /// [onSuccess] - Callback when payment succeeds
  /// [onFailure] - Callback when payment fails (receives error message)
  Future<void> makePayment({
    required double amount,
    required String orderId,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required VoidCallback onSuccess,
    required Function(String) onFailure,
  });
  
  /// Clean up resources
  void dispose();
}






import 'payment_gateway.dart';
import 'square_payment.dart';

/// Payment Gateway Configuration
/// 
/// This is the SINGLE place where you switch payment gateways
/// 
/// To switch from Square to Razorpay (or any other gateway):
/// 1. Change the return statement below
/// 2. That's it! All other code remains the same
class PaymentConfig {
  /// Get the payment gateway instance
  /// 
  /// Currently using: Square (Sandbox for testing)
  /// To switch to Razorpay: Change return statement to RazorpayPayment()
  static PaymentGateway getPaymentGateway() {
    // 🔥 CURRENTLY USING: Square Payment (Sandbox)
    return SquarePayment();
    
    // 🔥 TO SWITCH TO RAZORPAY (when ready):
    // Uncomment below and comment above:
    // return RazorpayPayment();
  }
  
  /// Get payment amount in the correct currency
  /// Square uses USD, so convert INR to USD if needed
  static double convertAmount(double inrAmount) {
    // For Square, we'll use approximate conversion
    // 1 USD ≈ 83 INR (adjust as needed)
    const double exchangeRate = 83.0;
    return inrAmount / exchangeRate;
  }
}






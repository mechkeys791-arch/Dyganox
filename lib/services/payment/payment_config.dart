import 'payment_gateway.dart';
// import 'square_payment.dart'; // Unused - payments disabled
import 'no_payment.dart';

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
  /// PAYMENTS DISABLED: Currently using NoPayment gateway (bypasses all payment processing)
  /// To re-enable payments: Change return statement to SquarePayment() or RazorpayPayment()
  static PaymentGateway getPaymentGateway() {
    // 🔥 PAYMENTS DISABLED: NoPayment gateway (bypasses payment, always succeeds)
    return NoPayment();
    
    // 🔥 TO RE-ENABLE PAYMENTS:
    // Uncomment one of the options below and comment above:
    // return SquarePayment(); // Square Payment (Sandbox for testing)
    // return RazorpayPayment(); // Razorpay Payment (when ready)
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






import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'payment_gateway.dart';
import '../api_config.dart';

/// Square Payment Gateway Implementation
/// 
/// This implementation uses Square's Payment API through your backend
/// The backend handles actual Square API calls for security
class SquarePayment implements PaymentGateway {
  late VoidCallback _onSuccess;
  late Function(String) _onFailure;
  BuildContext? _context;
  
  @override
  void initialize(BuildContext context) {
    _context = context;
    print('✅ Square Payment initialized');
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
    _onSuccess = onSuccess;
    _onFailure = onFailure;
    
    try {
      print('💳 Starting Square payment: ₹$amount');
      print('   Order ID: $orderId');
      print('   API URL: ${ApiConfig.baseUrl}/api/payment/square/create-intent');//explain:
      
      // Validate context
      if (_context == null || !_context!.mounted) {
        print('❌ Payment context is null or not mounted');
        _onFailure('Payment context is not available. Please try again.');
        return;
      }
      
      // Show payment processing dialog
      _showPaymentDialog(_context!);
      
      // Step 1: Create payment intent on backend
      print('📡 Creating payment intent...');
      final paymentIntentResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payment/square/create-intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'orderId': orderId,
          'customerName': customerName,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          'currency': 'USD', // Square uses USD, convert INR to USD if needed
        }),
      );
      
      print('📡 Payment intent response status: ${paymentIntentResponse.statusCode}');
      print('📡 Payment intent response body: ${paymentIntentResponse.body}');
      
      if (_context != null && _context!.mounted) {
        Navigator.pop(_context!); // Close processing dialog
      }
      
      if (paymentIntentResponse.statusCode != 200) {
        final errorBody = paymentIntentResponse.body;
        print('❌ Payment intent creation failed: $errorBody');
        print('   Status code: ${paymentIntentResponse.statusCode}');
        try {
          final error = jsonDecode(errorBody);
          final errorMessage = error['message'] ?? 'Failed to create payment intent';
          print('   Error message: $errorMessage');
          _onFailure(errorMessage);
        } catch (e) {
          print('   Could not parse error response: $e');
          _onFailure('Failed to create payment intent: ${paymentIntentResponse.statusCode}');
        }
        return;
      }
      
      final intentData = jsonDecode(paymentIntentResponse.body);
      final paymentIntentId = intentData['paymentIntentId'];
      final clientSecret = intentData['clientSecret'];
      
      print('✅ Payment intent created: $paymentIntentId');
      
      // Step 2: Show payment form to user
      // For Square, we'll use a simple form to collect card details
      // In production, you'd use Square's In-App Payments SDK
      
      if (_context != null && _context!.mounted) {
        // Show card input dialog
        await _showCardInputDialog(_context!, paymentIntentId, clientSecret, amount);
      } else {
        print('❌ Context not available for card input dialog');
        _onFailure('Payment context is not available. Please try again.');
      }
      
    } catch (e) {
      print('❌ Payment error: $e');
      if (_context != null && _context!.mounted) {
        Navigator.pop(_context!); // Close any open dialogs
      }
      _onFailure('Payment failed: $e');
    }
  }
  
  void _showPaymentDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Processing payment...'),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showCardInputDialog(
    BuildContext context,
    String paymentIntentId,
    String clientSecret,
    double amount,
  ) async {
    final cardNumberController = TextEditingController();
    final expiryController = TextEditingController();
    final cvvController = TextEditingController();
    final zipController = TextEditingController(text: '12345');
    
    // Pre-fill with test card for sandbox
    cardNumberController.text = '4111 1111 1111 1111';
    expiryController.text = '12/25';
    cvvController.text = '111';
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Amount: \$${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter test card details (Sandbox):',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '4111 1111 1111 1111',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry',
                        hintText: '12/25',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cvvController,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '111',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: zipController,
                decoration: const InputDecoration(
                  labelText: 'ZIP Code',
                  hintText: '12345',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Process payment with entered card details
      await _processPaymentWithCard(
        paymentIntentId,
        clientSecret,
        cardNumberController.text.replaceAll(' ', ''),
        expiryController.text,
        cvvController.text,
        zipController.text,
      );
    } else {
      // User cancelled payment
      print('❌ Payment cancelled by user');
      _onFailure('Payment cancelled');
    }
  }
  
  Future<void> _processPaymentWithCard(
    String paymentIntentId,
    String clientSecret,
    String cardNumber,
    String expiry,
    String cvv,
    String zip,
  ) async {
    try {
      if (_context != null && _context!.mounted) {
        _showPaymentDialog(_context!);
      }
      
      // Parse expiry
      final parts = expiry.trim().split('/');
      if (parts.length != 2) {
        if (_context != null && _context!.mounted) {
          Navigator.pop(_context!);
        }
        _onFailure('Invalid expiry date format. Use MM/YY');
        return;
      }
      
      final month = parts[0].padLeft(2, '0');
      final year = '20${parts[1]}';
      
      // Send card details to backend for processing
      print('📡 Processing payment with card...');
      print('   Payment Intent ID: $paymentIntentId');
      print('   API URL: ${ApiConfig.baseUrl}/api/payment/square/process');
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payment/square/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'paymentIntentId': paymentIntentId,
          'cardNumber': cardNumber,
          'expiryMonth': month,
          'expiryYear': year,
          'cvv': cvv,
          'zipCode': zip,
        }),
      );
      
      print('📡 Payment processing response status: ${response.statusCode}');
      print('📡 Payment processing response body: ${response.body}');
      
      if (_context != null && _context!.mounted) {
        Navigator.pop(_context!); // Close processing dialog
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Payment successful: ${data['paymentId']}');
          _onSuccess();
        } else {
          final errorMessage = data['message'] ?? 'Payment failed';
          print('❌ Payment failed: $errorMessage');
          _onFailure(errorMessage);
        }
      } else {
        print('❌ Payment processing failed with status: ${response.statusCode}');
        print('   Response body: ${response.body}');
        try {
          final error = jsonDecode(response.body);
          final errorMessage = error['message'] ?? 'Payment processing failed';
          print('   Error message: $errorMessage');
          _onFailure(errorMessage);
        } catch (e) {
          print('   Could not parse error response: $e');
          _onFailure('Payment processing failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (_context != null && _context!.mounted) {
        Navigator.pop(_context!);
      }
      _onFailure('Network error: $e');
    }
  }
  
  @override
  void dispose() {
    // Cleanup if needed
  }
}




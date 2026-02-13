package com.example.demo.controller;

import com.example.demo.model.Payment;
import com.example.demo.repository.PaymentRepo;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/payment/square")
public class SquarePaymentController {

    @Value("${square.application.id}")
    private String applicationId;
    
    @Value("${square.access.token}")
    private String accessToken;
    
    @Value("${square.environment}")
    private String environment;
    
    private final PaymentRepo paymentRepo;
    
    public SquarePaymentController(PaymentRepo paymentRepo) {
        this.paymentRepo = paymentRepo;
    }

    /**
     * Create a payment intent (first step in payment flow)
     * POST /api/payment/square/create-intent
     * 
     * SANDBOX MODE: This is a mock implementation for testing
     * 
     * NOTE: Payment functionality is currently disabled in the frontend.
     * This endpoint may still be called but payments are bypassed via NoPayment gateway.
     */
    @PostMapping("/create-intent")
    public ResponseEntity<Map<String, Object>> createPaymentIntent(@RequestBody Map<String, Object> request) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            // Get request data
            Double amount = ((Number) request.get("amount")).doubleValue();
            String orderId = (String) request.get("orderId");
            Long mechanicId = ((Number) request.getOrDefault("mechanicId", 0)).longValue();
            String currency = (String) request.getOrDefault("currency", "USD");
            
            // Generate mock payment intent ID
            String paymentIntentId = "pi_sandbox_" + UUID.randomUUID().toString();
            String clientSecret = "secret_" + UUID.randomUUID().toString();
            
            // Save payment to database
            Payment payment = new Payment(paymentIntentId, mechanicId, amount, currency, orderId);
            payment.setCustomerEmail((String) request.get("customerEmail"));
            payment.setCustomerPhone((String) request.get("customerPhone"));
            paymentRepo.save(payment);
            
            System.out.println("✅ Mock payment intent created: " + paymentIntentId);
            System.out.println("   Amount: $" + amount + " " + currency);
            System.out.println("   Order ID: " + orderId);
            System.out.println("   Mechanic ID: " + mechanicId);
            
            response.put("success", true);
            response.put("paymentIntentId", paymentIntentId);
            response.put("clientSecret", clientSecret);
            response.put("amount", amount);
            response.put("currency", currency);
            response.put("mode", "SANDBOX_MOCK");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            System.err.println("❌ Error creating payment intent: " + e.getMessage());
            e.printStackTrace();
            response.put("success", false);
            response.put("message", "Internal server error: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }

    /**
     * Process payment with card details
     * POST /api/payment/square/process
     * 
     * SANDBOX MODE: This is a mock implementation for testing
     * 
     * NOTE: Payment functionality is currently disabled in the frontend.
     * This endpoint may still be called but payments are bypassed via NoPayment gateway.
     */
    @PostMapping("/process")
    public ResponseEntity<Map<String, Object>> processPayment(@RequestBody Map<String, Object> request) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            String paymentIntentId = (String) request.get("paymentIntentId");
            String cardNumber = (String) request.get("cardNumber");
            
            // Find payment in database
            Payment payment = paymentRepo.findByPaymentIntentId(paymentIntentId)
                    .orElseThrow(() -> new RuntimeException("Payment intent not found"));
            
            System.out.println("🔄 Processing mock payment: " + paymentIntentId);
            System.out.println("   Card (last 4): ..." + cardNumber.substring(Math.max(0, cardNumber.length() - 4)));
            
            // Mock payment processing logic
            boolean shouldSucceed = !cardNumber.equals("4000000000000002"); // Decline card
            
            if (shouldSucceed) {
                // SUCCESS
                String mockPaymentId = "pay_sandbox_" + UUID.randomUUID().toString();
                
                payment.setPaymentId(mockPaymentId);
                payment.setStatus("SUCCESS");
                payment.setCompletedAt(LocalDateTime.now());
                payment.setPaymentMethod("CARD");
                paymentRepo.save(payment);
                
                System.out.println("✅ Mock payment successful: " + mockPaymentId);
                
                response.put("success", true);
                response.put("paymentId", mockPaymentId);
                response.put("status", "SUCCESS");
                response.put("message", "Payment processed successfully (SANDBOX MOCK)");
                response.put("mode", "SANDBOX_MOCK");
                
                return ResponseEntity.ok(response);
            } else {
                // DECLINED
                payment.setStatus("FAILED");
                paymentRepo.save(payment);
                
                System.out.println("❌ Mock payment declined (test card)");
                
                response.put("success", false);
                response.put("message", "Card declined (test card 4000000000000002)");
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
            }
            
        } catch (Exception e) {
            System.err.println("❌ Error processing payment: " + e.getMessage());
            e.printStackTrace();
            
            // Update payment status to failed
            try {
                Payment payment = paymentRepo.findByPaymentIntentId((String) request.get("paymentIntentId")).orElse(null);
                if (payment != null) {
                    payment.setStatus("FAILED");
                    paymentRepo.save(payment);
                }
            } catch (Exception ex) {
                // Ignore
            }
            
            response.put("success", false);
            response.put("message", "Internal server error: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }

    /**
     * Get payment status
     * GET /api/payment/square/{paymentIntentId}
     */
    @GetMapping("/{paymentIntentId}")
    public ResponseEntity<Map<String, Object>> getPaymentStatus(@PathVariable String paymentIntentId) {
        Map<String, Object> response = new HashMap<>();
        
        try {
            Payment payment = paymentRepo.findByPaymentIntentId(paymentIntentId)
                    .orElseThrow(() -> new RuntimeException("Payment not found"));
            
            response.put("success", true);
            response.put("paymentId", payment.getPaymentId());
            response.put("status", payment.getStatus());
            response.put("amount", payment.getAmount());
            response.put("currency", payment.getCurrency());
            response.put("createdAt", payment.getCreatedAt());
            response.put("completedAt", payment.getCompletedAt());
            response.put("mode", "SANDBOX_MOCK");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            response.put("success", false);
            response.put("message", "Payment not found");
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
        }
    }
}

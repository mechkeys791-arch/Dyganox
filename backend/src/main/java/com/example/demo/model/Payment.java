package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "payments")
public class Payment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String paymentIntentId; // Square payment intent ID
    private String paymentId; // Square payment ID (after successful payment)
    private Long mechanicId;
    private Long requestId; // Link to mechanic request
    private Double amount;
    private String currency; // USD, INR, etc.
    private String status; // PENDING, SUCCESS, FAILED, CANCELLED
    private String paymentMethod; // CARD, UPI, etc.
    private String customerEmail;
    private String customerPhone;
    private LocalDateTime createdAt;
    private LocalDateTime completedAt;
    private String orderId; // Your app's order ID

    public Payment() {}

    public Payment(String paymentIntentId, Long mechanicId, Double amount, String currency, String orderId) {
        this.paymentIntentId = paymentIntentId;
        this.mechanicId = mechanicId;
        this.amount = amount;
        this.currency = currency;
        this.orderId = orderId;
        this.status = "PENDING";
        this.createdAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getPaymentIntentId() { return paymentIntentId; }
    public void setPaymentIntentId(String paymentIntentId) { this.paymentIntentId = paymentIntentId; }

    public String getPaymentId() { return paymentId; }
    public void setPaymentId(String paymentId) { this.paymentId = paymentId; }

    public Long getMechanicId() { return mechanicId; }
    public void setMechanicId(Long mechanicId) { this.mechanicId = mechanicId; }

    public Long getRequestId() { return requestId; }
    public void setRequestId(Long requestId) { this.requestId = requestId; }

    public Double getAmount() { return amount; }
    public void setAmount(Double amount) { this.amount = amount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public String getCustomerPhone() { return customerPhone; }
    public void setCustomerPhone(String customerPhone) { this.customerPhone = customerPhone; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getCompletedAt() { return completedAt; }
    public void setCompletedAt(LocalDateTime completedAt) { this.completedAt = completedAt; }

    public String getOrderId() { return orderId; }
    public void setOrderId(String orderId) { this.orderId = orderId; }

    @Override
    public String toString() {
        return "Payment{" +
                "id=" + id +
                ", paymentIntentId='" + paymentIntentId + '\'' +
                ", paymentId='" + paymentId + '\'' +
                ", mechanicId=" + mechanicId +
                ", amount=" + amount +
                ", status='" + status + '\'' +
                ", orderId='" + orderId + '\'' +
                '}';
    }
}







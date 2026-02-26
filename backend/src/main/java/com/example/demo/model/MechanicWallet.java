package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "mechanic_wallets")
public class MechanicWallet {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long mechanicId;
    private Double balance = 0.0;
    private Double totalEarned = 0.0;
    private Integer minWithdrawAmount = 100;   // Minimum 100 INR to withdraw
    private LocalDateTime updatedAt = LocalDateTime.now();

    public MechanicWallet() {}

    public MechanicWallet(Long mechanicId) {
        this.mechanicId = mechanicId;
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getMechanicId() { return mechanicId; }
    public void setMechanicId(Long mechanicId) { this.mechanicId = mechanicId; }

    public Double getBalance() { return balance; }
    public void setBalance(Double balance) { this.balance = balance; }

    public Double getTotalEarned() { return totalEarned; }
    public void setTotalEarned(Double totalEarned) { this.totalEarned = totalEarned; }

    public Integer getMinWithdrawAmount() { return minWithdrawAmount; }
    public void setMinWithdrawAmount(Integer minWithdrawAmount) { this.minWithdrawAmount = minWithdrawAmount; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}

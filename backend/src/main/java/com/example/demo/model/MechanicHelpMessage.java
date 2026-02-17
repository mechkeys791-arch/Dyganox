package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Stores help/support chat messages between mechanics and admin.
 * Used when a mechanic (e.g. rejected) contacts admin; messages appear in admin dashboard and in mechanic's help chat.
 */
@Entity
@Table(name = "mechanic_help_messages")
public class MechanicHelpMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String mechanicEmail;
    @Column(length = 2000)
    private String message;
    private String sender; // MECHANIC or ADMIN
    private LocalDateTime createdAt = LocalDateTime.now();

    public MechanicHelpMessage() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getMechanicEmail() { return mechanicEmail; }
    public void setMechanicEmail(String mechanicEmail) { this.mechanicEmail = mechanicEmail; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public String getSender() { return sender; }
    public void setSender(String sender) { this.sender = sender; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

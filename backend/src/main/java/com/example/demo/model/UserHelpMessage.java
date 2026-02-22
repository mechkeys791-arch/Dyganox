package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Stores help/support chat messages between app users (customers) and admin.
 * Shown in user app Help & Support and in admin dashboard User Support.
 */
@Entity
@Table(name = "user_help_messages")
public class UserHelpMessage {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String userEmail;
    @Column(length = 2000)
    private String message;
    @Column(length = 512)
    private String imageUrl; // optional; only when messageType=IMAGE and user has photo permission
    @Column(length = 30)
    private String messageType = "TEXT"; // TEXT, IMAGE, PHOTO_PERMISSION_REQUEST, PHOTO_PERMISSION_GRANTED
    private String sender; // USER or ADMIN
    private LocalDateTime createdAt = LocalDateTime.now();

    public UserHelpMessage() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public String getImageUrl() { return imageUrl; }
    public void setImageUrl(String imageUrl) { this.imageUrl = imageUrl; }

    public String getMessageType() { return messageType; }
    public void setMessageType(String messageType) { this.messageType = messageType; }

    public String getSender() { return sender; }
    public void setSender(String sender) { this.sender = sender; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

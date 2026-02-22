package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/** Whether a user is allowed to send photos in support chat. Admin must approve. */
@Entity
@Table(name = "user_support_photo_permission", uniqueConstraints = @UniqueConstraint(columnNames = "userEmail"))
public class UserSupportPhotoPermission {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String userEmail;
    private boolean allowed;
    private LocalDateTime grantedAt;

    public UserSupportPhotoPermission() {}

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }
    public boolean isAllowed() { return allowed; }
    public void setAllowed(boolean allowed) { this.allowed = allowed; }
    public LocalDateTime getGrantedAt() { return grantedAt; }
    public void setGrantedAt(LocalDateTime grantedAt) { this.grantedAt = grantedAt; }
}

package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "mechanics")
public class Mechanic {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String email;
    private String phone;
    private String specialty;
    private String experience;
    private boolean nightTimeAvailable;
    private String latitude; // Registration location
    private String longitude; // Registration location
    private String status = "Available"; // Available, Busy, Offline
    private String approvalStatus = "PENDING"; // PENDING, APPROVED, REJECTED
    
    // Block/Suspend fields
    private boolean isBlocked = false;
    private boolean isSuspended = false;
    
    // Live tracking fields
    private boolean isOnline = false;
    private String currentLatitude; // Current live location
    private String currentLongitude; // Current live location
    private LocalDateTime lastLocationUpdate;
    
    // Document storage (JSON array or comma-separated URLs)
    @Column(length = 2000)
    private String documentUrls; // Store document URLs/paths

    public Mechanic() {}

    public Mechanic(String name, String email, String phone, String specialty, String experience, boolean nightTimeAvailable, String latitude, String longitude) {
        this.name = name;
        this.email = email;
        this.phone = phone;
        this.specialty = specialty;
        this.experience = experience;
        this.nightTimeAvailable = nightTimeAvailable;
        this.latitude = latitude;
        this.longitude = longitude;
        this.status = "Available"; // Default status
    }

    // Getters & Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getSpecialty() { return specialty; }
    public void setSpecialty(String specialty) { this.specialty = specialty; }

    public String getExperience() { return experience; }
    public void setExperience(String experience) { this.experience = experience; }

    public boolean isNightTimeAvailable() { return nightTimeAvailable; }
    public void setNightTimeAvailable(boolean nightTimeAvailable) { this.nightTimeAvailable = nightTimeAvailable; }

    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }

    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public String getApprovalStatus() { return approvalStatus; }
    public void setApprovalStatus(String approvalStatus) { this.approvalStatus = approvalStatus; }

    public boolean isBlocked() { return isBlocked; }
    public void setBlocked(boolean blocked) { isBlocked = blocked; }

    public boolean isSuspended() { return isSuspended; }
    public void setSuspended(boolean suspended) { isSuspended = suspended; }

    public boolean isOnline() { return isOnline; }
    public void setOnline(boolean online) { isOnline = online; }

    public String getCurrentLatitude() { return currentLatitude; }
    public void setCurrentLatitude(String currentLatitude) { this.currentLatitude = currentLatitude; }

    public String getCurrentLongitude() { return currentLongitude; }
    public void setCurrentLongitude(String currentLongitude) { this.currentLongitude = currentLongitude; }

    public LocalDateTime getLastLocationUpdate() { return lastLocationUpdate; }
    public void setLastLocationUpdate(LocalDateTime lastLocationUpdate) { this.lastLocationUpdate = lastLocationUpdate; }

    public String getDocumentUrls() { return documentUrls; }
    public void setDocumentUrls(String documentUrls) { this.documentUrls = documentUrls; }

    @Override
    public String toString() {
        return "Mechanic{" +
                "id=" + id +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", phone='" + phone + '\'' +
                ", specialty='" + specialty + '\'' +
                ", experience='" + experience + '\'' +
                ", nightTimeAvailable=" + nightTimeAvailable +
                ", latitude='" + latitude + '\'' +
                ", longitude='" + longitude + '\'' +
                ", status='" + status + '\'' +
                ", approvalStatus='" + approvalStatus + '\'' +
                ", isBlocked=" + isBlocked +
                ", isSuspended=" + isSuspended +
                ", isOnline=" + isOnline +
                '}';
    }
}

package com.example.demo.model;

import jakarta.persistence.*;

@Entity
@Table(name = "person")
public class Person {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String email; // User email (unique identifier)
    private String phone;
    private String address;
    private String chargerType;
    private String rate;
    private String availableHours;
    private String dateOfBirth; // Date of Birth (ISO format: YYYY-MM-DD)
    private String gender; // Gender (Male, Female, Other)
    private String profilePhotoUrl; // S3 URL for profile photo
    private java.time.LocalDateTime lastActiveAt; // Last app activity (for live users count)
    private Long totalUsageMinutes; // Total app usage time in minutes

    public Person() {}

    public Person(String name, String phone, String address, String chargerType, String rate, String availableHours) {
        this.name = name;
        this.phone = phone;
        this.address = address;
        this.chargerType = chargerType;
        this.rate = rate;
        this.availableHours = availableHours;
    }

    // Constructor for user profile
    public Person(String name, String email, String phone, String dateOfBirth, String gender) {
        this.name = name;
        this.email = email;
        this.phone = phone;
        this.dateOfBirth = dateOfBirth;
        this.gender = gender;
    }

    // Getters & Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAddress() { return address; }
    public void setAddress(String address) { this.address = address; }

    public String getChargerType() { return chargerType; }
    public void setChargerType(String chargerType) { this.chargerType = chargerType; }

    public String getRate() { return rate; }
    public void setRate(String rate) { this.rate = rate; }

    public String getAvailableHours() { return availableHours; }
    public void setAvailableHours(String availableHours) { this.availableHours = availableHours; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getDateOfBirth() { return dateOfBirth; }
    public void setDateOfBirth(String dateOfBirth) { this.dateOfBirth = dateOfBirth; }

    public String getGender() { return gender; }
    public void setGender(String gender) { this.gender = gender; }

    public String getProfilePhotoUrl() { return profilePhotoUrl; }
    public void setProfilePhotoUrl(String profilePhotoUrl) { this.profilePhotoUrl = profilePhotoUrl; }

    public java.time.LocalDateTime getLastActiveAt() { return lastActiveAt; }
    public void setLastActiveAt(java.time.LocalDateTime lastActiveAt) { this.lastActiveAt = lastActiveAt; }

    public Long getTotalUsageMinutes() { return totalUsageMinutes; }
    public void setTotalUsageMinutes(Long totalUsageMinutes) { this.totalUsageMinutes = totalUsageMinutes; }
}

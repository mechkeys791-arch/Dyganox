package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Stores mechanic registration form submissions (pending approval).
 * Table name "requests" as requested - all fields from the app registration form.
 */
@Entity
@Table(name = "requests")
public class MechanicRegistrationRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;
    private String email;
    private String phone;
    private String aadharNumber;
    private String experience;
    @Column(length = 2000)
    private String profilePhotoUrl;
    private String shopName;
    @Column(length = 1000)
    private String shopAddress;
    private String shopCity;
    private String shopState;
    private String shopPincode;
    private String shopCountry;
    private String latitude;
    private String longitude;
    @Column(length = 2000)
    private String services;
    private String specialty;
    private boolean nightTimeAvailable;
    private String openingTime;
    private String closingTime;
    @Column(length = 100)
    private String workingDays;
    private String approvalStatus = "PENDING"; // PENDING, APPROVED, REJECTED
    @Column(length = 50)
    private String vehicleTypes; // CAR, BIKE, or CAR,BIKE - which vehicle types mechanic serves
    @Column(length = 500)
    private String towingVehiclePhotoUrl; // Optional towing vehicle photo when mechanic offers towing
    @Column(length = 500)
    private String rejectionReason; // Set by admin when rejecting (for WhatsApp/UI later)

    private LocalDateTime createdAt = LocalDateTime.now();

    public MechanicRegistrationRequest() {}

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getAadharNumber() { return aadharNumber; }
    public void setAadharNumber(String aadharNumber) { this.aadharNumber = aadharNumber; }

    public String getExperience() { return experience; }
    public void setExperience(String experience) { this.experience = experience; }

    public String getProfilePhotoUrl() { return profilePhotoUrl; }
    public void setProfilePhotoUrl(String profilePhotoUrl) { this.profilePhotoUrl = profilePhotoUrl; }

    public String getShopName() { return shopName; }
    public void setShopName(String shopName) { this.shopName = shopName; }

    public String getShopAddress() { return shopAddress; }
    public void setShopAddress(String shopAddress) { this.shopAddress = shopAddress; }

    public String getShopCity() { return shopCity; }
    public void setShopCity(String shopCity) { this.shopCity = shopCity; }

    public String getShopState() { return shopState; }
    public void setShopState(String shopState) { this.shopState = shopState; }

    public String getShopPincode() { return shopPincode; }
    public void setShopPincode(String shopPincode) { this.shopPincode = shopPincode; }

    public String getShopCountry() { return shopCountry; }
    public void setShopCountry(String shopCountry) { this.shopCountry = shopCountry; }

    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }

    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }

    public String getServices() { return services; }
    public void setServices(String services) { this.services = services; }

    public String getSpecialty() { return specialty; }
    public void setSpecialty(String specialty) { this.specialty = specialty; }

    public boolean isNightTimeAvailable() { return nightTimeAvailable; }
    public void setNightTimeAvailable(boolean nightTimeAvailable) { this.nightTimeAvailable = nightTimeAvailable; }

    public String getOpeningTime() { return openingTime; }
    public void setOpeningTime(String openingTime) { this.openingTime = openingTime; }

    public String getClosingTime() { return closingTime; }
    public void setClosingTime(String closingTime) { this.closingTime = closingTime; }

    public String getWorkingDays() { return workingDays; }
    public void setWorkingDays(String workingDays) { this.workingDays = workingDays; }

    public String getApprovalStatus() { return approvalStatus; }
    public void setApprovalStatus(String approvalStatus) { this.approvalStatus = approvalStatus; }

    public String getVehicleTypes() { return vehicleTypes; }
    public void setVehicleTypes(String vehicleTypes) { this.vehicleTypes = vehicleTypes; }

    public String getTowingVehiclePhotoUrl() { return towingVehiclePhotoUrl; }
    public void setTowingVehiclePhotoUrl(String towingVehiclePhotoUrl) { this.towingVehiclePhotoUrl = towingVehiclePhotoUrl; }

    public String getRejectionReason() { return rejectionReason; }
    public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

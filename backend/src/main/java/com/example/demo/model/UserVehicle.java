package com.example.demo.model;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * User's vehicle - linked by user email. User can have multiple vehicles.
 */
@Entity
@Table(name = "user_vehicles")
public class UserVehicle {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String userEmail;      // owner (Person email)
    private String type;           // CAR, BIKE
    private Long makeId;
    private String makeName;       // denormalized for display
    private Long modelId;
    private String modelName;      // denormalized for display
    @Column(length = 500)
    private String modelImageUrl;  // from catalog or user upload
    private String plateNumber;    // registration plate (required, Indian format)
    private String year;           // optional year of manufacture
    private String fuelType;       // e.g. Petrol, Diesel, Electric, CNG, Hybrid (optional)
    @Column(length = 500)
    private String photoUrl;       // user-uploaded photo (legacy; no longer collected in app)
    private boolean isDefault;     // default vehicle for service requests
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) createdAt = LocalDateTime.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getUserEmail() { return userEmail; }
    public void setUserEmail(String userEmail) { this.userEmail = userEmail; }
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }
    public Long getMakeId() { return makeId; }
    public void setMakeId(Long makeId) { this.makeId = makeId; }
    public String getMakeName() { return makeName; }
    public void setMakeName(String makeName) { this.makeName = makeName; }
    public Long getModelId() { return modelId; }
    public void setModelId(Long modelId) { this.modelId = modelId; }
    public String getModelName() { return modelName; }
    public void setModelName(String modelName) { this.modelName = modelName; }
    public String getModelImageUrl() { return modelImageUrl; }
    public void setModelImageUrl(String modelImageUrl) { this.modelImageUrl = modelImageUrl; }
    public String getPlateNumber() { return plateNumber; }
    public void setPlateNumber(String plateNumber) { this.plateNumber = plateNumber; }
    public String getYear() { return year; }
    public void setYear(String year) { this.year = year; }
    public String getFuelType() { return fuelType; }
    public void setFuelType(String fuelType) { this.fuelType = fuelType; }
    public String getPhotoUrl() { return photoUrl; }
    public void setPhotoUrl(String photoUrl) { this.photoUrl = photoUrl; }
    public boolean isDefault() { return isDefault; }
    public void setDefault(boolean aDefault) { isDefault = aDefault; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}

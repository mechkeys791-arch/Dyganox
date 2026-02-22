package com.example.demo.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "mechanic_requests")
public class MechanicRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private Long mechanicId;
    private String customerName;

    /** Distance in km from mechanic to customer (sent by app, not persisted if column missing). */
    @Transient
    private Double distanceKm;
    private String customerPhone;
    private String customerEmail;
    private String serviceType;
    private Long userVehicleId;      // which vehicle broke down
    private String vehicleMakeName;
    private String vehicleModelName;
    private String vehiclePlateNumber;
    @Column(length = 500)
    private String vehiclePhotoUrl;
    private String description;
    private String latitude;
    private String longitude;
    private String status; // PENDING, ACCEPTED, REJECTED, COMPLETED
    private double amount;
    
    @JsonProperty("createdAt")
    private LocalDateTime requestTime;
    private LocalDateTime responseTime;

    public MechanicRequest() {}

    public MechanicRequest(Long mechanicId, String customerName, String customerPhone, 
                          String customerEmail, String serviceType, String description,
                          String latitude, String longitude, double amount) {
        this.mechanicId = mechanicId;
        this.customerName = customerName;
        this.customerPhone = customerPhone;
        this.customerEmail = customerEmail;
        this.serviceType = serviceType;
        this.description = description;
        this.latitude = latitude;
        this.longitude = longitude;
        this.amount = amount;
        this.status = "PENDING";
        this.requestTime = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Long getMechanicId() { return mechanicId; }
    public void setMechanicId(Long mechanicId) { this.mechanicId = mechanicId; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getCustomerPhone() { return customerPhone; }
    public void setCustomerPhone(String customerPhone) { this.customerPhone = customerPhone; }

    public Double getDistanceKm() { return distanceKm; }
    public void setDistanceKm(Double distanceKm) { this.distanceKm = distanceKm; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public String getServiceType() { return serviceType; }
    public void setServiceType(String serviceType) { this.serviceType = serviceType; }

    public Long getUserVehicleId() { return userVehicleId; }
    public void setUserVehicleId(Long userVehicleId) { this.userVehicleId = userVehicleId; }
    public String getVehicleMakeName() { return vehicleMakeName; }
    public void setVehicleMakeName(String vehicleMakeName) { this.vehicleMakeName = vehicleMakeName; }
    public String getVehicleModelName() { return vehicleModelName; }
    public void setVehicleModelName(String vehicleModelName) { this.vehicleModelName = vehicleModelName; }
    public String getVehiclePlateNumber() { return vehiclePlateNumber; }
    public void setVehiclePlateNumber(String vehiclePlateNumber) { this.vehiclePlateNumber = vehiclePlateNumber; }
    public String getVehiclePhotoUrl() { return vehiclePhotoUrl; }
    public void setVehiclePhotoUrl(String vehiclePhotoUrl) { this.vehiclePhotoUrl = vehiclePhotoUrl; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getLatitude() { return latitude; }
    public void setLatitude(String latitude) { this.latitude = latitude; }

    public String getLongitude() { return longitude; }
    public void setLongitude(String longitude) { this.longitude = longitude; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public double getAmount() { return amount; }
    public void setAmount(double amount) { this.amount = amount; }

    public LocalDateTime getRequestTime() { return requestTime; }
    public void setRequestTime(LocalDateTime requestTime) { this.requestTime = requestTime; }

    public LocalDateTime getResponseTime() { return responseTime; }
    public void setResponseTime(LocalDateTime responseTime) { this.responseTime = responseTime; }

    @Override
    public String toString() {
        return "MechanicRequest{" +
                "id=" + id +
                ", mechanicId=" + mechanicId +
                ", customerName='" + customerName + '\'' +
                ", customerPhone='" + customerPhone + '\'' +
                ", serviceType='" + serviceType + '\'' +
                ", status='" + status + '\'' +
                ", amount=" + amount +
                ", requestTime=" + requestTime +
                '}';
    }
}

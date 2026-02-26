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
    private String status; // PENDING, ACCEPTED, REJECTED, COMPLETED, PENDING_BROADCAST, PENDING_PAYMENT, MECHANIC_EN_ROUTE, ARRIVED, USER_CONFIRMED, MECHANIC_CONFIRMED
    private double amount;

    // Book Mechanic flow: problem category & details
    private String problemCategory;       // e.g. tyre_puncture, battery_jump, engine_repair, general_checkup
    @Column(length = 2000)
    private String diagnosticAnswers;    // JSON: {"q1":"Yes","q2":"No",...}
    @Column(length = 1000)
    private String comment;              // User's text description
    @Column(length = 2000)
    private String photoUrls;            // JSON array of photo URLs
    private Integer requestRadiusKm;     // 5, 10, or 20 - radius used to find mechanics
    private Double advanceAmount;        // 100 INR mandatory advance
    private Double platformFee;          // 9 INR
    private Double comingChargePerKm;    // 3 INR per km after 5km
    private Double comingChargeTotal;    // Total coming charge (0 if within 5km)
    private Double distanceKmToCustomer;  // Distance from accepted mechanic to customer
    private Long acceptedMechanicId;     // For broadcast: which mechanic accepted (null until accepted)
    private Boolean userConfirmedArrival;
    private Boolean mechanicConfirmedArrival;
    private Boolean userConfirmedCompleted;
    private Boolean mechanicConfirmedCompleted;
    @Column(length = 500)
    private String userCompletionRemarks;   // Work done or not, why, remarks
    @Column(length = 500)
    private String mechanicCompletionRemarks;
    private String refundStatus;          // PENDING, REFUNDED
    private LocalDateTime viewExpiryAt;   // 5 min window for mechanics to see request
    private Boolean outOfHoursRequest;    // true = extra 100 for minor repair when shop closed
    @Column(length = 500)
    private String notifiedMechanicIds;    // JSON array of mechanic IDs who received the request (for admin)
    private Double customerRating;         // 1-5 after service (customer rates mechanic)
    @Column(length = 500)
    private String customerRatingComment;

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

    public String getProblemCategory() { return problemCategory; }
    public void setProblemCategory(String problemCategory) { this.problemCategory = problemCategory; }
    public String getDiagnosticAnswers() { return diagnosticAnswers; }
    public void setDiagnosticAnswers(String diagnosticAnswers) { this.diagnosticAnswers = diagnosticAnswers; }
    public String getComment() { return comment; }
    public void setComment(String comment) { this.comment = comment; }
    public String getPhotoUrls() { return photoUrls; }
    public void setPhotoUrls(String photoUrls) { this.photoUrls = photoUrls; }
    public Integer getRequestRadiusKm() { return requestRadiusKm; }
    public void setRequestRadiusKm(Integer requestRadiusKm) { this.requestRadiusKm = requestRadiusKm; }
    public Double getAdvanceAmount() { return advanceAmount; }
    public void setAdvanceAmount(Double advanceAmount) { this.advanceAmount = advanceAmount; }
    public Double getPlatformFee() { return platformFee; }
    public void setPlatformFee(Double platformFee) { this.platformFee = platformFee; }
    public Double getComingChargePerKm() { return comingChargePerKm; }
    public void setComingChargePerKm(Double comingChargePerKm) { this.comingChargePerKm = comingChargePerKm; }
    public Double getComingChargeTotal() { return comingChargeTotal; }
    public void setComingChargeTotal(Double comingChargeTotal) { this.comingChargeTotal = comingChargeTotal; }
    public Double getDistanceKmToCustomer() { return distanceKmToCustomer; }
    public void setDistanceKmToCustomer(Double distanceKmToCustomer) { this.distanceKmToCustomer = distanceKmToCustomer; }
    public Long getAcceptedMechanicId() { return acceptedMechanicId; }
    public void setAcceptedMechanicId(Long acceptedMechanicId) { this.acceptedMechanicId = acceptedMechanicId; }
    public Boolean getUserConfirmedArrival() { return userConfirmedArrival; }
    public void setUserConfirmedArrival(Boolean userConfirmedArrival) { this.userConfirmedArrival = userConfirmedArrival; }
    public Boolean getMechanicConfirmedArrival() { return mechanicConfirmedArrival; }
    public void setMechanicConfirmedArrival(Boolean mechanicConfirmedArrival) { this.mechanicConfirmedArrival = mechanicConfirmedArrival; }
    public Boolean getUserConfirmedCompleted() { return userConfirmedCompleted; }
    public void setUserConfirmedCompleted(Boolean userConfirmedCompleted) { this.userConfirmedCompleted = userConfirmedCompleted; }
    public Boolean getMechanicConfirmedCompleted() { return mechanicConfirmedCompleted; }
    public void setMechanicConfirmedCompleted(Boolean mechanicConfirmedCompleted) { this.mechanicConfirmedCompleted = mechanicConfirmedCompleted; }
    public String getUserCompletionRemarks() { return userCompletionRemarks; }
    public void setUserCompletionRemarks(String userCompletionRemarks) { this.userCompletionRemarks = userCompletionRemarks; }
    public String getMechanicCompletionRemarks() { return mechanicCompletionRemarks; }
    public void setMechanicCompletionRemarks(String mechanicCompletionRemarks) { this.mechanicCompletionRemarks = mechanicCompletionRemarks; }
    public String getRefundStatus() { return refundStatus; }
    public void setRefundStatus(String refundStatus) { this.refundStatus = refundStatus; }
    public LocalDateTime getViewExpiryAt() { return viewExpiryAt; }
    public void setViewExpiryAt(LocalDateTime viewExpiryAt) { this.viewExpiryAt = viewExpiryAt; }
    public Boolean getOutOfHoursRequest() { return outOfHoursRequest; }
    public void setOutOfHoursRequest(Boolean outOfHoursRequest) { this.outOfHoursRequest = outOfHoursRequest; }
    public String getNotifiedMechanicIds() { return notifiedMechanicIds; }
    public void setNotifiedMechanicIds(String notifiedMechanicIds) { this.notifiedMechanicIds = notifiedMechanicIds; }
    public Double getCustomerRating() { return customerRating; }
    public void setCustomerRating(Double customerRating) { this.customerRating = customerRating; }
    public String getCustomerRatingComment() { return customerRatingComment; }
    public void setCustomerRatingComment(String customerRatingComment) { this.customerRatingComment = customerRatingComment; }

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

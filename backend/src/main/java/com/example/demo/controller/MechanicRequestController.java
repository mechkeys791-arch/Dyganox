package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.model.MechanicRequest;
import com.example.demo.model.UserVehicle;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.MechanicRequestRepo;
import com.example.demo.repository.UserVehicleRepo;
import com.example.demo.service.FcmService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/mechanic-requests")
public class MechanicRequestController {

    @Autowired
    private MechanicRequestRepo mechanicRequestRepo;

    @Autowired
    private MechanicRepo mechanicRepo;

    @Autowired
    private FcmService fcmService;

    @Autowired
    private UserVehicleRepo userVehicleRepo;

    @PostMapping
    public ResponseEntity<MechanicRequest> createRequest(@RequestBody MechanicRequest request) {
        System.out.println("📥 [Request] Received mechanicId=" + request.getMechanicId() + " customer=" + request.getCustomerName());
        try {
            request.setStatus("PENDING");
            request.setRequestTime(LocalDateTime.now());
            if (request.getUserVehicleId() != null) {
                Optional<UserVehicle> uvOpt = userVehicleRepo.findById(request.getUserVehicleId());
                if (uvOpt.isPresent()) {
                    UserVehicle uv = uvOpt.get();
                    request.setVehicleMakeName(uv.getMakeName());
                    request.setVehicleModelName(uv.getModelName());
                    request.setVehiclePlateNumber(uv.getPlateNumber());
                    String photo = uv.getPhotoUrl() != null && !uv.getPhotoUrl().isBlank()
                            ? uv.getPhotoUrl() : uv.getModelImageUrl();
                    request.setVehiclePhotoUrl(photo);
                }
            }
            MechanicRequest savedRequest = mechanicRequestRepo.save(request);
            Long requestId = savedRequest.getId();
            Long mechanicId = savedRequest.getMechanicId();
            System.out.println("✅ Request saved: requestId=" + requestId + ", mechanicId=" + mechanicId);

            // Send FCM to mechanic so they get Accept/Reject notification
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(mechanicId);
            if (!mechanicOpt.isPresent()) {
                System.err.println("⚠️ [FCM] Mechanic not found for mechanicId=" + mechanicId + ". Cannot send notification.");
            } else {
                Mechanic mechanic = mechanicOpt.get();
                String fcmToken = mechanic.getFcmToken();
                boolean hasToken = fcmToken != null && !fcmToken.isBlank();
                if (!hasToken) {
                    System.err.println("⚠️ [Request " + requestId + "] Notification NOT sent: mechanic " + mechanicId + " has no FCM token. Mechanic must open the app and go to Mechanic Dashboard on the device that should receive notifications (token is saved on first dashboard open).");
                } else {
                    System.out.println("[FCM] mechanicId=" + mechanicId + ", requestId=" + requestId + ", sending...");
                }
                fcmService.sendMechanicRequestNotification(
                        fcmToken,
                        requestId,
                        savedRequest.getCustomerName(),
                        savedRequest.getServiceType(),
                        savedRequest.getCustomerPhone(),
                        savedRequest.getAmount(),
                        savedRequest.getDistanceKm(),
                        savedRequest.getDescription());
            }

            return ResponseEntity.status(HttpStatus.CREATED).body(savedRequest);
        } catch (Exception e) {
            System.err.println("❌ Error saving request: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/mechanic/{mechanicId}")
    public ResponseEntity<List<MechanicRequest>> getRequestsByMechanic(@PathVariable Long mechanicId) {
        System.out.println("📤 GET request received - fetching requests for mechanic: " + mechanicId);
        try {
            List<MechanicRequest> requests = mechanicRequestRepo.findByMechanicIdOrderByRequestTimeDesc(mechanicId);
            System.out.println("📤 Found " + requests.size() + " requests for mechanic");
            return ResponseEntity.ok(requests);
        } catch (Exception e) {
            System.err.println("❌ Error fetching requests: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{requestId}")
    public ResponseEntity<MechanicRequest> getRequestById(@PathVariable Long requestId) {
        try {
            Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
            return opt.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
        } catch (Exception e) {
            System.err.println("❌ Error fetching request " + requestId + ": " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/mechanic/{mechanicId}/pending")
    public ResponseEntity<List<MechanicRequest>> getPendingRequests(@PathVariable Long mechanicId) {
        System.out.println("📤 GET pending requests for mechanic: " + mechanicId);
        try {
            List<MechanicRequest> requests = mechanicRequestRepo.findByMechanicIdAndStatus(mechanicId, "PENDING");
            System.out.println("📤 Found " + requests.size() + " pending requests");
            return ResponseEntity.ok(requests);
        } catch (Exception e) {
            System.err.println("❌ Error fetching pending requests: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/{requestId}/accept")
    public ResponseEntity<Map<String, String>> acceptRequest(@PathVariable Long requestId) {
        System.out.println("✅ Accepting request ID: " + requestId);
        try {
            Optional<MechanicRequest> optionalRequest = mechanicRequestRepo.findById(requestId);
            if (optionalRequest.isPresent()) {
                MechanicRequest request = optionalRequest.get();
                request.setStatus("ACCEPTED");
                request.setResponseTime(LocalDateTime.now());
                mechanicRequestRepo.save(request);
                
                Map<String, String> response = new HashMap<>();
                response.put("message", "Request accepted successfully");
                response.put("status", "ACCEPTED");
                
                System.out.println("✅ Request " + requestId + " accepted successfully");
                return ResponseEntity.ok(response);
            } else {
                Map<String, String> response = new HashMap<>();
                response.put("error", "Request not found");
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
            }
        } catch (Exception e) {
            System.err.println("❌ Error accepting request: " + e.getMessage());
            e.printStackTrace();
            Map<String, String> response = new HashMap<>();
            response.put("error", "Internal server error");
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }

    @PutMapping("/{requestId}/reject")
    public ResponseEntity<Map<String, String>> rejectRequest(@PathVariable Long requestId) {
        System.out.println("❌ Rejecting request ID: " + requestId);
        try {
            Optional<MechanicRequest> optionalRequest = mechanicRequestRepo.findById(requestId);
            if (optionalRequest.isPresent()) {
                MechanicRequest request = optionalRequest.get();
                request.setStatus("REJECTED");
                request.setResponseTime(LocalDateTime.now());
                mechanicRequestRepo.save(request);
                
                Map<String, String> response = new HashMap<>();
                response.put("message", "Request rejected");
                response.put("status", "REJECTED");
                
                System.out.println("❌ Request " + requestId + " rejected successfully");
                return ResponseEntity.ok(response);
            } else {
                Map<String, String> response = new HashMap<>();
                response.put("error", "Request not found");
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
            }
        } catch (Exception e) {
            System.err.println("❌ Error rejecting request: " + e.getMessage());
            e.printStackTrace();
            Map<String, String> response = new HashMap<>();
            response.put("error", "Internal server error");
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }

    @PutMapping("/{requestId}/complete")
    public ResponseEntity<Map<String, String>> completeRequest(@PathVariable Long requestId) {
        System.out.println("✅ Completing request ID: " + requestId);
        try {
            Optional<MechanicRequest> optionalRequest = mechanicRequestRepo.findById(requestId);
            if (optionalRequest.isPresent()) {
                MechanicRequest request = optionalRequest.get();
                request.setStatus("COMPLETED");
                request.setResponseTime(LocalDateTime.now());
                mechanicRequestRepo.save(request);
                
                Map<String, String> response = new HashMap<>();
                response.put("message", "Request completed successfully");
                response.put("status", "COMPLETED");
                
                System.out.println("✅ Request " + requestId + " completed successfully");
                return ResponseEntity.ok(response);
            } else {
                Map<String, String> response = new HashMap<>();
                response.put("error", "Request not found");
                return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
            }
        } catch (Exception e) {
            System.err.println("❌ Error completing request: " + e.getMessage());
            e.printStackTrace();
            Map<String, String> response = new HashMap<>();
            response.put("error", "Internal server error");
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
        }
    }

    @GetMapping
    public ResponseEntity<List<MechanicRequest>> getAllRequests() {
        System.out.println("📤 GET request received - fetching all requests");
        try {
            List<MechanicRequest> requests = mechanicRequestRepo.findAll();
            System.out.println("📤 Found " + requests.size() + " requests in database");
            return ResponseEntity.ok(requests);
        } catch (Exception e) {
            System.err.println("❌ Error fetching requests: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}

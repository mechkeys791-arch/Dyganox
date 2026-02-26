package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.model.MechanicRequest;
import com.example.demo.model.UserVehicle;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.MechanicRequestRepo;
import com.example.demo.repository.UserVehicleRepo;
import com.example.demo.service.BookMechanicService;
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
@CrossOrigin(origins = "*")
public class MechanicRequestController {

    @Autowired
    private MechanicRequestRepo mechanicRequestRepo;

    @Autowired
    private UserVehicleRepo userVehicleRepo;

    @Autowired
    private MechanicRepo mechanicRepo;

    @Autowired
    private FcmService fcmService;

    @Autowired
    private BookMechanicService bookMechanicService;

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
                    Double distanceKm = savedRequest.getDistanceKm();
                    if (distanceKm == null) {
                        distanceKm = computeDistanceKm(mechanic, savedRequest);
                    }
                    fcmService.sendMechanicRequestNotification(
                            fcmToken,
                            requestId,
                            savedRequest.getCustomerName(),
                            savedRequest.getServiceType(),
                            savedRequest.getCustomerPhone(),
                            savedRequest.getAmount(),
                            distanceKm,
                            savedRequest.getDescription());
                }
            }

            return ResponseEntity.status(HttpStatus.CREATED).body(savedRequest);
        } catch (Exception e) {
            System.err.println("❌ Error saving request: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /** Compute distance in km between mechanic location and customer (request) location using Haversine formula. */
    private Double computeDistanceKm(Mechanic mechanic, MechanicRequest request) {
        String mLat = mechanic.getCurrentLatitude() != null ? mechanic.getCurrentLatitude() : mechanic.getLatitude();
        String mLng = mechanic.getCurrentLongitude() != null ? mechanic.getCurrentLongitude() : mechanic.getLongitude();
        String rLat = request.getLatitude();
        String rLng = request.getLongitude();
        if (mLat == null || mLng == null || rLat == null || rLng == null) return null;
        try {
            double lat1 = Double.parseDouble(mLat);
            double lon1 = Double.parseDouble(mLng);
            double lat2 = Double.parseDouble(rLat);
            double lon2 = Double.parseDouble(rLng);
            final int R = 6371;
            double dLat = Math.toRadians(lat2 - lat1);
            double dLon = Math.toRadians(lon2 - lon1);
            double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                    + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                    * Math.sin(dLon / 2) * Math.sin(dLon / 2);
            double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
            return R * c;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Book Mechanic: create broadcast request (5/10/20 km), notify nearby mechanics. */
    @PostMapping("/broadcast")
    public ResponseEntity<?> createBroadcastRequest(@RequestBody Map<String, Object> body) {
        try {
            String customerName = getStr(body, "customerName");
            String customerEmail = getStr(body, "customerEmail");
            String customerPhone = getStr(body, "customerPhone");
            Long userVehicleId = body.get("userVehicleId") != null ? Long.valueOf(body.get("userVehicleId").toString()) : null;
            String problemCategory = getStr(body, "problemCategory");
            String description = getStr(body, "description");
            String diagnosticAnswers = getStr(body, "diagnosticAnswers");
            String comment = getStr(body, "comment");
            String photoUrls = getStr(body, "photoUrls");
            Double lat = body.get("latitude") != null ? Double.valueOf(body.get("latitude").toString()) : null;
            Double lng = body.get("longitude") != null ? Double.valueOf(body.get("longitude").toString()) : null;
            if (lat == null || lng == null) {
                return ResponseEntity.badRequest().body(Map.of("error", "latitude and longitude required"));
            }
            Double advanceAmount = body.get("advanceAmount") != null ? Double.valueOf(body.get("advanceAmount").toString()) : 100.0;
            Double platformFee = body.get("platformFee") != null ? Double.valueOf(body.get("platformFee").toString()) : 9.0;
            Double comingChargePerKm = body.get("comingChargePerKm") != null ? Double.valueOf(body.get("comingChargePerKm").toString()) : 3.0;
            Double comingChargeTotal = body.get("comingChargeTotal") != null ? Double.valueOf(body.get("comingChargeTotal").toString()) : 0.0;
            Integer requestRadiusKm = body.get("requestRadiusKm") != null ? Integer.valueOf(body.get("requestRadiusKm").toString()) : 5;
            Boolean outOfHoursRequest = body.get("outOfHoursRequest") != null && Boolean.TRUE.equals(body.get("outOfHoursRequest"));

            MechanicRequest saved = bookMechanicService.createBroadcastRequest(
                    customerName, customerEmail, customerPhone, userVehicleId, problemCategory, description,
                    diagnosticAnswers, comment, photoUrls, lat, lng, advanceAmount, platformFee,
                    comingChargePerKm, comingChargeTotal, requestRadiusKm, outOfHoursRequest);
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("error", e.getMessage()));
        }
    }

    private static String getStr(Map<String, Object> m, String key) {
        Object v = m.get(key);
        return v != null ? v.toString().trim() : null;
    }

    /** Book Mechanic: list requests visible to this mechanic (within 5 min window, category + radius). */
    @GetMapping("/nearby-for-mechanic")
    public ResponseEntity<List<MechanicRequest>> getNearbyForMechanic(
            @RequestParam Long mechanicId,
            @RequestParam double lat,
            @RequestParam double lng) {
        List<MechanicRequest> list = bookMechanicService.getNearbyRequestsForMechanic(mechanicId, lat, lng);
        return ResponseEntity.ok(list);
    }

    /** Book Mechanic: mechanic accepts request (first accept wins). */
    @PutMapping("/{requestId}/accept-by/{mechanicId}")
    public ResponseEntity<Map<String, Object>> acceptByMechanic(@PathVariable Long requestId, @PathVariable Long mechanicId) {
        Optional<MechanicRequest> opt = bookMechanicService.acceptByMechanic(requestId, mechanicId);
        if (opt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("error", "Request already accepted or expired"));
        }
        return ResponseEntity.ok(Map.of("message", "Accepted", "request", opt.get()));
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

    @PutMapping("/{requestId}/arrived")
    public ResponseEntity<Map<String, String>> markArrived(@PathVariable Long requestId) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        r.setStatus("ARRIVED");
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("message", "Marked as arrived", "status", "ARRIVED"));
    }

    @PutMapping("/{requestId}/confirm-arrival-user")
    public ResponseEntity<Map<String, String>> confirmArrivalUser(@PathVariable Long requestId) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        r.setUserConfirmedArrival(true);
        if (Boolean.TRUE.equals(r.getMechanicConfirmedArrival())) r.setStatus("USER_CONFIRMED");
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("message", "Confirmed"));
    }

    @PutMapping("/{requestId}/confirm-arrival-mechanic")
    public ResponseEntity<Map<String, String>> confirmArrivalMechanic(@PathVariable Long requestId) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        r.setMechanicConfirmedArrival(true);
        if (Boolean.TRUE.equals(r.getUserConfirmedArrival())) r.setStatus("USER_CONFIRMED");
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("message", "Confirmed"));
    }

    @PutMapping("/{requestId}/complete-user")
    public ResponseEntity<Map<String, String>> completeUser(
            @PathVariable Long requestId,
            @RequestBody(required = false) Map<String, String> body) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        r.setUserConfirmedCompleted(true);
        if (body != null && body.containsKey("remarks")) r.setUserCompletionRemarks(body.get("remarks"));
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("message", "Submitted"));
    }

    @PutMapping("/{requestId}/complete-mechanic")
    public ResponseEntity<Map<String, String>> completeMechanic(
            @PathVariable Long requestId,
            @RequestBody(required = false) Map<String, String> body) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        r.setMechanicConfirmedCompleted(true);
        if (body != null && body.containsKey("remarks")) r.setMechanicCompletionRemarks(body.get("remarks"));
        r.setStatus("COMPLETED");
        r.setResponseTime(LocalDateTime.now());
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("message", "Completed"));
    }

    @PutMapping("/{requestId}/cancel")
    public ResponseEntity<Map<String, String>> cancelRequest(@PathVariable Long requestId) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        if (!"PENDING_BROADCAST".equals(r.getStatus())) {
            return ResponseEntity.badRequest().body(Map.of("error", "Can only cancel pending requests"));
        }
        r.setStatus("CANCELLED");
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("message", "Request cancelled", "status", "CANCELLED"));
    }

    /** Customer rates mechanic after service (request must be COMPLETED and not already rated). */
    @PutMapping("/{requestId}/rate")
    public ResponseEntity<Map<String, Object>> rateRequest(
            @PathVariable Long requestId,
            @RequestBody Map<String, Object> body) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        if (!"COMPLETED".equals(r.getStatus())) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Can only rate completed requests"));
        }
        if (r.getCustomerRating() != null) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Already rated"));
        }
        Object ratingObj = body != null ? body.get("rating") : null;
        double rating = 5.0;
        if (ratingObj instanceof Number) {
            rating = ((Number) ratingObj).doubleValue();
        }
        rating = Math.max(1, Math.min(5, rating));
        String comment = body != null && body.get("comment") != null ? body.get("comment").toString() : null;
        if (comment != null && comment.length() > 500) comment = comment.substring(0, 500);
        r.setCustomerRating(rating);
        r.setCustomerRatingComment(comment);
        mechanicRequestRepo.save(r);
        Long mechanicId = r.getAcceptedMechanicId();
        if (mechanicId != null) {
            Optional<Mechanic> mOpt = mechanicRepo.findById(mechanicId);
            if (mOpt.isPresent()) {
                Mechanic m = mOpt.get();
                double current = m.getRating() != null ? m.getRating() : 0;
                int count = m.getRatingCount() != null ? m.getRatingCount() : 0;
                double newRating = (current * count + rating) / (count + 1);
                m.setRating(newRating);
                m.setRatingCount(count + 1);
                mechanicRepo.save(m);
            }
        }
        Map<String, Object> resp = new HashMap<>();
        resp.put("success", true);
        resp.put("message", "Thank you for your rating");
        return ResponseEntity.ok(resp);
    }

    @PutMapping("/{requestId}/refund-status")
    public ResponseEntity<Map<String, String>> setRefundStatus(
            @PathVariable Long requestId,
            @RequestBody Map<String, String> body) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRequest r = opt.get();
        if (body.containsKey("refundStatus")) r.setRefundStatus(body.get("refundStatus"));
        mechanicRequestRepo.save(r);
        return ResponseEntity.ok(Map.of("refundStatus", r.getRefundStatus() != null ? r.getRefundStatus() : "PENDING"));
    }

    @GetMapping("/customer/{customerEmail}")
    public ResponseEntity<List<MechanicRequest>> getRequestsByCustomer(@PathVariable String customerEmail) {
        List<MechanicRequest> requests = mechanicRequestRepo.findByCustomerEmailOrderByRequestTimeDesc(customerEmail);
        return ResponseEntity.ok(requests);
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

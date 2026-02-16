package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.model.MechanicRegistrationRequest;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.MechanicRegistrationRequestRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Random;
import java.util.stream.Collectors;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

@RestController
@RequestMapping("/api/mechanic")
@CrossOrigin(origins = "*")
public class MechanicController {

    @Autowired
    private MechanicRepo mechanicRepo;

    @Autowired
    private MechanicRegistrationRequestRepo mechanicRegistrationRequestRepo;
    
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    /**
     * Register a new mechanic (from app registration form).
     * Saves all provided fields into the "requests" table (MechanicRegistrationRequest).
     */
    @PostMapping
    public ResponseEntity<?> createMechanic(@RequestBody Map<String, Object> body) {
        System.out.println("📥 Received mechanic registration: " + body.keySet());
        try {
            MechanicRegistrationRequest r = new MechanicRegistrationRequest();
            r.setName(getString(body, "name"));
            r.setEmail(getString(body, "email"));
            r.setPhone(getString(body, "phone"));
            r.setAadharNumber(getString(body, "aadharNumber"));
            r.setExperience(getString(body, "experience"));
            r.setProfilePhotoUrl(getString(body, "profilePhotoUrl"));
            r.setShopName(getString(body, "shopName"));
            r.setShopAddress(getString(body, "shopAddress"));
            r.setShopCity(getString(body, "shopCity"));
            r.setShopState(getString(body, "shopState"));
            r.setShopPincode(getString(body, "shopPincode"));
            r.setShopCountry(getString(body, "shopCountry"));
            r.setLatitude(getString(body, "latitude"));
            r.setLongitude(getString(body, "longitude"));
            r.setServices(getString(body, "services"));
            r.setSpecialty(getString(body, "specialty"));
            r.setOpeningTime(getString(body, "openingTime"));
            r.setClosingTime(getString(body, "closingTime"));
            r.setWorkingDays(getString(body, "workingDays"));
            r.setNightTimeAvailable(Boolean.TRUE.equals(body.get("nightTimeAvailable")));
            String status = getString(body, "approvalStatus");
            r.setApprovalStatus(status != null && !status.isEmpty() ? status : "PENDING");

            MechanicRegistrationRequest saved = mechanicRegistrationRequestRepo.save(r);
            System.out.println("✅ Registration request saved in table 'requests' with ID: " + saved.getId() + ", email: " + saved.getEmail());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            System.err.println("❌ Error saving mechanic registration request: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(Map.of("error", e.getMessage()));
        }
    }

    private static String getString(Map<String, Object> map, String key) {
        Object v = map.get(key);
        if (v == null) return null;
        return v.toString().trim();
    }

    // ---------- Registration requests (table: requests) - admin approve/reject ----------

    @GetMapping("/registration-requests")
    public ResponseEntity<List<MechanicRegistrationRequest>> getAllRegistrationRequests(
            @RequestParam(required = false) String status) {
        try {
            List<MechanicRegistrationRequest> list = mechanicRegistrationRequestRepo.findAll();
            if (status != null && !status.isEmpty()) {
                list = list.stream()
                        .filter(r -> status.equalsIgnoreCase(r.getApprovalStatus()))
                        .collect(Collectors.toList());
            }
            list.sort((a, b) -> (b.getCreatedAt() != null && a.getCreatedAt() != null)
                    ? b.getCreatedAt().compareTo(a.getCreatedAt()) : 0);
            return ResponseEntity.ok(list);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/registration-requests/email/{email}")
    public ResponseEntity<MechanicRegistrationRequest> getRegistrationRequestByEmail(@PathVariable String email) {
        List<MechanicRegistrationRequest> list = mechanicRegistrationRequestRepo.findByEmailIgnoreCaseOrderByCreatedAtDesc(email != null ? email.trim() : "");
        if (list.isEmpty()) return ResponseEntity.notFound().build();
        return ResponseEntity.ok(list.get(0));
    }

    private static final String PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
    private static final int TEMP_PASSWORD_LENGTH = 8;

    private static String generateTempPassword() {
        Random r = new Random();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < TEMP_PASSWORD_LENGTH; i++) {
            sb.append(PASSWORD_CHARS.charAt(r.nextInt(PASSWORD_CHARS.length())));
        }
        return sb.toString();
    }

    @PutMapping("/registration-requests/{id}/approve")
    public ResponseEntity<?> approveRegistrationRequest(@PathVariable Long id) {
        Optional<MechanicRegistrationRequest> opt = mechanicRegistrationRequestRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRegistrationRequest req = opt.get();
        req.setApprovalStatus("APPROVED");
        mechanicRegistrationRequestRepo.save(req);
        // Create Mechanic with generated password (to be sent to mechanic's WhatsApp by admin/later)
        Mechanic m = new Mechanic();
        m.setName(req.getName());
        m.setEmail(req.getEmail());
        m.setPhone(req.getPhone());
        m.setAadharNumber(req.getAadharNumber());
        m.setExperience(req.getExperience());
        m.setProfilePhotoUrl(req.getProfilePhotoUrl());
        m.setShopName(req.getShopName());
        m.setShopAddress(req.getShopAddress());
        m.setShopCity(req.getShopCity());
        m.setShopState(req.getShopState());
        m.setShopPincode(req.getShopPincode());
        m.setShopCountry(req.getShopCountry());
        m.setLatitude(req.getLatitude());
        m.setLongitude(req.getLongitude());
        m.setServices(req.getServices());
        m.setSpecialty(req.getSpecialty() != null ? req.getSpecialty() : "General");
        m.setOpeningTime(req.getOpeningTime());
        m.setClosingTime(req.getClosingTime());
        m.setWorkingDays(req.getWorkingDays());
        m.setNightTimeAvailable(req.isNightTimeAvailable());
        m.setApprovalStatus("APPROVED");
        m.setStatus("Available");
        String tempPassword = generateTempPassword();
        m.setPassword(passwordEncoder.encode(tempPassword));
        m.setPasswordSet(true);
        mechanicRepo.save(m);
        System.out.println("✅ Registration request " + id + " approved; Mechanic created for " + req.getEmail() + ". Temp password (send to WhatsApp): " + tempPassword);
        return ResponseEntity.ok(Map.of(
            "message", "Approved",
            "requestId", id,
            "email", req.getEmail(),
            "tempPassword", tempPassword
        ));
    }

    @PutMapping("/registration-requests/{id}/reject")
    public ResponseEntity<?> rejectRegistrationRequest(@PathVariable Long id, @RequestBody(required = false) Map<String, String> body) {
        Optional<MechanicRegistrationRequest> opt = mechanicRegistrationRequestRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MechanicRegistrationRequest req = opt.get();
        req.setApprovalStatus("REJECTED");
        if (body != null && body.containsKey("reason")) {
            req.setRejectionReason(body.get("reason"));
        }
        mechanicRegistrationRequestRepo.save(req);
        System.out.println("❌ Registration request " + id + " rejected. Reason: " + req.getRejectionReason());
        return ResponseEntity.ok(Map.of("message", "Rejected", "requestId", id));
    }

    @GetMapping
    public ResponseEntity<List<Mechanic>> getAllMechanics(@RequestParam(required = false) String approved) {
        System.out.println("📤 GET request received - fetching all mechanics");
        try {
            List<Mechanic> mechanics = mechanicRepo.findAll();
            
            // If approved=true parameter is passed, filter to only approved mechanics
            if ("true".equalsIgnoreCase(approved)) {
                mechanics = mechanics.stream()
                        .filter(m -> m.getApprovalStatus() != null && m.getApprovalStatus().equals("APPROVED"))
                        .collect(java.util.stream.Collectors.toList());
                System.out.println("📤 Found " + mechanics.size() + " approved mechanics");
            } else {
                System.out.println("📤 Found " + mechanics.size() + " mechanics in database");
            }
            
            return ResponseEntity.ok(mechanics);
        } catch (Exception e) {
            System.err.println("❌ Error fetching mechanics: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/{id}")
    public ResponseEntity<Mechanic> getMechanicById(@PathVariable Long id) {
        System.out.println("📤 GET request for mechanic ID: " + id);
        Optional<Mechanic> mechanic = mechanicRepo.findById(id);
        if (mechanic.isPresent()) {
            System.out.println("✅ Found mechanic: " + mechanic.get());
            return ResponseEntity.ok(mechanic.get());
        } else {
            System.out.println("❌ Mechanic not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }

    @PutMapping("/{id}/status")
    public ResponseEntity<Mechanic> updateMechanicStatus(@PathVariable Long id, @RequestBody Map<String, String> request) {
        System.out.println("🔄 PUT request to update status for mechanic ID: " + id);
        System.out.println("📥 New status: " + request.get("status"));
        
        Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
        if (mechanicOpt.isPresent()) {
            Mechanic mechanic = mechanicOpt.get();
            String newStatus = request.get("status");
            
            if (newStatus != null && (newStatus.equals("Available") || newStatus.equals("Busy") || newStatus.equals("Offline"))) {
                mechanic.setStatus(newStatus);
                mechanic.setOnline(!"Offline".equals(newStatus));
                Mechanic updatedMechanic = mechanicRepo.save(mechanic);
                System.out.println("✅ Mechanic status updated successfully to: " + newStatus);
                return ResponseEntity.ok(updatedMechanic);
            } else {
                System.out.println("❌ Invalid status: " + newStatus);
                return ResponseEntity.badRequest().build();
            }
        } else {
            System.out.println("❌ Mechanic not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<Mechanic> updateMechanic(@PathVariable Long id, @RequestBody Mechanic updatedMechanic) {
        System.out.println("🔄 PUT request to update mechanic ID: " + id);
        Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
        if (mechanicOpt.isPresent()) {
            Mechanic mechanic = mechanicOpt.get();
            
            // Update fields
            if (updatedMechanic.getName() != null) mechanic.setName(updatedMechanic.getName());
            if (updatedMechanic.getEmail() != null) mechanic.setEmail(updatedMechanic.getEmail());
            if (updatedMechanic.getPhone() != null) mechanic.setPhone(updatedMechanic.getPhone());
            if (updatedMechanic.getSpecialty() != null) mechanic.setSpecialty(updatedMechanic.getSpecialty());
            if (updatedMechanic.getExperience() != null) mechanic.setExperience(updatedMechanic.getExperience());
            if (updatedMechanic.getLatitude() != null) mechanic.setLatitude(updatedMechanic.getLatitude());
            if (updatedMechanic.getLongitude() != null) mechanic.setLongitude(updatedMechanic.getLongitude());
            mechanic.setNightTimeAvailable(updatedMechanic.isNightTimeAvailable());
            if (updatedMechanic.getStatus() != null) mechanic.setStatus(updatedMechanic.getStatus());
            if (updatedMechanic.getProfilePhotoUrl() != null) mechanic.setProfilePhotoUrl(updatedMechanic.getProfilePhotoUrl());
            if (updatedMechanic.getAadharNumber() != null) mechanic.setAadharNumber(updatedMechanic.getAadharNumber());
            if (updatedMechanic.getShopName() != null) mechanic.setShopName(updatedMechanic.getShopName());
            if (updatedMechanic.getShopAddress() != null) mechanic.setShopAddress(updatedMechanic.getShopAddress());
            if (updatedMechanic.getShopCity() != null) mechanic.setShopCity(updatedMechanic.getShopCity());
            if (updatedMechanic.getShopState() != null) mechanic.setShopState(updatedMechanic.getShopState());
            if (updatedMechanic.getShopPincode() != null) mechanic.setShopPincode(updatedMechanic.getShopPincode());
            if (updatedMechanic.getShopCountry() != null) mechanic.setShopCountry(updatedMechanic.getShopCountry());
            if (updatedMechanic.getServices() != null) mechanic.setServices(updatedMechanic.getServices());
            if (updatedMechanic.getOpeningTime() != null) mechanic.setOpeningTime(updatedMechanic.getOpeningTime());
            if (updatedMechanic.getClosingTime() != null) mechanic.setClosingTime(updatedMechanic.getClosingTime());
            if (updatedMechanic.getWorkingDays() != null) mechanic.setWorkingDays(updatedMechanic.getWorkingDays());
            
            Mechanic savedMechanic = mechanicRepo.save(mechanic);
            System.out.println("✅ Mechanic updated successfully");
            return ResponseEntity.ok(savedMechanic);
        } else {
            System.out.println("❌ Mechanic not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteMechanic(@PathVariable Long id) {
        System.out.println("🗑️ DELETE request received for ID: " + id);
        Optional<Mechanic> mechanic = mechanicRepo.findById(id);
        if (mechanic.isPresent()) {
            mechanicRepo.deleteById(id);
            System.out.println("✅ Mechanic deleted successfully");
            return ResponseEntity.noContent().build();
        } else {
            System.out.println("❌ Mechanic not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }

    // Setup password after admin approval
    @PutMapping("/{id}/password")
    public ResponseEntity<Mechanic> setupPassword(@PathVariable Long id, @RequestBody Map<String, Object> request) {
        System.out.println("🔐 PUT request to setup password for mechanic ID: " + id);
        Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
        if (mechanicOpt.isPresent()) {
            Mechanic mechanic = mechanicOpt.get();
            
            // Check if mechanic is approved
            if (!"APPROVED".equals(mechanic.getApprovalStatus())) {
                System.out.println("❌ Mechanic not approved yet");
                return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
            }
            
            // Hash and save password
            String password = (String) request.get("password");
            if (password != null && !password.isEmpty()) {
                String hashedPassword = passwordEncoder.encode(password);
                mechanic.setPassword(hashedPassword);
                mechanic.setPasswordSet(true);
                Mechanic updated = mechanicRepo.save(mechanic);
                System.out.println("✅ Password set successfully for mechanic " + id);
                return ResponseEntity.ok(updated);
            } else {
                return ResponseEntity.badRequest().build();
            }
        } else {
            return ResponseEntity.notFound().build();
        }
    }

    // Register FCM token for push notifications (mechanic request accept/reject)
    @PutMapping("/{id}/fcm-token")
    public ResponseEntity<Mechanic> updateFcmToken(@PathVariable Long id, @RequestBody Map<String, String> body) {
        String fcmToken = body != null ? body.get("fcmToken") : null;
        Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
        if (mechanicOpt.isPresent()) {
            Mechanic mechanic = mechanicOpt.get();
            mechanic.setFcmToken(fcmToken);
            mechanicRepo.save(mechanic);
            System.out.println("✅ FCM token updated for mechanic ID: " + id);
            return ResponseEntity.ok(mechanic);
        }
        return ResponseEntity.notFound().build();
    }

    // Get mechanic by email (for password setup check)
    @GetMapping("/email/{email}")
    public ResponseEntity<Mechanic> getMechanicByEmail(@PathVariable String email) {
        System.out.println("📤 GET request for mechanic email: " + email);
        List<Mechanic> mechanics = mechanicRepo.findAll();
        Optional<Mechanic> mechanic = mechanics.stream()
                .filter(m -> email.equalsIgnoreCase(m.getEmail()))
                .findFirst();
        if (mechanic.isPresent()) {
            return ResponseEntity.ok(mechanic.get());
        } else {
            return ResponseEntity.notFound().build();
        }
    }
}

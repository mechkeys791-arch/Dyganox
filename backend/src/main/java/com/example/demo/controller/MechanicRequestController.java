package com.example.demo.controller;

import com.example.demo.model.MechanicRequest;
import com.example.demo.repository.MechanicRequestRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@CrossOrigin(origins = "*")
@RestController
@RequestMapping("/api/mechanic-requests")
public class MechanicRequestController {

    @Autowired
    private MechanicRequestRepo mechanicRequestRepo;

    @PostMapping
    public ResponseEntity<MechanicRequest> createRequest(@RequestBody MechanicRequest request) {
        System.out.println("📥 Received Mechanic Request: " + request);
        try {
            request.setStatus("PENDING");
            request.setRequestTime(LocalDateTime.now());
            MechanicRequest savedRequest = mechanicRequestRepo.save(request);
            System.out.println("✅ Request saved successfully with ID: " + savedRequest.getId());
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

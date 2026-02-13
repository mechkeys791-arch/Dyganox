package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.repository.MechanicRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/mechanic")
public class MechanicController {

    @Autowired
    private MechanicRepo mechanicRepo;

    @PostMapping
    public ResponseEntity<Mechanic> createMechanic(@RequestBody Mechanic mechanic) {
        System.out.println("📥 Received Mechanic data: " + mechanic);
        
        try {
            Mechanic savedMechanic = mechanicRepo.save(mechanic);
            System.out.println("✅ Mechanic saved successfully with ID: " + savedMechanic.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(savedMechanic);
        } catch (Exception e) {
            System.err.println("❌ Error saving mechanic: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping
    public ResponseEntity<List<Mechanic>> getAllMechanics() {
        System.out.println("📤 GET request received - fetching all mechanics");
        try {
            List<Mechanic> mechanics = mechanicRepo.findAll();
            System.out.println("📤 Found " + mechanics.size() + " mechanics in database");
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
}

package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.repository.MechanicRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@CrossOrigin(origins = "*")
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

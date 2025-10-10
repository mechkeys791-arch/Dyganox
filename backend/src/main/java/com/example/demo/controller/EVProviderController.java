package com.example.demo.controller;

import com.example.demo.model.EVProvider;
import com.example.demo.repository.EVProviderRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@CrossOrigin(origins = "*") // allow Flutter and Postman requests
@RestController
@RequestMapping("/api/evprovider")
public class EVProviderController {

    @Autowired
    private EVProviderRepo evProviderRepo;

    /**
     * POST: Create a new EV Provider
     * URL: http://localhost:8081/api/evprovider
     */
    @PostMapping
    public ResponseEntity<EVProvider> createEVProvider(@RequestBody EVProvider evProvider) {
        System.out.println("📥 Received EV Provider data: " + evProvider);
        System.out.println("📥 Name: " + evProvider.getName());
        System.out.println("📥 Phone: " + evProvider.getPhone());
        System.out.println("📥 Address: " + evProvider.getAddress());
        System.out.println("📥 Charger Type: " + evProvider.getChargerType());
        System.out.println("📥 Rate: " + evProvider.getRate());
        System.out.println("📥 Available Hours: " + evProvider.getAvailableHours());
        
        try {
            EVProvider savedProvider = evProviderRepo.save(evProvider);
            System.out.println("✅ EV Provider saved successfully with ID: " + savedProvider.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(savedProvider);
        } catch (Exception e) {
            System.err.println("❌ Error saving EV provider: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * GET: Fetch all EV Providers
     * URL: http://localhost:8081/api/evprovider
     */
    @GetMapping
    public ResponseEntity<List<EVProvider>> getAllEVProviders() {
        System.out.println("📤 GET request received - fetching all EV providers");
        try {
            List<EVProvider> providers = evProviderRepo.findAll();
            System.out.println("📤 Found " + providers.size() + " EV providers in database");
            for (EVProvider provider : providers) {
                System.out.println("📤 Provider: " + provider);
            }
            return ResponseEntity.ok(providers);
        } catch (Exception e) {
            System.err.println("❌ Error fetching EV providers: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * GET: Fetch EV Provider by ID
     * URL: http://localhost:8081/api/evprovider/{id}
     */
    @GetMapping("/{id}")
    public ResponseEntity<EVProvider> getEVProviderById(@PathVariable Long id) {
        System.out.println("📤 GET request for EV provider ID: " + id);
        Optional<EVProvider> provider = evProviderRepo.findById(id);
        if (provider.isPresent()) {
            System.out.println("✅ Found EV provider: " + provider.get());
            return ResponseEntity.ok(provider.get());
        } else {
            System.out.println("❌ EV provider not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * PUT: Update an existing EV Provider
     * URL: http://localhost:8081/api/evprovider/{id}
     */
    @PutMapping("/{id}")
    public ResponseEntity<EVProvider> updateEVProvider(@PathVariable Long id, @RequestBody EVProvider evProvider) {
        System.out.println("🔄 PUT request received for ID: " + id);
        System.out.println("🔄 Update data: " + evProvider);
        
        Optional<EVProvider> existingProvider = evProviderRepo.findById(id);
        if (existingProvider.isPresent()) {
            evProvider.setId(id);
            EVProvider updatedProvider = evProviderRepo.save(evProvider);
            System.out.println("✅ EV Provider updated successfully: " + updatedProvider);
            return ResponseEntity.ok(updatedProvider);
        } else {
            System.out.println("❌ EV provider not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * DELETE: Delete an EV Provider
     * URL: http://localhost:8081/api/evprovider/{id}
     */
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteEVProvider(@PathVariable Long id) {
        System.out.println("🗑️ DELETE request received for ID: " + id);
        Optional<EVProvider> provider = evProviderRepo.findById(id);
        if (provider.isPresent()) {
            evProviderRepo.deleteById(id);
            System.out.println("✅ EV Provider deleted successfully");
            return ResponseEntity.noContent().build();
        } else {
            System.out.println("❌ EV provider not found with ID: " + id);
            return ResponseEntity.notFound().build();
        }
    }
}


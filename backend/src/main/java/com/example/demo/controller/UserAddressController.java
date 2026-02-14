package com.example.demo.controller;

import com.example.demo.model.UserAddress;
import com.example.demo.repository.UserAddressRepo;
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
@RequestMapping("/api/user-addresses")
@CrossOrigin(origins = "*")
public class UserAddressController {

    @Autowired
    private UserAddressRepo userAddressRepo;

    // Save or update user address
    @PostMapping
    public ResponseEntity<UserAddress> saveAddress(@RequestBody Map<String, Object> addressData) {
        try {
            String userEmail = (String) addressData.get("userEmail");
            if (userEmail == null || userEmail.isEmpty()) {
                return ResponseEntity.badRequest().build();
            }

            // Check if address with same ID exists (for updates)
            UserAddress address;
            if (addressData.containsKey("id") && addressData.get("id") != null) {
                Long id = Long.parseLong(addressData.get("id").toString());
                Optional<UserAddress> existing = userAddressRepo.findById(id);
                if (existing.isPresent() && existing.get().getUserEmail().equals(userEmail)) {
                    address = existing.get();
                } else {
                    address = new UserAddress();
                }
            } else {
                address = new UserAddress();
            }

            // Update fields
            address.setUserEmail(userEmail);
            if (addressData.containsKey("label")) address.setLabel((String) addressData.get("label"));
            if (addressData.containsKey("fullAddress")) address.setFullAddress((String) addressData.get("fullAddress"));
            if (addressData.containsKey("addressLine1")) address.setAddressLine1((String) addressData.get("addressLine1"));
            if (addressData.containsKey("addressLine2")) address.setAddressLine2((String) addressData.get("addressLine2"));
            if (addressData.containsKey("city")) address.setCity((String) addressData.get("city"));
            if (addressData.containsKey("pincode")) address.setPincode((String) addressData.get("pincode"));
            if (addressData.containsKey("state")) address.setState((String) addressData.get("state"));
            if (addressData.containsKey("country")) address.setCountry((String) addressData.get("country"));
            if (addressData.containsKey("latitude")) {
                Object lat = addressData.get("latitude");
                if (lat != null) {
                    address.setLatitude(lat instanceof Double ? (Double) lat : Double.parseDouble(lat.toString()));
                }
            }
            if (addressData.containsKey("longitude")) {
                Object lng = addressData.get("longitude");
                if (lng != null) {
                    address.setLongitude(lng instanceof Double ? (Double) lng : Double.parseDouble(lng.toString()));
                }
            }
            if (addressData.containsKey("type")) address.setType((String) addressData.get("type"));
            if (addressData.containsKey("isSelected")) {
                Object selected = addressData.get("isSelected");
                address.setIsSelected(selected instanceof Boolean ? (Boolean) selected : Boolean.parseBoolean(selected.toString()));
            }

            // If this address is being selected, unselect all others
            if (address.getIsSelected() != null && address.getIsSelected()) {
                List<UserAddress> allAddresses = userAddressRepo.findByUserEmailOrderByCreatedAtDesc(userEmail);
                for (UserAddress addr : allAddresses) {
                    if (!addr.getId().equals(address.getId())) {
                        addr.setIsSelected(false);
                        userAddressRepo.save(addr);
                    }
                }
            }

            address.setUpdatedAt(LocalDateTime.now());
            UserAddress saved = userAddressRepo.save(address);

            System.out.println("✅ Address saved: ID=" + saved.getId() + ", Email=" + userEmail);
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            System.err.println("❌ Error saving address: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get all addresses for a user
    @GetMapping("/user/{email}")
    public ResponseEntity<List<UserAddress>> getUserAddresses(@PathVariable String email) {
        try {
            List<UserAddress> addresses = userAddressRepo.findByUserEmailOrderByCreatedAtDesc(email);
            return ResponseEntity.ok(addresses);
        } catch (Exception e) {
            System.err.println("❌ Error fetching addresses: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get selected address for a user
    @GetMapping("/user/{email}/selected")
    public ResponseEntity<UserAddress> getSelectedAddress(@PathVariable String email) {
        try {
            Optional<UserAddress> address = userAddressRepo.findByUserEmailAndIsSelected(email, true);
            if (address.isPresent()) {
                return ResponseEntity.ok(address.get());
            } else {
                return ResponseEntity.notFound().build();
            }
        } catch (Exception e) {
            System.err.println("❌ Error fetching selected address: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Delete address
    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteAddress(@PathVariable Long id, @RequestParam String userEmail) {
        try {
            Optional<UserAddress> address = userAddressRepo.findByUserEmailAndId(userEmail, id);
            if (address.isPresent()) {
                userAddressRepo.deleteById(id);
                System.out.println("✅ Address deleted: ID=" + id);
                return ResponseEntity.noContent().build();
            } else {
                return ResponseEntity.notFound().build();
            }
        } catch (Exception e) {
            System.err.println("❌ Error deleting address: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Set address as selected
    @PutMapping("/{id}/select")
    public ResponseEntity<UserAddress> selectAddress(@PathVariable Long id, @RequestParam String userEmail) {
        try {
            Optional<UserAddress> addressOpt = userAddressRepo.findByUserEmailAndId(userEmail, id);
            if (!addressOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }

            // Unselect all addresses for this user
            List<UserAddress> allAddresses = userAddressRepo.findByUserEmailOrderByCreatedAtDesc(userEmail);
            for (UserAddress addr : allAddresses) {
                addr.setIsSelected(false);
                userAddressRepo.save(addr);
            }

            // Select the chosen address
            UserAddress address = addressOpt.get();
            address.setIsSelected(true);
            address.setUpdatedAt(LocalDateTime.now());
            UserAddress saved = userAddressRepo.save(address);

            System.out.println("✅ Address selected: ID=" + id);
            return ResponseEntity.ok(saved);
        } catch (Exception e) {
            System.err.println("❌ Error selecting address: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}

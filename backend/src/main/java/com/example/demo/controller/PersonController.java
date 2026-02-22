package com.example.demo.controller;

import com.example.demo.model.Person;
import com.example.demo.model.UserAddress;
import com.example.demo.model.UserHelpMessage;
import com.example.demo.model.UserSupportPhotoPermission;
import com.example.demo.repository.PersonRepo;
import com.example.demo.repository.UserAddressRepo;
import com.example.demo.repository.UserHelpMessageRepo;
import com.example.demo.repository.UserSupportPhotoPermissionRepo;
import com.example.demo.service.SupportTypingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/person")
@CrossOrigin(origins = "*")
public class PersonController {

    @Autowired
    private PersonRepo personRepo;

    @Autowired
    private UserAddressRepo userAddressRepo;

    @Autowired
    private UserHelpMessageRepo userHelpMessageRepo;

    @Autowired
    private UserSupportPhotoPermissionRepo photoPermissionRepo;

    @Autowired
    private SupportTypingService supportTypingService;

    @PostMapping
    public Person createPerson(@RequestBody Person person) {
        System.out.println("📥 Received Person data: " + person);
        System.out.println("📥 Name: " + person.getName());
        System.out.println("📥 Email: " + person.getEmail());
        System.out.println("📥 Phone: " + person.getPhone());
        System.out.println("📥 Address: " + person.getAddress());
        System.out.println("📥 Charger Type: " + person.getChargerType());
        System.out.println("📥 Rate: " + person.getRate());
        System.out.println("📥 Available Hours: " + person.getAvailableHours());
        System.out.println("📥 DOB: " + person.getDateOfBirth());
        System.out.println("📥 Gender: " + person.getGender());
        
        try {
            // If email is provided, check if person already exists and update instead of creating new
            if (person.getEmail() != null && !person.getEmail().isEmpty()) {
                Optional<Person> existingPerson = personRepo.findByEmail(person.getEmail());
                if (existingPerson.isPresent()) {
                    // Update existing person
                    Person existing = existingPerson.get();
                    existing.setEmail(person.getEmail()); // Ensure email is set
                    if (person.getName() != null && !person.getName().isEmpty()) {
                        existing.setName(person.getName());
                    }
                    if (person.getPhone() != null && !person.getPhone().isEmpty()) {
                        existing.setPhone(person.getPhone());
                    }
                    // Always update dateOfBirth and gender (handle null and empty strings)
                    String dob = (person.getDateOfBirth() != null && !person.getDateOfBirth().isEmpty()) 
                        ? person.getDateOfBirth() : null;
                    String gender = (person.getGender() != null && !person.getGender().isEmpty()) 
                        ? person.getGender() : null;
                    existing.setDateOfBirth(dob);
                    existing.setGender(gender);
                    if (person.getProfilePhotoUrl() != null) existing.setProfilePhotoUrl(person.getProfilePhotoUrl());
                    System.out.println("   Setting DOB: " + dob);
                    System.out.println("   Setting Gender: " + gender);
                    
                    if (person.getAddress() != null) existing.setAddress(person.getAddress());
                    if (person.getChargerType() != null) existing.setChargerType(person.getChargerType());
                    if (person.getRate() != null) existing.setRate(person.getRate());
                    if (person.getAvailableHours() != null) existing.setAvailableHours(person.getAvailableHours());
                    
                    Person saved = personRepo.save(existing);
                    System.out.println("✅ Updated existing person with email: " + saved.getEmail() + ", ID: " + saved.getId());
                    System.out.println("   Saved email in DB: " + saved.getEmail());
                    System.out.println("   Saved DOB in DB: " + saved.getDateOfBirth());
                    System.out.println("   Saved Gender in DB: " + saved.getGender());
                    return saved;
                }
            }
            
            // Create new person - ensure dateOfBirth and gender are properly set
            // Handle empty strings as null
            if (person.getDateOfBirth() != null && person.getDateOfBirth().isEmpty()) {
                person.setDateOfBirth(null);
            }
            if (person.getGender() != null && person.getGender().isEmpty()) {
                person.setGender(null);
            }
            
            Person savedPerson = personRepo.save(person);
            System.out.println("✅ Person saved successfully with ID: " + savedPerson.getId());
            System.out.println("   Saved email in DB: " + savedPerson.getEmail());
            System.out.println("   Saved DOB in DB: " + savedPerson.getDateOfBirth());
            System.out.println("   Saved Gender in DB: " + savedPerson.getGender());
            return savedPerson;
        } catch (Exception e) {
            System.err.println("❌ Error saving person: " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
    }

    @GetMapping
    public List<Person> getAllPersons() {
        System.out.println("📤 GET request received - fetching all persons");
        try {
            List<Person> persons = personRepo.findAll();
            System.out.println("📤 Found " + persons.size() + " persons in database");
            for (Person person : persons) {
                System.out.println("📤 Person: ID=" + person.getId() + ", Name=" + person.getName());
            }
            return persons;
        } catch (Exception e) {
            System.err.println("❌ Error fetching persons: " + e.getMessage());
            e.printStackTrace();
            throw e;
        }
    }

    @GetMapping("/{id}")
    public Person getPersonById(@PathVariable Long id) {
        return personRepo.findById(id).orElse(null);
    }

    @PutMapping("/{id}")
    public Person updatePerson(@PathVariable Long id, @RequestBody Person person) {
        person.setId(id);
        return personRepo.save(person);
    }

    @DeleteMapping("/{id}")
    public void deletePerson(@PathVariable Long id) {
        personRepo.deleteById(id);
    }

    // Save or update user address (same as POST /api/user-addresses) so save works when UserAddressController not deployed
    @PostMapping("/addresses")
    public ResponseEntity<UserAddress> saveAddress(@RequestBody Map<String, Object> addressData) {
        try {
            String userEmail = (String) addressData.get("userEmail");
            if (userEmail == null || userEmail.isEmpty()) {
                return ResponseEntity.badRequest().build();
            }
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
            if (address.getIsSelected() != null && address.getIsSelected()) {
                List<UserAddress> allAddresses = userAddressRepo.findByUserEmailOrderByCreatedAtDesc(userEmail);
                for (UserAddress addr : allAddresses) {
                    if (address.getId() == null || !addr.getId().equals(address.getId())) {
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

    // Set address as selected (same as PUT /api/user-addresses/{id}/select)
    @PutMapping("/addresses/{id}/select")
    public ResponseEntity<UserAddress> selectAddress(@PathVariable Long id, @RequestParam String userEmail) {
        try {
            Optional<UserAddress> addressOpt = userAddressRepo.findByUserEmailAndId(userEmail, id);
            if (addressOpt.isEmpty()) {
                return ResponseEntity.notFound().build();
            }
            List<UserAddress> allAddresses = userAddressRepo.findByUserEmailOrderByCreatedAtDesc(userEmail);
            for (UserAddress addr : allAddresses) {
                addr.setIsSelected(false);
                userAddressRepo.save(addr);
            }
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

    // Delete address (same as DELETE /api/user-addresses/{id})
    @DeleteMapping("/addresses/{id}")
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

    // Get user's saved addresses (for location selection) - same as /api/user-addresses/user/{email}
    @GetMapping("/email/{email}/addresses")
    public ResponseEntity<List<UserAddress>> getUserAddressesByEmail(@PathVariable String email) {
        try {
            List<UserAddress> addresses = userAddressRepo.findByUserEmailOrderByCreatedAtDesc(email != null ? email.trim() : "");
            return ResponseEntity.ok(addresses);
        } catch (Exception e) {
            System.err.println("❌ Error fetching addresses: " + e.getMessage());
            return ResponseEntity.status(500).build();
        }
    }

    // Get user profile by email
    @GetMapping("/email/{email}")
    public ResponseEntity<Person> getPersonByEmail(@PathVariable String email) {
        System.out.println("🔍 GET request for email: " + email);
        
        // Try to find by exact email match
        Optional<Person> person = personRepo.findByEmail(email);
        
        if (person.isPresent()) {
            Person found = person.get();
            System.out.println("✅ Found user: ID=" + found.getId() + ", Name=" + found.getName());
            System.out.println("   Email in DB: " + found.getEmail());
            System.out.println("   DOB: " + found.getDateOfBirth());
            System.out.println("   Gender: " + found.getGender());
            return ResponseEntity.ok(found);
        } else {
            // Debug: List all persons to see what emails exist
            System.out.println("⚠️ User not found with email: " + email);
            System.out.println("🔍 Debug: Checking all persons in database...");
            List<Person> allPersons = personRepo.findAll();
            System.out.println("   Total persons in DB: " + allPersons.size());
            for (Person p : allPersons) {
                System.out.println("   Person ID=" + p.getId() + ", Email=" + p.getEmail() + ", Name=" + p.getName());
            }
            return ResponseEntity.status(404).body(null);
        }
    }

    // Create or update user profile by email
    @PostMapping("/profile")
    public Person saveOrUpdateProfile(@RequestBody Person person) {
        System.out.println("💾 POST /profile request received");
        System.out.println("   Email: " + person.getEmail());
        System.out.println("   Name: " + person.getName());
        System.out.println("   Phone: " + person.getPhone());
        System.out.println("   DOB: " + person.getDateOfBirth());
        System.out.println("   Gender: " + person.getGender());
        
        if (person.getEmail() == null || person.getEmail().isEmpty()) {
            throw new RuntimeException("Email is required");
        }
        
        // Check if user exists by email
        Optional<Person> existingPerson = personRepo.findByEmail(person.getEmail());
        
        if (existingPerson.isPresent()) {
            // Update existing user
            Person existing = existingPerson.get();
            if (person.getName() != null) existing.setName(person.getName());
            if (person.getPhone() != null) existing.setPhone(person.getPhone());
            // Handle empty strings for dateOfBirth and gender
            String dob = (person.getDateOfBirth() != null && !person.getDateOfBirth().isEmpty()) 
                ? person.getDateOfBirth() : null;
            String gender = (person.getGender() != null && !person.getGender().isEmpty()) 
                ? person.getGender() : null;
            existing.setDateOfBirth(dob);
            existing.setGender(gender);
            if (person.getProfilePhotoUrl() != null) existing.setProfilePhotoUrl(person.getProfilePhotoUrl());
            System.out.println("   Setting DOB: " + dob);
            System.out.println("   Setting Gender: " + gender);
            
            Person saved = personRepo.save(existing);
            System.out.println("✅ Updated existing user profile: ID=" + saved.getId());
            System.out.println("   Saved DOB: " + saved.getDateOfBirth());
            System.out.println("   Saved Gender: " + saved.getGender());
            return saved;
        } else {
            // Create new user profile - handle empty strings
            if (person.getDateOfBirth() != null && person.getDateOfBirth().isEmpty()) {
                person.setDateOfBirth(null);
            }
            if (person.getGender() != null && person.getGender().isEmpty()) {
                person.setGender(null);
            }
            
            Person saved = personRepo.save(person);
            System.out.println("✅ Created new user profile: ID=" + saved.getId());
            System.out.println("   Saved DOB: " + saved.getDateOfBirth());
            System.out.println("   Saved Gender: " + saved.getGender());
            return saved;
        }
    }

    // Update user profile by email (only updates non-null fields)
    @PutMapping("/profile/{email}")
    public Person updateProfileByEmail(@PathVariable String email, @RequestBody Person person) {
        Person existing = personRepo.findByEmail(email)
            .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        
        if (person.getName() != null) existing.setName(person.getName());
        if (person.getPhone() != null) existing.setPhone(person.getPhone());
        if (person.getDateOfBirth() != null) existing.setDateOfBirth(person.getDateOfBirth());
        if (person.getGender() != null) existing.setGender(person.getGender());
        if (person.getProfilePhotoUrl() != null) existing.setProfilePhotoUrl(person.getProfilePhotoUrl());
        
        return personRepo.save(existing);
    }

    // Activity ping - updates lastActiveAt; optional sessionMinutes to add to total usage
    @PostMapping("/activity")
    public ResponseEntity<Void> recordActivity(@RequestBody Map<String, Object> body) {
        try {
            String email = (String) body.get("email");
            if (email == null || email.isEmpty()) return ResponseEntity.badRequest().build();
            
            Optional<Person> opt = personRepo.findByEmail(email);
            if (opt.isPresent()) {
                Person p = opt.get();
                p.setLastActiveAt(java.time.LocalDateTime.now());
                Object sm = body.get("sessionMinutes");
                if (sm != null) {
                    long mins = sm instanceof Number ? ((Number) sm).longValue() : Long.parseLong(sm.toString());
                    p.setTotalUsageMinutes((p.getTotalUsageMinutes() != null ? p.getTotalUsageMinutes() : 0L) + mins);
                }
                personRepo.save(p);
            }
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.status(500).build();
        }
    }

    // ---------- Customer / User Support (in-app chat with admin) ----------
    @PostMapping("/support")
    public ResponseEntity<UserHelpMessage> sendSupportMessage(@RequestBody Map<String, Object> body) {
        String email = body != null && body.get("email") != null ? body.get("email").toString().trim() : null;
        String message = body != null && body.get("message") != null ? body.get("message").toString().trim() : null;
        String imageUrl = body != null && body.get("imageUrl") != null ? body.get("imageUrl").toString().trim() : null;
        String messageType = body != null && body.get("messageType") != null ? body.get("messageType").toString().trim().toUpperCase() : "TEXT";
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        if ("IMAGE".equals(messageType)) {
            if (imageUrl == null || imageUrl.isBlank()) return ResponseEntity.badRequest().build();
            Optional<UserSupportPhotoPermission> perm = photoPermissionRepo.findByUserEmailIgnoreCase(email);
            if (perm.isEmpty() || !perm.get().isAllowed())
                return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        if (!"IMAGE".equals(messageType) && (message == null || message.isBlank()) && (imageUrl == null || imageUrl.isBlank()))
            return ResponseEntity.badRequest().build();
        UserHelpMessage msg = new UserHelpMessage();
        msg.setUserEmail(email);
        msg.setMessage(message != null ? message : (imageUrl != null ? "[Photo]" : ""));
        msg.setImageUrl("IMAGE".equals(messageType) ? imageUrl : null);
        msg.setMessageType(messageType != null && !messageType.isEmpty() ? messageType : "TEXT");
        msg.setSender("USER");
        msg.setCreatedAt(LocalDateTime.now());
        UserHelpMessage saved = userHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    @GetMapping("/support")
    public ResponseEntity<List<UserHelpMessage>> getSupportMessages(@RequestParam String email) {
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        List<UserHelpMessage> messages = userHelpMessageRepo.findByUserEmailIgnoreCaseOrderByCreatedAtAsc(email.trim());
        return ResponseEntity.ok(messages);
    }

    @GetMapping("/support/photo-permission")
    public ResponseEntity<Map<String, Object>> getPhotoPermission(@RequestParam String email) {
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        Optional<UserSupportPhotoPermission> p = photoPermissionRepo.findByUserEmailIgnoreCase(email.trim());
        boolean allowed = p.isPresent() && p.get().isAllowed();
        return ResponseEntity.ok(Map.of("allowed", allowed));
    }

    @PostMapping("/support/request-photo-permission")
    public ResponseEntity<UserHelpMessage> requestPhotoPermission(@RequestBody Map<String, String> body) {
        String email = body != null ? body.get("email") : null;
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        UserHelpMessage msg = new UserHelpMessage();
        msg.setUserEmail(email.trim());
        msg.setMessage("User requested permission to send photos.");
        msg.setMessageType("PHOTO_PERMISSION_REQUEST");
        msg.setSender("USER");
        msg.setCreatedAt(LocalDateTime.now());
        UserHelpMessage saved = userHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    /** User requested help; notification goes to dashboard. Message: agent will join within 1 minute. */
    @PostMapping("/support/request-help")
    public ResponseEntity<UserHelpMessage> requestHelp(@RequestBody Map<String, String> body) {
        String email = body != null ? body.get("email") : null;
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        UserHelpMessage msg = new UserHelpMessage();
        msg.setUserEmail(email.trim());
        msg.setMessage("Customer wants help. An agent will join within 1 minute.");
        msg.setMessageType("HELP_REQUESTED");
        msg.setSender("USER");
        msg.setCreatedAt(LocalDateTime.now());
        UserHelpMessage saved = userHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    /** Returns whether the user is still waiting for an admin to join (after requesting help). */
    @GetMapping("/support/help-status")
    public ResponseEntity<Map<String, Boolean>> getHelpStatus(@RequestParam String email) {
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        List<UserHelpMessage> messages = userHelpMessageRepo.findByUserEmailIgnoreCaseOrderByCreatedAtAsc(email.trim());
        LocalDateTime lastHelpRequest = null;
        LocalDateTime lastAdminJoined = null;
        for (UserHelpMessage m : messages) {
            String type = m.getMessageType() != null ? m.getMessageType() : "";
            LocalDateTime at = m.getCreatedAt();
            if ("HELP_REQUESTED".equals(type)) lastHelpRequest = at;
            if ("ADMIN_JOINED".equals(type)) lastAdminJoined = at;
        }
        boolean waitingForAdmin = lastHelpRequest != null && (lastAdminJoined == null || lastAdminJoined.isBefore(lastHelpRequest));
        return ResponseEntity.ok(Map.of("waitingForAdmin", waitingForAdmin));
    }

    @PostMapping("/support/typing")
    public ResponseEntity<Void> setUserTyping(@RequestBody Map<String, Object> body) {
        String email = body != null && body.get("email") != null ? body.get("email").toString().trim() : null;
        Boolean typing = body != null && body.get("isTyping") != null ? Boolean.TRUE.equals(body.get("isTyping")) : false;
        if (email != null && !email.isBlank()) supportTypingService.setUserTyping(email, typing);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/support/typing")
    public ResponseEntity<Map<String, Boolean>> getAdminTyping(@RequestParam String email) {
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        boolean adminTyping = supportTypingService.isAdminTyping(email.trim());
        return ResponseEntity.ok(Map.of("adminTyping", adminTyping));
    }
}

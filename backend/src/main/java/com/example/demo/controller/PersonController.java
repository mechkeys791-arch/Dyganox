package com.example.demo.controller;

import com.example.demo.model.Person;
import com.example.demo.repository.PersonRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@CrossOrigin(origins = "*") // allow Flutter requests
@RestController
@RequestMapping("/api/person")
public class PersonController {

    @Autowired
    private PersonRepo personRepo;

    @PostMapping
    public Person createPerson(@RequestBody Person person) {
        System.out.println("📥 Received Person data: " + person);
        System.out.println("📥 Name: " + person.getName());
        System.out.println("📥 Phone: " + person.getPhone());
        System.out.println("📥 Address: " + person.getAddress());
        System.out.println("📥 Charger Type: " + person.getChargerType());
        System.out.println("📥 Rate: " + person.getRate());
        System.out.println("📥 Available Hours: " + person.getAvailableHours());
        
        try {
            Person savedPerson = personRepo.save(person);
            System.out.println("✅ Person saved successfully with ID: " + savedPerson.getId());
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

    // Get user profile by email
    @GetMapping("/email/{email}")
    public ResponseEntity<Person> getPersonByEmail(@PathVariable String email) {
        System.out.println("🔍 GET request for email: " + email);
        Optional<Person> person = personRepo.findByEmail(email);
        
        if (person.isPresent()) {
            Person found = person.get();
            System.out.println("✅ Found user: ID=" + found.getId() + ", Name=" + found.getName());
            System.out.println("   DOB: " + found.getDateOfBirth());
            System.out.println("   Gender: " + found.getGender());
            return ResponseEntity.ok(found);
        } else {
            System.out.println("⚠️ User not found with email: " + email);
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
            existing.setName(person.getName());
            existing.setPhone(person.getPhone());
            existing.setDateOfBirth(person.getDateOfBirth());
            existing.setGender(person.getGender());
            Person saved = personRepo.save(existing);
            System.out.println("✅ Updated existing user profile: ID=" + saved.getId());
            return saved;
        } else {
            // Create new user profile
            Person saved = personRepo.save(person);
            System.out.println("✅ Created new user profile: ID=" + saved.getId());
            return saved;
        }
    }

    // Update user profile by email
    @PutMapping("/profile/{email}")
    public Person updateProfileByEmail(@PathVariable String email, @RequestBody Person person) {
        Person existing = personRepo.findByEmail(email)
            .orElseThrow(() -> new RuntimeException("User not found with email: " + email));
        
        existing.setName(person.getName());
        existing.setPhone(person.getPhone());
        existing.setDateOfBirth(person.getDateOfBirth());
        existing.setGender(person.getGender());
        
        return personRepo.save(existing);
    }
}

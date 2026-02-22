package com.example.demo.controller;

import com.example.demo.model.Person;
import com.example.demo.repository.PersonRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.Map;
import java.util.Optional;

/**
 * App user auth: Google Sign-In. Verifies Google id_token and finds/creates Person by email.
 */
@RestController
@RequestMapping("/api/auth")
@CrossOrigin(origins = "*")
public class AuthController {

    private static final String GOOGLE_TOKENINFO = "https://oauth2.googleapis.com/tokeninfo?id_token=";

    private final PersonRepo personRepo;
    private final RestTemplate restTemplate = new RestTemplate();

    public AuthController(PersonRepo personRepo) {
        this.personRepo = personRepo;
    }

    /**
     * POST /api/auth/google
     * Body: { "idToken": "..." } (Google Sign-In id_token from the app).
     * Verifies token with Google, extracts email/name; finds or creates Person by email.
     * Returns { "success": true, "email": "...", "name": "..." } so the app can store session.
     */
    @PostMapping("/google")
    public ResponseEntity<Map<String, Object>> googleSignIn(@RequestBody Map<String, Object> body) {
        String idToken = body != null ? (String) body.get("idToken") : null;
        if (idToken == null || idToken.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "message", "idToken required"));
        }
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> payload = restTemplate.getForObject(GOOGLE_TOKENINFO + idToken, Map.class);
            if (payload == null || payload.containsKey("error")) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Invalid or expired Google token"));
            }
            String email = (String) payload.get("email");
            if (email == null || email.isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("success", false, "message", "Google account email not found"));
            }
            String name = (String) payload.get("name");
            if (name == null) name = (String) payload.get("given_name");
            if (name == null) name = email;

            Optional<Person> existing = personRepo.findByEmail(email.trim());
            if (existing.isPresent()) {
                Person p = existing.get();
                if (name != null && !name.equals(p.getName())) {
                    p.setName(name);
                    personRepo.save(p);
                }
                return ResponseEntity.ok(Map.of(
                    "success", true,
                    "email", p.getEmail(),
                    "name", p.getName() != null ? p.getName() : name
                ));
            }
            Person newPerson = new Person();
            newPerson.setEmail(email.trim());
            newPerson.setName(name);
            newPerson.setPhone("");
            personRepo.save(newPerson);
            return ResponseEntity.ok(Map.of(
                "success", true,
                "email", newPerson.getEmail(),
                "name", newPerson.getName() != null ? newPerson.getName() : name
            ));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "success", false,
                "message", e.getMessage() != null ? e.getMessage() : "Google sign-in failed"
            ));
        }
    }
}

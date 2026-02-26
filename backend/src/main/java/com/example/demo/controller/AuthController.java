package com.example.demo.controller;

import com.example.demo.model.Person;
import com.example.demo.repository.PersonRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestTemplate;

import java.util.HashMap;
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
            String picture = payload.get("picture") != null ? (String) payload.get("picture") : null;

            Optional<Person> existing = personRepo.findByEmail(email.trim());
            if (existing.isPresent()) {
                Person p = existing.get();
                if (name != null && !name.equals(p.getName())) {
                    p.setName(name);
                }
                if (picture != null && !picture.isBlank()) {
                    p.setProfilePhotoUrl(picture);
                }
                personRepo.save(p);
                return ResponseEntity.ok(buildAuthResponse(p.getEmail(), p.getName() != null ? p.getName() : name, p.getProfilePhotoUrl()));
            }
            Person newPerson = new Person();
            newPerson.setEmail(email.trim());
            newPerson.setName(name);
            newPerson.setPhone("");
            if (picture != null && !picture.isBlank()) {
                newPerson.setProfilePhotoUrl(picture);
            }
            personRepo.save(newPerson);
            return ResponseEntity.ok(buildAuthResponse(newPerson.getEmail(), newPerson.getName() != null ? newPerson.getName() : name, newPerson.getProfilePhotoUrl()));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of(
                "success", false,
                "message", e.getMessage() != null ? e.getMessage() : "Google sign-in failed"
            ));
        }
    }

    private Map<String, Object> buildAuthResponse(String email, String name, String profilePhotoUrl) {
        Map<String, Object> map = new HashMap<>();
        map.put("success", true);
        map.put("email", email);
        map.put("name", name);
        if (profilePhotoUrl != null && !profilePhotoUrl.isBlank()) {
            map.put("profilePhotoUrl", profilePhotoUrl);
        }
        return map;
    }
}

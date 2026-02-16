package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.model.Person;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.PersonRepo;
import com.example.demo.service.S3Service;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.*;

@RestController
@RequestMapping("/api/upload")
public class UploadController {

    private final S3Service s3Service;
    private final MechanicRepo mechanicRepo;
    private final PersonRepo personRepo;

    public UploadController(S3Service s3Service, MechanicRepo mechanicRepo, PersonRepo personRepo) {
        this.s3Service = s3Service;
        this.mechanicRepo = mechanicRepo;
        this.personRepo = personRepo;
    }

    /**
     * Upload user profile photo. Call with multipart/form-data: "file", "email"
     * Response: { "url": "https://bucket.s3.amazonaws.com/..." }
     */
    @PostMapping("/profile/user")
    public ResponseEntity<Map<String, String>> uploadUserProfilePhoto(
            @RequestParam("file") MultipartFile file,
            @RequestParam("email") String email) {
        try {
            String url = s3Service.uploadProfilePhoto("user", email, file);
            var opt = personRepo.findByEmail(email);
            if (opt.isPresent()) {
                var p = opt.get();
                p.setProfilePhotoUrl(url);
                personRepo.save(p);
            }
            // If Person doesn't exist yet, URL is still returned; app saves locally
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ User profile photo upload failed: " + e.getMessage());
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Upload mechanic profile photo (used during registration or profile edit).
     * Call with multipart/form-data, field name: "file"
     * Response: { "url": "https://bucket.s3.amazonaws.com/..." }
     */
    @PostMapping("/profile/mechanic")
    public ResponseEntity<Map<String, String>> uploadMechanicProfilePhoto(
            @RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadProfilePhoto("mechanic", String.valueOf(System.currentTimeMillis()), file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ Profile photo upload failed: " + e.getMessage());
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Upload banner/carousel image for homepage.
     * Response: { "url": "https://bucket.s3.amazonaws.com/banners/..." }
     */
    @PostMapping("/banner")
    public ResponseEntity<Map<String, String>> uploadBanner(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadBanner(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ Banner upload failed: " + e.getMessage());
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Upload mechanic document (Aadhar, license, etc.) and append to mechanic's documentUrls.
     * Requires mechanic ID in path.
     */
    @PostMapping("/mechanic/{id}/document")
    public ResponseEntity<Map<String, Object>> uploadMechanicDocument(
            @PathVariable Long id,
            @RequestParam("file") MultipartFile file) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (mechanicOpt.isEmpty()) {
                return ResponseEntity.notFound().build();
            }
            Mechanic mechanic = mechanicOpt.get();
            String url = s3Service.uploadMechanicDocument(id, file);
            List<String> urls = parseDocumentUrls(mechanic.getDocumentUrls());
            urls.add(url);
            mechanic.setDocumentUrls(new ObjectMapper().writeValueAsString(urls));
            mechanicRepo.save(mechanic);
            Map<String, Object> resp = new HashMap<>();
            resp.put("url", url);
            resp.put("documentUrls", mechanic.getDocumentUrls());
            return ResponseEntity.ok(resp);
        } catch (Exception e) {
            System.err.println("❌ Document upload failed: " + e.getMessage());
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    private List<String> parseDocumentUrls(String documentUrls) {
        if (documentUrls == null || documentUrls.isBlank()) return new ArrayList<>();
        try {
            if (documentUrls.trim().startsWith("[")) {
                return new ObjectMapper().readValue(documentUrls, new TypeReference<List<String>>() {});
            }
            return Arrays.asList(documentUrls.split(",\\s*"));
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }
}

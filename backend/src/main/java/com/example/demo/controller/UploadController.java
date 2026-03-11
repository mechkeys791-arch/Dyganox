package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.model.Person;
import com.example.demo.model.VehicleMake;
import com.example.demo.model.VehicleModel;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.PersonRepo;
import com.example.demo.repository.VehicleMakeRepo;
import com.example.demo.repository.VehicleModelRepo;
import com.example.demo.service.S3Service;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.nio.file.Files;
import java.util.*;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/upload")
@CrossOrigin(origins = "*")
public class UploadController {

    private static final Pattern SAFE_SUPPORT_FILENAME = Pattern.compile("^[a-fA-F0-9-]+\\.(jpg|jpeg|png|gif|webp)$");
    private static final String SUPPORT_PHOTOS_DIR = "support-photos";

    private final S3Service s3Service;
    private final MechanicRepo mechanicRepo;
    private final PersonRepo personRepo;
    private final VehicleMakeRepo vehicleMakeRepo;
    private final VehicleModelRepo vehicleModelRepo;

    public UploadController(S3Service s3Service, MechanicRepo mechanicRepo, PersonRepo personRepo,
                            VehicleMakeRepo vehicleMakeRepo, VehicleModelRepo vehicleModelRepo) {
        this.s3Service = s3Service;
        this.mechanicRepo = mechanicRepo;
        this.personRepo = personRepo;
        this.vehicleMakeRepo = vehicleMakeRepo;
        this.vehicleModelRepo = vehicleModelRepo;
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
     * Upload support chat photo. Call with multipart: "file", "email". User must have photo permission (enforced when sending message).
     * Uses S3 when configured; otherwise saves locally and returns path like /api/upload/serve-support-photo/{id}.jpg
     * Response: { "url": "https://..." or "/api/upload/serve-support-photo/..." }
     */
    @PostMapping("/support-photo")
    public ResponseEntity<Map<String, String>> uploadSupportPhoto(
            @RequestParam("file") MultipartFile file,
            @RequestParam("email") String email) {
        try {
            String url = s3Service.uploadSupportPhoto(email != null ? email : "unknown", file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            String fallbackUrl = saveSupportPhotoLocally(file);
            if (fallbackUrl != null) {
                return ResponseEntity.ok(Map.of("url", fallbackUrl));
            }
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage() != null ? e.getMessage() : "Upload failed"));
        }
    }

    /** Save support photo to local dir when S3 is unavailable. Returns path like /api/upload/serve-support-photo/uuid.jpg or null. */
    private String saveSupportPhotoLocally(MultipartFile file) {
        try {
            File dir = new File(SUPPORT_PHOTOS_DIR);
            if (!dir.exists() && !dir.mkdirs()) return null;
            String ext = "jpg";
            String name = file.getOriginalFilename();
            if (name != null && name.contains(".")) ext = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
            if (!Arrays.asList("jpg", "jpeg", "png", "gif", "webp").contains(ext)) ext = "jpg";
            String id = UUID.randomUUID().toString();
            File target = new File(dir, id + "." + ext);
            file.transferTo(target.toPath());
            return "/api/upload/serve-support-photo/" + id + "." + ext;
        } catch (Exception e) {
            return null;
        }
    }

    /** Serve locally stored support photos (fallback when S3 not configured). */
    @GetMapping("/serve-support-photo/{filename}")
    public ResponseEntity<byte[]> serveSupportPhoto(@PathVariable String filename) {
        if (filename == null || !SAFE_SUPPORT_FILENAME.matcher(filename).matches()) {
            return ResponseEntity.badRequest().build();
        }
        try {
            File file = new File(SUPPORT_PHOTOS_DIR, filename);
            if (!file.exists() || !file.isFile()) return ResponseEntity.notFound().build();
            byte[] bytes = Files.readAllBytes(file.toPath());
            String contentType = filename.toLowerCase().endsWith(".png") ? "image/png"
                    : filename.toLowerCase().endsWith(".gif") ? "image/gif"
                    : filename.toLowerCase().endsWith(".webp") ? "image/webp" : "image/jpeg";
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.parseMediaType(contentType));
            headers.setCacheControl("max-age=86400");
            return ResponseEntity.ok().headers(headers).body(bytes);
        } catch (Exception e) {
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Upload banner/carousel image to S3. Returns public S3 URL for use in app.
     * Requires AWS S3 configured (bucket, access-key-id, secret-access-key in application.properties or application-ec2.properties).
     */
    @PostMapping("/banner")
    public ResponseEntity<Map<String, String>> uploadBanner(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadBanner(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ Banner upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured. Set aws.s3.bucket, aws.access-key-id, aws.secret-access-key (e.g. in application-ec2.properties on EC2).";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload marketing poster to S3. Returns public S3 URL. Shown in app when admin sets poster active.
     * Requires S3 configured.
     */
    @PostMapping("/poster")
    public ResponseEntity<Map<String, String>> uploadPoster(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadPoster(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ Poster upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured. Set aws.s3.bucket, aws.access-key-id, aws.secret-access-key (e.g. in application-ec2.properties on EC2).";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload section poster image (e.g. below-services). Returns S3 URL.
     * Call with multipart: "file", optional "section" (default BELOW_SERVICES).
     */
    @PostMapping("/section-poster")
    public ResponseEntity<Map<String, String>> uploadSectionPoster(
            @RequestParam("file") MultipartFile file,
            @RequestParam(value = "section", required = false, defaultValue = "BELOW_SERVICES") String section) {
        try {
            String url = s3Service.uploadSectionPoster(section, file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured. Set aws.s3.bucket, aws.access-key-id, aws.secret-access-key.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload user vehicle photo. Call with multipart: "file", "email".
     * Response: { "url": "https://..." }. App can then PATCH/PUT user vehicle with this url.
     */
    @PostMapping("/vehicle-photo")
    public ResponseEntity<Map<String, String>> uploadVehiclePhoto(
            @RequestParam("file") MultipartFile file,
            @RequestParam("email") String email) {
        try {
            String url = s3Service.uploadVehiclePhoto(email != null ? email : "unknown", file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ Vehicle photo upload failed: " + e.getMessage());
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Upload vehicle catalog image (make or model) to S3. Updates make/model imageUrl with S3 URL for app.
     * Call with multipart: "file", "type" (make|model), "id" (makeId or modelId).
     * Requires S3 configured.
     */
    @PostMapping("/vehicle-catalog-photo")
    public ResponseEntity<Map<String, String>> uploadVehicleCatalogPhoto(
            @RequestParam("file") MultipartFile file,
            @RequestParam("type") String type,
            @RequestParam("id") Long id) {
        String typeNorm = type != null ? type.toLowerCase() : "";
        if (!"make".equals(typeNorm) && !"model".equals(typeNorm)) {
            return ResponseEntity.badRequest().body(Map.of("error", "type must be 'make' or 'model'"));
        }
        try {
            String url = s3Service.uploadVehicleCatalogPhoto(typeNorm, String.valueOf(id), file);
            if ("make".equals(typeNorm)) {
                vehicleMakeRepo.findById(id).ifPresent(m -> { m.setImageUrl(url); vehicleMakeRepo.save(m); });
            } else {
                vehicleModelRepo.findById(id).ifPresent(m -> { m.setImageUrl(url); vehicleModelRepo.save(m); });
            }
            return ResponseEntity.ok(Map.of("url", url));
        } catch (Exception e) {
            System.err.println("❌ Vehicle catalog photo upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured. Set aws.s3.bucket, aws.access-key-id, aws.secret-access-key (e.g. in application-ec2.properties on EC2).";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload home hero graphic (Lottie .json or GIF). Transparent overlay on homepage red header. Returns S3 URL.
     */
    @PostMapping("/home-hero-media")
    public ResponseEntity<Map<String, String>> uploadHomeHeroMedia(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadHomeHeroMedia(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ Home hero media upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured. Set aws.s3.bucket, aws.access-key-id, aws.secret-access-key.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload auth background video (login/signup). MP4 only. Returns S3 URL. Admin dashboard uses this, then saves URL via PUT /api/admin/auth-video.
     */
    @PostMapping("/auth-video")
    public ResponseEntity<Map<String, String>> uploadAuthVideo(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadAuthVideo(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ Auth video upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured. Set aws.s3.bucket, aws.access-key-id, aws.secret-access-key (e.g. in application-ec2.properties on EC2).";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload app logo (PNG/JPG/WebP, transparent recommended). Returns S3 URL. Admin then saves via PUT /api/admin/app-branding.
     */
    @PostMapping("/app-logo")
    public ResponseEntity<Map<String, String>> uploadAppLogo(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadAppLogo(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ App logo upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload splash animation (Lottie .json, GIF, or MP4). Returns S3 URL. Admin then saves via PUT /api/admin/app-branding.
     */
    @PostMapping("/splash-media")
    public ResponseEntity<Map<String, String>> uploadSplashMedia(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadSplashMedia(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ Splash media upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload custom loading animation (Lottie or GIF, e.g. car going). Returns S3 URL.
     */
    @PostMapping("/loading-media")
    public ResponseEntity<Map<String, String>> uploadLoadingMedia(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadLoadingMedia(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ Loading media upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    /**
     * Upload custom marker icon for "See nearest mechanic" map. PNG/JPG/WebP. Returns S3 URL. Admin saves via PUT app-branding (nearestMechanicMarkerIconUrl).
     */
    @PostMapping("/nearest-mechanic-marker-icon")
    public ResponseEntity<Map<String, String>> uploadNearestMechanicMarkerIcon(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadNearestMechanicMarkerIcon(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ Nearest mechanic marker icon upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) msg = "S3 is not configured.";
            if (msg.contains("Not Found") || msg.contains("NoSuchBucket") || msg.contains("404")) {
                msg = "S3 bucket not found. Check aws.s3.bucket and aws.s3.region in application-ec2.properties (or application.properties). Use region in URL for non–us-east-1 buckets.";
            }
            if (msg.contains("Access Denied") || msg.contains("403")) {
                msg = "S3 access denied. Check IAM has s3:PutObject on the bucket and bucket policy allows public GetObject if you need the image to load from the app.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    @PostMapping("/user-location-marker-icon")
    public ResponseEntity<Map<String, String>> uploadUserLocationMarkerIcon(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadUserLocationMarkerIcon(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ User location marker icon upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) msg = "S3 is not configured.";
            return ResponseEntity.status(500).body(Map.of("error", msg));
        }
    }

    @PostMapping("/car-service-image")
    public ResponseEntity<Map<String, String>> uploadCarServiceImage(@RequestParam("file") MultipartFile file) {
        try {
            return ResponseEntity.ok(Map.of("url", s3Service.uploadCarServiceImage(file)));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage() != null ? e.getMessage() : "Upload failed"));
        }
    }

    @PostMapping("/bike-service-image")
    public ResponseEntity<Map<String, String>> uploadBikeServiceImage(@RequestParam("file") MultipartFile file) {
        try {
            return ResponseEntity.ok(Map.of("url", s3Service.uploadBikeServiceImage(file)));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage() != null ? e.getMessage() : "Upload failed"));
        }
    }

    @PostMapping("/quick-service-icon")
    public ResponseEntity<Map<String, String>> uploadQuickServiceIcon(
            @RequestParam("file") MultipartFile file,
            @RequestParam("name") String name) {
        try {
            return ResponseEntity.ok(Map.of("url", s3Service.uploadQuickServiceIcon(name, file)));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            return ResponseEntity.status(500).body(Map.of("error", e.getMessage() != null ? e.getMessage() : "Upload failed"));
        }
    }

    /**
     * Upload welcome page media (GIF or MP4) for the "I'm a User / I'm a Mechanic" screen. Returns S3 URL.
     */
    @PostMapping("/welcome-page-media")
    public ResponseEntity<Map<String, String>> uploadWelcomePageMedia(@RequestParam("file") MultipartFile file) {
        try {
            String url = s3Service.uploadWelcomePageMedia(file);
            return ResponseEntity.ok(Map.of("url", url));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            System.err.println("❌ Welcome page media upload failed: " + e.getMessage());
            String msg = e.getMessage() != null ? e.getMessage() : "Upload failed";
            if (msg.contains("S3") || msg.contains("not configured")) {
                msg = "S3 is not configured.";
            }
            return ResponseEntity.status(500).body(Map.of("error", msg));
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

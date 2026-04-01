package com.example.demo.service;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.util.UUID;

@Service
public class S3Service {

    private final S3Client s3Client;

    @Value("${aws.s3.bucket:promech-profiles-dev}")
    private String bucket;

    @Value("${aws.s3.region:us-east-1}")
    private String region;

    public S3Service(ObjectProvider<S3Client> s3ClientProvider) {
        this.s3Client = s3ClientProvider.getIfAvailable();
    }

    /** Build public URL for the given key. Use region in host for non–us-east-1 to avoid "not found". */
    private String publicUrl(String key) {
        if (region == null || region.isBlank() || "us-east-1".equalsIgnoreCase(region.trim())) {
            return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
        }
        return String.format("https://%s.s3.%s.amazonaws.com/%s", bucket, region.trim(), key);
    }

    public String uploadProfilePhoto(String type, String idOrEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured. Set AWS credentials in application.properties.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("profiles/%s/%s/%s.%s", type, sanitize(idOrEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType(), file.getBytes());
        return publicUrl(key);
    }

    public String uploadMechanicDocument(Long mechanicId, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured. Set AWS credentials in application.properties.");
        }
        String ext = getExtension(file.getOriginalFilename(), "pdf");
        String key = String.format("documents/mechanic/%d/%s.%s", mechanicId, UUID.randomUUID(), ext);
        upload(key, file.getContentType(), file.getBytes());
        return publicUrl(key);
    }

    public String uploadBanner(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured. Set AWS credentials in application.properties.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("banners/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType(), file.getBytes());
        return publicUrl(key);
    }

    public String uploadPoster(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("posters/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload support chat photo (user must have photo permission). Returns public URL. */
    public String uploadSupportPhoto(String userEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("support/%s/%s.%s", sanitize(userEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload user vehicle photo. Returns public URL. */
    public String uploadVehiclePhoto(String userEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("vehicles/%s/%s.%s", sanitize(userEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload mechanic request damage photo (from Book Mechanic flow). Returns public URL. */
    public String uploadRequestDamagePhoto(String userEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("request-damage/%s/%s.%s", sanitize(userEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload section poster image (e.g. below-services banner). Returns public URL. */
    public String uploadSectionPoster(String sectionKey, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("section/%s/%s.%s", sanitize(sectionKey != null ? sectionKey : "BELOW_SERVICES"), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload vehicle catalog image (make or model). Used by admin to add car/bike selection images. */
    public String uploadVehicleCatalogPhoto(String type, String id, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("catalog/%s/%s/%s.%s", type, sanitize(id), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload auth background video (login/signup). MP4 only. Returns public S3 URL. */
    public String uploadAuthVideo(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "mp4");
        if (!"mp4".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Only MP4 format is supported for auth background video.");
        }
        String key = String.format("auth-video/%s.%s", UUID.randomUUID(), ext);
        String contentType = file.getContentType() != null ? file.getContentType() : "video/mp4";
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload home hero graphic: Lottie (.json) or GIF. Transparent overlay on red header. Returns public S3 URL. */
    public String uploadHomeHeroMedia(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "json");
        String contentType;
        if ("json".equalsIgnoreCase(ext)) {
            contentType = "application/json";
        } else if ("gif".equalsIgnoreCase(ext)) {
            contentType = file.getContentType() != null ? file.getContentType() : "image/gif";
        } else {
            throw new IllegalArgumentException("Only Lottie (.json) or GIF (.gif) are supported for home hero graphic.");
        }
        String key = String.format("home-hero/%s.%s", UUID.randomUUID(), ext);
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload app logo (transparent PNG). Used in splash, user type, login, signup, mechanic. */
    public String uploadAppLogo(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("App logo should be PNG, JPG, or WebP (transparent PNG recommended).");
        }
        String key = String.format("app-branding/logo/%s.%s", UUID.randomUUID(), ext);
        String contentType = file.getContentType() != null ? file.getContentType() : "image/png";
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload splash animation: Lottie (.json), GIF, or MP4. */
    public String uploadSplashMedia(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "json");
        String contentType;
        if ("json".equalsIgnoreCase(ext)) {
            contentType = "application/json";
        } else if ("gif".equalsIgnoreCase(ext)) {
            contentType = file.getContentType() != null ? file.getContentType() : "image/gif";
        } else if ("mp4".equalsIgnoreCase(ext)) {
            contentType = "video/mp4";
        } else {
            throw new IllegalArgumentException("Splash media must be Lottie (.json), GIF (.gif), or MP4 (.mp4).");
        }
        String key = String.format("app-branding/splash/%s.%s", UUID.randomUUID(), ext);
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload welcome page media (I'm User / I'm Mechanic screen): GIF or MP4. */
    public String uploadWelcomePageMedia(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "gif");
        String contentType;
        if ("gif".equalsIgnoreCase(ext)) {
            contentType = file.getContentType() != null ? file.getContentType() : "image/gif";
        } else if ("mp4".equalsIgnoreCase(ext)) {
            contentType = "video/mp4";
        } else {
            throw new IllegalArgumentException("Welcome page media must be GIF (.gif) or MP4 (.mp4).");
        }
        String key = String.format("app-branding/welcome/%s.%s", UUID.randomUUID(), ext);
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload custom loading animation (e.g. car going): Lottie (.json) or GIF. */
    public String uploadLoadingMedia(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "json");
        String contentType;
        if ("json".equalsIgnoreCase(ext)) {
            contentType = "application/json";
        } else if ("gif".equalsIgnoreCase(ext)) {
            contentType = file.getContentType() != null ? file.getContentType() : "image/gif";
        } else {
            throw new IllegalArgumentException("Loading media must be Lottie (.json) or GIF (.gif).");
        }
        String key = String.format("app-branding/loading/%s.%s", UUID.randomUUID(), ext);
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload custom marker icon for "See nearest mechanic" map pins. PNG/JPG/WebP. Uses region-aware URL so the link works. */
    public String uploadNearestMechanicMarkerIcon(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Marker icon should be PNG, JPG, or WebP.");
        }
        String key = String.format("app-branding/nearest-mechanic-marker/%s.%s", UUID.randomUUID(), ext);
        String contentType = file.getContentType() != null ? file.getContentType() : "image/png";
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Upload custom marker icon for user's location on "See nearest mechanic" map. PNG/JPG/WebP. */
    public String uploadUserLocationMarkerIcon(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Marker icon should be PNG, JPG, or WebP.");
        }
        String key = String.format("app-branding/user-location-marker/%s.%s", UUID.randomUUID(), ext);
        String contentType = file.getContentType() != null ? file.getContentType() : "image/png";
        upload(key, contentType, file.getBytes());
        return publicUrl(key);
    }

    /** Book mechanic map: mechanic at shop (before live GPS). */
    public String uploadMechanicShopMarkerIcon(MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Marker icon should be PNG, JPG, or WebP.");
        }
        String key = String.format("app-branding/book-mechanic-shop-marker/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/png", file.getBytes());
        return publicUrl(key);
    }

    /** Book mechanic map: mechanic driving (live GPS). */
    public String uploadMechanicDrivingMarkerIcon(MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Marker icon should be PNG, JPG, or WebP.");
        }
        String key = String.format("app-branding/book-mechanic-driving-marker/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/png", file.getBytes());
        return publicUrl(key);
    }

    /** Upload Car Services page header image. */
    public String uploadCarServiceImage(MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("app-branding/car-service/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload Bike Services page header image. */
    public String uploadBikeServiceImage(MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("app-branding/bike-service/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload quick service icon. name: night_service, towing, fuel_refill, ev_charging, tyre_care, minor_repair, battery_jump */
    public String uploadQuickServiceIcon(String name, MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Icon should be PNG, JPG, or WebP.");
        }
        String safe = name != null ? name.replaceAll("[^a-zA-Z0-9_-]", "_") : "icon";
        String key = String.format("app-branding/quick-service/%s/%s.%s", safe, UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/png", file.getBytes());
        return publicUrl(key);
    }

    /** Upload towing vehicle photo (mechanic registration). Returns S3 URL. */
    public String uploadTowingVehiclePhoto(MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Image should be PNG, JPG, or WebP.");
        }
        String key = String.format("towing-vehicle/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return publicUrl(key);
    }

    /** Upload problem category icon for Book Mechanic (e.g. tyre_puncture, battery_jump). vehicleType: car or bike (folder). */
    public String uploadProblemCategoryIcon(String problemId, String vehicleType, MultipartFile file) throws IOException {
        if (s3Client == null) throw new IllegalStateException("S3 is not configured.");
        String ext = getExtension(file.getOriginalFilename(), "png");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext) && !"webp".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Icon should be PNG, JPG, or WebP.");
        }
        String safe = problemId != null ? problemId.replaceAll("[^a-zA-Z0-9_-]", "_") : "problem";
        String vt = vehicleType != null ? vehicleType.trim().toLowerCase() : "car";
        if (!"bike".equals(vt)) vt = "car";
        String key = String.format("app-branding/problem-category/%s/%s/%s.%s", vt, safe, UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/png", file.getBytes());
        return publicUrl(key);
    }

    /** Image or short video for Night Service / service strip ads. */
    public String uploadServiceAdMedia(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        if (!"png".equalsIgnoreCase(ext) && !"jpg".equalsIgnoreCase(ext) && !"jpeg".equalsIgnoreCase(ext)
                && !"webp".equalsIgnoreCase(ext) && !"mp4".equalsIgnoreCase(ext) && !"mov".equalsIgnoreCase(ext)) {
            throw new IllegalArgumentException("Use PNG, JPG, WebP, MP4, or MOV.");
        }
        String key = String.format("service-ads/%s.%s", UUID.randomUUID(), ext);
        String ct = file.getContentType() != null ? file.getContentType() : "application/octet-stream";
        upload(key, ct, file.getBytes());
        return publicUrl(key);
    }

    private void upload(String key, String contentType, byte[] bytes) {
        PutObjectRequest req = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType(contentType != null ? contentType : "application/octet-stream")
                .build();
        s3Client.putObject(req, RequestBody.fromBytes(bytes));
    }

    private String getExtension(String filename, String fallback) {
        if (filename == null || !filename.contains(".")) return fallback;
        return filename.substring(filename.lastIndexOf('.') + 1).toLowerCase();
    }

    private String sanitize(String s) {
        if (s == null) return "unknown";
        return s.replaceAll("[^a-zA-Z0-9._-]", "_");
    }
}

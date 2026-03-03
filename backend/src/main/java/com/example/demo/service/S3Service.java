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

    public S3Service(ObjectProvider<S3Client> s3ClientProvider) {
        this.s3Client = s3ClientProvider.getIfAvailable();
    }

    public String uploadProfilePhoto(String type, String idOrEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured. Set AWS credentials in application.properties.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("profiles/%s/%s/%s.%s", type, sanitize(idOrEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType(), file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    public String uploadMechanicDocument(Long mechanicId, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured. Set AWS credentials in application.properties.");
        }
        String ext = getExtension(file.getOriginalFilename(), "pdf");
        String key = String.format("documents/mechanic/%d/%s.%s", mechanicId, UUID.randomUUID(), ext);
        upload(key, file.getContentType(), file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    public String uploadBanner(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured. Set AWS credentials in application.properties.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("banners/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType(), file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    public String uploadPoster(MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("posters/%s.%s", UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    /** Upload support chat photo (user must have photo permission). Returns public URL. */
    public String uploadSupportPhoto(String userEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("support/%s/%s.%s", sanitize(userEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    /** Upload user vehicle photo. Returns public URL. */
    public String uploadVehiclePhoto(String userEmail, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("vehicles/%s/%s.%s", sanitize(userEmail), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    /** Upload section poster image (e.g. below-services banner). Returns public URL. */
    public String uploadSectionPoster(String sectionKey, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("section/%s/%s.%s", sanitize(sectionKey != null ? sectionKey : "BELOW_SERVICES"), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
    }

    /** Upload vehicle catalog image (make or model). Used by admin to add car/bike selection images. */
    public String uploadVehicleCatalogPhoto(String type, String id, MultipartFile file) throws IOException {
        if (s3Client == null) {
            throw new IllegalStateException("S3 is not configured.");
        }
        String ext = getExtension(file.getOriginalFilename(), "jpg");
        String key = String.format("catalog/%s/%s/%s.%s", type, sanitize(id), UUID.randomUUID(), ext);
        upload(key, file.getContentType() != null ? file.getContentType() : "image/jpeg", file.getBytes());
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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
        return String.format("https://%s.s3.amazonaws.com/%s", bucket, key);
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

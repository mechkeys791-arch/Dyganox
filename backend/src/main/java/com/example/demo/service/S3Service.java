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

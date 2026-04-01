package com.example.demo.controller;

import com.example.demo.model.ServiceAd;
import com.example.demo.repository.ServiceAdRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/api/admin/service-ads")
@CrossOrigin(origins = "*")
public class ServiceAdAdminController {

    private final ServiceAdRepo serviceAdRepo;

    public ServiceAdAdminController(ServiceAdRepo serviceAdRepo) {
        this.serviceAdRepo = serviceAdRepo;
    }

    @GetMapping
    public ResponseEntity<List<ServiceAd>> list() {
        return ResponseEntity.ok(serviceAdRepo.findAll());
    }

    @PostMapping
    public ResponseEntity<?> create(@RequestBody Map<String, Object> body) {
        try {
            ServiceAd a = mapFromBody(body, new ServiceAd());
            a.setSource("PLATFORM");
            a.setMechanicId(null);
            if (a.getMediaUrl() == null || a.getMediaUrl().isBlank()) {
                return ResponseEntity.badRequest().body(Map.of("error", "mediaUrl required"));
            }
            return ResponseEntity.ok(serviceAdRepo.save(a));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Optional<ServiceAd> opt = serviceAdRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        ServiceAd a = opt.get();
        if (!"PLATFORM".equalsIgnoreCase(a.getSource())) {
            return ResponseEntity.badRequest().body(Map.of("error", "Use mechanic API for mechanic promos"));
        }
        mapFromBody(body, a);
        return ResponseEntity.ok(serviceAdRepo.save(a));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(@PathVariable Long id) {
        if (!serviceAdRepo.existsById(id)) return ResponseEntity.notFound().build();
        serviceAdRepo.deleteById(id);
        return ResponseEntity.ok(Map.of("ok", true));
    }

    private ServiceAd mapFromBody(Map<String, Object> body, ServiceAd a) {
        if (body.get("placement") != null) a.setPlacement(body.get("placement").toString().trim());
        if (body.get("title") != null) a.setTitle(body.get("title").toString());
        if (body.get("subtitle") != null) a.setSubtitle(body.get("subtitle").toString());
        if (body.get("headline") != null) a.setHeadline(body.get("headline").toString());
        if (body.get("mediaUrl") != null) a.setMediaUrl(body.get("mediaUrl").toString().trim());
        if (body.get("mediaType") != null) a.setMediaType(body.get("mediaType").toString().trim().toUpperCase());
        if (body.get("latitude") != null) a.setLatitude(body.get("latitude").toString());
        if (body.get("longitude") != null) a.setLongitude(body.get("longitude").toString());
        if (body.get("radiusKm") != null) {
            try {
                a.setRadiusKm(Double.parseDouble(body.get("radiusKm").toString()));
            } catch (Exception ignored) {}
        }
        if (body.get("active") != null) a.setActive(Boolean.TRUE.equals(body.get("active")) || "true".equalsIgnoreCase(String.valueOf(body.get("active"))));
        if (body.get("sortOrder") != null) {
            try {
                a.setSortOrder(Integer.parseInt(body.get("sortOrder").toString()));
            } catch (Exception ignored) {}
        }
        if (body.get("startsAt") != null && !body.get("startsAt").toString().isBlank()) {
            try {
                a.setStartsAt(Instant.parse(body.get("startsAt").toString()));
            } catch (Exception ignored) {}
        }
        if (body.get("endsAt") != null && !body.get("endsAt").toString().isBlank()) {
            try {
                a.setEndsAt(Instant.parse(body.get("endsAt").toString()));
            } catch (Exception ignored) {}
        }
        return a;
    }
}

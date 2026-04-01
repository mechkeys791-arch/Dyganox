package com.example.demo.controller;

import com.example.demo.model.ServiceAd;
import com.example.demo.repository.ServiceAdRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.*;

/**
 * Public: location-aware promotional strips (e.g. Night Service).
 */
@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class ServiceAdPublicController {

    private final ServiceAdRepo serviceAdRepo;

    public ServiceAdPublicController(ServiceAdRepo serviceAdRepo) {
        this.serviceAdRepo = serviceAdRepo;
    }

    @GetMapping("/service-ads")
    public ResponseEntity<List<Map<String, Object>>> listForPlacement(
            @RequestParam(defaultValue = "NIGHT_SERVICE") String placement,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        Instant now = Instant.now();
        List<ServiceAd> all = serviceAdRepo.findByPlacementAndActiveTrueOrderBySortOrderAscIdAsc(placement);
        List<Map<String, Object>> out = new ArrayList<>();
        for (ServiceAd a : all) {
            if (a.getStartsAt() != null && now.isBefore(a.getStartsAt())) continue;
            if (a.getEndsAt() != null && now.isAfter(a.getEndsAt())) continue;
            if (!matchesLocation(a, lat, lng)) continue;
            out.add(toPublicDto(a));
        }
        return ResponseEntity.ok(out);
    }

    private boolean matchesLocation(ServiceAd a, Double userLat, Double userLng) {
        String la = a.getLatitude();
        String lo = a.getLongitude();
        boolean noGeo = la == null || la.isBlank() || lo == null || lo.isBlank();
        if (noGeo) return true;
        double alat;
        double alng;
        try {
            alat = Double.parseDouble(la.trim());
            alng = Double.parseDouble(lo.trim());
        } catch (Exception e) {
            return true;
        }
        if (userLat == null || userLng == null) {
            return false;
        }
        double r = a.getRadiusKm() != null && a.getRadiusKm() > 0 ? a.getRadiusKm() : 25.0;
        return distanceKm(userLat, userLng, alat, alng) <= r;
    }

    private static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
        final double R = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double x = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
        return R * c;
    }

    private Map<String, Object> toPublicDto(ServiceAd a) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", a.getId());
        m.put("source", a.getSource());
        m.put("mechanicId", a.getMechanicId());
        m.put("title", a.getTitle() != null ? a.getTitle() : "");
        m.put("subtitle", a.getSubtitle() != null ? a.getSubtitle() : "");
        m.put("headline", a.getHeadline() != null ? a.getHeadline() : "");
        m.put("mediaUrl", a.getMediaUrl());
        m.put("mediaType", a.getMediaType() != null ? a.getMediaType() : "IMAGE");
        m.put("placement", a.getPlacement());
        m.put("sortOrder", a.getSortOrder() != null ? a.getSortOrder() : 0);
        return m;
    }
}

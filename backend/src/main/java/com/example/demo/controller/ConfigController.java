package com.example.demo.controller;

import com.example.demo.model.AppBranding;
import com.example.demo.model.AuthBackgroundVideo;
import com.example.demo.model.HomeHeroMedia;
import com.example.demo.model.Mechanic;
import com.example.demo.repository.AppBrandingRepo;
import com.example.demo.repository.AuthBackgroundVideoRepo;
import com.example.demo.repository.HomeHeroMediaRepo;
import com.example.demo.repository.MechanicRepo;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.stream.Collectors;

/**
 * Public config endpoints for the app (no auth). E.g. auth background video, home hero graphic.
 */
@RestController
@RequestMapping("/api/config")
@CrossOrigin(origins = "*")
public class ConfigController {

    private static final double EARTH_RADIUS_KM = 6371.0;

    private final AuthBackgroundVideoRepo authBackgroundVideoRepo;
    private final HomeHeroMediaRepo homeHeroMediaRepo;
    private final AppBrandingRepo appBrandingRepo;
    private final MechanicRepo mechanicRepo;

    public ConfigController(AuthBackgroundVideoRepo authBackgroundVideoRepo, HomeHeroMediaRepo homeHeroMediaRepo,
                            AppBrandingRepo appBrandingRepo, MechanicRepo mechanicRepo) {
        this.authBackgroundVideoRepo = authBackgroundVideoRepo;
        this.homeHeroMediaRepo = homeHeroMediaRepo;
        this.appBrandingRepo = appBrandingRepo;
        this.mechanicRepo = mechanicRepo;
    }

    private static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_KM * c;
    }

    /** Public: get auth background video config for login/signup. Returns videoUrl and active. */
    @GetMapping("/auth-video")
    public ResponseEntity<Map<String, Object>> getAuthVideo() {
        Optional<AuthBackgroundVideo> opt = authBackgroundVideoRepo.findTop1ByOrderByIdDesc();
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of("videoUrl", "", "active", false));
        }
        AuthBackgroundVideo c = opt.get();
        return ResponseEntity.ok(Map.of(
                "videoUrl", c.getVideoUrl() != null ? c.getVideoUrl() : "",
                "active", c.isActive()
        ));
    }

    /** Public: get home hero graphic config (Lottie or GIF overlay on red header). Returns mediaType, mediaUrl, active. */
    @GetMapping("/home-hero-media")
    public ResponseEntity<Map<String, Object>> getHomeHeroMedia() {
        Optional<HomeHeroMedia> opt = homeHeroMediaRepo.findTop1ByOrderByIdDesc();
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of("mediaType", "", "mediaUrl", "", "active", false));
        }
        HomeHeroMedia c = opt.get();
        return ResponseEntity.ok(Map.of(
                "mediaType", c.getMediaType() != null ? c.getMediaType() : "",
                "mediaUrl", c.getMediaUrl() != null ? c.getMediaUrl() : "",
                "active", c.isActive()
        ));
    }

    /** Public: get app branding (logo, splash, welcome, car/bike images, quick service icons). */
    @GetMapping("/app-branding")
    public ResponseEntity<Map<String, Object>> getAppBranding() {
        var opt = appBrandingRepo.findTop1ByOrderByIdDesc();
        Map<String, Object> map = new HashMap<>();
        map.put("appLogoUrl", "");
        map.put("splashMediaUrl", "");
        map.put("splashMediaType", "");
        map.put("welcomeTitle", "Welcome to ProMech");
        map.put("welcomePageMediaUrl", "");
        map.put("welcomePageMediaType", "");
        map.put("welcomePageGifUrl", "");
        map.put("loadingMediaUrl", "");
        map.put("loadingMediaType", "");
        map.put("carServiceImageUrl", "");
        map.put("bikeServiceImageUrl", "");
        map.put("quickServiceNightServiceIconUrl", "");
        map.put("quickServiceTowingIconUrl", "");
        map.put("quickServiceFuelRefillIconUrl", "");
        map.put("quickServiceEvChargingIconUrl", "");
        map.put("quickServiceTyreCareIconUrl", "");
        map.put("quickServiceMinorRepairIconUrl", "");
        map.put("quickServiceBatteryJumpIconUrl", "");
        map.put("nightServiceIconsJson", "");
        map.put("nearestMechanicMarkerIconUrl", "");
        map.put("userLocationMarkerIconUrl", "");
        map.put("mechanicShopMarkerIconUrl", "");
        map.put("mechanicDrivingMarkerIconUrl", "");
        map.put("problemCategoryIconsJson", "");
        if (opt.isPresent()) {
            AppBranding c = opt.get();
            map.put("appLogoUrl", c.getAppLogoUrl() != null ? c.getAppLogoUrl() : "");
            map.put("splashMediaUrl", c.getSplashMediaUrl() != null ? c.getSplashMediaUrl() : "");
            map.put("splashMediaType", c.getSplashMediaType() != null ? c.getSplashMediaType() : "");
            map.put("welcomeTitle", c.getWelcomeTitle() != null && !c.getWelcomeTitle().isEmpty() ? c.getWelcomeTitle() : "Welcome to ProMech");
            map.put("welcomePageMediaUrl", c.getWelcomePageMediaUrl() != null ? c.getWelcomePageMediaUrl() : "");
            map.put("welcomePageMediaType", c.getWelcomePageMediaType() != null ? c.getWelcomePageMediaType() : "");
            map.put("welcomePageGifUrl", c.getWelcomePageGifUrl() != null ? c.getWelcomePageGifUrl() : "");
            map.put("loadingMediaUrl", c.getLoadingMediaUrl() != null ? c.getLoadingMediaUrl() : "");
            map.put("loadingMediaType", c.getLoadingMediaType() != null ? c.getLoadingMediaType() : "");
            map.put("carServiceImageUrl", c.getCarServiceImageUrl() != null ? c.getCarServiceImageUrl() : "");
            map.put("bikeServiceImageUrl", c.getBikeServiceImageUrl() != null ? c.getBikeServiceImageUrl() : "");
            map.put("quickServiceNightServiceIconUrl", c.getQuickServiceNightServiceIconUrl() != null ? c.getQuickServiceNightServiceIconUrl() : "");
            map.put("quickServiceTowingIconUrl", c.getQuickServiceTowingIconUrl() != null ? c.getQuickServiceTowingIconUrl() : "");
            map.put("quickServiceFuelRefillIconUrl", c.getQuickServiceFuelRefillIconUrl() != null ? c.getQuickServiceFuelRefillIconUrl() : "");
            map.put("quickServiceEvChargingIconUrl", c.getQuickServiceEvChargingIconUrl() != null ? c.getQuickServiceEvChargingIconUrl() : "");
            map.put("quickServiceTyreCareIconUrl", c.getQuickServiceTyreCareIconUrl() != null ? c.getQuickServiceTyreCareIconUrl() : "");
            map.put("quickServiceMinorRepairIconUrl", c.getQuickServiceMinorRepairIconUrl() != null ? c.getQuickServiceMinorRepairIconUrl() : "");
            map.put("quickServiceBatteryJumpIconUrl", c.getQuickServiceBatteryJumpIconUrl() != null ? c.getQuickServiceBatteryJumpIconUrl() : "");
            map.put("nightServiceIconsJson", c.getNightServiceIconsJson() != null ? c.getNightServiceIconsJson() : "");
            map.put("nearestMechanicMarkerIconUrl", c.getNearestMechanicMarkerIconUrl() != null ? c.getNearestMechanicMarkerIconUrl() : "");
            map.put("userLocationMarkerIconUrl", c.getUserLocationMarkerIconUrl() != null ? c.getUserLocationMarkerIconUrl() : "");
            map.put("mechanicShopMarkerIconUrl", c.getMechanicShopMarkerIconUrl() != null ? c.getMechanicShopMarkerIconUrl() : "");
            map.put("mechanicDrivingMarkerIconUrl", c.getMechanicDrivingMarkerIconUrl() != null ? c.getMechanicDrivingMarkerIconUrl() : "");
            map.put("problemCategoryIconsJson", c.getProblemCategoryIconsJson() != null ? c.getProblemCategoryIconsJson() : "");
        }
        return ResponseEntity.ok(map);
    }

    /** Public: Night Service tile icons from admin (JSON string of key → image URL). */
    @GetMapping("/night-service-icons")
    public ResponseEntity<Map<String, String>> getNightServiceIcons() {
        Map<String, String> icons = new HashMap<>();
        var opt = appBrandingRepo.findTop1ByOrderByIdDesc();
        ObjectMapper om = new ObjectMapper();
        if (opt.isPresent()) {
            String json = opt.get().getNightServiceIconsJson();
            if (json != null && !json.isBlank()) {
                try {
                    icons = om.readValue(json, new TypeReference<Map<String, String>>() {});
                } catch (Exception ignored) {}
            }
        }
        return ResponseEntity.ok(icons);
    }

    /**
     * Book Mechanic "What's the problem?" icons.
     * Optional query: vehicleType=CAR|BIKE (default CAR).
     * Stored JSON may be nested: {"car":{"tyre_puncture":"https://..."},"bike":{...}} or legacy flat map (same URLs for both).
     */
    @GetMapping("/problem-category-icons")
    public ResponseEntity<Map<String, String>> getProblemCategoryIcons(
            @RequestParam(required = false, defaultValue = "CAR") String vehicleType) {
        var opt = appBrandingRepo.findTop1ByOrderByIdDesc();
        Map<String, String> icons = new HashMap<>();
        ObjectMapper om = new ObjectMapper();
        if (opt.isPresent()) {
            String json = opt.get().getProblemCategoryIconsJson();
            if (json != null && !json.isBlank()) {
                try {
                    JsonNode root = om.readTree(json);
                    if (root.isObject() && root.has("car") && root.has("bike")
                            && root.get("car").isObject() && root.get("bike").isObject()) {
                        String vt = vehicleType == null ? "CAR" : vehicleType.trim().toUpperCase();
                        JsonNode branch = "BIKE".equals(vt) ? root.get("bike") : root.get("car");
                        icons = om.convertValue(branch, new TypeReference<Map<String, String>>() {});
                    } else {
                        icons = om.readValue(json, new TypeReference<Map<String, String>>() {});
                    }
                } catch (Exception ignored) {}
            }
        }
        return ResponseEntity.ok(icons);
    }

    /**
     * Public: approved mechanics with coordinates for "See nearest mechanic" map.
     * Uses live location when set, otherwise registration shop coordinates. No PII in labels (app shows pins only).
     */
    @GetMapping("/nearest-mechanic-locations")
    public ResponseEntity<Map<String, Object>> getNearestMechanicLocations(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @RequestParam(required = false, defaultValue = "50") int radiusKm) {
        List<Mechanic> all = mechanicRepo.findAll();
        List<Map<String, Object>> locations = new ArrayList<>();
        for (Mechanic mech : all) {
            // Same visibility as Book Mechanic list: approved + not blocked (not excluded for suspended/offline).
            if (Boolean.TRUE.equals(mech.isBlocked())) {
                continue;
            }
            String approval = mech.getApprovalStatus();
            if (approval == null || !"APPROVED".equalsIgnoreCase(approval.trim())) {
                continue;
            }
            // Match BookMechanicService.withinRadiusForList: per-field current vs registration fallback.
            String latStr = (mech.getCurrentLatitude() != null && !mech.getCurrentLatitude().isBlank())
                    ? mech.getCurrentLatitude().trim()
                    : (mech.getLatitude() != null ? mech.getLatitude().trim() : null);
            String lngStr = (mech.getCurrentLongitude() != null && !mech.getCurrentLongitude().isBlank())
                    ? mech.getCurrentLongitude().trim()
                    : (mech.getLongitude() != null ? mech.getLongitude().trim() : null);
            if (latStr == null || lngStr == null || latStr.isEmpty() || lngStr.isEmpty()) {
                continue;
            }
            double mlat;
            double mlng;
            try {
                mlat = Double.parseDouble(latStr);
                mlng = Double.parseDouble(lngStr);
            } catch (Exception e) {
                continue;
            }
            if (lat != null && lng != null && radiusKm > 0) {
                if (distanceKm(lat, lng, mlat, mlng) > radiusKm) {
                    continue;
                }
            }
            Map<String, Object> row = new HashMap<>();
            row.put("id", mech.getId());
            row.put("latitude", latStr);
            row.put("longitude", lngStr);
            locations.add(row);
        }
        String markerIconUrl = "";
        String userLocationMarkerIconUrl = "";
        var brandingOpt = appBrandingRepo.findTop1ByOrderByIdDesc();
        if (brandingOpt.isPresent()) {
            AppBranding b = brandingOpt.get();
            if (b.getNearestMechanicMarkerIconUrl() != null) markerIconUrl = b.getNearestMechanicMarkerIconUrl();
            if (b.getUserLocationMarkerIconUrl() != null) userLocationMarkerIconUrl = b.getUserLocationMarkerIconUrl();
        }
        return ResponseEntity.ok(Map.of(
                "locations", locations,
                "markerIconUrl", markerIconUrl,
                "userLocationMarkerIconUrl", userLocationMarkerIconUrl != null ? userLocationMarkerIconUrl : ""
        ));
    }
}

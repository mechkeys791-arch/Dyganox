package com.example.demo.controller;

import com.example.demo.model.AppBranding;
import com.example.demo.model.AuthBackgroundVideo;
import com.example.demo.model.HomeHeroMedia;
import com.example.demo.model.NearestMechanicLocation;
import com.example.demo.repository.AppBrandingRepo;
import com.example.demo.repository.AuthBackgroundVideoRepo;
import com.example.demo.repository.HomeHeroMediaRepo;
import com.example.demo.repository.NearestMechanicLocationRepo;
import com.fasterxml.jackson.core.type.TypeReference;
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
    private final NearestMechanicLocationRepo nearestMechanicLocationRepo;

    public ConfigController(AuthBackgroundVideoRepo authBackgroundVideoRepo, HomeHeroMediaRepo homeHeroMediaRepo,
                            AppBrandingRepo appBrandingRepo, NearestMechanicLocationRepo nearestMechanicLocationRepo) {
        this.authBackgroundVideoRepo = authBackgroundVideoRepo;
        this.homeHeroMediaRepo = homeHeroMediaRepo;
        this.appBrandingRepo = appBrandingRepo;
        this.nearestMechanicLocationRepo = nearestMechanicLocationRepo;
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
        }
        return ResponseEntity.ok(map);
    }

    /** Public: get problem category icon URLs for Book Mechanic "What's the problem?". Returns map of problemId -> iconUrl from S3 (admin config). */
    @GetMapping("/problem-category-icons")
    public ResponseEntity<Map<String, String>> getProblemCategoryIcons() {
        var opt = appBrandingRepo.findTop1ByOrderByIdDesc();
        Map<String, String> icons = new HashMap<>();
        if (opt.isPresent()) {
            String json = opt.get().getProblemCategoryIconsJson();
            if (json != null && !json.isBlank()) {
                try {
                    icons = new ObjectMapper().readValue(json, new TypeReference<Map<String, String>>() {});
                } catch (Exception ignored) {}
            }
        }
        return ResponseEntity.ok(icons);
    }

    /** Public: get pins for "See nearest mechanic" map only. No names. Optional lat, lng, radiusKm to filter by distance. */
    @GetMapping("/nearest-mechanic-locations")
    public ResponseEntity<Map<String, Object>> getNearestMechanicLocations(
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng,
            @RequestParam(required = false, defaultValue = "50") int radiusKm) {
        List<NearestMechanicLocation> all = nearestMechanicLocationRepo.findAllByOrderByIdAsc();
        List<Map<String, Object>> locations = new ArrayList<>();
        for (NearestMechanicLocation loc : all) {
            try {
                double mlat = Double.parseDouble(loc.getLatitude());
                double mlng = Double.parseDouble(loc.getLongitude());
                if (lat != null && lng != null && radiusKm > 0) {
                    if (distanceKm(lat, lng, mlat, mlng) > radiusKm) continue;
                }
                locations.add(Map.of(
                        "id", loc.getId(),
                        "latitude", loc.getLatitude(),
                        "longitude", loc.getLongitude()
                ));
            } catch (Exception ignore) {}
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

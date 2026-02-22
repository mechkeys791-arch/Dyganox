package com.example.demo.controller;

import com.example.demo.model.MarketingPoster;
import com.example.demo.model.SectionPoster;
import com.example.demo.repository.MarketingPosterRepo;
import com.example.demo.repository.SectionPosterRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class PosterController {

    private final MarketingPosterRepo posterRepo;
    private final SectionPosterRepo sectionPosterRepo;

    public PosterController(MarketingPosterRepo posterRepo, SectionPosterRepo sectionPosterRepo) {
        this.posterRepo = posterRepo;
        this.sectionPosterRepo = sectionPosterRepo;
    }

    /** Public: get active marketing poster for user's location. Pass lat/lng for area (circle) targeting, or city/state. If no poster matches, returns empty (app shows homepage). */
    @GetMapping("/poster/active")
    public ResponseEntity<PosterDto> getActive(
            @RequestParam(required = false) String city,
            @RequestParam(required = false) String state,
            @RequestParam(required = false) Double lat,
            @RequestParam(required = false) Double lng) {
        String c = normalize(city);
        String s = normalize(state);
        List<MarketingPoster> active = posterRepo.findAllByActiveTrueOrderByIdDesc();
        // 1) Area (circle): user within radius of poster center
        if (lat != null && lng != null) {
            Optional<MarketingPoster> areaMatch = active.stream().filter(p -> matchesArea(p, lat, lng)).findFirst();
            if (areaMatch.isPresent()) return ResponseEntity.ok(toDto(areaMatch.get()));
        }
        // 2) Exact city+state, 3) state-only, 4) global
        Optional<MarketingPoster> exact = active.stream().filter(p -> matchesExact(p, c, s)).findFirst();
        if (exact.isPresent()) return ResponseEntity.ok(toDto(exact.get()));
        Optional<MarketingPoster> stateOnly = active.stream().filter(p -> matchesStateOnly(p, s)).findFirst();
        if (stateOnly.isPresent()) return ResponseEntity.ok(toDto(stateOnly.get()));
        Optional<MarketingPoster> global = active.stream().filter(PosterController::isGlobal).findFirst();
        return global.map(PosterController::toDto).map(ResponseEntity::ok).orElse(ResponseEntity.ok(new PosterDto(null, null, null)));
    }

    private static PosterDto toDto(MarketingPoster p) {
        return new PosterDto(p.getId(), p.getImageUrl(), p.getLinkUrl());
    }

    /** Poster has circle target and user is within radius (km). */
    private static boolean matchesArea(MarketingPoster p, double userLat, double userLng) {
        Double lat = p.getTargetLat();
        Double lng = p.getTargetLng();
        Double radiusKm = p.getTargetRadiusKm();
        if (lat == null || lng == null || radiusKm == null || radiusKm <= 0) return false;
        double km = haversineKm(lat, lng, userLat, userLng);
        return km <= radiusKm;
    }

    private static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
        final int R = 6371; // Earth radius km
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    private static boolean matchesExact(MarketingPoster p, String userCity, String userState) {
        String pCity = normalize(p.getTargetCity());
        String pState = normalize(p.getTargetState());
        return !pCity.isEmpty() && pCity.equalsIgnoreCase(userCity) && (pState.isEmpty() || pState.equalsIgnoreCase(userState));
    }

    private static boolean matchesStateOnly(MarketingPoster p, String userState) {
        String pCity = normalize(p.getTargetCity());
        String pState = normalize(p.getTargetState());
        return pCity.isEmpty() && !pState.isEmpty() && pState.equalsIgnoreCase(userState);
    }

    private static boolean isGlobal(MarketingPoster p) {
        if (!normalize(p.getTargetCity()).isEmpty() || !normalize(p.getTargetState()).isEmpty()) return false;
        if (p.getTargetLat() != null && p.getTargetLng() != null && p.getTargetRadiusKm() != null && p.getTargetRadiusKm() > 0) return false;
        return true;
    }

    private static String normalize(String s) {
        if (s == null) return "";
        return s.trim();
    }

    /** Public: get section images (e.g. below "Our Services"). section=BELOW_SERVICES */
    @GetMapping("/section-posters")
    public ResponseEntity<List<SectionPosterDto>> getSectionPosters(
            @RequestParam(defaultValue = "BELOW_SERVICES") String section) {
        List<SectionPoster> list = sectionPosterRepo.findBySectionKeyOrderBySortOrderAsc(section);
        List<SectionPosterDto> dtos = list.stream()
                .map(p -> new SectionPosterDto(p.getId(), p.getImageUrl(), p.getLinkUrl(), p.getSortOrder()))
                .collect(Collectors.toList());
        return ResponseEntity.ok(dtos);
    }

    public static record PosterDto(Long id, String imageUrl, String linkUrl) {}
    public static record SectionPosterDto(Long id, String imageUrl, String linkUrl, int sortOrder) {}
}

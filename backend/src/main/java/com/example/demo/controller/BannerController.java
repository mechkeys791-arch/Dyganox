package com.example.demo.controller;

import com.example.demo.repository.BannerRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api")
public class BannerController {

    private final BannerRepo bannerRepo;

    public BannerController(BannerRepo bannerRepo) {
        this.bannerRepo = bannerRepo;
    }

    /**
     * Public API - returns active banners for app. Optional targetType: CAR, BIKE, or omit for ALL.
     * Returns banners where targetType = ALL or targetType = requested type.
     */
    @GetMapping("/banners")
    public ResponseEntity<List<BannerDto>> getBanners(@RequestParam(required = false) String targetType) {
        List<com.example.demo.model.Banner> list;
        if (targetType != null && !targetType.isBlank()) {
            String t = targetType.toUpperCase();
            if ("CAR".equals(t) || "BIKE".equals(t)) {
                List<com.example.demo.model.Banner> all = bannerRepo.findByActiveTrueOrderBySortOrderAsc();
                list = all.stream()
                        .filter(b -> "ALL".equalsIgnoreCase(b.getTargetType()) || t.equalsIgnoreCase(b.getTargetType()))
                        .collect(Collectors.toList());
            } else {
                list = bannerRepo.findByActiveTrueOrderBySortOrderAsc();
            }
        } else {
            list = bannerRepo.findByActiveTrueOrderBySortOrderAsc();
        }
        return ResponseEntity.ok(list.stream()
                .map(b -> new BannerDto(b.getId(), b.getImageUrl(), b.getTitle(), b.getSubtitle(), b.getSortOrder(), b.getTargetType()))
                .collect(Collectors.toList()));
    }

    public static record BannerDto(Long id, String imageUrl, String title, String subtitle, int sortOrder, String targetType) {}
}

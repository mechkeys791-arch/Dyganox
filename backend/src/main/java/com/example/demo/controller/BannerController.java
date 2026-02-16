package com.example.demo.controller;

import com.example.demo.repository.BannerRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

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
     * Public API - returns active banners for app carousel.
     */
    @GetMapping("/banners")
    public ResponseEntity<List<BannerDto>> getBanners() {
        return ResponseEntity.ok(bannerRepo.findByActiveTrueOrderBySortOrderAsc().stream()
                .map(b -> new BannerDto(b.getId(), b.getImageUrl(), b.getTitle(), b.getSubtitle(), b.getSortOrder()))
                .collect(Collectors.toList()));
    }

    public static record BannerDto(Long id, String imageUrl, String title, String subtitle, int sortOrder) {}
}

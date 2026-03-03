package com.example.demo.controller;

import com.example.demo.model.AppBranding;
import com.example.demo.model.AuthBackgroundVideo;
import com.example.demo.model.HomeHeroMedia;
import com.example.demo.repository.AppBrandingRepo;
import com.example.demo.repository.AuthBackgroundVideoRepo;
import com.example.demo.repository.HomeHeroMediaRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Optional;

/**
 * Public config endpoints for the app (no auth). E.g. auth background video, home hero graphic.
 */
@RestController
@RequestMapping("/api/config")
@CrossOrigin(origins = "*")
public class ConfigController {

    private final AuthBackgroundVideoRepo authBackgroundVideoRepo;
    private final HomeHeroMediaRepo homeHeroMediaRepo;
    private final AppBrandingRepo appBrandingRepo;

    public ConfigController(AuthBackgroundVideoRepo authBackgroundVideoRepo, HomeHeroMediaRepo homeHeroMediaRepo, AppBrandingRepo appBrandingRepo) {
        this.authBackgroundVideoRepo = authBackgroundVideoRepo;
        this.homeHeroMediaRepo = homeHeroMediaRepo;
        this.appBrandingRepo = appBrandingRepo;
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

    /** Public: get app branding (logo, splash media, welcome title). */
    @GetMapping("/app-branding")
    public ResponseEntity<Map<String, Object>> getAppBranding() {
        var opt = appBrandingRepo.findTop1ByOrderByIdDesc();
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of(
                    "appLogoUrl", "",
                    "splashMediaUrl", "",
                    "splashMediaType", "",
                    "welcomeTitle", "Welcome to ProMech",
                    "welcomePageMediaUrl", "",
                    "welcomePageMediaType", "",
                    "welcomePageGifUrl", "",
                    "loadingMediaUrl", "",
                    "loadingMediaType", ""
            ));
        }
        AppBranding c = opt.get();
        return ResponseEntity.ok(Map.of(
                "appLogoUrl", c.getAppLogoUrl() != null ? c.getAppLogoUrl() : "",
                "splashMediaUrl", c.getSplashMediaUrl() != null ? c.getSplashMediaUrl() : "",
                "splashMediaType", c.getSplashMediaType() != null ? c.getSplashMediaType() : "",
                "welcomeTitle", c.getWelcomeTitle() != null && !c.getWelcomeTitle().isEmpty() ? c.getWelcomeTitle() : "Welcome to ProMech",
                "welcomePageMediaUrl", c.getWelcomePageMediaUrl() != null ? c.getWelcomePageMediaUrl() : "",
                "welcomePageMediaType", c.getWelcomePageMediaType() != null ? c.getWelcomePageMediaType() : "",
                "welcomePageGifUrl", c.getWelcomePageGifUrl() != null ? c.getWelcomePageGifUrl() : "",
                "loadingMediaUrl", c.getLoadingMediaUrl() != null ? c.getLoadingMediaUrl() : "",
                "loadingMediaType", c.getLoadingMediaType() != null ? c.getLoadingMediaType() : ""
        ));
    }
}

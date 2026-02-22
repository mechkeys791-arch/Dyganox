package com.example.demo.controller;

import com.example.demo.model.AppVersionConfig;
import com.example.demo.repository.AppVersionConfigRepo;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Comparator;
import java.util.List;

@RestController
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class AppVersionController {

    private final AppVersionConfigRepo versionRepo;

    public AppVersionController(AppVersionConfigRepo versionRepo) {
        this.versionRepo = versionRepo;
    }

    /**
     * Public: version check. currentVersion = app's package version (e.g. 1.0.0).
     * Returns updateAvailable=true if currentVersion < minRequiredVersion.
     */
    @GetMapping("/app/version-check")
    public ResponseEntity<VersionCheckDto> check(@RequestParam String currentVersion) {
        List<AppVersionConfig> all = versionRepo.findAll();
        AppVersionConfig config = all.stream().max(Comparator.comparing(AppVersionConfig::getId)).orElse(null);
        if (config == null || config.getMinRequiredVersion() == null || config.getMinRequiredVersion().isBlank()) {
            return ResponseEntity.ok(new VersionCheckDto(false, null, null, null, null));
        }
        boolean updateAvailable = isLessThan(currentVersion.trim(), config.getMinRequiredVersion().trim());
        return ResponseEntity.ok(new VersionCheckDto(
                updateAvailable,
                config.getLatestVersion(),
                config.getMinRequiredVersion(),
                config.getUpdateTitle(),
                config.getUpdateMessage()));
    }

    private static boolean isLessThan(String current, String required) {
        try {
            String[] a = current.split("\\.");
            String[] b = required.split("\\.");
            for (int i = 0; i < Math.max(a.length, b.length); i++) {
                int va = i < a.length ? Integer.parseInt(a[i].replaceAll("[^0-9]", "")) : 0;
                int vb = i < b.length ? Integer.parseInt(b[i].replaceAll("[^0-9]", "")) : 0;
                if (va < vb) return true;
                if (va > vb) return false;
            }
            return false;
        } catch (Exception e) {
            return true; // if unparseable, consider update available
        }
    }

    public static record VersionCheckDto(boolean updateAvailable, String latestVersion, String minRequiredVersion,
                                         String updateTitle, String updateMessage) {}
}

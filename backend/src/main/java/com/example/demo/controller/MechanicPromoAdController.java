package com.example.demo.controller;

import com.example.demo.model.Mechanic;
import com.example.demo.model.ServiceAd;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.ServiceAdRepo;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.YearMonth;
import java.time.ZoneId;
import java.util.Map;
import java.util.Optional;

/**
 * Mechanic monthly promo strip (1 per calendar month, free for now).
 */
@RestController
@RequestMapping("/api/mechanic")
@CrossOrigin(origins = "*")
public class MechanicPromoAdController {

    private final MechanicRepo mechanicRepo;
    private final ServiceAdRepo serviceAdRepo;

    public MechanicPromoAdController(MechanicRepo mechanicRepo, ServiceAdRepo serviceAdRepo) {
        this.mechanicRepo = mechanicRepo;
        this.serviceAdRepo = serviceAdRepo;
    }

    @GetMapping("/{id}/promo-ad/eligibility")
    public ResponseEntity<?> eligibility(@PathVariable Long id) {
        if (!mechanicRepo.existsById(id)) return ResponseEntity.notFound().build();
        String ym = YearMonth.now(ZoneId.systemDefault()).toString();
        long count = serviceAdRepo.countByMechanicIdAndPromoYearMonth(id, ym);
        return ResponseEntity.ok(Map.of(
                "canCreate", count < 1,
                "promoYearMonth", ym,
                "message", count >= 1 ? "You already have an active promotion for this month." : ""
        ));
    }

    @GetMapping("/{id}/promo-ad/current")
    public ResponseEntity<ServiceAd> current(@PathVariable Long id) {
        if (!mechanicRepo.existsById(id)) return ResponseEntity.notFound().build();
        String ym = YearMonth.now(ZoneId.systemDefault()).toString();
        return serviceAdRepo.findFirstByMechanicIdAndPromoYearMonthOrderByIdDesc(id, ym)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @PostMapping("/{id}/promo-ad")
    public ResponseEntity<?> create(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Optional<Mechanic> opt = mechanicRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        Mechanic mech = opt.get();
        String ym = YearMonth.now(ZoneId.systemDefault()).toString();
        if (serviceAdRepo.countByMechanicIdAndPromoYearMonth(id, ym) >= 1) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(Map.of("error", "One promotion per month. Try again next month."));
        }
        String mediaUrl = body != null && body.get("mediaUrl") != null ? body.get("mediaUrl").toString().trim() : "";
        if (mediaUrl.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "mediaUrl required (upload file first, then send URL)."));
        }
        String mediaType = "IMAGE";
        if (body != null && body.get("mediaType") != null) {
            String mt = body.get("mediaType").toString().trim().toUpperCase();
            if ("VIDEO".equals(mt)) mediaType = "VIDEO";
        }
        ServiceAd a = new ServiceAd();
        a.setPlacement("NIGHT_SERVICE");
        a.setSource("MECHANIC");
        a.setMechanicId(id);
        a.setMediaUrl(mediaUrl);
        a.setMediaType(mediaType);
        a.setPromoYearMonth(ym);
        a.setTitle(mech.getName() != null ? mech.getName() : "Mechanic");
        a.setSubtitle(body != null && body.get("subtitle") != null ? body.get("subtitle").toString() : "Tap to book — your request goes to this mechanic.");
        String name = mech.getName() != null ? mech.getName() : "This mechanic";
        a.setHeadline(name + " is ready — what's the problem? They'll fix it.");
        String lat = mech.getLatitude();
        String lng = mech.getLongitude();
        if (lat != null && !lat.isBlank() && lng != null && !lng.isBlank()) {
            a.setLatitude(lat.trim());
            a.setLongitude(lng.trim());
            double r = 25;
            if (body != null && body.get("radiusKm") != null) {
                try {
                    r = Double.parseDouble(body.get("radiusKm").toString());
                } catch (Exception ignored) {}
            }
            a.setRadiusKm(r);
        } else {
            a.setLatitude(null);
            a.setLongitude(null);
            a.setRadiusKm(50.0);
        }
        a.setActive(true);
        a.setSortOrder(50);
        return ResponseEntity.ok(serviceAdRepo.save(a));
    }
}

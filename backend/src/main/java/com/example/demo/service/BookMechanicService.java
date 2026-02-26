package com.example.demo.service;

import com.example.demo.model.Mechanic;
import com.example.demo.model.MechanicRequest;
import com.example.demo.model.UserVehicle;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.MechanicRequestRepo;
import com.example.demo.repository.UserVehicleRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class BookMechanicService {

    private static final double EARTH_RADIUS_KM = 6371.0;

    @Autowired
    private MechanicRepo mechanicRepo;
    @Autowired
    private MechanicRequestRepo mechanicRequestRepo;
    @Autowired
    private UserVehicleRepo userVehicleRepo;
    @Autowired
    private FcmService fcmService;

    /**
     * Haversine distance in km between two points.
     */
    public static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return EARTH_RADIUS_KM * c;
    }

    /**
     * Find approved mechanics that serve the given problem category and are within radiusKm of (lat, lng).
     * Returns mechanics without exposing phone or distance to client (for public list).
     */
    public List<Map<String, Object>> findMechanicsByCategoryAndLocation(
            String problemCategory, Double lat, Double lng, int radiusKm) {
        List<Mechanic> all = mechanicRepo.findAll();
        List<Mechanic> approved = all.stream()
                .filter(m -> "APPROVED".equalsIgnoreCase(m.getApprovalStatus()) && !Boolean.TRUE.equals(m.isBlocked()))
                .filter(m -> servesCategory(m, problemCategory))
                .filter(m -> withinRadius(m, lat, lng, radiusKm))
                .collect(Collectors.toList());
        List<Map<String, Object>> result = new ArrayList<>();
        for (Mechanic m : approved) {
            Map<String, Object> map = new HashMap<>();
            map.put("id", m.getId());
            map.put("name", m.getName());
            map.put("specialty", m.getSpecialty());
            map.put("experience", m.getExperience());
            map.put("nightTimeAvailable", m.isNightTimeAvailable());
            map.put("services", m.getServices());
            map.put("status", m.getStatus());
            map.put("categoryIconUrl", m.getCategoryIconUrl());
            map.put("openingTime", m.getOpeningTime());
            map.put("closingTime", m.getClosingTime());
            map.put("workingDays", m.getWorkingDays());
            // Intentionally omit: phone, latitude, longitude, distance
            result.add(map);
        }
        return result;
    }

    /**
     * Find mechanic IDs within radius (5, 10, or 20 km) that serve the category.
     * Used for broadcast. Returns list of mechanics with their distance for picking radius tier.
     */
    public List<Mechanic> findMechanicsForBroadcast(double lat, double lng, String problemCategory, int radiusKm) {
        List<Mechanic> all = mechanicRepo.findAll();
        return all.stream()
                .filter(m -> "APPROVED".equalsIgnoreCase(m.getApprovalStatus()) && !Boolean.TRUE.equals(m.isBlocked()))
                .filter(m -> "Available".equalsIgnoreCase(m.getStatus()) || "Busy".equalsIgnoreCase(m.getStatus()))
                .filter(m -> servesCategory(m, problemCategory))
                .filter(m -> withinRadius(m, lat, lng, radiusKm))
                .collect(Collectors.toList());
    }

    private boolean servesCategory(Mechanic m, String problemCategory) {
        if (problemCategory == null || problemCategory.isBlank()) return true;
        String cats = m.getServiceCategories();
        if (cats == null || cats.isBlank()) return true;
        String lower = problemCategory.toLowerCase();
        if (cats.contains(lower)) return true;
        if (cats.contains("\"" + lower + "\"")) return true;
        for (String part : cats.split("[,{\"\\[\\]\s]+")) {
            if (part.trim().equalsIgnoreCase(problemCategory)) return true;
        }
        return false;
    }

    private boolean withinRadius(Mechanic m, Double userLat, Double userLng, int radiusKm) {
        if (userLat == null || userLng == null) return true;
        String slat = m.getLatitude();
        String slng = m.getLongitude();
        if (slat == null || slng == null) return false;
        double mlat = Double.parseDouble(slat);
        double mlng = Double.parseDouble(slng);
        double dist = distanceKm(userLat, userLng, mlat, mlng);
        Integer max = m.getMaxServingRadiusKm();
        if (max != null && dist > max) return false;
        return dist <= radiusKm;
    }

    /**
     * Create broadcast request: 5km first, then 10km, then 20km. Notify all mechanics in that radius.
     */
    public MechanicRequest createBroadcastRequest(
            String customerName, String customerEmail, String customerPhone,
            Long userVehicleId, String problemCategory, String description,
            String diagnosticAnswers, String comment, String photoUrls,
            double lat, double lng, Double advanceAmount, Double platformFee,
            Double comingChargePerKm, Double comingChargeTotal, Integer requestRadiusKm,
            Boolean outOfHoursRequest) {
        MechanicRequest req = new MechanicRequest();
        req.setMechanicId(null);
        req.setAcceptedMechanicId(null);
        req.setCustomerName(customerName);
        req.setCustomerEmail(customerEmail);
        req.setCustomerPhone(customerPhone);
        req.setUserVehicleId(userVehicleId);
        req.setServiceType(problemCategory);
        req.setProblemCategory(problemCategory);
        req.setDescription(description);
        req.setDiagnosticAnswers(diagnosticAnswers);
        req.setComment(comment);
        req.setPhotoUrls(photoUrls);
        req.setLatitude(String.valueOf(lat));
        req.setLongitude(String.valueOf(lng));
        req.setAdvanceAmount(advanceAmount != null ? advanceAmount : 100.0);
        req.setPlatformFee(platformFee != null ? platformFee : 9.0);
        req.setComingChargePerKm(comingChargePerKm != null ? comingChargePerKm : 3.0);
        req.setComingChargeTotal(comingChargeTotal != null ? comingChargeTotal : 0.0);
        req.setRequestRadiusKm(requestRadiusKm != null ? requestRadiusKm : 5);
        req.setOutOfHoursRequest(Boolean.TRUE.equals(outOfHoursRequest));
        req.setStatus("PENDING_BROADCAST");
        req.setRequestTime(LocalDateTime.now());
        req.setViewExpiryAt(LocalDateTime.now().plusMinutes(5));
        req.setRefundStatus("PENDING");
        req.setAmount(0);

        if (userVehicleId != null) {
            userVehicleRepo.findById(userVehicleId).ifPresent(uv -> {
                req.setVehicleMakeName(uv.getMakeName());
                req.setVehicleModelName(uv.getModelName());
                req.setVehiclePlateNumber(uv.getPlateNumber());
                String photo = uv.getPhotoUrl() != null && !uv.getPhotoUrl().isBlank() ? uv.getPhotoUrl() : uv.getModelImageUrl();
                req.setVehiclePhotoUrl(photo);
            });
        }

        MechanicRequest saved = mechanicRequestRepo.save(req);
        // Determine radius: try 5km, then 10km, then 20km
        int radius = 5;
        List<Mechanic> mechanics = findMechanicsForBroadcast(lat, lng, problemCategory, 5);
        if (mechanics.isEmpty()) {
            radius = 10;
            mechanics = findMechanicsForBroadcast(lat, lng, problemCategory, 10);
        }
        if (mechanics.isEmpty()) {
            radius = 20;
            mechanics = findMechanicsForBroadcast(lat, lng, problemCategory, 20);
        }
        saved.setRequestRadiusKm(radius);
        List<Long> notifiedIds = new ArrayList<>();
        for (Mechanic m : mechanics) {
            notifiedIds.add(m.getId());
            double dist = distanceKm(lat, lng,
                    Double.parseDouble(m.getLatitude()), Double.parseDouble(m.getLongitude()));
            if (m.getFcmToken() != null && !m.getFcmToken().isBlank()) {
                fcmService.sendMechanicRequestNotification(
                        m.getFcmToken(), saved.getId(), customerName, problemCategory,
                        customerPhone, saved.getAdvanceAmount() != null ? saved.getAdvanceAmount() : 100,
                        dist, description);
            }
        }
        try {
            saved.setNotifiedMechanicIds(new ObjectMapper().writeValueAsString(notifiedIds));
        } catch (JsonProcessingException ignored) {}
        saved = mechanicRequestRepo.save(saved);
        return saved;
    }

    /**
     * Accept request by mechanic (first accept wins). Others are not notified to avoid rush.
     */
    public Optional<MechanicRequest> acceptByMechanic(Long requestId, Long mechanicId) {
        Optional<MechanicRequest> opt = mechanicRequestRepo.findById(requestId);
        if (opt.isEmpty()) return Optional.empty();
        MechanicRequest req = opt.get();
        if (req.getAcceptedMechanicId() != null) return Optional.empty();
        if (!"PENDING_BROADCAST".equals(req.getStatus())) return Optional.empty();
        if (req.getViewExpiryAt() != null && LocalDateTime.now().isAfter(req.getViewExpiryAt()))
            return Optional.empty();

        Optional<Mechanic> mechanicOpt = mechanicRepo.findById(mechanicId);
        if (mechanicOpt.isEmpty()) return Optional.empty();
        Mechanic mechanic = mechanicOpt.get();
        double mlat = Double.parseDouble(mechanic.getLatitude());
        double mlng = Double.parseDouble(mechanic.getLongitude());
        double clat = Double.parseDouble(req.getLatitude());
        double clng = Double.parseDouble(req.getLongitude());
        double dist = distanceKm(mlat, mlng, clat, clng);
        if (!servesCategory(mechanic, req.getProblemCategory())) return Optional.empty();
        Integer maxR = mechanic.getMaxServingRadiusKm();
        if (maxR != null && dist > maxR) return Optional.empty();

        req.setAcceptedMechanicId(mechanicId);
        req.setMechanicId(mechanicId);
        req.setStatus("PENDING_PAYMENT");
        req.setDistanceKmToCustomer(dist);
        req.setResponseTime(LocalDateTime.now());
        mechanicRequestRepo.save(req);
        return Optional.of(req);
    }

    /**
     * List requests visible to this mechanic (within view window, within his radius, category match).
     */
    public List<MechanicRequest> getNearbyRequestsForMechanic(Long mechanicId, double lat, double lng) {
        Optional<Mechanic> mOpt = mechanicRepo.findById(mechanicId);
        if (mOpt.isEmpty()) return Collections.emptyList();
        Mechanic mechanic = mOpt.get();
        List<MechanicRequest> pending = mechanicRequestRepo.findByStatusAndAcceptedMechanicIdIsNull("PENDING_BROADCAST");
        LocalDateTime now = LocalDateTime.now();
        List<MechanicRequest> result = new ArrayList<>();
        for (MechanicRequest r : pending) {
            if (r.getViewExpiryAt() != null && now.isAfter(r.getViewExpiryAt())) continue;
            if (!servesCategory(mechanic, r.getProblemCategory())) continue;
            try {
                double clat = Double.parseDouble(r.getLatitude());
                double clng = Double.parseDouble(r.getLongitude());
                double dist = distanceKm(lat, lng, clat, clng);
                Integer maxR = mechanic.getMaxServingRadiusKm();
                if (maxR != null && dist > maxR) continue;
                Integer reqRadius = r.getRequestRadiusKm();
                if (reqRadius != null && dist > reqRadius) continue;
                result.add(r);
            } catch (Exception ignore) {}
        }
        result.sort((a, b) -> b.getRequestTime().compareTo(a.getRequestTime()));
        return result;
    }
}

package com.example.demo.controller;

import com.example.demo.model.AppBranding;
import com.example.demo.model.AppVersionConfig;
import com.example.demo.model.AuthBackgroundVideo;
import com.example.demo.model.Banner;
import com.example.demo.model.HomeHeroMedia;
import com.example.demo.model.MarketingPoster;
import com.example.demo.model.SectionPoster;
import com.example.demo.model.Mechanic;
import com.example.demo.model.MechanicHelpMessage;
import com.example.demo.model.UserHelpMessage;
import com.example.demo.model.UserSupportPhotoPermission;
import com.example.demo.model.MechanicRequest;
import com.example.demo.model.Payment;
import com.example.demo.model.Person;
import com.example.demo.repository.AppBrandingRepo;
import com.example.demo.repository.AppVersionConfigRepo;
import com.example.demo.repository.AuthBackgroundVideoRepo;
import com.example.demo.repository.BannerRepo;
import com.example.demo.repository.HomeHeroMediaRepo;
import com.example.demo.repository.MarketingPosterRepo;
import com.example.demo.repository.SectionPosterRepo;
import com.example.demo.repository.MechanicHelpMessageRepo;
import com.example.demo.repository.UserHelpMessageRepo;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.MechanicRequestRepo;
import com.example.demo.repository.MechanicRegistrationRequestRepo;
import com.example.demo.repository.PaymentRepo;
import com.example.demo.repository.PersonRepo;
import com.example.demo.repository.UserAddressRepo;
import com.example.demo.repository.UserSupportPhotoPermissionRepo;
import com.example.demo.service.SupportTypingService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;
import java.util.Comparator;

@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    @Autowired
    private MechanicRepo mechanicRepo;

    @Autowired
    private MechanicRequestRepo mechanicRequestRepo;

    @Autowired
    private MechanicRegistrationRequestRepo mechanicRegistrationRequestRepo;

    @Autowired
    private PaymentRepo paymentRepo;

    @Autowired
    private PersonRepo personRepo;

    @Autowired
    private BannerRepo bannerRepo;

    @Autowired
    private MarketingPosterRepo marketingPosterRepo;

    @Autowired
    private SectionPosterRepo sectionPosterRepo;

    @Autowired
    private AppVersionConfigRepo appVersionConfigRepo;

    @Autowired
    private AuthBackgroundVideoRepo authBackgroundVideoRepo;

    @Autowired
    private HomeHeroMediaRepo homeHeroMediaRepo;

    @Autowired
    private AppBrandingRepo appBrandingRepo;

    @Autowired
    private UserAddressRepo userAddressRepo;

    @Autowired
    private MechanicHelpMessageRepo mechanicHelpMessageRepo;

    @Autowired
    private UserHelpMessageRepo userHelpMessageRepo;

    @Autowired
    private UserSupportPhotoPermissionRepo photoPermissionRepo;

    @Autowired
    private SupportTypingService supportTypingService;

    // Get all mechanics with approval status
    @GetMapping("/mechanics")
    public ResponseEntity<List<Mechanic>> getAllMechanics() {
        try {
            List<Mechanic> mechanics = mechanicRepo.findAll();
            return ResponseEntity.ok(mechanics);
        } catch (Exception e) {
            System.err.println("❌ Error fetching mechanics: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get pending mechanics (awaiting approval)
    @GetMapping("/mechanics/pending")
    public ResponseEntity<List<Mechanic>> getPendingMechanics() {
        try {
            List<Mechanic> allMechanics = mechanicRepo.findAll();
            List<Mechanic> pendingMechanics = allMechanics.stream()
                    .filter(m -> m.getApprovalStatus() == null || 
                            m.getApprovalStatus().equals("PENDING"))
                    .collect(Collectors.toList());
            return ResponseEntity.ok(pendingMechanics);
        } catch (Exception e) {
            System.err.println("❌ Error fetching pending mechanics: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Approve mechanic
    @PutMapping("/mechanics/{id}/approve")
    public ResponseEntity<Mechanic> approveMechanic(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (mechanicOpt.isPresent()) {
                Mechanic mechanic = mechanicOpt.get();
                mechanic.setApprovalStatus("APPROVED");
                Mechanic updated = mechanicRepo.save(mechanic);
                System.out.println("✅ Mechanic " + id + " approved");
                return ResponseEntity.ok(updated);
            } else {
                return ResponseEntity.notFound().build();
            }
        } catch (Exception e) {
            System.err.println("❌ Error approving mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Reject mechanic
    @PutMapping("/mechanics/{id}/reject")
    public ResponseEntity<Mechanic> rejectMechanic(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (mechanicOpt.isPresent()) {
                Mechanic mechanic = mechanicOpt.get();
                mechanic.setApprovalStatus("REJECTED");
                Mechanic updated = mechanicRepo.save(mechanic);
                System.out.println("❌ Mechanic " + id + " rejected");
                return ResponseEntity.ok(updated);
            } else {
                return ResponseEntity.notFound().build();
            }
        } catch (Exception e) {
            System.err.println("❌ Error rejecting mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get all service requests
    @GetMapping("/requests")
    public ResponseEntity<List<MechanicRequest>> getAllRequests() {
        try {
            List<MechanicRequest> requests = mechanicRequestRepo.findAll();
            return ResponseEntity.ok(requests);
        } catch (Exception e) {
            System.err.println("❌ Error fetching requests: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get analytics/dashboard stats (range: 1h, 1d, 1M, 2M, 1y, or lifetime)
    @GetMapping("/analytics")
    public ResponseEntity<Map<String, Object>> getAnalytics(@RequestParam(required = false) String range) {
        try {
            System.out.println("[Admin] /analytics requested, range=" + range);
            Map<String, Object> analytics = new HashMap<>();
            
            // Time window for request-based stats (null = lifetime)
            LocalDateTime since = null;
            if (range != null && !range.isEmpty() && !"lifetime".equalsIgnoreCase(range.trim())) {
                LocalDateTime now = LocalDateTime.now();
                switch (range.trim().toLowerCase()) {
                    case "1h": since = now.minusHours(1); break;
                    case "1d": since = now.minusDays(1); break;
                    case "1m": since = now.minusMonths(1); break;
                    case "2m": since = now.minusMonths(2); break;
                    case "1y": since = now.minusYears(1); break;
                    default: break;
                }
            }
            final LocalDateTime sinceFilter = since; // effectively final for lambda
            
            // Total mechanics (current snapshot – not time-filtered)
            List<Mechanic> allMechanics = mechanicRepo.findAll();
            long totalMechanics = allMechanics.size();
            long approvedMechanics = allMechanics.stream()
                    .filter(m -> m.getApprovalStatus() != null && m.getApprovalStatus().equals("APPROVED"))
                    .count();
            long pendingMechanics = allMechanics.stream()
                    .filter(m -> m.getApprovalStatus() == null || m.getApprovalStatus().equals("PENDING"))
                    .count();
            long rejectedMechanics = allMechanics.stream()
                    .filter(m -> m.getApprovalStatus() != null && m.getApprovalStatus().equals("REJECTED"))
                    .count();
            
            // Service requests stats (time-filtered when range is set)
            List<MechanicRequest> fromDb = mechanicRequestRepo.findAll();
            final List<MechanicRequest> allRequests = (sinceFilter != null)
                    ? fromDb.stream()
                            .filter(r -> r.getRequestTime() != null && !r.getRequestTime().isBefore(sinceFilter))
                            .collect(Collectors.toList())
                    : fromDb;
            long totalRequests = allRequests.size();
            long pendingRequests = allRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("PENDING"))
                    .count();
            long acceptedRequests = allRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("ACCEPTED"))
                    .count();
            long completedRequests = allRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("COMPLETED"))
                    .count();
            long rejectedRequests = allRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("REJECTED"))
                    .count();
            
            // Calculate total revenue from completed requests (in range)
            double totalRevenue = allRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("COMPLETED"))
                    .mapToDouble(MechanicRequest::getAmount)
                    .sum();
            
            // Payment stats (defensive: payments table may not exist yet)
            long totalPayments = 0;
            long successfulPayments = 0;
            double paymentRevenue = 0.0;
            try {
                List<Payment> allPayments = paymentRepo.findAll();
                totalPayments = allPayments.size();
                successfulPayments = allPayments.stream()
                        .filter(p -> p.getStatus() != null && p.getStatus().equals("SUCCESS"))
                        .count();
                paymentRevenue = allPayments.stream()
                        .filter(p -> p.getStatus() != null && p.getStatus().equals("SUCCESS"))
                        .mapToDouble(p -> p.getAmount() != null ? p.getAmount() : 0.0)
                        .sum();
            } catch (Exception pe) {
                System.err.println("⚠️ Payment stats skipped: " + pe.getMessage());
            }
            
            // Active mechanics (Available status)
            long activeMechanics = allMechanics.stream()
                    .filter(m -> m.getStatus() != null && m.getStatus().equals("Available") &&
                            (m.getApprovalStatus() == null || m.getApprovalStatus().equals("APPROVED")))
                    .count();
            
            // Online vs Offline
            long onlineMechanics = allMechanics.stream()
                    .filter(m -> m.getApprovalStatus() != null && m.getApprovalStatus().equals("APPROVED") &&
                            !m.isBlocked() && !m.isSuspended())
                    .filter(Mechanic::isOnline)
                    .count();
            long offlineMechanics = allMechanics.stream()
                    .filter(m -> m.getApprovalStatus() != null && m.getApprovalStatus().equals("APPROVED") &&
                            !m.isBlocked() && !m.isSuspended())
                    .filter(m -> !m.isOnline())
                    .count();
            
            // Mechanics by city
            Map<String, Map<String, Long>> mechanicsByCity = new LinkedHashMap<>();
            for (Mechanic m : allMechanics) {
                if (m.getApprovalStatus() == null || !m.getApprovalStatus().equals("APPROVED")) continue;
                String city = (m.getShopCity() != null && !m.getShopCity().isEmpty()) ? m.getShopCity() : "Unknown";
                mechanicsByCity.putIfAbsent(city, new HashMap<>());
                Map<String, Long> cityStats = mechanicsByCity.get(city);
                cityStats.putIfAbsent("total", 0L);
                cityStats.putIfAbsent("online", 0L);
                cityStats.putIfAbsent("offline", 0L);
                cityStats.put("total", cityStats.get("total") + 1);
                if (m.isOnline()) cityStats.put("online", cityStats.get("online") + 1);
                else cityStats.put("offline", cityStats.get("offline") + 1);
            }
            
            // Requests by service type
            Map<String, Long> requestsByServiceType = allRequests.stream()
                    .collect(Collectors.groupingBy(
                            r -> r.getServiceType() != null ? r.getServiceType() : "Unknown",
                            Collectors.counting()
                    ));
            
            // Recent requests (last 7 days within current range)
            LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);
            long recentRequests = allRequests.stream()
                    .filter(r -> r.getRequestTime() != null && r.getRequestTime().isAfter(sevenDaysAgo))
                    .count();
            
            Map<String, Object> mechanicsMap = new HashMap<>();
            mechanicsMap.put("total", totalMechanics);
            mechanicsMap.put("approved", approvedMechanics);
            mechanicsMap.put("pending", pendingMechanics);
            mechanicsMap.put("rejected", rejectedMechanics);
            mechanicsMap.put("active", activeMechanics);
            mechanicsMap.put("online", onlineMechanics);
            mechanicsMap.put("offline", offlineMechanics);
            analytics.put("mechanics", mechanicsMap);
            analytics.put("mechanicsByCity", mechanicsByCity);
            // Pending mechanic registration applications (new signups from app - table: requests)
            long pendingRegistrationRequests = mechanicRegistrationRequestRepo.findAll().stream()
                    .filter(r -> "PENDING".equalsIgnoreCase(r.getApprovalStatus()))
                    .count();
            analytics.put("pendingRegistrationRequests", pendingRegistrationRequests);
            
            analytics.put("requests", Map.of(
                    "total", totalRequests,
                    "pending", pendingRequests,
                    "accepted", acceptedRequests,
                    "completed", completedRequests,
                    "rejected", rejectedRequests,
                    "recent7Days", recentRequests
            ));
            
            analytics.put("revenue", Map.of(
                    "totalFromRequests", totalRevenue,
                    "totalFromPayments", paymentRevenue,
                    "total", totalRevenue + paymentRevenue
            ));
            
            analytics.put("payments", Map.of(
                    "total", totalPayments,
                    "successful", successfulPayments
            ));
            
            analytics.put("requestsByServiceType", requestsByServiceType);

            // Peak hour (hour of day with most requests)
            Map<Integer, Long> requestsByHour = allRequests.stream()
                    .filter(r -> r.getRequestTime() != null)
                    .collect(Collectors.groupingBy(r -> r.getRequestTime().getHour(), Collectors.counting()));
            int peakHour = requestsByHour.entrySet().stream()
                    .max(Map.Entry.comparingByValue())
                    .map(Map.Entry::getKey).orElse(0);
            analytics.put("peakHour", peakHour);

            // Live users (users active in last 5 minutes)
            LocalDateTime fiveMinsAgo = LocalDateTime.now().minusMinutes(5);
            List<Person> allUsers = personRepo.findAll().stream()
                    .filter(u -> u.getEmail() != null && !u.getEmail().isEmpty())
                    .collect(Collectors.toList());
            long liveUsers = allUsers.stream()
                    .filter(u -> u.getLastActiveAt() != null && u.getLastActiveAt().isAfter(fiveMinsAgo))
                    .count();
            analytics.put("liveUsers", liveUsers);

            // Total app usage hours (sum of totalUsageMinutes across users)
            long totalUsageMinutes = allUsers.stream()
                    .mapToLong(u -> u.getTotalUsageMinutes() != null ? u.getTotalUsageMinutes() : 0L)
                    .sum();
            analytics.put("totalUsageHours", Math.round(totalUsageMinutes / 60.0 * 100.0) / 100.0);

            // Users by city and state (from UserAddress - distinct users per location)
            List<com.example.demo.model.UserAddress> allAddresses = userAddressRepo.findAll();
            Map<String, Long> usersByCity = allAddresses.stream()
                    .filter(a -> a.getCity() != null && !a.getCity().isEmpty())
                    .collect(Collectors.groupingBy(com.example.demo.model.UserAddress::getCity,
                            Collectors.mapping(com.example.demo.model.UserAddress::getUserEmail,
                                    Collectors.collectingAndThen(Collectors.toSet(), s -> (long) s.size()))));
            Map<String, Long> usersByState = allAddresses.stream()
                    .filter(a -> a.getState() != null && !a.getState().isEmpty())
                    .collect(Collectors.groupingBy(com.example.demo.model.UserAddress::getState,
                            Collectors.mapping(com.example.demo.model.UserAddress::getUserEmail,
                                    Collectors.collectingAndThen(Collectors.toSet(), s -> (long) s.size()))));
            analytics.put("usersByCity", usersByCity);
            analytics.put("usersByState", usersByState);
            
            return ResponseEntity.ok(analytics);
        } catch (Exception e) {
            System.err.println("❌ Error fetching analytics: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get mechanic performance (response rate, completion rate)
    @GetMapping("/mechanics/{id}/performance")
    public ResponseEntity<Map<String, Object>> getMechanicPerformance(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            List<MechanicRequest> mechanicRequests = mechanicRequestRepo.findByMechanicIdOrderByRequestTimeDesc(id);
            
            long totalRequests = mechanicRequests.size();
            long acceptedRequests = mechanicRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("ACCEPTED"))
                    .count();
            long completedRequests = mechanicRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("COMPLETED"))
                    .count();
            long rejectedRequests = mechanicRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("REJECTED"))
                    .count();
            
            double responseRate = totalRequests > 0 ? 
                    ((double)(acceptedRequests + rejectedRequests) / totalRequests) * 100 : 0;
            double completionRate = totalRequests > 0 ? 
                    ((double)completedRequests / totalRequests) * 100 : 0;
            
            double totalEarnings = mechanicRequests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("COMPLETED"))
                    .mapToDouble(MechanicRequest::getAmount)
                    .sum();
            
            Map<String, Object> performance = new HashMap<>();
            performance.put("totalRequests", totalRequests);
            performance.put("acceptedRequests", acceptedRequests);
            performance.put("completedRequests", completedRequests);
            performance.put("rejectedRequests", rejectedRequests);
            performance.put("responseRate", Math.round(responseRate * 100.0) / 100.0);
            performance.put("completionRate", Math.round(completionRate * 100.0) / 100.0);
            performance.put("totalEarnings", totalEarnings);
            
            return ResponseEntity.ok(performance);
        } catch (Exception e) {
            System.err.println("❌ Error fetching mechanic performance: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get service request tracking (which mechanics are responding to requests)
    @GetMapping("/requests/tracking")
    public ResponseEntity<Map<String, Object>> getRequestTracking() {
        try {
            List<MechanicRequest> allRequests = mechanicRequestRepo.findAll();
            
            // Group requests by mechanic
            Map<Long, List<MechanicRequest>> requestsByMechanic = allRequests.stream()
                    .collect(Collectors.groupingBy(MechanicRequest::getMechanicId));
            
            List<Map<String, Object>> mechanicTracking = new ArrayList<>();
            
            for (Map.Entry<Long, List<MechanicRequest>> entry : requestsByMechanic.entrySet()) {
                Long mechanicId = entry.getKey();
                List<MechanicRequest> requests = entry.getValue();
                
                Optional<Mechanic> mechanicOpt = mechanicRepo.findById(mechanicId);
                String mechanicName = mechanicOpt.isPresent() ? mechanicOpt.get().getName() : "Unknown";
                
                long total = requests.size();
                long accepted = requests.stream()
                        .filter(r -> r.getStatus() != null && r.getStatus().equals("ACCEPTED"))
                        .count();
                long completed = requests.stream()
                        .filter(r -> r.getStatus() != null && r.getStatus().equals("COMPLETED"))
                        .count();
                long pending = requests.stream()
                        .filter(r -> r.getStatus() != null && r.getStatus().equals("PENDING"))
                        .count();
                
                // Calculate average response time (for accepted requests)
                double avgResponseTime = requests.stream()
                        .filter(r -> r.getStatus() != null && r.getStatus().equals("ACCEPTED") && 
                                r.getRequestTime() != null && r.getResponseTime() != null)
                        .mapToLong(r -> {
                            long seconds = java.time.Duration.between(r.getRequestTime(), r.getResponseTime()).getSeconds();
                            return seconds;
                        })
                        .average()
                        .orElse(0.0);
                
                Map<String, Object> tracking = new HashMap<>();
                tracking.put("mechanicId", mechanicId);
                tracking.put("mechanicName", mechanicName);
                tracking.put("totalRequests", total);
                tracking.put("accepted", accepted);
                tracking.put("completed", completed);
                tracking.put("pending", pending);
                tracking.put("avgResponseTimeMinutes", Math.round(avgResponseTime / 60.0 * 100.0) / 100.0);
                
                mechanicTracking.add(tracking);
            }
            
            Map<String, Object> result = new HashMap<>();
            result.put("mechanicTracking", mechanicTracking);
            result.put("totalMechanicsWithRequests", requestsByMechanic.size());
            
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("❌ Error fetching request tracking: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ========== USER MANAGEMENT ==========
    
    // Get all users
    @GetMapping("/users")
    public ResponseEntity<List<Person>> getAllUsers() {
        try {
            List<Person> users = personRepo.findAll();
            // Filter to only users (those with email, not EV providers)
            users = users.stream()
                    .filter(u -> u.getEmail() != null && !u.getEmail().isEmpty())
                    .collect(Collectors.toList());
            return ResponseEntity.ok(users);
        } catch (Exception e) {
            System.err.println("❌ Error fetching users: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Search users by phone or email
    @GetMapping("/users/search")
    public ResponseEntity<List<Person>> searchUsers(@RequestParam String query) {
        try {
            List<Person> allUsers = personRepo.findAll();
            List<Person> results = allUsers.stream()
                    .filter(u -> {
                        String email = u.getEmail() != null ? u.getEmail().toLowerCase() : "";
                        String phone = u.getPhone() != null ? u.getPhone().toLowerCase() : "";
                        String name = u.getName() != null ? u.getName().toLowerCase() : "";
                        String searchQuery = query.toLowerCase();
                        return email.contains(searchQuery) || phone.contains(searchQuery) || name.contains(searchQuery);
                    })
                    .filter(u -> u.getEmail() != null && !u.getEmail().isEmpty()) // Only users, not EV providers
                    .collect(Collectors.toList());
            return ResponseEntity.ok(results);
        } catch (Exception e) {
            System.err.println("❌ Error searching users: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get user bookings/history by email
    @GetMapping("/users/{email}/bookings")
    public ResponseEntity<List<MechanicRequest>> getUserBookings(@PathVariable String email) {
        try {
            List<MechanicRequest> bookings = mechanicRequestRepo.findByCustomerEmailOrderByRequestTimeDesc(email);
            return ResponseEntity.ok(bookings);
        } catch (Exception e) {
            System.err.println("❌ Error fetching user bookings: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Update user (admin edit)
    @PutMapping("/users/{id}")
    public ResponseEntity<Person> updateUser(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        try {
            Optional<Person> opt = personRepo.findById(id);
            if (opt.isEmpty()) return ResponseEntity.notFound().build();
            Person p = opt.get();
            if (body.get("name") != null) p.setName(body.get("name").toString());
            if (body.get("email") != null) p.setEmail(body.get("email").toString());
            if (body.get("phone") != null) p.setPhone(body.get("phone").toString());
            if (body.get("address") != null) p.setAddress(body.get("address").toString());
            if (body.get("dateOfBirth") != null) p.setDateOfBirth(body.get("dateOfBirth").toString());
            if (body.get("gender") != null) p.setGender(body.get("gender").toString());
            if (body.get("profilePhotoUrl") != null) p.setProfilePhotoUrl(body.get("profilePhotoUrl").toString());
            return ResponseEntity.ok(personRepo.save(p));
        } catch (Exception e) {
            System.err.println("❌ Error updating user: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Delete user (admin)
    @DeleteMapping("/users/{id}")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        try {
            if (!personRepo.existsById(id)) return ResponseEntity.notFound().build();
            personRepo.deleteById(id);
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            System.err.println("❌ Error deleting user: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ========== MECHANIC MANAGEMENT ENHANCEMENTS ==========
    
    // Get mechanic profile details
    @GetMapping("/mechanics/{id}/profile")
    public ResponseEntity<Map<String, Object>> getMechanicProfile(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            List<MechanicRequest> requests = mechanicRequestRepo.findByMechanicIdOrderByRequestTimeDesc(id);
            
            Map<String, Object> profile = new HashMap<>();
            profile.put("mechanic", mechanic);
            profile.put("totalRequests", requests.size());
            profile.put("completedRequests", requests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("COMPLETED"))
                    .count());
            profile.put("pendingRequests", requests.stream()
                    .filter(r -> r.getStatus() != null && r.getStatus().equals("PENDING"))
                    .count());
            profile.put("documentUrls", mechanic.getDocumentUrls());
            
            return ResponseEntity.ok(profile);
        } catch (Exception e) {
            System.err.println("❌ Error fetching mechanic profile: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Update mechanic documents
    @PutMapping("/mechanics/{id}/documents")
    public ResponseEntity<Mechanic> updateMechanicDocuments(@PathVariable Long id, @RequestBody Map<String, String> request) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            String documentUrls = request.get("documentUrls");
            if (documentUrls != null) {
                mechanic.setDocumentUrls(documentUrls);
            }
            
            Mechanic updated = mechanicRepo.save(mechanic);
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            System.err.println("❌ Error updating mechanic documents: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Update mechanic (admin edit – all fields optional)
    @PutMapping("/mechanics/{id}")
    public ResponseEntity<Mechanic> updateMechanic(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        try {
            Optional<Mechanic> opt = mechanicRepo.findById(id);
            if (opt.isEmpty()) return ResponseEntity.notFound().build();
            Mechanic m = opt.get();
            if (body.get("name") != null) m.setName(body.get("name").toString());
            if (body.get("email") != null) m.setEmail(body.get("email").toString());
            if (body.get("phone") != null) m.setPhone(body.get("phone").toString());
            if (body.get("specialty") != null) m.setSpecialty(body.get("specialty").toString());
            if (body.get("experience") != null) m.setExperience(body.get("experience").toString());
            if (body.containsKey("nightTimeAvailable")) m.setNightTimeAvailable(Boolean.TRUE.equals(body.get("nightTimeAvailable")));
            if (body.get("latitude") != null) m.setLatitude(body.get("latitude").toString());
            if (body.get("longitude") != null) m.setLongitude(body.get("longitude").toString());
            if (body.get("status") != null) m.setStatus(body.get("status").toString());
            if (body.get("approvalStatus") != null) m.setApprovalStatus(body.get("approvalStatus").toString());
            if (body.get("profilePhotoUrl") != null) m.setProfilePhotoUrl(body.get("profilePhotoUrl").toString());
            if (body.get("categoryIconUrl") != null) m.setCategoryIconUrl(body.get("categoryIconUrl").toString());
            if (body.get("shopName") != null) m.setShopName(body.get("shopName").toString());
            if (body.get("shopAddress") != null) m.setShopAddress(body.get("shopAddress").toString());
            if (body.get("shopCity") != null) m.setShopCity(body.get("shopCity").toString());
            if (body.get("shopState") != null) m.setShopState(body.get("shopState").toString());
            if (body.get("shopPincode") != null) m.setShopPincode(body.get("shopPincode").toString());
            if (body.get("shopCountry") != null) m.setShopCountry(body.get("shopCountry").toString());
            if (body.get("services") != null) m.setServices(body.get("services").toString());
            if (body.get("openingTime") != null) m.setOpeningTime(body.get("openingTime").toString());
            if (body.get("closingTime") != null) m.setClosingTime(body.get("closingTime").toString());
            if (body.get("workingDays") != null) m.setWorkingDays(body.get("workingDays").toString());
            if (body.get("serviceCategories") != null) m.setServiceCategories(body.get("serviceCategories").toString());
            if (body.get("vehicleTypes") != null) m.setVehicleTypes(body.get("vehicleTypes").toString());
            if (body.get("documentUrls") != null) m.setDocumentUrls(body.get("documentUrls").toString());
            if (body.get("towingVehiclePhotoUrl") != null) m.setTowingVehiclePhotoUrl(body.get("towingVehiclePhotoUrl").toString());
            if (body.containsKey("maxServingRadiusKm") && body.get("maxServingRadiusKm") != null)
                m.setMaxServingRadiusKm(((Number) body.get("maxServingRadiusKm")).intValue());
            if (body.containsKey("perKmCharge") && body.get("perKmCharge") != null)
                m.setPerKmCharge(((Number) body.get("perKmCharge")).doubleValue());
            return ResponseEntity.ok(mechanicRepo.save(m));
        } catch (Exception e) {
            System.err.println("❌ Error updating mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Delete mechanic (admin)
    @DeleteMapping("/mechanics/{id}")
    public ResponseEntity<Void> deleteMechanic(@PathVariable Long id) {
        try {
            if (!mechanicRepo.existsById(id)) return ResponseEntity.notFound().build();
            mechanicRepo.deleteById(id);
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            System.err.println("❌ Error deleting mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ========== BANNERS / CAROUSEL ==========
    @GetMapping("/banners")
    public ResponseEntity<List<Banner>> getAllBanners() {
        try {
            return ResponseEntity.ok(bannerRepo.findAllByOrderBySortOrderAsc());
        } catch (Exception e) {
            System.err.println("❌ Error fetching banners: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/banners")
    public ResponseEntity<Banner> createBanner(@RequestBody Map<String, Object> body) {
        try {
            Banner b = new Banner();
            b.setImageUrl((String) body.get("imageUrl"));
            b.setTitle((String) body.get("title"));
            b.setSubtitle((String) body.get("subtitle"));
            b.setSortOrder(body.containsKey("sortOrder") ? ((Number) body.get("sortOrder")).intValue() : 0);
            b.setActive(body.get("active") != Boolean.FALSE);
            if (body.get("targetType") != null) b.setTargetType(body.get("targetType").toString());
            return ResponseEntity.ok(bannerRepo.save(b));
        } catch (Exception e) {
            System.err.println("❌ Error creating banner: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PutMapping("/banners/{id}")
    public ResponseEntity<Banner> updateBanner(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        try {
            Optional<Banner> opt = bannerRepo.findById(id);
            if (opt.isEmpty()) return ResponseEntity.notFound().build();
            Banner b = opt.get();
            if (body.containsKey("imageUrl")) b.setImageUrl((String) body.get("imageUrl"));
            if (body.containsKey("title")) b.setTitle((String) body.get("title"));
            if (body.containsKey("subtitle")) b.setSubtitle((String) body.get("subtitle"));
            if (body.containsKey("sortOrder")) b.setSortOrder(((Number) body.get("sortOrder")).intValue());
            if (body.containsKey("active")) b.setActive((Boolean) body.get("active"));
            if (body.containsKey("targetType")) b.setTargetType(body.get("targetType").toString());
            return ResponseEntity.ok(bannerRepo.save(b));
        } catch (Exception e) {
            System.err.println("❌ Error updating banner: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @DeleteMapping("/banners/{id}")
    public ResponseEntity<Void> deleteBanner(@PathVariable Long id) {
        try {
            if (bannerRepo.existsById(id)) {
                bannerRepo.deleteById(id);
                return ResponseEntity.ok().build();
            }
            return ResponseEntity.notFound().build();
        } catch (Exception e) {
            System.err.println("❌ Error deleting banner: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Block mechanic
    @PutMapping("/mechanics/{id}/block")
    public ResponseEntity<Mechanic> blockMechanic(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            mechanic.setBlocked(true);
            Mechanic updated = mechanicRepo.save(mechanic);
            System.out.println("🚫 Mechanic " + id + " blocked");
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            System.err.println("❌ Error blocking mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Unblock mechanic
    @PutMapping("/mechanics/{id}/unblock")
    public ResponseEntity<Mechanic> unblockMechanic(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            mechanic.setBlocked(false);
            Mechanic updated = mechanicRepo.save(mechanic);
            System.out.println("✅ Mechanic " + id + " unblocked");
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            System.err.println("❌ Error unblocking mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Suspend mechanic
    @PutMapping("/mechanics/{id}/suspend")
    public ResponseEntity<Mechanic> suspendMechanic(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            mechanic.setSuspended(true);
            Mechanic updated = mechanicRepo.save(mechanic);
            System.out.println("⏸️ Mechanic " + id + " suspended");
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            System.err.println("❌ Error suspending mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Unsuspend mechanic
    @PutMapping("/mechanics/{id}/unsuspend")
    public ResponseEntity<Mechanic> unsuspendMechanic(@PathVariable Long id) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            mechanic.setSuspended(false);
            Mechanic updated = mechanicRepo.save(mechanic);
            System.out.println("▶️ Mechanic " + id + " unsuspended");
            return ResponseEntity.ok(updated);
        } catch (Exception e) {
            System.err.println("❌ Error unsuspending mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Manually create mechanic (admin) – for partner mechanics who login
    @PostMapping("/mechanics/create")
    public ResponseEntity<Mechanic> createMechanic(@RequestBody Mechanic mechanic) {
        try {
            // Set defaults for admin-created mechanics
            if (mechanic.getApprovalStatus() == null || mechanic.getApprovalStatus().isEmpty()) {
                mechanic.setApprovalStatus("APPROVED"); // Auto-approve admin-created mechanics
            }
            mechanic.setBlocked(false);
            mechanic.setSuspended(false);
            mechanic.setOnline(false);
            
            Mechanic saved = mechanicRepo.save(mechanic);
            System.out.println("✅ Admin created mechanic: " + saved.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(saved);
        } catch (Exception e) {
            System.err.println("❌ Error creating mechanic: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ========== LIVE TRACKING ==========
    
    // Get all mechanics with live locations (for Google Maps)
    @GetMapping("/mechanics/locations")
    public ResponseEntity<List<Map<String, Object>>> getMechanicLocations(@RequestParam(required = false) String filter) {
        try {
            List<Mechanic> mechanics = mechanicRepo.findAll();
            List<Map<String, Object>> locations = new ArrayList<>();
            
            for (Mechanic mechanic : mechanics) {
                // Filter by online/offline if requested
                if (filter != null) {
                    if (filter.equals("online") && !mechanic.isOnline()) continue;
                    if (filter.equals("offline") && mechanic.isOnline()) continue;
                }
                
                // Only show approved, non-blocked, non-suspended mechanics
                if (mechanic.getApprovalStatus() != null && mechanic.getApprovalStatus().equals("APPROVED") &&
                    !mechanic.isBlocked() && !mechanic.isSuspended()) {
                    
                    Map<String, Object> location = new HashMap<>();
                    location.put("id", mechanic.getId());
                    location.put("name", mechanic.getName());
                    location.put("phone", mechanic.getPhone());
                    location.put("specialty", mechanic.getSpecialty());
                    location.put("status", mechanic.getStatus());
                    location.put("isOnline", mechanic.isOnline());
                    
                    // Use current location if available, otherwise use registration location
                    if (mechanic.getCurrentLatitude() != null && mechanic.getCurrentLongitude() != null) {
                        location.put("latitude", mechanic.getCurrentLatitude());
                        location.put("longitude", mechanic.getCurrentLongitude());
                        location.put("lastUpdate", mechanic.getLastLocationUpdate());
                    } else {
                        location.put("latitude", mechanic.getLatitude());
                        location.put("longitude", mechanic.getLongitude());
                        location.put("lastUpdate", null);
                    }
                    
                    locations.add(location);
                }
            }
            
            return ResponseEntity.ok(locations);
        } catch (Exception e) {
            System.err.println("❌ Error fetching mechanic locations: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Update mechanic location (called by mobile app)
    @PutMapping("/mechanics/{id}/location")
    public ResponseEntity<Mechanic> updateMechanicLocation(
            @PathVariable Long id,
            @RequestBody Map<String, String> request) {
        try {
            Optional<Mechanic> mechanicOpt = mechanicRepo.findById(id);
            if (!mechanicOpt.isPresent()) {
                return ResponseEntity.notFound().build();
            }
            
            Mechanic mechanic = mechanicOpt.get();
            String lat = request.get("latitude");
            String lng = request.get("longitude");
            
            if (lat != null && lng != null) {
                mechanic.setCurrentLatitude(lat);
                mechanic.setCurrentLongitude(lng);
                mechanic.setLastLocationUpdate(LocalDateTime.now());
                mechanic.setOnline(true);
                
                Mechanic updated = mechanicRepo.save(mechanic);
                return ResponseEntity.ok(updated);
            } else {
                return ResponseEntity.badRequest().build();
            }
        } catch (Exception e) {
            System.err.println("❌ Error updating mechanic location: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // Get active jobs (requests with ACCEPTED status)
    @GetMapping("/jobs/active")
    public ResponseEntity<List<Map<String, Object>>> getActiveJobs() {
        try {
            List<MechanicRequest> activeRequests = mechanicRequestRepo.findByStatus("ACCEPTED");
            List<Map<String, Object>> activeJobs = new ArrayList<>();
            
            for (MechanicRequest request : activeRequests) {
                Optional<Mechanic> mechanicOpt = mechanicRepo.findById(request.getMechanicId());
                String mechanicName = mechanicOpt.isPresent() ? mechanicOpt.get().getName() : "Unknown";
                
                Map<String, Object> job = new HashMap<>();
                job.put("requestId", request.getId());
                job.put("customerName", request.getCustomerName());
                job.put("customerPhone", request.getCustomerPhone());
                job.put("serviceType", request.getServiceType());
                job.put("mechanicId", request.getMechanicId());
                job.put("mechanicName", mechanicName);
                job.put("requestTime", request.getRequestTime());
                job.put("responseTime", request.getResponseTime());
                job.put("amount", request.getAmount());
                
                // Get mechanic location if available
                if (mechanicOpt.isPresent()) {
                    Mechanic mechanic = mechanicOpt.get();
                    if (mechanic.getCurrentLatitude() != null && mechanic.getCurrentLongitude() != null) {
                        job.put("mechanicLatitude", mechanic.getCurrentLatitude());
                        job.put("mechanicLongitude", mechanic.getCurrentLongitude());
                    } else {
                        job.put("mechanicLatitude", mechanic.getLatitude());
                        job.put("mechanicLongitude", mechanic.getLongitude());
                    }
                }
                
                job.put("serviceLatitude", request.getLatitude());
                job.put("serviceLongitude", request.getLongitude());
                
                activeJobs.add(job);
            }
            
            return ResponseEntity.ok(activeJobs);
        } catch (Exception e) {
            System.err.println("❌ Error fetching active jobs: " + e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    // ---------- Mechanic Help / Support Chat (admin sees messages, can reply) ----------
    @GetMapping("/help/messages")
    public ResponseEntity<?> getHelpMessages(@RequestParam(required = false) String email) {
        try {
            if (email != null && !email.isBlank()) {
                List<MechanicHelpMessage> messages = mechanicHelpMessageRepo.findByMechanicEmailIgnoreCaseOrderByCreatedAtAsc(email.trim());
                return ResponseEntity.ok(messages);
            }
            List<MechanicHelpMessage> all = mechanicHelpMessageRepo.findAll();
            all.sort((a, b) -> (b.getCreatedAt() != null && a.getCreatedAt() != null)
                    ? b.getCreatedAt().compareTo(a.getCreatedAt()) : 0);
            Set<String> emails = new LinkedHashSet<>();
            for (MechanicHelpMessage m : all) {
                if (m.getMechanicEmail() != null) emails.add(m.getMechanicEmail());
            }
            return ResponseEntity.ok(new ArrayList<>(emails));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @PostMapping("/help/reply")
    public ResponseEntity<MechanicHelpMessage> replyToHelp(@RequestBody Map<String, String> body) {
        String mechanicEmail = body != null ? body.get("mechanicEmail") : null;
        String message = body != null ? body.get("message") : null;
        if (mechanicEmail == null || mechanicEmail.isBlank() || message == null || message.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        MechanicHelpMessage msg = new MechanicHelpMessage();
        msg.setMechanicEmail(mechanicEmail.trim());
        msg.setMessage(message.trim());
        msg.setSender("ADMIN");
        msg.setCreatedAt(LocalDateTime.now());
        MechanicHelpMessage saved = mechanicHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    @PostMapping("/help/typing")
    public ResponseEntity<Void> setMechanicHelpAdminTyping(@RequestBody Map<String, Object> body) {
        String mechanicEmail = body != null && body.get("mechanicEmail") != null ? body.get("mechanicEmail").toString().trim() : null;
        Boolean typing = body != null && body.get("isTyping") != null ? Boolean.TRUE.equals(body.get("isTyping")) : false;
        if (mechanicEmail != null && !mechanicEmail.isBlank()) supportTypingService.setMechanicAdminTyping(mechanicEmail, typing);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/help/typing")
    public ResponseEntity<Map<String, Boolean>> getMechanicTyping(@RequestParam String email) {
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        return ResponseEntity.ok(Map.of("mechanicTyping", supportTypingService.isMechanicTyping(email.trim())));
    }

    // ---------- User / Customer Support (admin sees user messages, can reply) ----------
    @GetMapping("/user-support/customer-details")
    public ResponseEntity<Map<String, Object>> getCustomerDetails(@RequestParam String email) {
        try {
            Optional<Person> userOpt = personRepo.findByEmail(email.trim());
            List<MechanicRequest> bookings = mechanicRequestRepo.findByCustomerEmailOrderByRequestTimeDesc(email.trim());
            Map<String, Object> out = new HashMap<>();
            out.put("user", userOpt.orElse(null));
            out.put("bookings", bookings);
            return ResponseEntity.ok(out);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/user-support/photo-permission")
    public ResponseEntity<Map<String, Object>> getUserPhotoPermission(@RequestParam String email) {
        Optional<UserSupportPhotoPermission> p = photoPermissionRepo.findByUserEmailIgnoreCase(email.trim());
        boolean allowed = p.isPresent() && p.get().isAllowed();
        return ResponseEntity.ok(Map.of("allowed", allowed));
    }

    @PostMapping("/user-support/approve-photo-permission")
    public ResponseEntity<Map<String, Object>> approvePhotoPermission(@RequestBody Map<String, String> body) {
        String userEmail = body != null ? body.get("userEmail") : null;
        if (userEmail == null || userEmail.isBlank()) return ResponseEntity.badRequest().build();
        Optional<UserSupportPhotoPermission> existing = photoPermissionRepo.findByUserEmailIgnoreCase(userEmail.trim());
        UserSupportPhotoPermission perm = existing.orElse(new UserSupportPhotoPermission());
        perm.setUserEmail(userEmail.trim());
        perm.setAllowed(true);
        perm.setGrantedAt(LocalDateTime.now());
        photoPermissionRepo.save(perm);
        UserHelpMessage sysMsg = new UserHelpMessage();
        sysMsg.setUserEmail(userEmail.trim());
        sysMsg.setMessage("Customer care approved photo sharing. You can now send photos.");
        sysMsg.setMessageType("PHOTO_PERMISSION_GRANTED");
        sysMsg.setSender("ADMIN");
        sysMsg.setCreatedAt(LocalDateTime.now());
        userHelpMessageRepo.save(sysMsg);
        return ResponseEntity.ok(Map.of("success", true));
    }

    @PostMapping("/user-support/typing")
    public ResponseEntity<Void> setAdminTyping(@RequestBody Map<String, Object> body) {
        String userEmail = body != null && body.get("userEmail") != null ? body.get("userEmail").toString().trim() : null;
        Boolean typing = body != null && body.get("isTyping") != null ? Boolean.TRUE.equals(body.get("isTyping")) : false;
        if (userEmail != null && !userEmail.isBlank()) supportTypingService.setAdminTyping(userEmail, typing);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/user-support/typing")
    public ResponseEntity<Map<String, Boolean>> getUserTyping(@RequestParam String email) {
        if (email == null || email.isBlank()) return ResponseEntity.badRequest().build();
        return ResponseEntity.ok(Map.of("userTyping", supportTypingService.isUserTyping(email.trim())));
    }

    /** Thread list with status (open/closed) for professional dashboard. */
    @GetMapping("/user-support/threads")
    public ResponseEntity<List<Map<String, Object>>> getUserSupportThreads() {
        try {
            List<UserHelpMessage> all = userHelpMessageRepo.findAll();
            all.sort((a, b) -> (b.getCreatedAt() != null && a.getCreatedAt() != null)
                    ? b.getCreatedAt().compareTo(a.getCreatedAt()) : 0);
            Map<String, UserHelpMessage> lastByEmail = new LinkedHashMap<>();
            for (UserHelpMessage m : all) {
                String e = m.getUserEmail();
                if (e != null && !e.isBlank() && !lastByEmail.containsKey(e)) lastByEmail.put(e, m);
            }
            List<Map<String, Object>> threads = new ArrayList<>();
            for (Map.Entry<String, UserHelpMessage> entry : lastByEmail.entrySet()) {
                UserHelpMessage last = entry.getValue();
                boolean closed = "CONVERSATION_ENDED".equals(last.getMessageType());
                Map<String, Object> t = new HashMap<>();
                t.put("email", entry.getKey());
                t.put("closed", closed);
                t.put("lastMessageAt", last.getCreatedAt() != null ? last.getCreatedAt().toString() : null);
                threads.add(t);
            }
            return ResponseEntity.ok(threads);
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    @GetMapping("/user-support/messages")
    public ResponseEntity<?> getUserSupportMessages(@RequestParam(required = false) String email) {
        try {
            if (email != null && !email.isBlank()) {
                List<UserHelpMessage> messages = userHelpMessageRepo.findByUserEmailIgnoreCaseOrderByCreatedAtAsc(email.trim());
                return ResponseEntity.ok(messages);
            }
            List<UserHelpMessage> all = userHelpMessageRepo.findAll();
            all.sort((a, b) -> (b.getCreatedAt() != null && a.getCreatedAt() != null)
                    ? b.getCreatedAt().compareTo(a.getCreatedAt()) : 0);
            Set<String> emails = new LinkedHashSet<>();
            for (UserHelpMessage m : all) {
                if (m.getUserEmail() != null) emails.add(m.getUserEmail());
            }
            return ResponseEntity.ok(new ArrayList<>(emails));
        } catch (Exception e) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /** Admin joins the support chat; inserts "Admin has joined and ready to text" so the app can stop showing "Waiting for admin". */
    @PostMapping("/user-support/join")
    public ResponseEntity<UserHelpMessage> joinUserSupport(@RequestBody Map<String, String> body) {
        String userEmail = body != null && body.get("userEmail") != null ? body.get("userEmail").toString().trim() : null;
        if (userEmail == null || userEmail.isBlank()) return ResponseEntity.badRequest().build();
        UserHelpMessage msg = new UserHelpMessage();
        msg.setUserEmail(userEmail);
        msg.setMessage("Admin has joined and ready to text.");
        msg.setMessageType("ADMIN_JOINED");
        msg.setSender("ADMIN");
        msg.setCreatedAt(LocalDateTime.now());
        UserHelpMessage saved = userHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    /** End the conversation: inserts thank-you message and marks thread as closed for "recent solved". */
    @PostMapping("/user-support/end-conversation")
    public ResponseEntity<UserHelpMessage> endUserSupportConversation(@RequestBody Map<String, String> body) {
        String userEmail = body != null && body.get("userEmail") != null ? body.get("userEmail").toString().trim() : null;
        if (userEmail == null || userEmail.isBlank()) return ResponseEntity.badRequest().build();
        UserHelpMessage msg = new UserHelpMessage();
        msg.setUserEmail(userEmail);
        msg.setMessage("Thank you for using ProMech. Chat with us if you find any difficulty.");
        msg.setMessageType("CONVERSATION_ENDED");
        msg.setSender("ADMIN");
        msg.setCreatedAt(LocalDateTime.now());
        UserHelpMessage saved = userHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    @PostMapping("/user-support/reply")
    public ResponseEntity<UserHelpMessage> replyToUserSupport(@RequestBody Map<String, Object> body) {
        String userEmail = body != null && body.get("userEmail") != null ? body.get("userEmail").toString().trim() : null;
        String message = body != null && body.get("message") != null ? body.get("message").toString().trim() : null;
        String imageUrl = body != null && body.get("imageUrl") != null ? body.get("imageUrl").toString().trim() : null;
        if (userEmail == null || userEmail.isBlank()) return ResponseEntity.badRequest().build();
        if ((message == null || message.isBlank()) && (imageUrl == null || imageUrl.isBlank()))
            return ResponseEntity.badRequest().build();
        UserHelpMessage msg = new UserHelpMessage();
        msg.setUserEmail(userEmail);
        msg.setMessage(message != null ? message : (imageUrl != null ? "[Photo]" : ""));
        msg.setImageUrl(imageUrl);
        msg.setMessageType(imageUrl != null && !imageUrl.isEmpty() ? "IMAGE" : "TEXT");
        msg.setSender("ADMIN");
        msg.setCreatedAt(LocalDateTime.now());
        UserHelpMessage saved = userHelpMessageRepo.save(msg);
        return ResponseEntity.status(HttpStatus.CREATED).body(saved);
    }

    // ========== MARKETING POSTER ==========
    @GetMapping("/poster")
    public ResponseEntity<MarketingPoster> getPoster() {
        return marketingPosterRepo.findFirstByOrderByIdDesc()
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/poster/all")
    public ResponseEntity<List<MarketingPoster>> getAllPosters() {
        return ResponseEntity.ok(marketingPosterRepo.findAll());
    }

    @PostMapping("/poster")
    public ResponseEntity<MarketingPoster> createPoster(@RequestBody Map<String, Object> body) {
        MarketingPoster p = new MarketingPoster();
        p.setImageUrl(body != null ? (String) body.get("imageUrl") : null);
        p.setLinkUrl(body != null ? (String) body.get("linkUrl") : null);
        p.setActive(body != null && body.get("active") != Boolean.FALSE);
        if (body != null) {
            p.setTargetCity((String) body.get("targetCity"));
            p.setTargetState((String) body.get("targetState"));
            if (body.get("targetLat") != null) p.setTargetLat(((Number) body.get("targetLat")).doubleValue());
            if (body.get("targetLng") != null) p.setTargetLng(((Number) body.get("targetLng")).doubleValue());
            if (body.get("targetRadiusKm") != null) p.setTargetRadiusKm(((Number) body.get("targetRadiusKm")).doubleValue());
        }
        return ResponseEntity.status(HttpStatus.CREATED).body(marketingPosterRepo.save(p));
    }

    @PutMapping("/poster/{id}")
    public ResponseEntity<MarketingPoster> updatePoster(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Optional<MarketingPoster> opt = marketingPosterRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        MarketingPoster p = opt.get();
        if (body != null) {
            if (body.containsKey("imageUrl")) p.setImageUrl((String) body.get("imageUrl"));
            if (body.containsKey("linkUrl")) p.setLinkUrl((String) body.get("linkUrl"));
            if (body.containsKey("active")) p.setActive((Boolean) body.get("active"));
            if (body.containsKey("targetCity")) p.setTargetCity((String) body.get("targetCity"));
            if (body.containsKey("targetState")) p.setTargetState((String) body.get("targetState"));
            if (body.containsKey("targetLat")) p.setTargetLat(body.get("targetLat") != null ? ((Number) body.get("targetLat")).doubleValue() : null);
            if (body.containsKey("targetLng")) p.setTargetLng(body.get("targetLng") != null ? ((Number) body.get("targetLng")).doubleValue() : null);
            if (body.containsKey("targetRadiusKm")) p.setTargetRadiusKm(body.get("targetRadiusKm") != null ? ((Number) body.get("targetRadiusKm")).doubleValue() : null);
        }
        return ResponseEntity.ok(marketingPosterRepo.save(p));
    }

    @DeleteMapping("/poster/{id}")
    public ResponseEntity<Void> deletePoster(@PathVariable Long id) {
        if (!marketingPosterRepo.existsById(id)) return ResponseEntity.notFound().build();
        marketingPosterRepo.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    // ========== SECTION POSTERS (below "Our Services" in app) ==========
    @GetMapping("/section-posters")
    public ResponseEntity<List<SectionPoster>> getSectionPosters(@RequestParam(defaultValue = "BELOW_SERVICES") String section) {
        return ResponseEntity.ok(sectionPosterRepo.findBySectionKeyOrderBySortOrderAsc(section));
    }

    @PostMapping("/section-posters")
    public ResponseEntity<SectionPoster> createSectionPoster(@RequestBody Map<String, Object> body) {
        SectionPoster p = new SectionPoster();
        p.setSectionKey(body != null ? (String) body.getOrDefault("sectionKey", "BELOW_SERVICES") : "BELOW_SERVICES");
        p.setImageUrl(body != null ? (String) body.get("imageUrl") : null);
        p.setLinkUrl(body != null ? (String) body.get("linkUrl") : null);
        p.setSortOrder(body != null && body.get("sortOrder") != null ? ((Number) body.get("sortOrder")).intValue() : 0);
        return ResponseEntity.status(HttpStatus.CREATED).body(sectionPosterRepo.save(p));
    }

    @PutMapping("/section-posters/{id}")
    public ResponseEntity<SectionPoster> updateSectionPoster(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Optional<SectionPoster> opt = sectionPosterRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        SectionPoster p = opt.get();
        if (body != null) {
            if (body.containsKey("imageUrl")) p.setImageUrl((String) body.get("imageUrl"));
            if (body.containsKey("linkUrl")) p.setLinkUrl((String) body.get("linkUrl"));
            if (body.containsKey("sortOrder")) p.setSortOrder(((Number) body.get("sortOrder")).intValue());
        }
        return ResponseEntity.ok(sectionPosterRepo.save(p));
    }

    @DeleteMapping("/section-posters/{id}")
    public ResponseEntity<Void> deleteSectionPoster(@PathVariable Long id) {
        if (!sectionPosterRepo.existsById(id)) return ResponseEntity.notFound().build();
        sectionPosterRepo.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    // ========== AUTH BACKGROUND VIDEO (login/signup) ==========
    @GetMapping("/auth-video")
    public ResponseEntity<Map<String, Object>> getAuthVideo() {
        Optional<AuthBackgroundVideo> opt = authBackgroundVideoRepo.findTop1ByOrderByIdDesc();
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of("id", (Object) null, "videoUrl", "", "active", false));
        }
        AuthBackgroundVideo c = opt.get();
        Map<String, Object> body = new HashMap<>();
        body.put("id", c.getId());
        body.put("videoUrl", c.getVideoUrl() != null ? c.getVideoUrl() : "");
        body.put("active", c.isActive());
        return ResponseEntity.ok(body);
    }

    @PutMapping("/auth-video")
    public ResponseEntity<AuthBackgroundVideo> updateAuthVideo(@RequestBody Map<String, Object> body) {
        String videoUrl = body != null && body.get("videoUrl") != null ? body.get("videoUrl").toString().trim() : null;
        Boolean active = body != null && body.get("active") != null ? Boolean.TRUE.equals(body.get("active")) : true;
        AuthBackgroundVideo c = authBackgroundVideoRepo.findTop1ByOrderByIdDesc().orElse(new AuthBackgroundVideo());
        c.setVideoUrl(videoUrl);
        c.setActive(active != null ? active : true);
        return ResponseEntity.ok(authBackgroundVideoRepo.save(c));
    }

    // ========== HOME HERO GRAPHIC (transparent overlay on red header) ==========
    @GetMapping("/home-hero-media")
    public ResponseEntity<Map<String, Object>> getHomeHeroMedia() {
        Optional<HomeHeroMedia> opt = homeHeroMediaRepo.findTop1ByOrderByIdDesc();
        if (opt.isEmpty()) {
            return ResponseEntity.ok(Map.of("id", (Object) null, "mediaType", "", "mediaUrl", "", "active", false));
        }
        HomeHeroMedia c = opt.get();
        Map<String, Object> out = new HashMap<>();
        out.put("id", c.getId());
        out.put("mediaType", c.getMediaType() != null ? c.getMediaType() : "");
        out.put("mediaUrl", c.getMediaUrl() != null ? c.getMediaUrl() : "");
        out.put("active", c.isActive());
        return ResponseEntity.ok(out);
    }

    @PutMapping("/home-hero-media")
    public ResponseEntity<HomeHeroMedia> updateHomeHeroMedia(@RequestBody Map<String, Object> body) {
        String mediaType = body != null && body.get("mediaType") != null ? body.get("mediaType").toString().trim().toLowerCase() : null;
        String mediaUrl = body != null && body.get("mediaUrl") != null ? body.get("mediaUrl").toString().trim() : null;
        Boolean active = body != null && body.get("active") != null ? Boolean.TRUE.equals(body.get("active")) : true;
        if (mediaType != null && !mediaType.isEmpty() && !"lottie".equals(mediaType) && !"gif".equals(mediaType)) {
            mediaType = "lottie";
        }
        HomeHeroMedia c = homeHeroMediaRepo.findTop1ByOrderByIdDesc().orElse(new HomeHeroMedia());
        if (mediaType != null) c.setMediaType(mediaType);
        c.setMediaUrl(mediaUrl);
        c.setActive(active != null ? active : true);
        return ResponseEntity.ok(homeHeroMediaRepo.save(c));
    }

    // ========== APP BRANDING (logo, splash, welcome title) ==========
    @GetMapping("/app-branding")
    public ResponseEntity<Map<String, Object>> getAppBranding() {
        Optional<AppBranding> opt = appBrandingRepo.findTop1ByOrderByIdDesc();
        if (opt.isEmpty()) {
            Map<String, Object> out = new HashMap<>();
            out.put("id", null);
            out.put("appLogoUrl", "");
            out.put("splashMediaUrl", "");
            out.put("splashMediaType", "");
            out.put("welcomeTitle", "Welcome to ProMech");
            out.put("welcomePageMediaUrl", "");
            out.put("welcomePageMediaType", "");
            out.put("welcomePageGifUrl", "");
            out.put("loadingMediaUrl", "");
            out.put("loadingMediaType", "");
            out.put("nearestMechanicMarkerIconUrl", "");
            out.put("userLocationMarkerIconUrl", "");
            out.put("carServiceImageUrl", "");
            out.put("bikeServiceImageUrl", "");
            out.put("quickServiceNightServiceIconUrl", "");
            out.put("quickServiceTowingIconUrl", "");
            out.put("quickServiceFuelRefillIconUrl", "");
            out.put("quickServiceEvChargingIconUrl", "");
            out.put("quickServiceTyreCareIconUrl", "");
            out.put("quickServiceMinorRepairIconUrl", "");
            out.put("quickServiceBatteryJumpIconUrl", "");
            out.put("problemCategoryIconsJson", "");
            return ResponseEntity.ok(out);
        }
        AppBranding c = opt.get();
        Map<String, Object> out = new HashMap<>();
        out.put("id", c.getId());
        out.put("appLogoUrl", c.getAppLogoUrl() != null ? c.getAppLogoUrl() : "");
        out.put("splashMediaUrl", c.getSplashMediaUrl() != null ? c.getSplashMediaUrl() : "");
        out.put("splashMediaType", c.getSplashMediaType() != null ? c.getSplashMediaType() : "");
        out.put("welcomeTitle", c.getWelcomeTitle() != null && !c.getWelcomeTitle().isEmpty() ? c.getWelcomeTitle() : "Welcome to ProMech");
        out.put("welcomePageMediaUrl", c.getWelcomePageMediaUrl() != null ? c.getWelcomePageMediaUrl() : "");
        out.put("welcomePageMediaType", c.getWelcomePageMediaType() != null ? c.getWelcomePageMediaType() : "");
        out.put("welcomePageGifUrl", c.getWelcomePageGifUrl() != null ? c.getWelcomePageGifUrl() : "");
        out.put("loadingMediaUrl", c.getLoadingMediaUrl() != null ? c.getLoadingMediaUrl() : "");
        out.put("loadingMediaType", c.getLoadingMediaType() != null ? c.getLoadingMediaType() : "");
        out.put("nearestMechanicMarkerIconUrl", c.getNearestMechanicMarkerIconUrl() != null ? c.getNearestMechanicMarkerIconUrl() : "");
        out.put("userLocationMarkerIconUrl", c.getUserLocationMarkerIconUrl() != null ? c.getUserLocationMarkerIconUrl() : "");
        out.put("carServiceImageUrl", c.getCarServiceImageUrl() != null ? c.getCarServiceImageUrl() : "");
        out.put("bikeServiceImageUrl", c.getBikeServiceImageUrl() != null ? c.getBikeServiceImageUrl() : "");
        out.put("quickServiceNightServiceIconUrl", c.getQuickServiceNightServiceIconUrl() != null ? c.getQuickServiceNightServiceIconUrl() : "");
        out.put("quickServiceTowingIconUrl", c.getQuickServiceTowingIconUrl() != null ? c.getQuickServiceTowingIconUrl() : "");
        out.put("quickServiceFuelRefillIconUrl", c.getQuickServiceFuelRefillIconUrl() != null ? c.getQuickServiceFuelRefillIconUrl() : "");
        out.put("quickServiceEvChargingIconUrl", c.getQuickServiceEvChargingIconUrl() != null ? c.getQuickServiceEvChargingIconUrl() : "");
        out.put("quickServiceTyreCareIconUrl", c.getQuickServiceTyreCareIconUrl() != null ? c.getQuickServiceTyreCareIconUrl() : "");
        out.put("quickServiceMinorRepairIconUrl", c.getQuickServiceMinorRepairIconUrl() != null ? c.getQuickServiceMinorRepairIconUrl() : "");
        out.put("quickServiceBatteryJumpIconUrl", c.getQuickServiceBatteryJumpIconUrl() != null ? c.getQuickServiceBatteryJumpIconUrl() : "");
        out.put("problemCategoryIconsJson", c.getProblemCategoryIconsJson() != null ? c.getProblemCategoryIconsJson() : "");
        return ResponseEntity.ok(out);
    }

    @PutMapping("/app-branding")
    public ResponseEntity<AppBranding> updateAppBranding(@RequestBody Map<String, Object> body) {
        String appLogoUrl = body != null && body.get("appLogoUrl") != null ? body.get("appLogoUrl").toString().trim() : null;
        String splashMediaUrl = body != null && body.get("splashMediaUrl") != null ? body.get("splashMediaUrl").toString().trim() : null;
        String splashMediaType = body != null && body.get("splashMediaType") != null ? body.get("splashMediaType").toString().trim().toLowerCase() : null;
        String welcomeTitle = body != null && body.get("welcomeTitle") != null ? body.get("welcomeTitle").toString().trim() : null;
        String welcomePageMediaUrl = body != null && body.get("welcomePageMediaUrl") != null ? body.get("welcomePageMediaUrl").toString().trim() : null;
        String welcomePageMediaType = body != null && body.get("welcomePageMediaType") != null ? body.get("welcomePageMediaType").toString().trim().toLowerCase() : null;
        String welcomePageGifUrl = body != null && body.get("welcomePageGifUrl") != null ? body.get("welcomePageGifUrl").toString().trim() : null;
        String loadingMediaUrl = body != null && body.get("loadingMediaUrl") != null ? body.get("loadingMediaUrl").toString().trim() : null;
        String loadingMediaType = body != null && body.get("loadingMediaType") != null ? body.get("loadingMediaType").toString().trim().toLowerCase() : null;
        String nearestMechanicMarkerIconUrl = body != null && body.get("nearestMechanicMarkerIconUrl") != null ? body.get("nearestMechanicMarkerIconUrl").toString().trim() : null;
        String userLocationMarkerIconUrl = body != null && body.get("userLocationMarkerIconUrl") != null ? body.get("userLocationMarkerIconUrl").toString().trim() : null;
        String carServiceImageUrl = body != null && body.get("carServiceImageUrl") != null ? body.get("carServiceImageUrl").toString().trim() : null;
        String bikeServiceImageUrl = body != null && body.get("bikeServiceImageUrl") != null ? body.get("bikeServiceImageUrl").toString().trim() : null;
        String quickServiceNightServiceIconUrl = body != null && body.get("quickServiceNightServiceIconUrl") != null ? body.get("quickServiceNightServiceIconUrl").toString().trim() : null;
        String quickServiceTowingIconUrl = body != null && body.get("quickServiceTowingIconUrl") != null ? body.get("quickServiceTowingIconUrl").toString().trim() : null;
        String quickServiceFuelRefillIconUrl = body != null && body.get("quickServiceFuelRefillIconUrl") != null ? body.get("quickServiceFuelRefillIconUrl").toString().trim() : null;
        String quickServiceEvChargingIconUrl = body != null && body.get("quickServiceEvChargingIconUrl") != null ? body.get("quickServiceEvChargingIconUrl").toString().trim() : null;
        String quickServiceTyreCareIconUrl = body != null && body.get("quickServiceTyreCareIconUrl") != null ? body.get("quickServiceTyreCareIconUrl").toString().trim() : null;
        String quickServiceMinorRepairIconUrl = body != null && body.get("quickServiceMinorRepairIconUrl") != null ? body.get("quickServiceMinorRepairIconUrl").toString().trim() : null;
        String quickServiceBatteryJumpIconUrl = body != null && body.get("quickServiceBatteryJumpIconUrl") != null ? body.get("quickServiceBatteryJumpIconUrl").toString().trim() : null;
        String problemCategoryIconsJson = body != null && body.get("problemCategoryIconsJson") != null ? body.get("problemCategoryIconsJson").toString().trim() : null;
        if (splashMediaType != null && !splashMediaType.isEmpty() && !"lottie".equals(splashMediaType) && !"gif".equals(splashMediaType) && !"video".equals(splashMediaType)) {
            splashMediaType = "lottie";
        }
        if (welcomePageMediaType != null && !welcomePageMediaType.isEmpty() && !"gif".equals(welcomePageMediaType) && !"video".equals(welcomePageMediaType)) {
            welcomePageMediaType = "gif";
        }
        if (loadingMediaType != null && !loadingMediaType.isEmpty() && !"lottie".equals(loadingMediaType) && !"gif".equals(loadingMediaType)) {
            loadingMediaType = "gif";
        }
        AppBranding c = appBrandingRepo.findTop1ByOrderByIdDesc().orElse(new AppBranding());
        if (appLogoUrl != null) c.setAppLogoUrl(appLogoUrl);
        if (splashMediaUrl != null) c.setSplashMediaUrl(splashMediaUrl);
        if (splashMediaType != null) c.setSplashMediaType(splashMediaType);
        if (welcomeTitle != null) c.setWelcomeTitle(welcomeTitle);
        if (welcomePageMediaUrl != null) c.setWelcomePageMediaUrl(welcomePageMediaUrl);
        if (welcomePageMediaType != null) c.setWelcomePageMediaType(welcomePageMediaType);
        if (welcomePageGifUrl != null) c.setWelcomePageGifUrl(welcomePageGifUrl);
        if (loadingMediaUrl != null) c.setLoadingMediaUrl(loadingMediaUrl);
        if (loadingMediaType != null) c.setLoadingMediaType(loadingMediaType);
        if (nearestMechanicMarkerIconUrl != null) c.setNearestMechanicMarkerIconUrl(nearestMechanicMarkerIconUrl);
        if (userLocationMarkerIconUrl != null) c.setUserLocationMarkerIconUrl(userLocationMarkerIconUrl);
        if (carServiceImageUrl != null) c.setCarServiceImageUrl(carServiceImageUrl);
        if (bikeServiceImageUrl != null) c.setBikeServiceImageUrl(bikeServiceImageUrl);
        if (quickServiceNightServiceIconUrl != null) c.setQuickServiceNightServiceIconUrl(quickServiceNightServiceIconUrl);
        if (quickServiceTowingIconUrl != null) c.setQuickServiceTowingIconUrl(quickServiceTowingIconUrl);
        if (quickServiceFuelRefillIconUrl != null) c.setQuickServiceFuelRefillIconUrl(quickServiceFuelRefillIconUrl);
        if (quickServiceEvChargingIconUrl != null) c.setQuickServiceEvChargingIconUrl(quickServiceEvChargingIconUrl);
        if (quickServiceTyreCareIconUrl != null) c.setQuickServiceTyreCareIconUrl(quickServiceTyreCareIconUrl);
        if (quickServiceMinorRepairIconUrl != null) c.setQuickServiceMinorRepairIconUrl(quickServiceMinorRepairIconUrl);
        if (quickServiceBatteryJumpIconUrl != null) c.setQuickServiceBatteryJumpIconUrl(quickServiceBatteryJumpIconUrl);
        if (problemCategoryIconsJson != null) c.setProblemCategoryIconsJson(problemCategoryIconsJson);
        return ResponseEntity.ok(appBrandingRepo.save(c));
    }

    // ========== APP VERSION (force update) ==========
    @GetMapping("/app-version")
    public ResponseEntity<AppVersionConfig> getAppVersion() {
        List<AppVersionConfig> all = appVersionConfigRepo.findAll();
        AppVersionConfig c = all.isEmpty() ? null : all.stream().max(Comparator.comparing(AppVersionConfig::getId)).orElse(null);
        return c != null ? ResponseEntity.ok(c) : ResponseEntity.notFound().build();
    }

    @PostMapping("/app-version")
    public ResponseEntity<AppVersionConfig> saveAppVersion(@RequestBody Map<String, Object> body) {
        AppVersionConfig c = new AppVersionConfig();
        if (body != null) {
            c.setLatestVersion((String) body.get("latestVersion"));
            c.setMinRequiredVersion((String) body.get("minRequiredVersion"));
            c.setUpdateTitle((String) body.get("updateTitle"));
            c.setUpdateMessage((String) body.get("updateMessage"));
        }
        return ResponseEntity.ok(appVersionConfigRepo.save(c));
    }

    @PutMapping("/app-version/{id}")
    public ResponseEntity<AppVersionConfig> updateAppVersion(@PathVariable Long id, @RequestBody Map<String, Object> body) {
        Optional<AppVersionConfig> opt = appVersionConfigRepo.findById(id);
        if (opt.isEmpty()) return ResponseEntity.notFound().build();
        AppVersionConfig c = opt.get();
        if (body != null) {
            if (body.containsKey("latestVersion")) c.setLatestVersion((String) body.get("latestVersion"));
            if (body.containsKey("minRequiredVersion")) c.setMinRequiredVersion((String) body.get("minRequiredVersion"));
            if (body.containsKey("updateTitle")) c.setUpdateTitle((String) body.get("updateTitle"));
            if (body.containsKey("updateMessage")) c.setUpdateMessage((String) body.get("updateMessage"));
        }
        return ResponseEntity.ok(appVersionConfigRepo.save(c));
    }
}

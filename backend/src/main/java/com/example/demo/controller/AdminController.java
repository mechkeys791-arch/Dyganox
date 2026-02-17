package com.example.demo.controller;

import com.example.demo.model.Banner;
import com.example.demo.model.Mechanic;
import com.example.demo.model.MechanicHelpMessage;
import com.example.demo.model.MechanicRequest;
import com.example.demo.model.Payment;
import com.example.demo.model.Person;
import com.example.demo.repository.BannerRepo;
import com.example.demo.repository.MechanicHelpMessageRepo;
import com.example.demo.repository.MechanicRepo;
import com.example.demo.repository.MechanicRequestRepo;
import com.example.demo.repository.PaymentRepo;
import com.example.demo.repository.PersonRepo;
import com.example.demo.repository.UserAddressRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/admin")
@CrossOrigin(origins = "*")
public class AdminController {

    @Autowired
    private MechanicRepo mechanicRepo;

    @Autowired
    private MechanicRequestRepo mechanicRequestRepo;

    @Autowired
    private PaymentRepo paymentRepo;

    @Autowired
    private PersonRepo personRepo;

    @Autowired
    private BannerRepo bannerRepo;

    @Autowired
    private UserAddressRepo userAddressRepo;

    @Autowired
    private MechanicHelpMessageRepo mechanicHelpMessageRepo;

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

    // Get analytics/dashboard stats
    @GetMapping("/analytics")
    public ResponseEntity<Map<String, Object>> getAnalytics() {
        try {
            System.out.println("[Admin] /analytics requested");
            Map<String, Object> analytics = new HashMap<>();
            
            // Total mechanics
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
            
            // Service requests stats
            List<MechanicRequest> allRequests = mechanicRequestRepo.findAll();
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
            
            // Calculate total revenue from completed requests
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
            
            // Recent requests (last 7 days)
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

    // Manually create mechanic (admin)
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
}
